import SwiftUI
import SwiftData

struct WeekView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var state: AppState

    @State private var games: [GameRelease] = []

    private let calendar = Calendar.current

    private var weekDays: [Date] {
        let monday = calendar.startOfWeek(for: state.focusDate)
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: monday) }
    }

    var body: some View {
        GeometryReader { geo in
            HStack(alignment: .top, spacing: 0) {
                ForEach(Array(weekDays.enumerated()), id: \.element) { index, day in
                    let dayGames = games.filter { game in
                        guard let d = game.releaseDate else { return false }
                        return calendar.isDate(d, inSameDayAs: day)
                    }

                    if index > 0 {
                        Divider()
                    }

                    WeekDayColumn(
                        date: day,
                        games: dayGames,
                        cardWidth: (geo.size.width / 7) - 16,
                        onSelect: { state.selectedGame = $0 }
                    )
                }
            }
        }
        .task(id: state.focusDate) { await loadGames() }
        .task(id: state.filterSnapshot) { await loadGames() }
    }

    private func loadGames() async {
        let monday = calendar.startOfWeek(for: state.focusDate)
        let sunday = calendar.date(byAdding: .day, value: 7, to: monday)!
        let minPop = state.minPopularity

        let predicate = #Predicate<GameRelease> { game in
            game.releaseDate != nil
            && game.releaseDate! >= monday
            && game.releaseDate! < sunday
            && game.popularity >= minPop
        }
        let descriptor = FetchDescriptor<GameRelease>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.popularity, order: .reverse)]
        )

        do {
            let fetched = try modelContext.fetch(descriptor)
            games = fetched.filter { state.matches($0) }
        } catch {
            print("[WeekView] Fetch failed: \(error)")
        }
    }
}

// MARK: - Day column

struct WeekDayColumn: View {
    let date: Date
    let games: [GameRelease]
    let cardWidth: CGFloat
    let onSelect: (GameRelease) -> Void

    private var isToday: Bool { Calendar.current.isDateInToday(date) }

    private let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "nb_NO")
        f.dateFormat = "EEE"
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 3) {
                Text(dayFormatter.string(from: date).uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(.secondary)

                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.system(size: 16, weight: isToday ? .bold : .medium))
                    .foregroundStyle(isToday ? .white : .primary)
                    .frame(width: 30, height: 30)
                    .background(isToday ? Color.accentColor : Color.clear, in: Circle())

                if isToday {
                    Text("I dag")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                }

                if !games.isEmpty {
                    Text("\(games.count) spill")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.2)
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.12), in: Capsule())
                } else if !isToday {
                    Color.clear.frame(height: 16)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isToday ? Color.accentColor.opacity(0.05) : Color.clear)

            Divider()

            // Game cover cards
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(games, id: \.externalId) { game in
                        WeekCoverCard(game: game, cardWidth: cardWidth)
                            .onTapGesture { onSelect(game) }
                    }
                }
                .padding(6)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(isToday ? Color.accentColor.opacity(0.03) : Color.clear)
    }
}

// MARK: - Cover card

struct WeekCoverCard: View {
    let game: GameRelease
    let cardWidth: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Cover area
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

            // Title
            Text(game.title)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(2)
                .lineSpacing(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 6)
                .padding(.vertical, 5)
        }
        .background(.background)
        .clipShape(.rect(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.secondary.opacity(0.3), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.06), radius: 3, y: 1)
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
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(3.0/4.0, contentMode: .fit)
    }
}
