import SwiftUI
import SwiftData

struct TbaView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var state: AppState

    @State private var games: [GameRelease] = []
    @State private var sortByPopularity = true

    private let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 12)
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Sort toolbar
            HStack {
                Text("\(games.count) spill uten dato")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("Sorter", selection: $sortByPopularity) {
                    Text("Popularitet").tag(true)
                    Text("Alfabetisk").tag(false)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.bar)

            Divider()

            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(sortedGames, id: \.externalId) { game in
                        TbaCard(game: game)
                            .onTapGesture { state.selectedGame = game }
                    }
                }
                .padding(16)
            }
        }
        .task { await loadGames() }
        .task(id: state.activePlatforms) { await loadGames() }
        .task(id: state.minPopularity) { await loadGames() }
    }

    private var sortedGames: [GameRelease] {
        sortByPopularity
            ? games.sorted { $0.popularity > $1.popularity }
            : games.sorted { $0.title < $1.title }
    }

    private func loadGames() async {
        let descriptor = FetchDescriptor<GameRelease>(
            predicate: #Predicate { $0.releaseDate == nil }
        )
        let all = (try? modelContext.fetch(descriptor)) ?? []
        games = all.filter { state.matches($0) }
    }
}

struct TbaCard: View {
    let game: GameRelease

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Cover
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
            .frame(height: 140)
            .clipped()

            VStack(alignment: .leading, spacing: 4) {
                Text(game.title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .lineLimit(2)

                if !game.platforms.isEmpty {
                    Text(game.platforms.joined(separator: " · "))
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }

                if game.popularity > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 9))
                        Text("\(game.popularity)")
                            .font(.system(size: 9))
                    }
                    .foregroundStyle(.orange)
                }
            }
            .padding(8)
        }
        .background(.quaternary, in: .rect(cornerRadius: 10))
        .clipShape(.rect(cornerRadius: 10))
    }
}
