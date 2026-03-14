import SwiftUI
import SwiftData

struct DayView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var state: AppState

    @State private var games: [GameRelease] = []
    private let calendar = Calendar.current

    var body: some View {
        Group {
            if games.isEmpty {
                ContentUnavailableView(
                    "Ingen spill denne dagen",
                    systemImage: "calendar.badge.minus",
                    description: Text(state.focusDate.formatted(.dateTime.weekday(.wide).day().month(.wide).year()))
                )
            } else {
                List(games, id: \.externalId) { game in
                    DayGameRow(game: game)
                        .onTapGesture { state.selectedGame = game }
                }
            }
        }
        .task(id: state.focusDate) { await loadGames() }
        .task(id: state.activePlatforms) { await loadGames() }
        .task(id: state.minPopularity) { await loadGames() }
    }

    private func loadGames() async {
        let descriptor = FetchDescriptor<GameRelease>(
            sortBy: [SortDescriptor(\.popularity, order: .reverse)]
        )
        let all = (try? modelContext.fetch(descriptor)) ?? []
        games = all.filter { game in
            guard let date = game.releaseDate else { return false }
            return calendar.isDate(date, inSameDayAs: state.focusDate) && state.matches(game)
        }
    }
}

struct DayGameRow: View {
    let game: GameRelease

    var body: some View {
        HStack(spacing: 14) {
            AsyncImage(url: URL(string: game.coverImageUrl ?? "")) { image in
                image.resizable().aspectRatio(3/4, contentMode: .fill)
            } placeholder: {
                Rectangle().fill(game.title.pillColor.opacity(0.2))
            }
            .frame(width: 48, height: 64)
            .clipShape(.rect(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 4) {
                Text(game.title)
                    .font(.headline)
                    .lineLimit(1)

                if !game.platforms.isEmpty {
                    Text(game.platforms.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !game.genres.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(game.genres.prefix(3), id: \.self) { genre in
                            Text(genre)
                                .font(.system(size: 10))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(game.title.pillColor.opacity(0.15), in: Capsule())
                                .foregroundStyle(game.title.pillColor)
                        }
                    }
                }
            }

            Spacer()

            if game.popularity > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "flame.fill").font(.caption2)
                    Text("\(game.popularity)").font(.caption)
                }
                .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 4)
    }
}
