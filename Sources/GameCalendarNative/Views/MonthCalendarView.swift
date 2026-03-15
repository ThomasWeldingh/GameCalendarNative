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

            // Calendar grid — fills available height
            GeometryReader { geo in
                let rowHeight = max(80, (geo.size.height - 5) / 6)
                LazyVGrid(columns: columns, spacing: 1) {
                    ForEach(gridDays, id: \.self) { date in
                        DayCell(
                            date: date,
                            isCurrentMonth: calendar.isDate(date, equalTo: state.focusDate, toGranularity: .month),
                            isToday: calendar.isDateInToday(date),
                            games: gamesFor(date: date),
                            cellHeight: rowHeight,
                            onSelect: { state.selectedGame = $0 }
                        )
                    }
                }
            }
        }
        .task(id: state.focusDate) { await loadGames() }
        .task(id: state.filterSnapshot) { await loadGames() }
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
        let minPop = state.minPopularity

        // Fetch games with dates in range — avoid force-unwrap in predicate
        // (SwiftData's #Predicate may not translate `!` correctly to SQL)
        let predicate = #Predicate<GameRelease> { game in
            game.popularity >= minPop
        }
        var descriptor = FetchDescriptor<GameRelease>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.popularity, order: .reverse)]
        )
        descriptor.fetchLimit = 5000

        let fetched: [GameRelease]
        do {
            fetched = try modelContext.fetch(descriptor)
        } catch {
            print("[MonthCalendarView] Fetch failed: \(error)")
            return
        }

        var grouped: [Int: [GameRelease]] = [:]
        for game in fetched {
            guard let date = game.releaseDate,
                  date >= start && date < end,
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
    let cellHeight: CGFloat
    let onSelect: (GameRelease) -> Void

    private var maxVisible: Int {
        if cellHeight < 100 { return 2 }
        if cellHeight < 140 { return 3 }
        if cellHeight < 200 { return 5 }
        return 7
    }

    private var isCompact: Bool { cellHeight < 100 }

    var body: some View {
        VStack(alignment: .leading, spacing: isCompact ? 1 : 2) {
            // Day number
            HStack {
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(isCompact ? .caption : .callout)
                    .fontWeight(isToday ? .bold : .regular)
                    .foregroundStyle(isToday ? Color.white : isCurrentMonth ? Color.primary : Color.secondary.opacity(0.4))
                    .frame(width: isCompact ? 22 : 26, height: isCompact ? 22 : 26)
                    .background(isToday ? Color.accentColor : .clear, in: Circle())
                Spacer()
            }
            .padding(.horizontal, 4)
            .padding(.top, 4)

            // Game pills
            ForEach(Array(games.prefix(maxVisible)), id: \.externalId) { game in
                GamePill(game: game, compact: isCompact)
                    .onTapGesture { onSelect(game) }
            }

            // Overflow indicator
            if games.count > maxVisible {
                Text("+\(games.count - maxVisible) til")
                    .font(.system(size: isCompact ? 10 : 11))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }

            Spacer(minLength: 2)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .frame(height: cellHeight)
        .clipped()
        .background(isCurrentMonth ? Color(.windowBackgroundColor) : Color(.underPageBackgroundColor))
        .opacity(isCurrentMonth ? 1 : 0.5)
    }
}

// MARK: - Game pill

struct GamePill: View {
    let game: GameRelease
    var compact: Bool = false

    private var thumbnailSize: CGFloat { compact ? 14 : 20 }
    private var fontSize: CGFloat { compact ? 10 : 11 }

    var body: some View {
        HStack(spacing: 4) {
            // Colored left accent bar
            RoundedRectangle(cornerRadius: 1)
                .fill(game.title.pillColor)
                .frame(width: 3)

            // Cover thumbnail
            AsyncImage(url: URL(string: game.coverImageUrl ?? "")) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: compact ? 7 : 9))
                    .foregroundStyle(game.title.pillColor.opacity(0.6))
            }
            .frame(width: thumbnailSize, height: thumbnailSize)
            .clipShape(.rect(cornerRadius: 2))

            // Title (uppercase to match web)
            Text(game.title)
                .font(.system(size: fontSize))
                .textCase(.uppercase)
                .lineLimit(1)
                .foregroundStyle(.primary)
        }
        .padding(.trailing, 4)
        .padding(.vertical, compact ? 2 : 3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: .rect(cornerRadius: 3))
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
