import Foundation
import SwiftUI
import SwiftData

// MARK: - Theme mode

enum ThemeMode: String, CaseIterable {
    case system, light, dark

    var label: String {
        switch self {
        case .system: return String(localized: "System")
        case .light:  return String(localized: "Lys")
        case .dark:   return String(localized: "Mørk")
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light:  return "sun.max.fill"
        case .dark:   return "moon.fill"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

enum ViewType: String, CaseIterable {
    case month, week, day, tba, wishlist, lists, new

    var label: String {
        switch self {
        case .month:    return String(localized: "Måned")
        case .week:     return String(localized: "Uke")
        case .day:      return String(localized: "Dag")
        case .tba:      return String(localized: "Kommende")
        case .wishlist: return String(localized: "Ønskeliste")
        case .lists:    return String(localized: "Lister")
        case .new:      return String(localized: "Nylig lagt til")
        }
    }

    var shortLabel: String {
        switch self {
        case .new:      return String(localized: "Nylig")
        case .wishlist: return String(localized: "Ønskeliste")
        case .lists:    return String(localized: "Lister")
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
        case .lists:    return "list.bullet.rectangle"
        case .new:      return "sparkles"
        }
    }

    var isCalendarMode: Bool {
        switch self {
        case .month, .week, .day: return true
        case .tba, .wishlist, .lists, .new: return false
        }
    }

    static var calendarModes: [ViewType] { [.month, .week, .day] }
    static var sectionTabs: [ViewType] { [.tba, .wishlist, .lists, .new] }
}

@Observable
@MainActor
class AppState {
    // Onboarding
    var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") }
        set { UserDefaults.standard.set(newValue, forKey: "hasCompletedOnboarding") }
    }

    // Navigation
    var viewType: ViewType = .month
    var lastCalendarMode: ViewType = .month
    var focusDate: Date = Calendar.current.startOfMonth(for: .now)
    var selectedGame: GameRelease? = nil

    // Search
    var searchQuery: String = ""

    // Month view layout toggle (persisted)
    var monthCardLayout: Bool = false {
        didSet { UserDefaults.standard.set(monthCardLayout, forKey: "monthCardLayout") }
    }

    // Theme (persisted)
    var themeMode: ThemeMode = .system {
        didSet { UserDefaults.standard.set(themeMode.rawValue, forKey: "themeMode") }
    }
    var accentColorName: String = "blue" {
        didSet { UserDefaults.standard.set(accentColorName, forKey: "accentColorName") }
    }

    var accentColor: Color {
        switch accentColorName {
        case "blue":   return .blue
        case "purple": return .purple
        case "green":  return .green
        case "orange": return .orange
        case "red":    return .red
        case "pink":   return .pink
        case "teal":   return .teal
        case "indigo": return .indigo
        default:       return .blue
        }
    }

    static let accentColorOptions: [(name: String, color: Color, label: String)] = [
        ("blue", .blue, String(localized: "Blå")),
        ("purple", .purple, String(localized: "Lilla")),
        ("green", .green, String(localized: "Grønn")),
        ("orange", .orange, String(localized: "Oransje")),
        ("red", .red, String(localized: "Rød")),
        ("pink", .pink, String(localized: "Rosa")),
        ("teal", .teal, String(localized: "Turkis")),
        ("indigo", .indigo, String(localized: "Indigo")),
    ]

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
        monthCardLayout = defaults.bool(forKey: "monthCardLayout")
        if let themeRaw = defaults.string(forKey: "themeMode"),
           let mode = ThemeMode(rawValue: themeRaw) {
            themeMode = mode
        }
        if let colorName = defaults.string(forKey: "accentColorName") {
            accentColorName = colorName
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
        importPhase = String(localized: "Synkroniserer fra API...")
        let apiClient = ApiSyncClient(baseURL: apiBaseURL)
        let actor = ImportActor(modelContainer: container)
        do {
            result = try await actor.runApiSync(client: apiClient)
        } catch {
            // API failed — fall back to IGDB
            guard let creds = KeychainService.credentials else {
                importError = String(localized: "Backend API utilgjengelig og IGDB-nøkler mangler")
                return
            }

            let tokenService = IgdbTokenService()
            let igdbClient = IgdbClient(credentials: creds, tokenService: tokenService)
            let igdbActor = ImportActor(modelContainer: container)

            importPhase = String(localized: "Henter nylige spill fra IGDB...")
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
