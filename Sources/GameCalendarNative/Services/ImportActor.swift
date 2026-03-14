import Foundation
import SwiftData

struct ImportStats {
    var inserted: Int = 0
    var updated: Int = 0
    var skipped: Int = 0
    var filtered: Int = 0
}

/// Background actor that syncs game data from the backend API into the local SwiftData store.
/// Uses content-hash deduplication so unchanged games are skipped instantly.
actor ImportActor {
    private let modelContainer: ModelContainer
    private let apiClient: ApiSyncClient

    init(modelContainer: ModelContainer, apiClient: ApiSyncClient) {
        self.modelContainer = modelContainer
        self.apiClient = apiClient
    }

    // MARK: - Public

    func run() async throws -> ImportStats {
        let modelContext = ModelContext(modelContainer)
        let run = ImportRun(source: "api")
        modelContext.insert(run)
        try modelContext.save()

        do {
            let stats = try await fetchAndProcess(in: modelContext)
            run.completedAt = Date()
            run.status = "Completed"
            run.itemsInserted = stats.inserted
            run.itemsUpdated = stats.updated
            run.itemsSkipped = stats.skipped
            run.itemsFiltered = stats.filtered
            try modelContext.save()
            return stats
        } catch {
            run.completedAt = Date()
            run.status = "Failed"
            run.errorSummary = error.localizedDescription
            try? modelContext.save()
            throw error
        }
    }

    // MARK: - Private

    private func fetchAndProcess(in modelContext: ModelContext) async throws -> ImportStats {
        // Fetch dated + TBA games in parallel from backend API
        async let datedTask = apiClient.fetchDatedGames()
        async let tbaTask = apiClient.fetchTbaGames()
        let allGames = try await datedTask + tbaTask

        // Pre-load ALL existing SourceRecords into a dictionary for O(1) lookups
        // This avoids ~28,500 individual DB queries (the previous bottleneck)
        let allRecords = try modelContext.fetch(FetchDescriptor<SourceRecord>())
        var recordsByExternalId: [String: SourceRecord] = [:]
        for record in allRecords {
            recordsByExternalId[record.externalId] = record
        }

        var stats = ImportStats()

        for game in allGames {
            processGame(game, stats: &stats, lookup: &recordsByExternalId, in: modelContext)
        }

        try modelContext.save()
        return stats
    }

    private func processGame(
        _ game: NormalizedGame,
        stats: inout ImportStats,
        lookup: inout [String: SourceRecord],
        in modelContext: ModelContext
    ) {
        let externalId = game.externalId

        if let existing = lookup[externalId] {
            // Migrate old IGDB source to API
            if existing.source == "igdb" {
                existing.source = "api"
            }

            // Skip if content hasn't changed
            guard existing.contentHash != game.contentHash else {
                stats.skipped += 1
                return
            }

            existing.contentJson = game.contentJson
            existing.contentHash = game.contentHash
            existing.fetchedAt = Date()
            if let gameRelease = existing.game {
                game.apply(to: gameRelease)
            }
            stats.updated += 1
        } else {
            let gameRelease = game.toGameRelease()
            modelContext.insert(gameRelease)

            let record = SourceRecord(
                externalId: externalId,
                source: "api",
                contentJson: game.contentJson,
                contentHash: game.contentHash
            )
            record.game = gameRelease
            modelContext.insert(record)
            lookup[externalId] = record
            stats.inserted += 1
        }
    }
}
