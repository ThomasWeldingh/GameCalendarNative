import SwiftUI
import SwiftData

struct SectionTabsBar: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var state: AppState
    @Binding var showFilter: Bool

    @Query private var wishlistEntries: [WishlistEntry]

    @State private var showSettings = false
    @State private var searchExpanded = false
    @State private var searchText = ""
    @State private var notificationsEnabled = UserDefaults.standard.bool(forKey: "notificationsEnabled")
    @FocusState private var searchFieldFocused: Bool

    var body: some View {
        HStack(spacing: 2) {
            // Kommende tab
            sectionButton(for: .tba)

            // Wishlist tab (heart icon + count)
            wishlistButton

            // "Nylig lagt til" — only visible in calendar modes or when active
            if state.viewType.isCalendarMode || state.viewType == .new {
                sectionButton(for: .new)
            }

            Spacer()

            // Platform chips
            platformChips

            // Expandable search field
            expandableSearchField

            Spacer()

            // Filter button
            filterButton

            // Settings
            settingsButton

            // Import button
            importButton
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
    }

    // MARK: - Section button

    @ViewBuilder
    private func sectionButton(for type: ViewType) -> some View {
        let isActive = state.viewType == type
        Button {
            if isActive {
                state.returnToCalendar()
            } else {
                state.switchToSection(type)
            }
        } label: {
            Text(type.label)
                .font(.callout)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(isActive ? Color.accentColor.opacity(0.12) : Color.clear,
                            in: .rect(cornerRadius: 7))
                .foregroundStyle(isActive ? Color.accentColor : Color.primary)
                .fontWeight(isActive ? .semibold : .regular)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Wishlist button

    private var wishlistButton: some View {
        let isActive = state.viewType == .wishlist
        return Button {
            if isActive {
                state.returnToCalendar()
            } else {
                state.switchToSection(.wishlist)
            }
        } label: {
            HStack(spacing: 5) {
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
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isActive ? Color.accentColor.opacity(0.12) : Color.clear,
                        in: .rect(cornerRadius: 7))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Platform chips

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

    // MARK: - Filter button

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

    // MARK: - Import button

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

    // MARK: - Expandable search field

    @ViewBuilder
    private var expandableSearchField: some View {
        if searchExpanded {
            HStack(spacing: 5) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)

                TextField("Søk spill...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.caption)
                    .focused($searchFieldFocused)
                    .onChange(of: searchText) { _, newValue in
                        state.searchQuery = newValue
                    }

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        state.searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    searchText = ""
                    state.searchQuery = ""
                    searchExpanded = false
                    searchFieldFocused = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.gray.opacity(0.12), in: Capsule())
            .frame(width: 200)
        } else {
            Button {
                searchExpanded = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    searchFieldFocused = true
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 10))
                    Text("Søk")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.gray.opacity(0.12), in: Capsule())
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Settings button

    private var settingsButton: some View {
        Button {
            showSettings.toggle()
        } label: {
            Image(systemName: "gearshape")
        }
        .buttonStyle(.bordered)
        .help("Innstillinger")
        #if os(macOS)
        .popover(isPresented: $showSettings, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Innstillinger")
                    .font(.headline)

                Toggle("Varsler for ønskeliste", isOn: $notificationsEnabled)
                    .onChange(of: notificationsEnabled) { _, enabled in
                        UserDefaults.standard.set(enabled, forKey: "notificationsEnabled")
                        if enabled {
                            Task {
                                let granted = await NotificationService.shared.requestPermission()
                                if !granted {
                                    notificationsEnabled = false
                                    UserDefaults.standard.set(false, forKey: "notificationsEnabled")
                                } else {
                                    let games = wishlistEntries.map(\.game)
                                    await NotificationService.shared.rescheduleAll(wishlistedGames: games)
                                }
                            }
                        } else {
                            NotificationService.shared.removeAll()
                        }
                    }

                Text("Få varslinger når spill på ønskelisten får dato, oppdateringer, og påminnelser før lansering.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
            .frame(width: 280)
        }
        #endif
    }

    private var activeFilterCount: Int {
        var count = 0
        if state.minPopularity > 0 { count += 1 }
        if !state.selectedGenres.isEmpty { count += 1 }
        if !state.selectedPublishers.isEmpty { count += 1 }
        if !state.showIndie { count += 1 }
        return count
    }
}
