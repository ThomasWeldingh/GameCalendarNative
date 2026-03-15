import Foundation
import SwiftData

#if os(macOS)
/// Schedules a daily background import using NSBackgroundActivityScheduler.
/// Call `start(container:)` once at app launch.
final class BackgroundRefreshService: @unchecked Sendable {
    static let shared = BackgroundRefreshService()

    private var scheduler: NSBackgroundActivityScheduler?

    private init() {}

    func start(container: ModelContainer) {
        let activity = NSBackgroundActivityScheduler(identifier: "no.thomasj.GameCalendarNative.dailyImport")
        activity.repeats = true
        activity.interval = 24 * 60 * 60   // 24 hours
        activity.tolerance = 60 * 60        // ±1 hour
        activity.qualityOfService = .background
        scheduler = activity

        activity.schedule { [weak self] completion in
            guard let self else { completion(.deferred); return }
            Task {
                await self.runImport(container: container)
                completion(.finished)
            }
        }
    }

    private func runImport(container: ModelContainer) async {
        let urlString = UserDefaults.standard.string(forKey: "apiBaseURL") ?? "http://localhost:5262"
        guard let baseURL = URL(string: urlString) else { return }
        let client = ApiSyncClient(baseURL: baseURL)
        let actor = ImportActor(modelContainer: container)

        var result: ImportResult?

        // Try API first, fall back to IGDB
        do {
            result = try await actor.runApiSync(client: client)
        } catch {
            guard let creds = KeychainService.credentials else { return }
            let tokenService = IgdbTokenService()
            let igdb = IgdbClient(credentials: creds, tokenService: tokenService)
            let igdbActor = ImportActor(modelContainer: container)
            result = try? await igdbActor.runIgdbProgressive(client: igdb)
        }

        // Process notification events
        guard let result else { return }
        for event in result.events {
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

        // Re-schedule calendar notifications for all wishlisted games
        let context = ModelContext(container)
        let entries = (try? context.fetch(FetchDescriptor<WishlistEntry>())) ?? []
        await NotificationService.shared.rescheduleAll(wishlistedGames: entries.map(\.game))
    }
}
#endif
