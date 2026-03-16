import SwiftUI
import SwiftData

@main
struct GameCalendarApp: App {
    @State private var appState = AppState()
    let container: ModelContainer

    init() {
        do {
            let schema = Schema([
                GameRelease.self,
                WishlistEntry.self,
                ImportRun.self,
                SourceRecord.self,
                SteamPrice.self,
                GameList.self,
                GameListEntry.self,
            ])
            container = try ModelContainer(for: schema)
        } catch {
            fatalError("Klarte ikke å opprette ModelContainer: \(error)")
        }

        // Seed default game lists if none exist
        let context = ModelContext(container)
        let existingCount = (try? context.fetchCount(FetchDescriptor<GameList>())) ?? 0
        if existingCount == 0 {
            for (index, def) in GameList.defaults.enumerated() {
                context.insert(GameList(name: def.name, icon: def.icon, colorHex: def.colorHex, sortOrder: index))
            }
            try? context.save()
        }

        // Clean up orphaned GameListEntry records (entries pointing to deleted games)
        let allGameIds = Set((try? context.fetch(FetchDescriptor<GameRelease>()).map(\.externalId)) ?? [])
        if !allGameIds.isEmpty {
            let allEntries = (try? context.fetch(FetchDescriptor<GameListEntry>())) ?? []
            var deletedCount = 0
            for entry in allEntries {
                if !allGameIds.contains(entry.gameExternalId) {
                    context.delete(entry)
                    deletedCount += 1
                }
            }
            if deletedCount > 0 { try? context.save() }
        }

        #if os(macOS)
        BackgroundRefreshService.shared.start(container: container)
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView(appState: appState)
                .onAppear {
                    // Deferred setup — bundle proxy must be ready
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        NotificationService.shared.setupDelegate()
                        Task {
                            let granted = await NotificationService.shared.requestPermission()
                            if granted && !UserDefaults.standard.bool(forKey: "notificationsEnabled") {
                                UserDefaults.standard.set(true, forKey: "notificationsEnabled")
                            }
                        }
                    }
                }
        }
        .modelContainer(container)
        .commands { AppCommands(state: appState) }

        #if os(macOS)
        MenuBarExtra("Game Calendar", systemImage: "gamecontroller") {
            MenuBarView()
                .modelContainer(container)
        }
        .menuBarExtraStyle(.window)
        #endif
    }
}
