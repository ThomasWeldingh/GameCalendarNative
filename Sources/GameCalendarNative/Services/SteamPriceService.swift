import Foundation
import SwiftData

/// Fetches game prices from Steam's storefront API in USD and NOK.
/// Rate-limited to ~200 requests per 5 minutes.
actor SteamPriceService {
    static let shared = SteamPriceService()

    private let session = URLSession.shared
    private let baseURL = "https://store.steampowered.com/api/appdetails"
    private let delayBetweenRequests: UInt64 = 1_500_000_000  // 1.5 seconds in nanoseconds

    // MARK: - Steam API response types

    struct SteamResponse: Codable {
        let success: Bool
        let data: SteamAppData?
    }

    struct SteamAppData: Codable {
        let isFree: Bool?
        let priceOverview: PriceOverview?

        enum CodingKeys: String, CodingKey {
            case isFree = "is_free"
            case priceOverview = "price_overview"
        }
    }

    struct PriceOverview: Codable {
        let currency: String
        let initial: Int       // Price in cents (øre)
        let final: Int         // Price in cents after discount
        let discountPercent: Int

        enum CodingKeys: String, CodingKey {
            case currency
            case initial
            case final = "final"
            case discountPercent = "discount_percent"
        }
    }

    // MARK: - Fetch prices for wishlisted games

    /// Fetches Steam prices for all wishlisted games that have a steamAppId.
    /// Only fetches if cached price is older than 24 hours.
    @MainActor
    func fetchPricesForWishlist(container: ModelContainer) async {
        let context = ModelContext(container)

        // Get all wishlisted games with Steam App IDs
        let wishlistDescriptor = FetchDescriptor<WishlistEntry>()
        guard let entries = try? context.fetch(wishlistDescriptor) else { return }

        let gamesWithSteam = entries.compactMap { entry -> (String, String)? in
            guard let steamId = entry.game.steamAppId else { return nil }
            return (steamId, entry.game.externalId)
        }

        guard !gamesWithSteam.isEmpty else { return }

        // Check which ones need refreshing
        for (steamAppId, gameExternalId) in gamesWithSteam {
            // Check if we already have a fresh price
            let predicate = #Predicate<SteamPrice> { $0.steamAppId == steamAppId }
            var descriptor = FetchDescriptor(predicate: predicate)
            descriptor.fetchLimit = 1
            if let existing = try? context.fetch(descriptor).first, !existing.isStale {
                continue
            }

            // Fetch from Steam API
            do {
                let price = try await fetchPrice(steamAppId: steamAppId, gameExternalId: gameExternalId)

                // Upsert
                if let existing = try? context.fetch(descriptor).first {
                    existing.priceUsdCents = price.priceUsdCents
                    existing.priceNokCents = price.priceNokCents
                    existing.discountPercent = price.discountPercent
                    existing.isFree = price.isFree
                    existing.fetchedAt = Date()
                } else {
                    context.insert(price)
                }

                try? context.save()
            } catch {
                // Skip this game, continue with others
                continue
            }

            // Rate limiting
            try? await Task.sleep(nanoseconds: delayBetweenRequests)
        }
    }

    // MARK: - Fetch single game price

    private func fetchPrice(steamAppId: String, gameExternalId: String) async throws -> SteamPrice {
        // Fetch USD price
        let usdPrice = try await fetchRegionPrice(steamAppId: steamAppId, countryCode: "us")

        // Small delay between requests
        try? await Task.sleep(nanoseconds: 500_000_000)

        // Fetch NOK price
        let nokPrice = try await fetchRegionPrice(steamAppId: steamAppId, countryCode: "no")

        let isFree = usdPrice?.isFree ?? nokPrice?.isFree ?? false

        return SteamPrice(
            steamAppId: steamAppId,
            gameExternalId: gameExternalId,
            priceUsdCents: usdPrice?.priceCents,
            priceNokCents: nokPrice?.priceCents,
            discountPercent: usdPrice?.discountPercent ?? 0,
            isFree: isFree
        )
    }

    struct RegionPriceResult {
        let priceCents: Int?
        let discountPercent: Int
        let isFree: Bool
    }

    private func fetchRegionPrice(steamAppId: String, countryCode: String) async throws -> RegionPriceResult? {
        guard let url = URL(string: "\(baseURL)?appids=\(steamAppId)&cc=\(countryCode)") else {
            return nil
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            return nil
        }

        // Steam returns: { "123456": { "success": true, "data": {...} } }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let appData = json[steamAppId] as? [String: Any],
              let success = appData["success"] as? Bool, success,
              let innerData = appData["data"] as? [String: Any] else {
            return nil
        }

        let isFree = innerData["is_free"] as? Bool ?? false

        if isFree {
            return RegionPriceResult(priceCents: 0, discountPercent: 0, isFree: true)
        }

        guard let priceOverview = innerData["price_overview"] as? [String: Any] else {
            return RegionPriceResult(priceCents: nil, discountPercent: 0, isFree: false)
        }

        let finalPrice = priceOverview["final"] as? Int
        let discountPercent = priceOverview["discount_percent"] as? Int ?? 0

        return RegionPriceResult(priceCents: finalPrice, discountPercent: discountPercent, isFree: false)
    }
}
