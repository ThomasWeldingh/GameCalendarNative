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
                let rowHeight = max(80, (geo.size.height - 11) / 6)
                LazyVGrid(columns: columns, spacing: 1) {
                    ForEach(gridDays, id: \.self) { date in
                        DayCell(
                            date: date,
                            isCurrentMonth: calendar.isDate(date, equalTo: state.focusDate, toGranularity: .month),
                            isToday: calendar.isDateInToday(date),
                            games: gamesFor(date: date),
                            totalGameCount: totalGamesFor(date: date),
                            cellHeight: rowHeight,
                            useCards: state.monthCardLayout,
                            onSelect: { state.selectedGame = $0 },
                            onShowDay: {
                                state.focusDate = date
                                state.switchToCalendarMode(.day)
                            }
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
        let weekday = (calendar.component(.weekday, from: start) + 5) % 7
        let gridStart = calendar.date(byAdding: .day, value: -weekday, to: start)!
        return (0..<42).compactMap { calendar.date(byAdding: .day, value: $0, to: gridStart) }
    }

    /// Returns the top 2 most popular games for a date
    private func gamesFor(date: Date) -> [GameRelease] {
        let day = calendar.component(.day, from: date)
        guard calendar.isDate(date, equalTo: state.focusDate, toGranularity: .month) else { return [] }
        return Array((gamesByDay[day] ?? []).prefix(2))
    }

    /// Returns total game count for a date (for overflow indicator)
    private func totalGamesFor(date: Date) -> Int {
        let day = calendar.component(.day, from: date)
        guard calendar.isDate(date, equalTo: state.focusDate, toGranularity: .month) else { return 0 }
        return (gamesByDay[day] ?? []).count
    }

    // MARK: - Data loading

    private func loadGames() async {
        let start = calendar.startOfMonth(for: state.focusDate)
        let end = calendar.date(byAdding: .month, value: 1, to: start)!
        let minPop = state.minPopularity

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

        // Games are already sorted by popularity (desc) from the fetch
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
    let games: [GameRelease]       // Already limited to top 2
    let totalGameCount: Int        // Total count for overflow
    let cellHeight: CGFloat
    var useCards: Bool = false
    let onSelect: (GameRelease) -> Void
    let onShowDay: () -> Void

    private var isCompact: Bool { cellHeight < 100 }
    private var showCards: Bool { useCards && cellHeight >= 130 }

    private var overflowCount: Int { totalGameCount - games.count }

    // Space budget for card mode:
    // header = 34pt, title = 16pt, overflow = 18pt, padding = 8pt
    private var cardCoverHeight: CGFloat {
        let header: CGFloat = 34
        let titleRow: CGFloat = 16
        let overflow: CGFloat = overflowCount > 0 ? 18 : 0
        let padding: CGFloat = 8
        return max(30, cellHeight - header - titleRow - overflow - padding)
    }

    private let miniCardColumns = [
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Day number header
            dayHeader

            if showCards {
                miniCardGrid
            } else {
                pillList
            }

            // Overflow indicator — clickable, navigates to day view
            if overflowCount > 0 {
                Button {
                    onShowDay()
                } label: {
                    Text("+\(overflowCount) til")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .frame(height: cellHeight)
        .clipped()
        .background(isCurrentMonth ? Color(.windowBackgroundColor) : Color(.underPageBackgroundColor))
        .opacity(isCurrentMonth ? 1 : 0.5)
    }

    // MARK: - Day header

    private var dayHeader: some View {
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
        .padding(.bottom, 2)
    }

    // MARK: - Pill list

    private var pillList: some View {
        ForEach(games, id: \.externalId) { game in
            GamePill(game: game, compact: isCompact)
                .onTapGesture { onSelect(game) }
        }
    }

    // MARK: - 2-column mini card grid

    private var miniCardGrid: some View {
        LazyVGrid(columns: miniCardColumns, alignment: .leading, spacing: 4) {
            ForEach(games, id: \.externalId) { game in
                MiniGameCard(game: game, coverHeight: cardCoverHeight)
                    .onTapGesture { onSelect(game) }
            }
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Mini game card

struct MiniGameCard: View {
    let game: GameRelease
    let coverHeight: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Cover image — constrained to available height
            Color.clear
                .frame(height: coverHeight)
                .overlay {
                    AsyncImage(url: URL(string: game.coverImageUrl ?? "")) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        LinearGradient(
                            colors: [game.title.pillColor, game.title.pillColor.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .overlay {
                            Text(game.title.prefix(2).uppercased())
                                .font(.system(size: 12, weight: .heavy))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                }
                .clipShape(.rect(cornerRadius: 4))

            // Title
            Text(game.title)
                .font(.system(size: 9, weight: .medium))
                .lineLimit(1)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .top)
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
