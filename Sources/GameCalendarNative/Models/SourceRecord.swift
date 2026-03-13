import Foundation
import SwiftData

@Model
final class SourceRecord {
    @Attribute(.unique) var externalId: String
    var source: String
    var contentJson: String
    var contentHash: String
    var fetchedAt: Date
    var game: GameRelease?

    init(externalId: String, source: String, contentJson: String, contentHash: String) {
        self.externalId = externalId
        self.source = source
        self.contentJson = contentJson
        self.contentHash = contentHash
        self.fetchedAt = Date()
    }
}
