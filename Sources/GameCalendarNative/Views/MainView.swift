import SwiftUI
import SwiftData

struct MainView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var state: AppState

    @State private var showFilter = false

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
                CalendarNavigationBar(state: state)
                SectionTabsBar(state: state, showFilter: $showFilter)
                Divider()
                ZStack {
                    contentView
                    if !state.searchQuery.isEmpty {
                        ZStack(alignment: .top) {
                            Rectangle()
                                .fill(.background)
                            SearchResultsView(query: state.searchQuery, state: state)
                        }
                    }
                }
                Divider()
                footerBar
            }
            .navigationTitle("")
            .toolbar { macOSToolbar }
        }
        .frame(minWidth: 900, minHeight: 600)
        .overlay {
            if state.selectedGame != nil {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture { state.selectedGame = nil }
                    .transition(.opacity)
            }
        }
        .overlay {
            if let game = state.selectedGame {
                GameDetailSheet(game: game, state: state)
                    .frame(width: 640)
                    .frame(minHeight: 400, maxHeight: .infinity)
                    .background(.background, in: .rect(cornerRadius: 12))
                    .clipShape(.rect(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.3), radius: 20)
                    .padding(40)
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.15), value: state.selectedGame?.externalId)
        .onKeyPress(.leftArrow) {
            guard state.selectedGame == nil, state.viewType.isCalendarMode else { return .ignored }
            state.navigateBack()
            return .handled
        }
        .onKeyPress(.rightArrow) {
            guard state.selectedGame == nil, state.viewType.isCalendarMode else { return .ignored }
            state.navigateForward()
            return .handled
        }
    }

    // MARK: - iOS layout

    #if os(iOS)
    @Query private var wishlistEntries: [WishlistEntry]

    private var iOSLayout: some View {
        TabView(selection: $state.viewType) {
            ForEach(ViewType.allCases, id: \.self) { type in
                NavigationStack {
                    iOSContent(for: type)
                        .navigationTitle(type.label)
                        .toolbar {
                            if type.isCalendarMode {
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
                        Label(type.shortLabel, systemImage: type.icon)
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
        case .lists:    GameListsView(state: state)
        case .new:      NewGamesView(state: state)
        }
    }

    // iOS-only toolbar buttons (kept here since iOS layout is separate)
    private var filterButton: some View {
        Button {
            showFilter.toggle()
        } label: {
            Image(systemName: "line.3.horizontal.decrease")
        }
    }

    private var importButton: some View {
        Button {
            Task { await state.runImport(container: modelContext.container) }
        } label: {
            if state.isImporting {
                ProgressView().controlSize(.small)
            } else {
                Image(systemName: "arrow.clockwise")
            }
        }
        .disabled(state.isImporting)
    }

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
            GameListsView(state: state)
                .opacity(state.viewType == .lists ? 1 : 0)
                .allowsHitTesting(state.viewType == .lists)
            NewGamesView(state: state)
                .opacity(state.viewType == .new ? 1 : 0)
                .allowsHitTesting(state.viewType == .new)
        }
    }

    // MARK: - Search overlay (iOS only)

    private var searchOverlay: some View {
        ZStack(alignment: .top) {
            Rectangle()
                .fill(.background)
                .ignoresSafeArea()
            SearchResultsView(query: state.searchQuery, state: state)
        }
    }

    // MARK: - macOS toolbar

    @ToolbarContentBuilder
    private var macOSToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .automatic) {
            importStatsLabel
        }
    }

    @ViewBuilder
    private var importStatsLabel: some View {
        if let stats = state.lastImportStats {
            Text("+\(stats.inserted) nye")
                .font(.caption)
                .foregroundStyle(.secondary)
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
                    state.switchToSection(.new)
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
