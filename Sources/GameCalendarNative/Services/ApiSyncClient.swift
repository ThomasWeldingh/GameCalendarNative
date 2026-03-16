import Foundation

/// Fetches game data from the backend API instead of IGDB directly.
/// The backend already has all ~28,500 games processed and ready.
struct ApiSyncClient {
    let baseURL: URL

    init(baseURL: URL) {
        self.baseURL = baseURL
    }

    /// Fetches dated games from `GET /api/calendar` (1 year back by default).
    func fetchDatedGames() async throws -> [NormalizedGame] {
        let url = baseURL.appendingPathComponent("api/calendar")
        let items: [ApiCalendarItem] = try await fetch(url)
        return items.map { $0.toNormalized() }
    }

    /// Fetches TBA/announced games from `GET /api/announced`.
    func fetchTbaGames() async throws -> [NormalizedGame] {
        let url = baseURL.appendingPathComponent("api/announced")
        let items: [ApiCalendarItem] = try await fetch(url)
        return items.map { $0.toNormalized() }
    }

    private func fetch<T: Decodable>(_ url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.timeoutInterval = 60
        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200...299).contains(statusCode) else {
            throw ApiSyncError.requestFailed(statusCode)
        }
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }
}

enum ApiSyncError: LocalizedError {
    case requestFailed(Int)

    var errorDescription: String? {
        switch self {
        case .requestFailed(let code):
            return "API request failed with status \(code)"
        }
    }
}

// MARK: - DTO matching backend CalendarItem JSON

struct ApiCalendarItem: Decodable {
    let id: Int
    let title: String
    let date: String?
    let releaseWindow: String?
    let description: String?
    let coverImageUrl: String?
    let platforms: [String]
    let genres: [String]
    let popularity: Int
    let rating: Double?
    let videoIds: [String]
    let screenshotUrls: [String]
    let developer: String?
    let publisher: String?
    let websiteUrl: String?
}

private let iso8601DateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(identifier: "UTC")
    return formatter
}()

extension ApiCalendarItem {
    func toNormalized() -> NormalizedGame {
        let releaseDate: Date? = date.flatMap { iso8601DateFormatter.date(from: $0) }

        // Build a stable JSON representation for content hashing
        let contentJson = buildContentJson()

        return NormalizedGame(
            externalId: String(id),
            source: "api",
            title: title,
            releaseDate: releaseDate,
            releaseWindow: releaseWindow,
            coverImageUrl: coverImageUrl,
            description: description,
            contentJson: contentJson,
            platforms: platforms,
            genres: genres,
            ageRating: nil,
            popularity: popularity,
            rating: rating,
            videoIds: videoIds,
            screenshotUrls: screenshotUrls,
            developer: developer,
            publisher: publisher,
            websiteUrl: websiteUrl,
            steamAppId: Self.extractSteamAppId(from: websiteUrl),
            themeIds: [],
            similarGameIds: []
        )
    }

    /// Extract Steam App ID from a website URL if it's a Steam store link
    static func extractSteamAppId(from url: String?) -> String? {
        guard let url, url.contains("steampowered.com") else { return nil }
        let parts = url.components(separatedBy: "/")
        guard let appIndex = parts.firstIndex(of: "app"),
              appIndex + 1 < parts.count else { return nil }
        let appId = parts[appIndex + 1]
        return appId.allSatisfy(\.isNumber) ? appId : nil
    }

    private func buildContentJson() -> String {
        // Encode self to JSON for stable content hashing
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        guard let data = try? encoder.encode(CodableItem(from: self)),
              let json = String(data: data, encoding: .utf8) else {
            return "{\"id\":\(id)}"
        }
        return json
    }
}

/// Encodable wrapper for stable JSON serialization (used for content hashing).
private struct CodableItem: Encodable {
    let id: Int
    let title: String
    let date: String?
    let releaseWindow: String?
    let description: String?
    let coverImageUrl: String?
    let platforms: [String]
    let genres: [String]
    let popularity: Int
    let rating: Double?
    let videoIds: [String]
    let screenshotUrls: [String]
    let developer: String?
    let publisher: String?
    let websiteUrl: String?

    init(from item: ApiCalendarItem) {
        self.id = item.id
        self.title = item.title
        self.date = item.date
        self.releaseWindow = item.releaseWindow
        self.description = item.description
        self.coverImageUrl = item.coverImageUrl
        self.platforms = item.platforms
        self.genres = item.genres
        self.popularity = item.popularity
        self.rating = item.rating
        self.videoIds = item.videoIds
        self.screenshotUrls = item.screenshotUrls
        self.developer = item.developer
        self.publisher = item.publisher
        self.websiteUrl = item.websiteUrl
    }
}
