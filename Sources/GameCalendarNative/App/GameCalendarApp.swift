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
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
