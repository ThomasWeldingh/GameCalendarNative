import Foundation
import SwiftUI
import SwiftData

enum ViewType: String, CaseIterable {
    case month, week, tba, wishlist

    var label: String {
        switch self {
        case .month:    return "Måned"
        case .week:     return "Uke"
        case .tba:      return "TBA"
        case .wishlist: return "Ønskeliste"
        }
    }

    var icon: String {
        switch self {
        case .month:    return "calendar"
        case .week:     return "calendar.day.timeline.left"
        case .tba:      return "questionmark.circle"
        case .wishlist: return "heart"
        }
    }
}

@Observable
@MainActor
class AppState {
    // Navigation
    var viewType: ViewType = .month
    var focusDate: Date = Calendar.current.startOfMonth(for: .now)
    var selectedGame: GameRelease? = nil

    // Search
    var searchQuery: String = ""

    // Filters
    var activePlatforms: Set<String> = ["PC", "PlayStation", "Xbox", "Switch"]
    var selectedGenres: Set<String> = []
    var minPopularity: Int = 0
    var showIndie: Bool = true

    // Import
    var isImporting: Bool = false
    var importError: String? = nil
    var lastImportStats: ImportStats? = nil

    private let tokenService = IgdbTokenService()

    // MARK: - Navigation

    var focusDateLabel: String {
        switch viewType {
        case .month:
            return focusDate.formatted(.dateTime.month(.wide).year())
        case .week:
            let end = Calendar.current.date(byAdding: .day, value: 6, to: focusDate)!
            return "\(focusDate.formatted(.dateTime.day().month(.abbreviated))) – \(end.formatted(.dateTime.day().month(.abbreviated).year()))"
        default:
            return ""
        }
    }

    func navigateBack() {
        let unit: Calendar.Component = viewType == .week ? .weekOfYear : .month
        focusDate = Calendar.current.date(byAdding: unit, value: -1, to: focusDate) ?? focusDate
    }

    func navigateForward() {
        let unit: Calendar.Component = viewType == .week ? .weekOfYear : .month
        focusDate = Calendar.current.date(byAdding: unit, value: 1, to: focusDate) ?? focusDate
    }

    func goToToday() {
        focusDate = Calendar.current.startOfMonth(for: .now)
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
        return true
    }

    // MARK: - Import

    func runImport(container: ModelContainer) async {
        guard let credentials = KeychainService.credentials else { return }
        isImporting = true
        importError = nil
        defer { isImporting = false }

        let client = IgdbClient(credentials: credentials, tokenService: tokenService)
        let actor = ImportActor(modelContainer: container, igdbClient: client)
        do {
            lastImportStats = try await actor.run()
        } catch {
            importError = error.localizedDescription
        }
    }
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
