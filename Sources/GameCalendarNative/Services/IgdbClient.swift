import Foundation

struct IgdbClient {
    private let credentials: IgdbCredentials
    private let tokenService: IgdbTokenService

    private static let pageSize = 200
    private static let targetPlatformIds = [6, 48, 49, 130, 167, 169]
    static let platformNames: [Int: String] = [
        6: "PC",
        48: "PlayStation", 167: "PlayStation",
        49: "Xbox", 169: "Xbox",
        130: "Switch",
    ]

    init(credentials: IgdbCredentials, tokenService: IgdbTokenService) {
        self.credentials = credentials
        self.tokenService = tokenService
    }

    // MARK: - Public

    func fetchGames(from cutoffDate: Date, to endDate: Date? = nil, updatedSince: Date?) async throws -> [NormalizedGame] {
        let token = try await tokenService.getToken(
            clientId: credentials.clientId,
            clientSecret: credentials.clientSecret
        )
        let unixFrom = Int(cutoffDate.timeIntervalSince1970)
        let toClause = endDate.map { " & first_release_date < \(Int($0.timeIntervalSince1970))" } ?? ""
        let platformFilter = Self.targetPlatformIds.map(String.init).joined(separator: ",")
        let sinceClause = sinceFilter(updatedSince)

        let fields = igdbFields
        var all: [IgdbGame] = []
        var offset = 0

        while true {
            let query = "\(fields) where first_release_date >= \(unixFrom)\(toClause) & platforms = (\(platformFilter))\(sinceClause); sort first_release_date asc; limit \(Self.pageSize); offset \(offset);"
            let page = try await fetchPage(query: query, token: token)
            all.append(contentsOf: page)
            if page.count < Self.pageSize { break }
            offset += Self.pageSize
        }

        return all.map(toNormalized)
    }

    func fetchTbaGames(updatedSince: Date?) async throws -> [NormalizedGame] {
        let token = try await tokenService.getToken(
            clientId: credentials.clientId,
            clientSecret: credentials.clientSecret
        )
        let platformFilter = Self.targetPlatformIds.map(String.init).joined(separator: ",")
        let sinceClause = sinceFilter(updatedSince)

        let fields = igdbFields
        var all: [IgdbGame] = []
        var offset = 0

        while true {
            let query = "\(fields) where first_release_date = null & platforms = (\(platformFilter)) & hypes > 0\(sinceClause); sort hypes desc; limit \(Self.pageSize); offset \(offset);"
            let page = try await fetchPage(query: query, token: token)
            all.append(contentsOf: page)
            if page.count < Self.pageSize { break }
            offset += Self.pageSize
        }

        return all.map(toNormalized)
    }

    // MARK: - Private

    private var igdbFields: String {
        "fields id, name, first_release_date, cover.url, summary, platforms.id, platforms.name, genres.name, age_ratings.category, age_ratings.rating, hypes, total_rating_count, total_rating, videos.video_id, videos.name, screenshots.url, involved_companies.developer, involved_companies.publisher, involved_companies.company.name, websites.category, websites.url, themes.id;"
    }

    private func sinceFilter(_ date: Date?) -> String {
        guard let date else { return "" }
        return " & updated_at >= \(Int(date.timeIntervalSince1970))"
    }

    private func fetchPage(query: String, token: String) async throws -> [IgdbGame] {
        var request = URLRequest(url: URL(string: "https://api.igdb.com/v4/games")!)
        request.httpMethod = "POST"
        request.setValue(credentials.clientId, forHTTPHeaderField: "Client-ID")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = Data(query.utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard statusCode == 200 else { throw IgdbError.requestFailed(statusCode) }

        return try JSONDecoder().decode([IgdbGame].self, from: data)
    }

    private func toNormalized(_ g: IgdbGame) -> NormalizedGame {
        let releaseDate: Date? = g.firstReleaseDate.map {
            Date(timeIntervalSince1970: TimeInterval($0))
        }

        let coverUrl: String? = g.cover.flatMap { cover -> String? in
            guard let raw = cover.url else { return nil }
            let url = raw.hasPrefix("//") ? "https:" + raw : raw
            return url.replacingOccurrences(of: "t_thumb", with: "t_720p")
        }

        let platforms = (g.platforms ?? [])
            .compactMap { Self.platformNames[$0.id] }
            .uniqued()

        let genres = (g.genres ?? [])
            .compactMap(\.name)
            .filter { !$0.isEmpty }
            .uniqued()

        let videoIds = Array(
            (g.videos ?? []).compactMap(\.videoId).filter { !$0.isEmpty }.prefix(2)
        )

        let screenshotUrls = Array(
            (g.screenshots ?? []).compactMap { shot -> String? in
                guard let raw = shot.url else { return nil }
                let url = raw.hasPrefix("//") ? "https:" + raw : raw
                return url.replacingOccurrences(of: "t_thumb", with: "t_1080p")
            }.prefix(5)
        )

        let developer = g.involvedCompanies?.first { $0.developer == true }?.company?.name ?? nil
        let publisher = g.involvedCompanies?.first { $0.publisher == true }?.company?.name ?? nil
        let websiteUrl = extractWebsiteUrl(g.websites)

        let contentJson = (try? JSONEncoder().encode(g))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"

        return NormalizedGame(
            externalId: String(g.id),
            source: "igdb",
            title: g.name,
            releaseDate: releaseDate,
            releaseWindow: nil,
            coverImageUrl: coverUrl,
            description: g.summary,
            contentJson: contentJson,
            platforms: platforms,
            genres: genres,
            ageRating: extractAgeRating(g.ageRatings),
            popularity: g.totalRatingCount ?? g.hypes ?? 0,
            rating: g.totalRating,
            videoIds: videoIds,
            screenshotUrls: screenshotUrls,
            developer: developer,
            publisher: publisher,
            websiteUrl: websiteUrl,
            themeIds: (g.themes ?? []).map(\.id)
        )
    }

    private func extractWebsiteUrl(_ sites: [IgdbWebsite]?) -> String? {
        guard let sites, !sites.isEmpty else { return nil }
        return sites.first { $0.category == 1 }.flatMap(\.url)   // Official
            ?? sites.first { $0.category == 13 }.flatMap(\.url)  // Steam
            ?? sites.first { $0.category == 16 }.flatMap(\.url)  // Epic
            ?? sites.first { $0.category == 17 }.flatMap(\.url)  // GOG
    }

    private func extractAgeRating(_ ratings: [IgdbAgeRating]?) -> String? {
        guard let ratings else { return nil }
        if let pegi = ratings.first(where: { $0.category == 2 }) {
            switch pegi.rating {
            case 1: return "3+"
            case 2: return "7+"
            case 3: return "12+"
            case 4: return "16+"
            case 5: return "18+"
            default: break
            }
        }
        if let esrb = ratings.first(where: { $0.category == 1 }) {
            switch esrb.rating {
            case 7, 8: return "3+"    // EC / E
            case 9:    return "12+"   // E10+
            case 10:   return "16+"   // T
            case 11, 12: return "18+" // M / AO
            default: break
            }
        }
        return nil
    }

}

// MARK: - Sequence helpers

private extension Sequence where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
