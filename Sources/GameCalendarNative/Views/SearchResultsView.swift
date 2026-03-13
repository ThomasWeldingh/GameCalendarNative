import SwiftUI
import SwiftData

struct SearchResultsView: View {
    @Environment(\.modelContext) private var modelContext
    let query: String
    let state: AppState

    @State private var results: [GameRelease] = []
    @State private var isSearching = false

    var body: some View {
        Group {
            if isSearching {
                ProgressView("Søker...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if results.isEmpty && query.count >= 2 {
                ContentUnavailableView.search(text: query)
            } else {
                List(results, id: \.externalId) { game in
                    SearchResultRow(game: game)
                        .onTapGesture { state.selectedGame = game }
                }
            }
        }
        .task(id: query) { await search() }
    }

    private func search() async {
        guard query.count >= 2 else { results = []; return }
        isSearching = true
        let lower = query.lowercased()
        let all = (try? modelContext.fetch(FetchDescriptor<GameRelease>())) ?? []
        results = all
            .filter { game in
                game.title.lowercased().contains(lower)
                || game.developer?.lowercased().contains(lower) == true
                || game.publisher?.lowercased().contains(lower) == true
                || game.genres.contains { $0.lowercased().contains(lower) }
            }
            .sorted { $0.popularity > $1.popularity }
            .prefix(60)
            .map { $0 }
        isSearching = false
    }
}

struct SearchResultRow: View {
    let game: GameRelease

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: game.coverImageUrl ?? "")) { image in
                image.resizable().aspectRatio(3/4, contentMode: .fill)
            } placeholder: {
                Rectangle().fill(game.title.pillColor.opacity(0.2))
            }
            .frame(width: 36, height: 48)
            .clipShape(.rect(cornerRadius: 4))

            VStack(alignment: .leading, spacing: 3) {
                Text(game.title)
                    .fontWeight(.medium)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if let date = game.releaseDate {
                        Text(date.formatted(date: .abbreviated, time: .omitted))
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    } else {
                        Text("TBA").foregroundStyle(.secondary).font(.caption)
                    }
                    if !game.platforms.isEmpty {
                        Text(game.platforms.joined(separator: " · "))
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                }
            }

            Spacer()

            if game.popularity > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "flame.fill").font(.caption2)
                    Text("\(game.popularity)").font(.caption)
                }
                .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 2)
    }
}
