import Foundation
import SwiftUI
import SwiftData

enum ViewType: String, CaseIterable {
    case month, week, day, tba, wishlist, new

    var label: String {
        switch self {
        case .month:    return "Måned"
        case .week:     return "Uke"
        case .day:      return "Dag"
        case .tba:      return "Kommende"
        case .wishlist: return "Ønskeliste"
        case .new:      return "Nylig lagt til"
        }
    }

    var shortLabel: String {
        switch self {
        case .new:      return "Nylig"
        case .wishlist: return "Ønskeliste"
        default: return label
        }
    }

    var icon: String {
        switch self {
        case .month:    return "calendar"
        case .week:     return "calendar.day.timeline.left"
        case .day:      return "calendar.badge.clock"
        case .tba:      return "questionmark.circle"
        case .wishlist: return "heart.fill"
        case .new:      return "sparkles"
        }
    }

    var isCalendarMode: Bool {
        switch self {
        case .month, .week, .day: return true
        case .tba, .wishlist, .new: return false
        }
    }

    static var calendarModes: [ViewType] { [.month, .week, .day] }
    static var sectionTabs: [ViewType] { [.tba, .wishlist, .new] }
}

@Observable
@MainActor
class AppState {
    // Navigation
    var viewType: ViewType = .month
    var lastCalendarMode: ViewType = .month
    var focusDate: Date = Calendar.current.startOfMonth(for: .now)
    var selectedGame: GameRelease? = nil

    // Search
    var searchQuery: String = ""

    // Filters (persisted to UserDefaults)
    var activePlatforms: Set<String> = [] {
        didSet { if !isLoadingFilters { saveFilters() } }
    }
    var selectedGenres: Set<String> = [] {
        didSet { if !isLoadingFilters { saveFilters() } }
    }
    var selectedPublishers: Set<String> = [] {
        didSet { if !isLoadingFilters { saveFilters() } }
    }
    var minPopularity: Int = 0 {
        didSet { if !isLoadingFilters { saveFilters() } }
    }
    var showIndie: Bool = true {
        didSet { if !isLoadingFilters { saveFilters() } }
    }

    /// Incremented after each import to trigger view reloads
    var dataGeneration: Int = 0

    // Import
    var isImporting: Bool = false
    var importError: String? = nil
    var lastImportStats: ImportStats? = nil
    var lastImportedAt: Date? = nil

    private var isLoadingFilters = false

    /// Base URL for the backend API (configurable via UserDefaults)
    var apiBaseURL: URL {
        let urlString = UserDefaults.standard.string(forKey: "apiBaseURL") ?? "http://localhost:5262"
        return URL(string: urlString) ?? URL(string: "http://localhost:5262")!
    }

    init() {
        loadFilters()
    }

    // MARK: - Filter persistence

    private func saveFilters() {
        let defaults = UserDefaults.standard
        defaults.set(Array(activePlatforms), forKey: "activePlatforms")
        defaults.set(Array(selectedGenres), forKey: "selectedGenres")
        defaults.set(Array(selectedPublishers), forKey: "selectedPublishers")
        defaults.set(minPopularity, forKey: "minPopularity")
        defaults.set(showIndie, forKey: "showIndie")
    }

    private func loadFilters() {
        isLoadingFilters = true
        defer { isLoadingFilters = false }
        let defaults = UserDefaults.standard
        if let platforms = defaults.stringArray(forKey: "activePlatforms") {
            activePlatforms = Set(platforms)
        }
        if let genres = defaults.stringArray(forKey: "selectedGenres") {
            selectedGenres = Set(genres)
        }
        if let publishers = defaults.stringArray(forKey: "selectedPublishers") {
            selectedPublishers = Set(publishers)
        }
        if defaults.object(forKey: "minPopularity") != nil {
            minPopularity = defaults.integer(forKey: "minPopularity")
        }
        if defaults.object(forKey: "showIndie") != nil {
            showIndie = defaults.bool(forKey: "showIndie")
        }
    }

    // MARK: - Navigation

    var focusDateLabel: String {
        let mode = viewType.isCalendarMode ? viewType : lastCalendarMode
        switch mode {
        case .month:
            return focusDate.formatted(.dateTime.month(.wide).year())
        case .week:
            let end = Calendar.current.date(byAdding: .day, value: 6, to: focusDate)!
            return "\(focusDate.formatted(.dateTime.day().month(.abbreviated))) – \(end.formatted(.dateTime.day().month(.abbreviated).year()))"
        case .day:
            return focusDate.formatted(.dateTime.weekday(.wide).day().month(.wide).year())
        default:
            return ""
        }
    }

    var showsDateNav: Bool {
        viewType == .month || viewType == .week || viewType == .day
    }

    func navigateBack() {
        let unit: Calendar.Component
        switch viewType {
        case .week: unit = .weekOfYear
        case .day:  unit = .day
        default:    unit = .month
        }
        focusDate = Calendar.current.date(byAdding: unit, value: -1, to: focusDate) ?? focusDate
    }

