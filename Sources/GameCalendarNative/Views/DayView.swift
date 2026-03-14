import SwiftUI
import SwiftData

struct DayView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var state: AppState

    @State private var games: [GameRelease] = []
    private let calendar = Calendar.current

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 4)

    var body: some View {
        Group {
            if games.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "calendar")
                        .font(.system(size: 36))
                        .foregroundStyle(.quaternary)
                    Text("Ingen spillslipp denne dagen")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Game count header
                        HStack(spacing: 8) {
                            Text("\(games.count)")
                                .font(.system(size: 28, weight: .heavy))
                                .foregroundStyle(.primary)
                            Text("spill slippes\ndenne dagen")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                                .lineSpacing(2)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)

                        // Card grid (4 columns like web)
                        LazyVGrid(columns: columns, spacing: 0) {
                            ForEach(games, id: \.externalId) { game in
                                DayGameCard(game: game)
                                    .onTapGesture { state.selectedGame = game }
                            }
                        }
                    }
                }
            }
        }
        .task(id: state.focusDate) { await loadGames() }
        .task(id: state.filterSnapshot) { await loadGames() }
    }

    private func loadGames() async {
        let dayStart = calendar.startOfDay(for: state.focusDate)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
        let minPop = state.minPopularity
        let nilDate = Date.distantPast

        let predicate = #Predicate<GameRelease> { game in
            (game.releaseDate ?? nilDate) >= dayStart
            && (game.releaseDate ?? nilDate) < dayEnd
            && game.popularity >= minPop
        }
        let descriptor = FetchDescriptor<GameRelease>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.popularity, order: .reverse)]
        )
        let fetched = (try? modelContext.fetch(descriptor)) ?? []
        games = fetched.filter { state.matches($0) }
    }
}

// MARK: - Day card (matches web's day-card with cover + body)

struct DayGameCard: View {
    let game: GameRelease

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Cover with heart + rating overlays
            ZStack(alignment: .topTrailing) {
                ZStack(alignment: .bottomLeading) {
                    coverImage

                    if let rating = game.rating {
                        RatingBadge(score: rating)
                            .padding(6)
                    }
                }

                HeartOverlayButton(game: game)
                    .padding(6)
            }

            // Body (generous padding like web)
            VStack(alignment: .leading, spacing: 8) {
                Text(game.title)
                    .font(.system(size: 16, weight: .bold))
                    .lineLimit(2)
                    .lineSpacing(2)

                // Date in accent color
                if let date = game.releaseDate {
                    Text(date.formatted(.dateTime.weekday(.wide).day().month(.wide).year()))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }

                // Platform badges (small pills)
                if !game.platforms.isEmpty {
                    WrappingHStack(spacing: 4) {
                        ForEach(game.platforms, id: \.self) { platform in
                            Text(platform)
                                .font(.system(size: 10, weight: .bold))
                                .tracking(0.3)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(.quaternary, in: Capsule())
                        }
                    }
                }

                // Genres (outline pills)
                if !game.genres.isEmpty {
                    WrappingHStack(spacing: 4) {
                        ForEach(game.genres.prefix(4), id: \.self) { genre in
                            Text(genre)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .overlay(Capsule().stroke(Color.secondary.opacity(0.3), lineWidth: 0.5))
                        }
                    }
                }

                // Description
                if let desc = game.gameDescription, !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .lineSpacing(3)
                }
            }
            .padding(16)
        }
        .overlay(alignment: .trailing) {
            Rectangle().fill(Color.secondary.opacity(0.2)).frame(width: 0.5)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.secondary.opacity(0.2)).frame(height: 0.5)
        }
    }

    @ViewBuilder
    private var coverImage: some View {
        AsyncImage(url: URL(string: game.coverImageUrl ?? "")) { image in
            image.resizable().aspectRatio(3.0/4.0, contentMode: .fill)
        } placeholder: {
            LinearGradient(
                colors: [game.title.pillColor, game.title.pillColor.opacity(0.5)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay {
                Text(game.title.prefix(2).uppercased())
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundStyle(.white.opacity(0.7))
                    .tracking(1)
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(3.0/4.0, contentMode: .fit)
    }
}

// MARK: - Wrapping horizontal stack for tags/badges

struct WrappingHStack: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
        }

        return (CGSize(width: maxX, height: y + rowHeight), positions)
    }
}
