import Foundation
import UserNotifications

/// Manages all local notifications for wishlisted games.
/// Access to UNUserNotificationCenter is deferred because SPM executables
/// don't have a full bundle proxy at init time.
final class NotificationService: @unchecked Sendable {
    static let shared = NotificationService()

    private var _center: UNUserNotificationCenter?
    private var center: UNUserNotificationCenter? {
        if _center == nil {
            guard Bundle.main.bundleIdentifier != nil else { return nil }
            _center = UNUserNotificationCenter.current()
        }
        return _center
    }

    private init() {}

    // MARK: - Permission

    func requestPermission() async -> Bool {
        guard let center else { return false }
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    /// Set delegate (call after app is fully launched)
    func setupDelegate() {
        center?.delegate = NotificationDelegate.shared
    }

    // MARK: - Identifier scheme: gcal.<type>.<externalId>

    private func id(_ type: String, _ externalId: String) -> String {
        "gcal.\(type).\(externalId)"
    }

    // MARK: - Calendar-based scheduling (7d, 24h, release day)

    func scheduleReleaseNotifications(for game: GameRelease) async {
        guard let center else { return }
        guard UserDefaults.standard.bool(forKey: "notificationsEnabled") else { return }
        await removeReleaseNotifications(for: game.externalId)

        guard let releaseDate = game.releaseDate else { return }
        let now = Date()
        let cal = Calendar.current

        // 7 days before — 09:00
        if let sevenBefore = cal.date(byAdding: .day, value: -7, to: releaseDate),
           sevenBefore > now {
            let content = UNMutableNotificationContent()
            content.title = "Om 1 uke"
            content.body = "\(game.title) slippes om 7 dager!"
            content.sound = .default
            content.userInfo = ["externalId": game.externalId]

            var comps = cal.dateComponents([.year, .month, .day], from: sevenBefore)
            comps.hour = 9; comps.minute = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            try? await center.add(UNNotificationRequest(
                identifier: id("release7d", game.externalId), content: content, trigger: trigger
            ))
        }

        // 24 hours before — 18:00
        if let oneBefore = cal.date(byAdding: .day, value: -1, to: releaseDate),
           oneBefore > now {
            let content = UNMutableNotificationContent()
            content.title = "I morgen!"
            content.body = "\(game.title) slippes i morgen!"
            content.sound = .default
            content.userInfo = ["externalId": game.externalId]

            var comps = cal.dateComponents([.year, .month, .day], from: oneBefore)
            comps.hour = 18; comps.minute = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            try? await center.add(UNNotificationRequest(
                identifier: id("release24h", game.externalId), content: content, trigger: trigger
            ))
        }

        // Release day — 09:00
        let startOfRelease = cal.startOfDay(for: releaseDate)
        if startOfRelease >= cal.startOfDay(for: now) {
            let content = UNMutableNotificationContent()
            content.title = "Lansering i dag!"
            content.body = "\(game.title) er ute nå!"
            content.sound = .default
            content.userInfo = ["externalId": game.externalId]

            var comps = cal.dateComponents([.year, .month, .day], from: releaseDate)
            comps.hour = 9; comps.minute = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            try? await center.add(UNNotificationRequest(
                identifier: id("releaseDay", game.externalId), content: content, trigger: trigger
            ))
        }
    }

    // MARK: - Event-driven notifications

    func notifyDateConfirmed(title: String, releaseDate: Date?, externalId: String) async {
        guard let center else { return }
        guard UserDefaults.standard.bool(forKey: "notificationsEnabled") else { return }

        let content = UNMutableNotificationContent()
        content.title = "Dato bekreftet!"
        if let date = releaseDate {
            content.body = "\(title) slippes \(date.formatted(.dateTime.day().month(.wide).year()))"
        } else {
            content.body = "\(title) har fått en bekreftet lanseringsdato"
        }
        content.sound = .default
        content.userInfo = ["externalId": externalId]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        try? await center.add(UNNotificationRequest(
            identifier: id("dateConfirmed", externalId), content: content, trigger: trigger
        ))
    }

    /// Convenience overload accepting a GameRelease directly.
    func notifyDateConfirmed(game: GameRelease) async {
        await notifyDateConfirmed(title: game.title, releaseDate: game.releaseDate, externalId: game.externalId)
    }

    func notifyGameUpdated(title: String, externalId: String, changes: [String]) async {
        guard let center else { return }
        guard UserDefaults.standard.bool(forKey: "notificationsEnabled") else { return }

        let content = UNMutableNotificationContent()
        content.title = "Oppdatering"
        content.body = "\(title): \(changes.joined(separator: ", "))"
        content.sound = .default
        content.userInfo = ["externalId": externalId]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        try? await center.add(UNNotificationRequest(
            identifier: id("gameUpdated", externalId), content: content, trigger: trigger
        ))
    }

    // MARK: - Removal

    func removeReleaseNotifications(for externalId: String) async {
        center?.removePendingNotificationRequests(withIdentifiers: [
            id("release7d", externalId),
            id("release24h", externalId),
            id("releaseDay", externalId),
        ])
    }

    func removeAllNotifications(for externalId: String) async {
        let ids = [
            id("dateConfirmed", externalId),
            id("gameUpdated", externalId),
            id("release7d", externalId),
            id("release24h", externalId),
            id("releaseDay", externalId),
        ]
        center?.removePendingNotificationRequests(withIdentifiers: ids)
        center?.removeDeliveredNotifications(withIdentifiers: ids)
    }

    // MARK: - Bulk

    func rescheduleAll(wishlistedGames: [GameRelease]) async {
        guard UserDefaults.standard.bool(forKey: "notificationsEnabled") else { return }
        for game in wishlistedGames {
            await scheduleReleaseNotifications(for: game)
        }
    }

    func removeAll() {
        center?.removeAllPendingNotificationRequests()
        center?.removeAllDeliveredNotifications()
    }
}
