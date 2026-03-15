import Foundation
import UserNotifications

/// Handles notification presentation and tap actions.
/// Posts `.openGameFromNotification` so ContentView can open the game detail sheet.
class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    static let shared = NotificationDelegate()

    // Show banner even when the app is in the foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    // Handle notification tap — post to open the game
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        if let externalId = userInfo["externalId"] as? String {
            await MainActor.run {
                NotificationCenter.default.post(
                    name: .openGameFromNotification,
                    object: nil,
                    userInfo: ["externalId": externalId]
                )
            }
        }
    }
}
