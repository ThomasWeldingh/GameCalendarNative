import SwiftUI
import SwiftData

#if os(macOS)
/// Compact view shown in the macOS menu bar extra.
struct MenuBarView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var wishlisted: [GameRelease] = []
    @State private var popular: [GameRelease] = []

    private let maxItems = 8

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Kommende spill")
                    .font(.headline)
                Spacer()
                Text(weekRangeLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            if wishlisted.isEmpty && popular.isEmpty {
                Text("Ingen spill denne uken")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                    .frame(maxWidth: .infinity)
                    .padding(12)
            } else {
                // Wishlisted games first
                if !wishlisted.isEmpty {
                    MenuBarSectionHeader(title: "Fra ønskelisten")
                    ForEach(wishlisted, id: \.externalId) { game in
                        MenuBarGameRow(game: game, isWishlisted: true)
                    }
                }

                // Popular releases
                if !popular.isEmpty {
                    if !wishlisted.isEmpty { Divider().padding(.vertical, 4) }
                    MenuBarSectionHeader(title: "Populære utgivelser")
                    ForEach(popular, id: \.externalId) { game in
                        MenuBarGameRow(game: game, isWishlisted: false)
                    }
                }
            }

            Divider()

            // Open app button
            Button("Åpne Game Calendar") {
                NSApp.activate(ignoringOtherApps: true)
                NSApp.windows.first?.makeKeyAndOrderFront(nil)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 300)
        .task { await loadGames() }
    }

    private var weekRangeLabel: String {
        let cal = Calendar.current
        let monday = cal.startOfWeek(for: .now)
        let sunday = cal.date(byAdding: .day, value: 6, to: monday)!
        let fmt = Date.FormatStyle().day().month(.abbreviated)
        return "\(monday.formatted(fmt)) – \(sunday.formatted(fmt))"
    }

    private func loadGames() async {
        let cal = Calendar.current
        let monday = cal.startOfWeek(for: .now)
        let sunday = cal.date(byAdding: .day, value: 7, to: monday)!

        let descriptor = FetchDescriptor<GameRelease>(
            sortBy: [SortDescriptor(\.releaseDate), SortDescriptor(\.popularity, order: .reverse)]
        )
        let allGames = (try? modelContext.fetch(descriptor)) ?? []
        let weekGames = allGames.filter { game in
            guard let date = game.releaseDate else { return false }
            return date >= monday && date < sunday
        }

        // Split into wishlisted vs regular
        let wishlistedIds = Set(
            weekGames
                .filter { !$0.wishlistEntries.isEmpty }
                .map(\.externalId)
        )

        let wishlistGames = weekGames
            .filter { wishlistedIds.contains($0.externalId) }

        // Fill remaining slots with top popular games (not already wishlisted)
        let remainingSlots = max(0, maxItems - wishlistGames.count)
        let popularGames = weekGames
            .filter { !wishlistedIds.contains($0.externalId) }
            .sorted { $0.popularity > $1.popularity }
            .prefix(remainingSlots)
            .map { $0 }

        wishlisted = wishlistGames
        popular = popularGames
    }
}

struct MenuBarSectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .padding(.horizontal, 12)
            .padding(.top, 6)
            .padding(.bottom, 2)
    }
}

struct MenuBarGameRow: View {
    let game: GameRelease
    var isWishlisted: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(game.title.pillColor)
                .frame(width: 3, height: 32)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(game.title)
                        .font(.callout)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    if isWishlisted {
                        Image(systemName: "heart.fill")
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                }

                if let date = game.releaseDate {
                    Text(date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
}
#endif
