import Foundation
import SwiftData

@Model
final class GameRelease {
    @Attribute(.unique) var externalId: String
    var title: String
    var releaseDate: Date?
    var releaseWindow: String?
    var gameDescription: String?
    var coverImageUrl: String?
    var platforms: [String]
    var genres: [String]
    var videoIds: [String]
    var screenshotUrls: [String]
    var ageRating: String?
    var developer: String?
    var publisher: String?
    var websiteUrl: String?
    var popularity: Int
    var rating: Double?
    var themeIds: [Int]
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \WishlistEntry.game)
    var wishlistEntries: [WishlistEntry] = []

    init(
        externalId: String,
        title: String,
        releaseDate: Date? = nil,
        releaseWindow: String? = nil,
        gameDescription: String? = nil,
        coverImageUrl: String? = nil,
        platforms: [String] = [],
        genres: [String] = [],
        videoIds: [String] = [],
        screenshotUrls: [String] = [],
        ageRating: String? = nil,
        developer: String? = nil,
        publisher: String? = nil,
        websiteUrl: String? = nil,
        popularity: Int = 0,
        rating: Double? = nil,
        themeIds: [Int] = []
    ) {
        self.externalId = externalId
        self.title = title
        self.releaseDate = releaseDate
        self.releaseWindow = releaseWindow
        self.gameDescription = gameDescription
        self.coverImageUrl = coverImageUrl
        self.platforms = platforms
        self.genres = genres
        self.videoIds = videoIds
        self.screenshotUrls = screenshotUrls
        self.ageRating = ageRating
        self.developer = developer
        self.publisher = publisher
        self.websiteUrl = websiteUrl
        self.popularity = popularity
        self.rating = rating
        self.themeIds = themeIds
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
