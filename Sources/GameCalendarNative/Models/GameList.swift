import Foundation
import SwiftData

@Model
final class GameList {
    @Attribute(.unique) var id: UUID
    var name: String
    var icon: String          // SF Symbol name
    var colorHex: String      // Hex color for the list
    var sortOrder: Int
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \GameListEntry.list)
    var entries: [GameListEntry] = []

    init(
        name: String,
        icon: String = "list.bullet",
        colorHex: String = "007AFF",
        sortOrder: Int = 0
    ) {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.sortOrder = sortOrder
        self.createdAt = Date()
    }

    var color: SwiftUI.Color {
        Color(hex: colorHex)
    }

    /// Default lists seeded on first launch
    static let defaults: [(name: String, icon: String, colorHex: String)] = [
        ("Spiller nå", "play.fill", "34C759"),
        ("Fullført", "checkmark.circle.fill", "007AFF"),
        ("Backlog", "clock.fill", "FF9500"),
        ("Interessert", "eye.fill", "AF52DE"),
    ]
}

@Model
final class GameListEntry {
    var list: GameList
    var gameExternalId: String
    var addedAt: Date
    var notes: String?

    init(list: GameList, gameExternalId: String, notes: String? = nil) {
        self.list = list
        self.gameExternalId = gameExternalId
        self.addedAt = Date()
        self.notes = notes
    }
}

// MARK: - Hex color helper

import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: Double
        switch hex.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255.0
            g = Double((int >> 8) & 0xFF) / 255.0
            b = Double(int & 0xFF) / 255.0
        default:
            r = 0; g = 0; b = 0
        }
        self.init(red: r, green: g, blue: b)
    }
}
