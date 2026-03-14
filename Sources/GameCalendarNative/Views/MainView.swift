import SwiftUI
import SwiftData

struct MainView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var state: AppState

    @State private var showFilter = false
    @Query private var wishlistEntries: [WishlistEntry]

    var body: some View {
        #if os(iOS)
        iOSLayout
        #else
        macOSLayout
        #endif
    }

    // MARK: - macOS layout

    private var macOSLayout: some View {
        NavigationStack {
            VStack(spacing: 0) {
                tabStrip
                Divider()
                contentView
                Divider()
                footerBar
            }
            .navigationTitle("")
            .toolbar { macOSToolbar }
        }
        .searchable(text: $state.searchQuery, prompt: "Søk etter spill...")
        .frame(minWidth: 900, minHeight: 600)
        .sheet(item: $state.selectedGame) { game in
            NavigationStack { GameDetailSheet(game: game, state: state) }
        }
        .overlay {
            if !state.searchQuery.isEmpty {
                searchOverlay
            }
        }
    }

    // MARK: - Tab strip (web-style second row)

    private var tabStrip: some View {
        HStack(spacing: 2) {
            ForEach(ViewType.allCases, id: \.self) { type in
                tabButton(for: type)
            }

            // Today button
            Button("I dag") {
                state.goToToday()
            }
            .buttonStyle(.plain)
            .font(.callout)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.quaternary, in: .rect(cornerRadius: 7))
            .padding(.leading, 4)

            Spacer()

            // Date navigation (month/week/day only)
            if state.showsDateNav {
                HStack(spacing: 2) {
                    Button { state.navigateBack() } label: {
                        Image(systemName: "chevron.left").font(.callout)
                    }
                    .buttonStyle(.plain)
                    .padding(6)

                    Text(state.focusDateLabel)
                        .font(.callout)
                        .fontWeight(.semibold)
                        .frame(minWidth: 180)

                    Button { state.navigateForward() } label: {
                        Image(systemName: "chevron.right").font(.callout)
                    }
                    .buttonStyle(.plain)
                    .padding(6)
                }
                .padding(.trailing, 8)
            }

            // Filter button
            filterButton

            // Import
            importButton
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
    }

    @ViewBuilder
    private func tabButton(for type: ViewType) -> some View {
        let isActive = state.viewType == type
        Button {
            state.viewType = type
        } label: {
            HStack(spacing: 5) {
                if type == .wishlist {
                    Image(systemName: "heart.fill")
                        .font(.callout)
                        .foregroundStyle(.red)
                    if wishlistEntries.count > 0 {
                        Text("\(wishlistEntries.count)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(.red, in: Capsule())
                            .foregroundStyle(.white)
                    }
                } else {
                    Text(type.label)
                        .font(.callout)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isActive ? Color.accentColor.opacity(0.12) : Color.clear, in: .rect(cornerRadius: 7))
            .foregroundStyle(isActive ? Color.accentColor : Color.primary)
            .fontWeight(isActive ? .semibold : .regular)
        }
        .buttonStyle(.plain)
    }

    // MARK: - iOS layout

    #if os(iOS)
    private var iOSLayout: some View {
        TabView(selection: $state.viewType) {
            ForEach(ViewType.allCases, id: \.self) { type in
                NavigationStack {
                    iOSContent(for: type)
                        .navigationTitle(type.label)
                        .toolbar {
                            if type == .month || type == .week || type == .day {
                                ToolbarItemGroup(placement: .navigationBarLeading) {
                                    dateNavButtons
                                }
                            }
                            ToolbarItemGroup(placement: .navigationBarTrailing) {
                                filterButton
                                importButton
                            }
                        }
                }
                .tabItem {
                    if type == .wishlist {
                        Label("\(type.label) \(wishlistEntries.count)", systemImage: type.icon)
                    } else {
                        Label(type.label, systemImage: type.icon)
                    }
                }
                .tag(type)
            }
        }
        .searchable(text: $state.searchQuery, prompt: "Søk etter spill...")
        .sheet(item: $state.selectedGame) { game in
            NavigationStack { GameDetailSheet(game: game, state: state) }
        }
        .sheet(isPresented: $showFilter) {
            NavigationStack {
                FilterView(state: state)
                    .navigationTitle("Filtre")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Ferdig") { showFilter = false }
                        }
                    }
            }
        }
        .overlay {
            if !state.searchQuery.isEmpty {
                searchOverlay
            }
        }
    }

    @ViewBuilder
    private func iOSContent(for type: ViewType) -> some View {
        switch type {
        case .month:    MonthCalendarView(state: state)
        case .week:     WeekView(state: state)
        case .day:      DayView(state: state)
        case .tba:      TbaView(state: state)
        case .wishlist: WishlistView(state: state)
        case .new:      NewGamesView(state: state)
        }
    }
    #endif

    // MARK: - Shared content (ZStack keeps views alive for instant tab switching)

    private var contentView: some View {
        ZStack {
            MonthCalendarView(state: state)
                .opacity(state.viewType == .month ? 1 : 0)
                .allowsHitTesting(state.viewType == .month)
            WeekView(state: state)
                .opacity(state.viewType == .week ? 1 : 0)
                .allowsHitTesting(state.viewType == .week)
            DayView(state: state)
                .opacity(state.viewType == .day ? 1 : 0)
                .allowsHitTesting(state.viewType == .day)
            TbaView(state: state)
                .opacity(state.viewType == .tba ? 1 : 0)
                .allowsHitTesting(state.viewType == .tba)
            WishlistView(state: state)
                .opacity(state.viewType == .wishlist ? 1 : 0)
                .allowsHitTesting(state.viewType == .wishlist)
            NewGamesView(state: state)
                .opacity(state.viewType == .new ? 1 : 0)
                .allowsHitTesting(state.viewType == .new)
        }
    }

    // MARK: - Search overlay

    private var searchOverlay: some View {
        VStack(spacing: 0) {
            #if os(macOS)
            Color.clear.frame(height: 52)
            #endif
            ZStack(alignment: .top) {
                Rectangle()
                    .fill(.background)
                    .ignoresSafeArea()
                SearchResultsView(query: state.searchQuery, state: state)
            }
        }
    }

    // MARK: - macOS toolbar

    @ToolbarContentBuilder
    private var macOSToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .automatic) {
            platformChips
            importStatsLabel
        }
    }

    // MARK: - Reusable pieces

    private var dateNavButtons: some View {
        HStack(spacing: 0) {
            Button(action: state.navigateBack) {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.plain)
            Button(state.focusDateLabel, action: state.goToToday)
                .buttonStyle(.plain)
                .font(.headline)
                .frame(minWidth: 160)
            Button(action: state.navigateForward) {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.plain)
        }
    }

    private var filterButton: some View {
        Button {
            showFilter.toggle()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "line.3.horizontal.decrease")
                Text("Filter")
                if activeFilterCount > 0 {
                    Text("\(activeFilterCount)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.accentColor, in: Capsule())
                        .foregroundStyle(.white)
                }
            }
        }
        .buttonStyle(.bordered)
        .help("Filtrering")
        #if os(macOS)
        .popover(isPresented: $showFilter, arrowEdge: .bottom) {
            FilterView(state: state)
        }
        #endif
    }

    private var importButton: some View {
        Button {
            Task { await state.runImport(container: modelContext.container) }
        } label: {
            if state.isImporting {
                ProgressView().controlSize(.small)
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                    Text("Importer")
                }
            }
        }
        .buttonStyle(.borderedProminent)
        .disabled(state.isImporting)
        .help("Importer spill fra IGDB")
    }

    @ViewBuilder
    private var importStatsLabel: some View {
        if let stats = state.lastImportStats {
            Text("+\(stats.inserted) nye")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var activeFilterCount: Int {
        var count = 0
        if state.minPopularity > 0 { count += 1 }
        if !state.selectedGenres.isEmpty { count += 1 }
        if !state.selectedPublishers.isEmpty { count += 1 }
        if !state.showIndie { count += 1 }
        return count
    }

    @ViewBuilder
    private var platformChips: some View {
        HStack(spacing: 6) {
            ForEach(["PC", "PlayStation", "Xbox", "Switch"], id: \.self) { platform in
                let isActive = state.activePlatforms.contains(platform)
                let color = platformColor(platform)
                Button {
                    if isActive { state.activePlatforms.remove(platform) }
                    else { state.activePlatforms.insert(platform) }
                } label: {
                    Text(platform)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(isActive ? color : color.opacity(0.12), in: Capsule())
                        .foregroundStyle(isActive ? .white : color)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func platformColor(_ platform: String) -> Color {
        switch platform {
        case "PC":          return .blue
        case "PlayStation": return .indigo
        case "Xbox":        return .green
        case "Switch":      return .red
        default:            return .gray
        }
    }

    // MARK: - Footer bar (matches web's app-footer)

    private var footerBar: some View {
        HStack(spacing: 12) {
            Text("Spillkalender")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let importedAt = state.lastImportedAt {
                HStack(spacing: 4) {
                    Text("Sist oppdatert:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(importedAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("siden")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let stats = state.lastImportStats, stats.inserted > 0 {
                Button {
                    state.viewType = .new
                } label: {
                    HStack(spacing: 4) {
                        Text("+\(stats.inserted) nye spill")
                            .font(.caption)
                            .foregroundStyle(Color.accentColor)
                    }
                }
                .buttonStyle(.plain)
            }

            Spacer()

            if state.isImporting {
                HStack(spacing: 4) {
                    Circle()
                        .fill(.green)
                        .frame(width: 6, height: 6)
                    Text("Importerer...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
    }
}
