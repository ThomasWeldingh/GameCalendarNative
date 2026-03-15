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
                            cellHeight: rowHeight,
                            useCards: state.monthCardLayout,
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
    var useCards: Bool = false
    let onSelect: (GameRelease) -> Void

    private var isCompact: Bool { cellHeight < 100 }

    /// Use card layout only when toggled on AND cells are tall enough
    private var showCards: Bool { useCards && cellHeight >= 130 }

    private var maxVisible: Int {
        if showCards {
            if cellHeight < 220 { return 2 }
            if cellHeight < 320 { return 4 }
            return 6
        }
        // Day header ≈ 34pt, overflow text ≈ 18pt, each pill ≈ 28pt (compact) or 30pt (normal)
        let headerHeight: CGFloat = 34
        let overflowHeight: CGFloat = 18
        let pillHeight: CGFloat = isCompact ? 24 : 30
        let available = cellHeight - headerHeight - overflowHeight
        return max(1, Int(available / pillHeight))
    }

    private let miniCardColumns = [
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: isCompact ? 1 : 2) {
            // Day number — always visible above content
            dayHeader

            // Game entries — pills or 2-column mini cards
            if showCards {
                miniCardGrid
            } else {
                pillList
            }

            // Overflow indicator
            if games.count > maxVisible {
                Text("+\(games.count - maxVisible) til")
                    .font(.system(size: isCompact ? 10 : 11))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
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
        VStack(spacing: 0) {
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
            .padding(.bottom, showCards ? 4 : 0)

            // Separator line in card mode
            if showCards {
                Divider()
            }
        }
    }

    // MARK: - Pill list

    private var pillList: some View {
        ForEach(Array(games.prefix(maxVisible)), id: \.externalId) { game in
            GamePill(game: game, compact: isCompact)
                .onTapGesture { onSelect(game) }
        }
    }

    // MARK: - 2-column mini card grid

    private var miniCardGrid: some View {
        LazyVGrid(columns: miniCardColumns, alignment: .leading, spacing: 4) {
            ForEach(Array(games.prefix(maxVisible)), id: \.externalId) { game in
                MiniGameCard(game: game)
                    .onTapGesture { onSelect(game) }
            }
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Mini game card (expanded cell mode)

struct MiniGameCard: View {
    let game: GameRelease

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Cover image — guaranteed 1:1 square
            ZStack(alignment: .bottomLeading) {
                Color.clear
                    .aspectRatio(1, contentMode: .fit)
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
                    .clipped()

                // Rating badge
                if let rating = game.rating {
                    RatingBadge(score: rating)
                        .scaleEffect(0.65, anchor: .bottomLeading)
                        .padding(2)
                }
            }
            .clipShape(.rect(cornerRadius: 4))

            // Title
            Text(game.title)
                .font(.system(size: 9, weight: .semibold))
                .lineLimit(1)
                .foregroundStyle(.primary)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }
}

// MARK: - Game pill (compact & normal modes)

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
