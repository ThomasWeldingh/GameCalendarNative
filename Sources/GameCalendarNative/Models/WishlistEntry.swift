import Foundation
import SwiftData

@Model
final class WishlistEntry {
    var game: GameRelease
    var addedAt: Date

    init(game: GameRelease) {
        self.game = game
        self.addedAt = Date()
    }
}
