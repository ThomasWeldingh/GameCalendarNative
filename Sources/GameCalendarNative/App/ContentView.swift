import SwiftUI
import SwiftData

struct ContentView: View {
    @Bindable var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @State private var showOnboarding: Bool

    init(appState: AppState) {
        self.appState = appState
        _showOnboarding = State(initialValue: !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding"))
    }

    var body: some View {
        Group {
            if showOnboarding {
                OnboardingView(state: appState) {
                    withAnimation {
                        showOnboarding = false
                    }
                }
            } else {
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
        .preferredColorScheme(appState.themeMode.colorScheme)
        .tint(appState.accentColor)
    }
}

extension Notification.Name {
    static let openGameFromNotification = Notification.Name("openGameFromNotification")
}
