import Foundation

// MARK: - IGDB API response models (mirror of the C# IgdbModels.cs)

struct IgdbGame: Codable {
    let id: Int
    let name: String
    let firstReleaseDate: Int?
    let cover: IgdbCover?
    let summary: String?
    let platforms: [IgdbPlatform]?
    let genres: [IgdbGenre]?
    let ageRatings: [IgdbAgeRating]?
    let hypes: Int?
    let totalRatingCount: Int?
    let totalRating: Double?
    let videos: [IgdbVideo]?
    let screenshots: [IgdbScreenshot]?
    let involvedCompanies: [IgdbInvolvedCompany]?
    let websites: [IgdbWebsite]?
    let themes: [IgdbTheme]?

    enum CodingKeys: String, CodingKey {
        case id, name, cover, summary, platforms, genres, hypes, videos, screenshots, websites, themes
        case firstReleaseDate = "first_release_date"
        case ageRatings = "age_ratings"
        case totalRatingCount = "total_rating_count"
        case totalRating = "total_rating"
        case involvedCompanies = "involved_companies"
    }
}

struct IgdbCover: Codable {
    let url: String?
}

struct IgdbPlatform: Codable {
    let id: Int
    let name: String
}

struct IgdbGenre: Codable {
    let name: String
}

struct IgdbAgeRating: Codable {
    /// 1 = ESRB, 2 = PEGI
    let category: Int
    let rating: Int
}

struct IgdbTheme: Codable {
    let id: Int
}

struct IgdbVideo: Codable {
    let videoId: String
    let name: String

    enum CodingKeys: String, CodingKey {
        case name
        case videoId = "video_id"
    }
}

struct IgdbScreenshot: Codable {
    let url: String
}

struct IgdbInvolvedCompany: Codable {
    let developer: Bool
    let publisher: Bool
    let company: IgdbCompany?
}

struct IgdbCompany: Codable {
    let name: String
}

struct IgdbWebsite: Codable {
    /// 1=Official 13=Steam 16=Epic 17=GOG
    let category: Int
    let url: String
}

// MARK: - Twitch OAuth token response

struct TwitchTokenResponse: Decodable {
    let accessToken: String
    let expiresIn: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
    }
}
