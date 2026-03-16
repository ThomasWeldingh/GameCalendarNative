import Foundation
import CryptoKit

/// Intermediate representation of a game fetched from IGDB,
/// before it is persisted to SwiftData.
struct NormalizedGame {
    let externalId: String
    let source: String
    let title: String
    let releaseDate: Date?
    let releaseWindow: String?
    let coverImageUrl: String?
    let description: String?
    let contentJson: String
    let platforms: [String]
    let genres: [String]
    let ageRating: String?
    let popularity: Int
    let rating: Double?
    let videoIds: [String]
    let screenshotUrls: [String]
    let developer: String?
    let publisher: String?
    let websiteUrl: String?
    let steamAppId: String?
    let themeIds: [Int]
    let similarGameIds: [Int]

    var contentHash: String {
        let digest = SHA256.hash(data: Data(contentJson.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    func toGameRelease() -> GameRelease {
        GameRelease(
            externalId: externalId,
            title: title,
            releaseDate: releaseDate,
            releaseWindow: releaseWindow,
            gameDescription: description,
            coverImageUrl: coverImageUrl,
            platforms: platforms,
            genres: genres,
            videoIds: videoIds,
            screenshotUrls: screenshotUrls,
            ageRating: ageRating,
            developer: developer,
            publisher: publisher,
            websiteUrl: websiteUrl,
            steamAppId: steamAppId,
            popularity: popularity,
            rating: rating,
            themeIds: themeIds,
            similarGameIds: similarGameIds
        )
    }

    func apply(to game: GameRelease) {
        game.title = title
        game.releaseDate = releaseDate
        game.releaseWindow = releaseWindow
        game.gameDescription = description
        game.coverImageUrl = coverImageUrl
        game.platforms = platforms
        game.genres = genres
        game.videoIds = videoIds
        game.screenshotUrls = screenshotUrls
        game.ageRating = ageRating
        game.developer = developer
        game.publisher = publisher
        game.websiteUrl = websiteUrl
        game.steamAppId = steamAppId
        game.popularity = popularity
        game.rating = rating
        game.themeIds = themeIds
        game.similarGameIds = similarGameIds
        game.updatedAt = Date()
    }
}