    func navigateForward() {
        let unit: Calendar.Component
        switch viewType {
        case .week: unit = .weekOfYear
        case .day:  unit = .day
        default:    unit = .month
        }
        focusDate = Calendar.current.date(byAdding: unit, value: 1, to: focusDate) ?? focusDate
    }

    func goToToday() {
        if !viewType.isCalendarMode {
            viewType = lastCalendarMode
        }
        switch viewType {
        case .day:
            focusDate = Calendar.current.startOfDay(for: .now)
        case .week:
            focusDate = Calendar.current.startOfWeek(for: .now)
        default:
            focusDate = Calendar.current.startOfMonth(for: .now)
        }
    }

    func switchToCalendarMode(_ mode: ViewType) {
        guard mode.isCalendarMode else { return }
        lastCalendarMode = mode
        viewType = mode
    }

    func switchToSection(_ section: ViewType) {
        guard !section.isCalendarMode else { return }
        if viewType.isCalendarMode {
            lastCalendarMode = viewType
        }
        viewType = section
    }

    func returnToCalendar() {
        viewType = lastCalendarMode
    }

    // MARK: - Filter snapshot (for consolidated .task(id:) triggers)

    var filterSnapshot: FilterSnapshot {
        FilterSnapshot(
            platforms: activePlatforms,
            genres: selectedGenres,
            publishers: selectedPublishers,
            minPopularity: minPopularity,
            showIndie: showIndie,
            dataGeneration: dataGeneration
        )
    }

    // MARK: - Filtering

    func matches(_ game: GameRelease) -> Bool {
        if !activePlatforms.isEmpty,
           !game.platforms.contains(where: { activePlatforms.contains($0) }) {
            return false
        }
        if game.popularity < minPopularity { return false }
        if !showIndie && game.genres.contains("Indie") { return false }
        if !selectedGenres.isEmpty,
           !game.genres.contains(where: { selectedGenres.contains($0) }) {
            return false
        }
        if !selectedPublishers.isEmpty,
           let pub = game.publisher, !selectedPublishers.contains(pub) {
            return false
        }
        if !selectedPublishers.isEmpty && game.publisher == nil {
            return false
        }
        return true
    }

    // MARK: - Import (API-first, IGDB progressive fallback)

    var importPhase: String? = nil

    func runImport(container: ModelContainer) async {
        isImporting = true
        importError = nil
        importPhase = nil
        defer {
            isImporting = false
            importPhase = nil
            lastImportedAt = Date()
        }

        var result: ImportResult?

        // Try backend API first (fast: 2 HTTP requests)
        importPhase = "Synkroniserer fra API..."
        let apiClient = ApiSyncClient(baseURL: apiBaseURL)
        let actor = ImportActor(modelContainer: container)
        do {
            result = try await actor.runApiSync(client: apiClient)
        } catch {
            // API failed — fall back to IGDB
            guard let creds = KeychainService.credentials else {
                importError = "Backend API utilgjengelig og IGDB-nøkler mangler"
                return
            }

            let tokenService = IgdbTokenService()
            let igdbClient = IgdbClient(credentials: creds, tokenService: tokenService)
            let igdbActor = ImportActor(modelContainer: container)

            importPhase = "Henter nylige spill fra IGDB..."
            do {
                result = try await igdbActor.runIgdbProgressive(client: igdbClient)
            } catch {
                importError = error.localizedDescription
            }
        }

        guard let result else { return }
        lastImportStats = result.stats
        dataGeneration += 1

        // Process notification events from import
        await processNotificationEvents(result.events, container: container)
    }

    private func processNotificationEvents(_ events: [ImportNotificationEvent], container: ModelContainer) async {
        guard UserDefaults.standard.bool(forKey: "notificationsEnabled") else { return }

        for event in events {
            switch event.kind {
            case .dateConfirmed:
                await NotificationService.shared.notifyDateConfirmed(
                    title: event.title, releaseDate: event.releaseDate, externalId: event.externalId
                )
            case .gameUpdated:
                await NotificationService.shared.notifyGameUpdated(
                    title: event.title, externalId: event.externalId, changes: event.changes
                )
            }
        }

        // Re-schedule all calendar notifications (dates may have shifted)
        let context = ModelContext(container)
        let entries = (try? context.fetch(FetchDescriptor<WishlistEntry>())) ?? []
        let games = entries.map(\.game)
        await NotificationService.shared.rescheduleAll(wishlistedGames: games)
    }
}

// MARK: - Filter snapshot

struct FilterSnapshot: Equatable {
    let platforms: Set<String>
    let genres: Set<String>
    let publishers: Set<String>
    let minPopularity: Int
    let showIndie: Bool
    let dataGeneration: Int
}

// MARK: - Calendar helpers

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let comps = dateComponents([.year, .month], from: date)
        return self.date(from: comps) ?? date
    }

    func startOfWeek(for date: Date) -> Date {
        var comps = dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        comps.weekday = 2 // Monday
        return self.date(from: comps) ?? date
    }
}
