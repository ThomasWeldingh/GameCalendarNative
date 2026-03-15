import Foundation
import SwiftData

struct ImportStats {
    var inserted: Int = 0
    var updated: Int = 0
    var skipped: Int = 0
    var filtered: Int = 0
}

/// Notification-worthy event detected during import.
struct ImportNotificationEvent {
    enum Kind { case dateConfirmed, gameUpdated }
    let kind: Kind
    let externalId: String
    let title: String
    let releaseDate: Date?
    let changes: [String]
}

/// Combined result from an import run.
struct ImportResult {
    var stats: ImportStats
    var events: [ImportNotificationEvent]
}

/// Background actor that syncs game data into the local SwiftData store.
/// Supports two modes:
///   1. Fast API sync (2 HTTP requests from backend)
///   2. Progressive IGDB fallback (phased: recent → older → TBA, saves after each phase)
actor ImportActor {
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    // MARK: - API Sync (fast path)

    func runApiSync(client: ApiSyncClient) async throws -> ImportResult {
        let modelContext = ModelContext(modelContainer)
        let run = ImportRun(source: "api")
        modelContext.insert(run)
        try modelContext.save()

        do {
            async let datedTask = client.fetchDatedGames()
            async let tbaTask = client.fetchTbaGames()
            let allGames = try await datedTask + tbaTask

            var (stats, lookup) = try prepareContext(modelContext)
            var events: [ImportNotificationEvent] = []
            for game in allGames {
                processGame(game, stats: &stats, events: &events, lookup: &lookup, in: modelContext)
            }
            try modelContext.save()

            completeRun(run, stats: stats, in: modelContext)
            return ImportResult(stats: stats, events: events)
        } catch {
            failRun(run, error: error, in: modelContext)
            throw error
        }
    }

    // MARK: - IGDB Progressive (fallback)

    func runIgdbProgressive(client: IgdbClient) async throws -> ImportResult {
        let modelContext = ModelContext(modelContainer)
        let run = ImportRun(source: "igdb")
        modelContext.insert(run)
        try modelContext.save()

        do {
            var (stats, lookup) = try prepareContext(modelContext)
            var events: [ImportNotificationEvent] = []

            let now = Date()
            let oneMonthAgo = Calendar.current.date(byAdding: .month, value: -1, to: now)!
            let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: now)!

            // Phase 1: Recent (1 month back → future)
            let recent = try await client.fetchGames(from: oneMonthAgo, updatedSince: nil)
            for game in recent {
                processGame(game, stats: &stats, events: &events, lookup: &lookup, in: modelContext)
            }
            try modelContext.save()

            // Phase 2: Older (1 year back → 1 month back)
            let older = try await client.fetchGames(from: oneYearAgo, to: oneMonthAgo, updatedSince: nil)
            for game in older {
                processGame(game, stats: &stats, events: &events, lookup: &lookup, in: modelContext)
            }
            try modelContext.save()

            // Phase 3: TBA games
            let tba = try await client.fetchTbaGames(updatedSince: nil)
            for game in tba {
                processGame(game, stats: &stats, events: &events, lookup: &lookup, in: modelContext)
            }
            try modelContext.save()

            completeRun(run, stats: stats, in: modelContext)
            return ImportResult(stats: stats, events: events)
        } catch {
            failRun(run, error: error, in: modelContext)
            throw error
        }
    }

    // MARK: - Shared helpers

    private func prepareContext(_ modelContext: ModelContext) throws -> (ImportStats, [String: SourceRecord]) {
        let allRecords = try modelContext.fetch(FetchDescriptor<SourceRecord>())
        var lookup: [String: SourceRecord] = [:]
        for record in allRecords {
            lookup[record.externalId] = record
        }
        return (ImportStats(), lookup)
    }

    private func processGame(
        _ game: NormalizedGame,
        stats: inout ImportStats,
        events: inout [ImportNotificationEvent],
        lookup: inout [String: SourceRecord],
        in modelContext: ModelContext
    ) {
        let externalId = game.externalId

        if let existing = lookup[externalId] {
            if existing.source != game.source {
                existing.source = game.source
            }

            guard existing.contentHash != game.contentHash else {
                stats.skipped += 1
                return
            }

            existing.contentJson = game.contentJson
            existing.contentHash = game.contentHash
            existing.fetchedAt = Date()

            if let gameRelease = existing.game {
                // Capture pre-update state for notification detection
                let hadNoDate = gameRelease.releaseDate == nil
                let oldVideoCount = gameRelease.videoIds.count
                let oldScreenshotCount = gameRelease.screenshotUrls.count
                let oldDescription = gameRelease.gameDescription
                let oldReleaseDate = gameRelease.releaseDate

                game.apply(to: gameRelease)

                // Only generate events for wishlisted games
                if !gameRelease.wishlistEntries.isEmpty {
                    // Date confirmed (TBA → dated)
                    if hadNoDate && gameRelease.releaseDate != nil {
                        events.append(ImportNotificationEvent(
                            kind: .dateConfirmed,
                            externalId: externalId,
                            title: gameRelease.title,
                            releaseDate: gameRelease.releaseDate,
                            changes: ["Lanseringsdato bekreftet"]
                        ))
                    } else {
                        // Significant update (only if dateConfirmed didn't fire)
                        var updateChanges: [String] = []
                        if gameRelease.videoIds.count > oldVideoCount {
                            updateChanges.append("ny trailer")
                        }
                        if gameRelease.screenshotUrls.count > oldScreenshotCount {
                            updateChanges.append("nye skjermbilder")
                        }
                        if oldDescription != gameRelease.gameDescription && gameRelease.gameDescription != nil {
                            updateChanges.append("oppdatert beskrivelse")
                        }
                        if oldReleaseDate != nil && gameRelease.releaseDate != nil
                            && oldReleaseDate != gameRelease.releaseDate {
                            updateChanges.append("endret lanseringsdato")
                        }
                        if !updateChanges.isEmpty {
                            events.append(ImportNotificationEvent(
                                kind: .gameUpdated,
                                externalId: externalId,
                                title: gameRelease.title,
                                releaseDate: gameRelease.releaseDate,
                                changes: updateChanges
                            ))
                        }
                    }
                }
            }
            stats.updated += 1
        } else {
            let gameRelease = game.toGameRelease()
            modelContext.insert(gameRelease)

            let record = SourceRecord(
                externalId: externalId,
                source: game.source,
                contentJson: game.contentJson,
                contentHash: game.contentHash
            )
            record.game = gameRelease
            modelContext.insert(record)
            lookup[externalId] = record
            stats.inserted += 1
        }
    }

    private func completeRun(_ run: ImportRun, stats: ImportStats, in modelContext: ModelContext) {
        run.completedAt = Date()
        run.status = "Completed"
        run.itemsInserted = stats.inserted
        run.itemsUpdated = stats.updated
        run.itemsSkipped = stats.skipped
        run.itemsFiltered = stats.filtered
        try? modelContext.save()
    }

    private func failRun(_ run: ImportRun, error: Error, in modelContext: ModelContext) {
        run.completedAt = Date()
        run.status = "Failed"
        run.errorSummary = error.localizedDescription
        try? modelContext.save()
    }
}
