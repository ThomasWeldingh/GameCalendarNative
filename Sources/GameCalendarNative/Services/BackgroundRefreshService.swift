import Foundation
import SwiftData

#if os(macOS)
/// Schedules a daily background import using NSBackgroundActivityScheduler.
/// Call `start(container:)` once at app launch.
final class BackgroundRefreshService: @unchecked Sendable {
    static let shared = BackgroundRefreshService()

    private var scheduler: NSBackgroundActivityScheduler?
    private let tokenService = IgdbTokenService()

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
        guard let credentials = KeychainService.credentials else { return }
        let client = IgdbClient(credentials: credentials, tokenService: tokenService)
        let actor = ImportActor(modelContainer: container, igdbClient: client)
        _ = try? await actor.run()
    }
}
#endif
