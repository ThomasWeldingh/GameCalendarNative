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
            HStack(alignment: .top, spacing: 1) {
                ForEach(weekDays, id: \.self) { day in
                    let dayGames = games.filter { game in
                        guard let d = game.releaseDate else { return false }
                        return calendar.isDate(d, inSameDayAs: day)
                    }
                    WeekDayColumn(
                        date: day,
                        games: dayGames,
                        cardWidth: (geo.size.width - 8) / 7 - 16,
                        onSelect: { state.selectedGame = $0 }
                    )
                }
            }
        }
        .task(id: state.focusDate) { await loadGames() }
        .task(id: state.activePlatforms) { await loadGames() }
        .task(id: state.minPopularity) { await loadGames() }
    }

    private func loadGames() async {
        let monday = calendar.startOfWeek(for: state.focusDate)
        let sunday = calendar.date(byAdding: .day, value: 7, to: monday)!
        let descriptor = FetchDescriptor<GameRelease>(
            sortBy: [SortDescriptor(\.popularity, order: .reverse)]
        )
        let all = (try? modelContext.fetch(descriptor)) ?? []
        games = all.filter { game in
            guard let date = game.releaseDate else { return false }
            return date >= monday && date < sunday && state.matches(game)
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
            VStack(spacing: 4) {
                Text(dayFormatter.string(from: date).uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.title2)
                    .fontWeight(isToday ? .bold : .regular)
                    .foregroundStyle(isToday ? .white : .primary)
                    .frame(width: 36, height: 36)
                    .background(isToday ? Color.accentColor : Color.clear, in: Circle())

                if !games.isEmpty {
                    Text("\(games.count) spill")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())
                } else {
                    Color.clear.frame(height: 18)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isToday ? Color.accentColor.opacity(0.06) : Color.clear)

            Divider()

            // Game cover cards
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(games, id: \.externalId) { game in
                        WeekCoverCard(game: game, cardWidth: cardWidth)
                            .onTapGesture { onSelect(game) }
                    }
                }
                .padding(8)
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
        VStack(alignment: .leading, spacing: 6) {
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
            .frame(width: max(cardWidth, 40), height: max(cardWidth * 4 / 3, 54))
            .clipShape(.rect(cornerRadius: 8))
            .shadow(color: .black.opacity(0.2), radius: 4, y: 2)

            Text(game.title)
                .font(.caption)
                .fontWeight(.semibold)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
