import SwiftUI
import SwiftData

struct NewGamesView: View {
    @Environment(\.modelContext) private var modelContext
    let state: AppState

    @State private var games: [GameRelease] = []

    private let columns = [GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 12)]

    var body: some View {
        Group {
            if games.isEmpty {
                ContentUnavailableView(
                    "Ingen nye spill",
                    systemImage: "sparkles",
                    description: Text("Kjør en import for å hente nye spill fra IGDB")
                )
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("\(games.count) nye spill fra siste import")
                            .font(.callout)
                            .foregroundStyle(.secondary)
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
        // Find the most recent createdAt date
        let allDescriptor = FetchDescriptor<GameRelease>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let all = (try? modelContext.fetch(allDescriptor)) ?? []
        guard let newest = all.first?.createdAt else { return }

        // Show games created in the same calendar day as the newest
        let cal = Calendar.current
        let newestDay = cal.startOfDay(for: newest)
        games = all.filter { game in
            cal.startOfDay(for: game.createdAt) == newestDay
        }
    }
}

struct NewGameCard: View {
    let game: GameRelease

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                AsyncImage(url: URL(string: game.coverImageUrl ?? "")) { image in
                    image.resizable().aspectRatio(3/4, contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(game.title.pillColor.opacity(0.2))
                        .overlay {
                            Image(systemName: "gamecontroller")
                                .foregroundStyle(game.title.pillColor.opacity(0.5))
                        }
                }
                .frame(height: 120)
                .clipped()

                Text("NY")
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.accentColor, in: Capsule())
                    .foregroundStyle(.white)
                    .padding(6)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(game.title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .lineLimit(2)

                if let date = game.releaseDate {
                    Text(date.formatted(date: .abbreviated, time: .omitted))
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
