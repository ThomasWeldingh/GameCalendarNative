import Foundation

/// Fetches game news/updates from Steam's public News API.
actor SteamNewsService {
    static let shared = SteamNewsService()

    private let session = URLSession.shared
    private let baseURL = "https://api.steampowered.com/ISteamNews/GetNewsForApp/v2"

    struct SteamNewsResponse: Codable {
        let appnews: AppNews?
    }

    struct AppNews: Codable {
        let newsitems: [NewsItem]?
    }

    struct NewsItem: Codable, Identifiable {
        let gid: String
        let title: String
        let url: String
        let author: String?
        let contents: String
        let feedlabel: String?
        let date: Int           // Unix timestamp
        let feedname: String?

        var id: String { gid }

        var dateFormatted: Date {
            Date(timeIntervalSince1970: TimeInterval(date))
        }

        /// Strip BB-code and HTML tags for a clean preview
        var cleanContents: String {
            var text = contents
            // Remove BB code tags like [h1], [b], [url=...], etc.
            text = text.replacingOccurrences(of: "\\[/?[a-zA-Z0-9=\" ]*\\]", with: "", options: .regularExpression)
            // Remove HTML tags
            text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            // Collapse whitespace
            text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    /// Fetch recent news for a Steam app. Returns up to `count` items.
    func fetchNews(steamAppId: String, count: Int = 5) async -> [NewsItem] {
        guard let url = URL(string: "\(baseURL)?appid=\(steamAppId)&count=\(count)&maxlength=500&format=json") else {
            return []
        }

        do {
            let (data, response) = try await session.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return []
            }
            let decoded = try JSONDecoder().decode(SteamNewsResponse.self, from: data)
            return decoded.appnews?.newsitems ?? []
        } catch {
            return []
        }
    }
}
