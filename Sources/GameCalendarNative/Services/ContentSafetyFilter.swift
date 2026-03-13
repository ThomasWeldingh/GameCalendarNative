import Foundation

/// Mirrors ContentSafetyFilter.cs — excludes adult/gambling content before import.
struct ContentSafetyFilter {
    var filterAdultContent: Bool = true
    var filterGamblingContent: Bool = true

    // IGDB theme ID 42 = Erotic
    private static let adultThemeIds: Set<Int> = [42]
    private static let adultKeywords = ["hentai", "nsfw", "sex", "erotic", "18+", "adult"]
    private static let gamblingKeywords = ["casino", "gambling", "slot machine", "poker", "blackjack", "roulette"]

    /// Returns `(exclude: true, reason)` if the game should be skipped.
    func shouldExclude(_ game: NormalizedGame) -> (exclude: Bool, reason: String) {
        if filterAdultContent {
            if game.themeIds.contains(where: { Self.adultThemeIds.contains($0) }) {
                return (true, "adult IGDB theme")
            }
            if matches(game.title, keywords: Self.adultKeywords)
                || matches(game.description, keywords: Self.adultKeywords) {
                return (true, "adult keyword in title/description")
            }
        }
        if filterGamblingContent {
            if matches(game.title, keywords: Self.gamblingKeywords)
                || matches(game.description, keywords: Self.gamblingKeywords) {
                return (true, "gambling keyword in title/description")
            }
        }
        return (false, "")
    }

    private func matches(_ text: String?, keywords: [String]) -> Bool {
        guard let text, !text.isEmpty else { return false }
        let lower = text.lowercased()
        return keywords.contains { lower.contains($0) }
    }
}
