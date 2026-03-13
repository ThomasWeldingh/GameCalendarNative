import SwiftUI
import SwiftData

@main
struct GameCalendarApp: App {
    let container: ModelContainer

    init() {
        do {
            let schema = Schema([
                GameRelease.self,
                WishlistEntry.self,
                ImportRun.self,
                SourceRecord.self,
            ])
            container = try ModelContainer(for: schema)
        } catch {
            fatalError("Klarte ikke å opprette ModelContainer: \(error)")
        }

        #if os(macOS)
        BackgroundRefreshService.shared.start(container: container)
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)

        #if os(macOS)
        MenuBarExtra("Game Calendar", systemImage: "gamecontroller") {
            MenuBarView()
                .modelContainer(container)
        }
        .menuBarExtraStyle(.window)
        #endif
    }
}
