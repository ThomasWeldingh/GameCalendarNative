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
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 1) {
                ForEach(weekDays, id: \.self) { day in
                    WeekDayColumn(
                        date: day,
                        games: games.filter { game in
                            guard let d = game.releaseDate else { return false }
                            return calendar.isDate(d, inSameDayAs: day)
                        },
                        onSelect: { state.selectedGame = $0 }
                    )
                }
            }
            .frame(minWidth: 900)
        }
        .task(id: state.focusDate) { await loadGames() }
        .task(id: state.activePlatforms) { await loadGames() }
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

struct WeekDayColumn: View {
    let date: Date
    let games: [GameRelease]
    let onSelect: (GameRelease) -> Void

    private var isToday: Bool { Calendar.current.isDateInToday(date) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(spacing: 2) {
                Text(date.formatted(.dateTime.weekday(.abbreviated)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.title3)
                    .fontWeight(isToday ? .bold : .regular)
                    .foregroundStyle(isToday ? Color.accentColor : Color.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(.quaternary)

            Divider()

            // Games
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(games, id: \.externalId) { game in
                        WeekGameCard(game: game)
                            .onTapGesture { onSelect(game) }
                    }
                }
                .padding(6)
            }
        }
        .frame(minWidth: 120, maxWidth: .infinity)
        .background(isToday ? Color.accentColor.opacity(0.05) : Color(.windowBackgroundColor))
    }
}

struct WeekGameCard: View {
    let game: GameRelease

    var body: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2)
                .fill(game.title.pillColor)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 1) {
                Text(game.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(2)
                if !game.platforms.isEmpty {
                    Text(game.platforms.joined(separator: ", "))
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: .rect(cornerRadius: 6))
    }
}
