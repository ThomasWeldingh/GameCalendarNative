import SwiftUI
import SwiftData

struct NewGamesView: View {
    @Environment(\.modelContext) private var modelContext
    let state: AppState

    @State private var games: [GameRelease] = []
    @State private var isLoading = true

    private let columns = [GridItem(.adaptive(minimum: 130, maximum: 200), spacing: 12)]

    var body: some View {
        Group {
            if isLoading {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Nye spill lagt til")
                                .font(.headline)
                            Text("Fra siste import")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 16)

                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(0..<8, id: \.self) { _ in
                                SkeletonCard()
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.vertical, 16)
                }
            } else if games.isEmpty {
                ContentUnavailableView(
                    "Ingen nye spill",
                    systemImage: "sparkles",
                    description: Text("Kjør en import for å hente nye spill fra IGDB")
                )
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Header (matches web)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Nye spill lagt til")
                                .font(.headline)
                            Text("Fra siste import")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 16)

                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(games, id: \.externalId) { game in
                                NewGameCard(game: game)
                                    .onTapGesture { state.selectedGame = game }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.vertical, 16)
                }
            }
        }
        .task { await loadGames() }
    }

    private func loadGames() async {
        do {
            // First, fetch just 1 game to find the most recent import date
            var recentDescriptor = FetchDescriptor<GameRelease>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            recentDescriptor.fetchLimit = 1
            guard let newest = try modelContext.fetch(recentDescriptor).first else {
                isLoading = false
                return
            }

            // Then fetch only games from that day
            let cal = Calendar.current
            let newestDay = cal.startOfDay(for: newest.createdAt)
            let nextDay = cal.date(byAdding: .day, value: 1, to: newestDay)!

            let predicate = #Predicate<GameRelease> { game in
                game.createdAt >= newestDay && game.createdAt < nextDay
            }
            let descriptor = FetchDescriptor<GameRelease>(
                predicate: predicate,
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            games = try modelContext.fetch(descriptor)
        } catch {
            print("[NewGamesView] Fetch failed: \(error)")
        }
        isLoading = false
    }
}

struct NewGameCard: View {
    let game: GameRelease

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Cover with heart + rating overlays (no "NY" badge - implied by the view)
            GameCoverImage(game: game, height: 120)
                .clipShape(.rect(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(game.title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .lineLimit(2)

                if let date = game.releaseDate {
                    Text(date.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(size: 10))
                        .foregroundStyle(Color.accentColor)
                } else if let window = game.releaseWindow {
                    Text(window)
                        .font(.system(size: 10))
                        .foregroundStyle(Color.accentColor)
                } else {
                    Text("TBA")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(8)
        }
        .background(.quaternary, in: .rect(cornerRadius: 10))
        .clipShape(.rect(cornerRadius: 10))
    }
}
