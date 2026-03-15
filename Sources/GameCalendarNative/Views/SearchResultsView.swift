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

        // Debounce to avoid searching on every keystroke
        try? await Task.sleep(for: .milliseconds(200))
        guard !Task.isCancelled else { return }

        let queryStr = query
        let predicate = #Predicate<GameRelease> { game in
            game.title.localizedStandardContains(queryStr)
        }
        var descriptor = FetchDescriptor<GameRelease>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.popularity, order: .reverse)]
        )
        descriptor.fetchLimit = 60
        do {
            results = try modelContext.fetch(descriptor)
        } catch {
            print("[SearchResultsView] Fetch failed: \(error)")
        }
        isSearching = false
    }
}

struct SearchResultRow: View {
    let game: GameRelease

    var body: some View {
        HStack(spacing: 12) {
            // Larger cover image (matches web proportions)
            AsyncImage(url: URL(string: game.coverImageUrl ?? "")) { image in
                image.resizable().aspectRatio(3/4, contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(game.title.pillColor.opacity(0.2))
                    .overlay {
                        Text(game.title.prefix(2).uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(game.title.pillColor.opacity(0.6))
                    }
            }
            .frame(width: 48, height: 64)
            .clipShape(.rect(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 4) {
                Text(game.title)
                    .fontWeight(.medium)
                    .lineLimit(1)

                if let date = game.releaseDate {
                    Text(date.formatted(date: .abbreviated, time: .omitted))
                        .foregroundStyle(.secondary)
                        .font(.caption)
                } else {
                    Text("TBA").foregroundStyle(.secondary).font(.caption)
                }

                // Platform badges (matches web's styled chips)
                if !game.platforms.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(game.platforms, id: \.self) { platform in
                            Text(platform)
                                .font(.system(size: 9))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(.quaternary, in: Capsule())
                        }
                    }
                }
            }

            Spacer()

            // Heart button
            HeartOverlayButton(game: game)

            if game.popularity > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "flame.fill").font(.caption2)
                    Text("\(game.popularity)").font(.caption)
                }
                .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 4)
    }
}
