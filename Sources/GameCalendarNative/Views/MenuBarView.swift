import SwiftUI
import SwiftData

#if os(macOS)
/// Compact view shown in the macOS menu bar extra.
struct MenuBarView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var upcomingGames: [GameRelease] = []

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

            if upcomingGames.isEmpty {
                Text("Ingen spill denne uken")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                    .frame(maxWidth: .infinity)
                    .padding(12)
            } else {
                ForEach(upcomingGames, id: \.externalId) { game in
                    MenuBarGameRow(game: game)
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
        .frame(width: 280)
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
        let all = (try? modelContext.fetch(descriptor)) ?? []
        upcomingGames = all.filter { game in
            guard let date = game.releaseDate else { return false }
            return date >= monday && date < sunday
        }
        .prefix(10)
        .map { $0 }
    }
}

struct MenuBarGameRow: View {
    let game: GameRelease

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(game.title.pillColor)
                .frame(width: 3, height: 32)

            VStack(alignment: .leading, spacing: 1) {
                Text(game.title)
                    .font(.callout)
                    .fontWeight(.medium)
                    .lineLimit(1)

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
