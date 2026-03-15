import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var appState = AppState()
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        MainView(state: appState)
            .onReceive(NotificationCenter.default.publisher(for: .openGameFromNotification)) { notification in
                guard let externalId = notification.userInfo?["externalId"] as? String else { return }
                let predicate = #Predicate<GameRelease> { $0.externalId == externalId }
                var descriptor = FetchDescriptor(predicate: predicate)
                descriptor.fetchLimit = 1
                if let game = try? modelContext.fetch(descriptor).first {
                    appState.selectedGame = game
                }
            }
    }
}

extension Notification.Name {
    static let openGameFromNotification = Notification.Name("openGameFromNotification")
}
