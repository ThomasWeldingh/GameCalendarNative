import Foundation
import SwiftData

@Model
final class SteamPrice {
    @Attribute(.unique) var steamAppId: String
    var gameExternalId: String
    var priceUsdCents: Int?
    var priceNokCents: Int?
    var discountPercent: Int
    var isFree: Bool
    var fetchedAt: Date

    init(
        steamAppId: String,
        gameExternalId: String,
        priceUsdCents: Int? = nil,
        priceNokCents: Int? = nil,
        discountPercent: Int = 0,
        isFree: Bool = false
    ) {
        self.steamAppId = steamAppId
        self.gameExternalId = gameExternalId
        self.priceUsdCents = priceUsdCents
        self.priceNokCents = priceNokCents
        self.discountPercent = discountPercent
        self.isFree = isFree
        self.fetchedAt = Date()
    }

    // MARK: - Formatted prices

    var formattedUsd: String? {
        guard let cents = priceUsdCents else { return nil }
        if isFree { return "Gratis" }
        let dollars = Double(cents) / 100.0
        return String(format: "$%.2f", dollars)
    }

    var formattedNok: String? {
        guard let cents = priceNokCents else { return nil }
        if isFree { return "Gratis" }
        let kroner = Double(cents) / 100.0
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "NOK"
        formatter.locale = Locale(identifier: "nb_NO")
        return formatter.string(from: NSNumber(value: kroner))
    }

    var isStale: Bool {
        let hours24 = TimeInterval(24 * 60 * 60)
        return Date().timeIntervalSince(fetchedAt) > hours24
    }
}
