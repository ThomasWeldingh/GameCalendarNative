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

    // MARK: - macOS

    private var macOSLayout: some View {
        NavigationStack {
            contentView
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

    // MARK: - iOS

    #if os(iOS)
    private var iOSLayout: some View {
        TabView(selection: $state.viewType) {
            ForEach(ViewType.allCases, id: \.self) { type in
                NavigationStack {
                    iOSContent(for: type)
                        .navigationTitle(type.label)
                        .toolbar {
                            if type == .month || type == .week {
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
                .tabItem { Label(type.label, systemImage: type.icon) }
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
        case .tba:      TbaView(state: state)
        case .wishlist: WishlistView(state: state)
        }
    }
    #endif

    // MARK: - Shared content

    @ViewBuilder
    private var contentView: some View {
        switch state.viewType {
        case .month:    MonthCalendarView(state: state)
        case .week:     WeekView(state: state)
        case .tba:      TbaView(state: state)
        case .wishlist: WishlistView(state: state)
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
        ToolbarItemGroup(placement: .navigation) {
            Picker("Visning", selection: $state.viewType) {
                ForEach(ViewType.allCases, id: \.self) { type in
                    Label(type.label, systemImage: type.icon).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 320)
        }

        if state.viewType == .month || state.viewType == .week {
            ToolbarItemGroup(placement: .principal) {
                dateNavButtons
            }
        }

        ToolbarItemGroup(placement: .automatic) {
            platformChips
        }

        ToolbarItemGroup(placement: .automatic) {
            filterButton

            if let stats = state.lastImportStats {
                Text("+\(stats.inserted)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            importButton
        }
    }

    // MARK: - Reusable toolbar pieces

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
                Image(systemName: "arrow.clockwise")
            }
        }
        .help("Importer spill fra IGDB")
        .disabled(state.isImporting)
    }

    private var activeFilterCount: Int {
        var count = 0
        if state.minPopularity > 0 { count += 1 }
        if !state.selectedGenres.isEmpty { count += 1 }
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
}
