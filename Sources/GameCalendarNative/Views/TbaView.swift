import SwiftUI
import SwiftData

struct TbaView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var state: AppState

    @State private var games: [GameRelease] = []
    @State private var sortByPopularity = true
    @State private var isLoading = true

    private let columns = [
        GridItem(.adaptive(minimum: 130, maximum: 200), spacing: 16)
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Sort toolbar (pill buttons matching web)
            HStack(spacing: 6) {
                Text("Sorter:")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)

                sortButton(label: "Popularitet", isActive: sortByPopularity) {
                    sortByPopularity = true
                }

                sortButton(label: "A\u{2013}Z", isActive: !sortByPopularity) {
                    sortByPopularity = false
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            if isLoading {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(0..<12, id: \.self) { _ in
                            SkeletonCard()
                        }
                    }
                    .padding(16)
                }
            } else if games.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 36))
                        .foregroundStyle(.quaternary)
                    Text("Ingen kommende spill uten dato")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(sortedGames, id: \.externalId) { game in
                            TbaCard(game: game)
                                .onTapGesture { state.selectedGame = game }
                        }
                    }
                    .padding(16)
                }
            }
        }
        .task(id: state.filterSnapshot) { await loadGames() }
    }

    @ViewBuilder
    private func sortButton(label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(isActive ? Color.accentColor.opacity(0.1) : Color.clear, in: Capsule())
                .foregroundStyle(isActive ? Color.accentColor : .secondary)
                .overlay(
                    Capsule().stroke(
                        isActive ? Color.accentColor.opacity(0.4) : Color.secondary.opacity(0.3),
                        lineWidth: 0.5
                    )
                )
        }
        .buttonStyle(.plain)
    }

    private var sortedGames: [GameRelease] {
        sortByPopularity
            ? games.sorted { $0.popularity > $1.popularity }
            : games.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    private func loadGames() async {
        let minPop = state.minPopularity
        let predicate = #Predicate<GameRelease> { game in
            game.releaseDate == nil && game.popularity >= minPop
        }
        var descriptor = FetchDescriptor<GameRelease>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.popularity, order: .reverse)]
        )
        descriptor.fetchLimit = 500
        do {
            let fetched = try modelContext.fetch(descriptor)
            games = fetched.filter { state.matches($0) }
        } catch {
            print("[TbaView] Fetch failed: \(error)")
        }
        isLoading = false
    }
}

struct TbaCard: View {
    let game: GameRelease

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Cover with heart + rating
            ZStack(alignment: .topTrailing) {
                ZStack(alignment: .bottomLeading) {
                    coverImage

                    if let rating = game.rating {
                        RatingBadge(score: rating)
                            .padding(6)
                    }
                }

                CardOverlayButtons(game: game)
                    .padding(6)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(game.title)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(2)
                    .lineSpacing(1)

                // Release window (uppercase with tracking, like web)
                if let window = game.releaseWindow {
                    Text(window.uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.3)
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .background(.background)
        .clipShape(.rect(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.3), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
    }

    @ViewBuilder
    private var coverImage: some View {
        AsyncImage(url: URL(string: game.coverImageUrl ?? "")) { image in
            image.resizable().aspectRatio(3.0/4.0, contentMode: .fill)
        } placeholder: {
            Color.accentColor.opacity(0.1)
                .overlay {
                    Text(game.title.prefix(2).uppercased())
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.secondary)
                }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(3.0/4.0, contentMode: .fit)
    }
}
