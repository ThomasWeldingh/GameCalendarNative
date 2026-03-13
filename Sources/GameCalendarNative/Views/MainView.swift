import SwiftUI
import SwiftData

struct MainView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var state: AppState

    var body: some View {
        NavigationStack {
            Group {
                switch state.viewType {
                case .month:
                    MonthCalendarView(state: state)
                case .week:
                    WeekView(state: state)
                case .tba:
                    TbaView(state: state)
                case .wishlist:
                    WishlistView(state: state)
                }
            }
            .navigationTitle("")
            .toolbar { toolbarContent }
        }
        .sheet(item: $state.selectedGame) { game in
            GameDetailSheet(game: game, state: state)
        }
        .searchable(text: $state.searchQuery, prompt: "Søk etter spill...")
        .frame(minWidth: 900, minHeight: 600)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        // View type
        ToolbarItemGroup(placement: .navigation) {
            Picker("Visning", selection: $state.viewType) {
                ForEach(ViewType.allCases, id: \.self) { type in
                    Label(type.label, systemImage: type.icon).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 320)
        }

        // Date navigation (month/week only)
        if state.viewType == .month || state.viewType == .week {
            ToolbarItemGroup(placement: .principal) {
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

        // Platform filters
        ToolbarItemGroup(placement: .automatic) {
            platformChips
        }

        // Import button
        ToolbarItemGroup(placement: .automatic) {
            if let stats = state.lastImportStats {
                Text("+\(stats.inserted)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

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
    }

    @ViewBuilder
    private var platformChips: some View {
        HStack(spacing: 4) {
            ForEach(["PC", "PlayStation", "Xbox", "Switch"], id: \.self) { platform in
                Toggle(platform, isOn: Binding(
                    get: { state.activePlatforms.contains(platform) },
                    set: { on in
                        if on { state.activePlatforms.insert(platform) }
                        else { state.activePlatforms.remove(platform) }
                    }
                ))
                .toggleStyle(.button)
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(platformColor(platform))
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

// MARK: - Placeholder views (filled in later)

struct WishlistView: View {
    let state: AppState
    var body: some View {
        ContentUnavailableView("Ønskeliste", systemImage: "heart", description: Text("Ingen spill lagt til ennå"))
    }
}
