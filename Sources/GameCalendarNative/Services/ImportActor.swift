import Foundation
import SwiftData

struct ImportStats {
    var inserted: Int = 0
    var updated: Int = 0
    var skipped: Int = 0
    var filtered: Int = 0
}

/// Background actor that runs the full IGDB import pipeline against a SwiftData store.
actor ImportActor {
    // Store container, not context — context is created on the actor's executor in run()
    private let modelContainer: ModelContainer
    private let igdbClient: IgdbClient
    private let safetyFilter = ContentSafetyFilter()

    init(modelContainer: ModelContainer, igdbClient: IgdbClient) {
        self.modelContainer = modelContainer
        self.igdbClient = igdbClient
    }

    // MARK: - Public

    func run() async throws -> ImportStats {
        // Create ModelContext here so it lives on this actor's executor (not main thread)
        let modelContext = ModelContext(modelContainer)
        let lastCompleted = try lastCompletedImportDate(in: modelContext)
        let run = ImportRun(source: "igdb")
        modelContext.insert(run)
        try modelContext.save()

        do {
            let stats = try await fetchAndProcess(updatedSince: lastCompleted, in: modelContext)
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

    private func lastCompletedImportDate(in modelContext: ModelContext) throws -> Date? {
        var descriptor = FetchDescriptor<ImportRun>(
            predicate: #Predicate { $0.status == "Completed" }
        )
        descriptor.sortBy = [SortDescriptor(\.completedAt, order: .reverse)]
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first?.completedAt
    }

    private func fetchAndProcess(updatedSince: Date?, in modelContext: ModelContext) async throws -> ImportStats {
        let cutoff = Calendar.current.date(byAdding: .year, value: -1, to: Date())!

        async let datedTask = igdbClient.fetchGames(from: cutoff, updatedSince: updatedSince)
        async let tbaTask = igdbClient.fetchTbaGames(updatedSince: updatedSince)
        let allGames = try await datedTask + tbaTask

        var stats = ImportStats()

        for game in allGames {
            let (exclude, _) = safetyFilter.shouldExclude(game)
            if exclude {
                stats.filtered += 1
                continue
            }
            try processGame(game, stats: &stats, in: modelContext)
        }

        try modelContext.save()
        return stats
    }

    private func processGame(_ game: NormalizedGame, stats: inout ImportStats, in modelContext: ModelContext) throws {
        let externalId = game.externalId
        var descriptor = FetchDescriptor<SourceRecord>(
            predicate: #Predicate { $0.externalId == externalId && $0.source == "igdb" }
        )
        descriptor.fetchLimit = 1
        let existing = try modelContext.fetch(descriptor).first

        if let existing {
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
                source: "igdb",
                contentJson: game.contentJson,
                contentHash: game.contentHash
            )
            record.game = gameRelease
            modelContext.insert(record)
            stats.inserted += 1
        }
    }
}
