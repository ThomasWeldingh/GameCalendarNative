import SwiftUI
import SwiftData

struct MonthCalendarView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var state: AppState

    @State private var gamesByDay: [Int: [GameRelease]] = [:]

    private let calendar = Calendar.current
    private let dayHeaders = ["Man", "Tir", "Ons", "Tor", "Fre", "Lør", "Søn"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 1), count: 7)

    var body: some View {
        VStack(spacing: 0) {
            // Day-of-week headers
            LazyVGrid(columns: columns, spacing: 1) {
                ForEach(dayHeaders, id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
            }
            .background(.quaternary)

            Divider()

            // Calendar grid
            ScrollView {
                LazyVGrid(columns: columns, spacing: 1) {
                    ForEach(gridDays, id: \.self) { date in
                        DayCell(
                            date: date,
                            isCurrentMonth: calendar.isDate(date, equalTo: state.focusDate, toGranularity: .month),
                            isToday: calendar.isDateInToday(date),
                            games: gamesFor(date: date),
                            onSelect: { state.selectedGame = $0 }
                        )
                    }
                }
            }
        }
        .task(id: state.focusDate) { await loadGames() }
        .task(id: state.activePlatforms) { await loadGames() }
        .task(id: state.minPopularity) { await loadGames() }
        .task(id: state.selectedGenres) { await loadGames() }
    }

    // MARK: - Grid calculation

    private var gridDays: [Date] {
        let start = calendar.startOfMonth(for: state.focusDate)
        // Weekday offset (Mon=1…Sun=7 → 0-based Mon=0)
        let weekday = (calendar.component(.weekday, from: start) + 5) % 7
        let gridStart = calendar.date(byAdding: .day, value: -weekday, to: start)!
        return (0..<42).compactMap { calendar.date(byAdding: .day, value: $0, to: gridStart) }
    }

    private func gamesFor(date: Date) -> [GameRelease] {
        let day = calendar.component(.day, from: date)
        guard calendar.isDate(date, equalTo: state.focusDate, toGranularity: .month) else { return [] }
        return gamesByDay[day] ?? []
    }

    // MARK: - Data loading

    private func loadGames() async {
        let start = calendar.startOfMonth(for: state.focusDate)
        let end = calendar.date(byAdding: .month, value: 1, to: start)!

        let descriptor = FetchDescriptor<GameRelease>(
            sortBy: [SortDescriptor(\.popularity, order: .reverse)]
        )
        let all = (try? modelContext.fetch(descriptor)) ?? []

        var grouped: [Int: [GameRelease]] = [:]
        for game in all {
            guard let date = game.releaseDate,
                  date >= start, date < end,
                  state.matches(game) else { continue }
            let day = calendar.component(.day, from: date)
            grouped[day, default: []].append(game)
        }
        gamesByDay = grouped
    }
}

// MARK: - Day cell

struct DayCell: View {
    let date: Date
    let isCurrentMonth: Bool
    let isToday: Bool
    let games: [GameRelease]
    let onSelect: (GameRelease) -> Void

    private let maxVisible = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Day number
            HStack {
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.caption)
                    .fontWeight(isToday ? .bold : .regular)
                    .foregroundStyle(isToday ? Color.white : isCurrentMonth ? Color.primary : Color.secondary.opacity(0.4))
                    .frame(width: 22, height: 22)
                    .background(isToday ? Color.accentColor : .clear, in: Circle())
                Spacer()
            }
            .padding(.horizontal, 4)
            .padding(.top, 4)

            // Game pills
            ForEach(Array(games.prefix(maxVisible)), id: \.externalId) { game in
                GamePill(game: game)
                    .onTapGesture { onSelect(game) }
            }

            // Overflow indicator
            if games.count > maxVisible {
                Text("+\(games.count - maxVisible) til")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }

            Spacer(minLength: 4)
        }
        .frame(maxWidth: .infinity, minHeight: 80, alignment: .top)
        .background(isCurrentMonth ? Color(.windowBackgroundColor) : Color(.underPageBackgroundColor))
        .opacity(isCurrentMonth ? 1 : 0.5)
    }
}

// MARK: - Game pill

struct GamePill: View {
    let game: GameRelease

    var body: some View {
        Text(game.title)
            .font(.system(size: 10))
            .lineLimit(1)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(game.title.pillColor.opacity(0.25), in: .rect(cornerRadius: 3))
            .foregroundStyle(game.title.pillColor)
    }
}

// MARK: - Color from title hash

extension String {
    var pillColor: Color {
        let hash = self.unicodeScalars.reduce(0) { ($0 &* 31) &+ Int($1.value) }
        let hue = Double(abs(hash) % 360) / 360.0
        return Color(hue: hue, saturation: 0.6, brightness: 0.75)
    }
}
