import SwiftUI
import SwiftData
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct WishlistView: View {
    let state: AppState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WishlistEntry.addedAt, order: .reverse) private var entries: [WishlistEntry]

    private let columns = [GridItem(.adaptive(minimum: 130, maximum: 220), spacing: 16)]

    private var availableNowGames: [GameRelease] {
        let today = Calendar.current.startOfDay(for: Date())
        return entries.compactMap { entry -> GameRelease? in
            guard let date = entry.game.releaseDate,
                  date < today else { return nil }
            return entry.game
        }
        .sorted { $0.popularity > $1.popularity }
    }

    private var upcomingGames: [GameRelease] {
        let today = Calendar.current.startOfDay(for: Date())
        let in14 = Calendar.current.date(byAdding: .day, value: 14, to: today)!
        return entries.compactMap { entry -> GameRelease? in
            guard let date = entry.game.releaseDate,
                  date >= today,
                  date <= in14 else { return nil }
            return entry.game
        }
        .sorted { ($0.releaseDate ?? .distantFuture) < ($1.releaseDate ?? .distantFuture) }
    }

    private var datedCount: Int {
        entries.filter { $0.game.releaseDate != nil }.count
    }

    var body: some View {
        Group {
            if entries.isEmpty {
                ContentUnavailableView(
                    "Ønskelisten er tom",
                    systemImage: "heart",
                    description: Text("Klikk på hjertet på et spill for å legge det til")
                )
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Available now (already released)
                        if !availableNowGames.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Tilgjengelig nå")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)
                                    .padding(.horizontal, 20)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(availableNowGames, id: \.externalId) { game in
                                            UpcomingWishlistCard(game: game)
                                                .onTapGesture { state.selectedGame = game }
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                }
                            }
                        }

                        // Upcoming section (games within 14 days)
                        if !upcomingGames.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Spill som kommer snart")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)
                                    .padding(.horizontal, 20)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(upcomingGames, id: \.externalId) { game in
                                            UpcomingWishlistCard(game: game)
                                                .onTapGesture { state.selectedGame = game }
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                }
                            }
                        }

                        // Full wishlist grid
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Alle ønsker (\(entries.count))")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)

                                Spacer()

                                if datedCount > 0 {
                                    Button {
                                        exportIcs()
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "arrow.down.circle")
                                                .font(.caption)
                                            Text("Last ned kalender (\(datedCount) spill)")
                                                .font(.caption)
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }
                            .padding(.horizontal, 20)

                            // All wishlisted games grid
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(entries) { entry in
                                    WishlistCard(game: entry.game, onRemove: { remove(entry) })
                                        .onTapGesture { state.selectedGame = entry.game }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.vertical, 20)
                }
            }
        }
    }

    private func remove(_ entry: WishlistEntry) {
        let externalId = entry.game.externalId
        modelContext.delete(entry)
        Task { await NotificationService.shared.removeAllNotifications(for: externalId) }
    }

    private func exportIcs() {
        let games = entries.map(\.game)
        let icsContent = ICSExporter.buildBulkIcs(for: games)
        guard let fileURL = ICSExporter.saveToFile(content: icsContent, filename: "spillønskeliste.ics") else { return }

        #if os(macOS)
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.calendarEvent]
        panel.nameFieldStringValue = "spillønskeliste.ics"
        panel.begin { response in
            if response == .OK, let dest = panel.url {
                try? FileManager.default.copyItem(at: fileURL, to: dest)
            }
        }
        #else
        // On iOS, use share sheet
        let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
        #endif
    }
}

// MARK: - Large game card

struct WishlistCard: View {
    let game: GameRelease
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Cover image with heart overlay
            ZStack(alignment: .topTrailing) {
                ZStack(alignment: .bottomLeading) {
                    AsyncImage(url: URL(string: game.coverImageUrl ?? "")) { image in
                        image.resizable().aspectRatio(3/4, contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(game.title.pillColor.opacity(0.2))
                            .overlay {
                                Text(game.title.prefix(2).uppercased())
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundStyle(game.title.pillColor.opacity(0.4))
                            }
                    }
                    .frame(maxWidth: .infinity)
                    .aspectRatio(3/4, contentMode: .fit)
                    .clipShape(.rect(cornerRadius: 10))

                    // Rating badge
                    if let rating = game.rating {
                        RatingBadge(score: rating)
                            .padding(6)
                    }
                }

                // Heart remove button
                Button(action: onRemove) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.red)
                        .padding(7)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .padding(8)
            }

            // Title
            Text(game.title)
                .font(.callout)
                .fontWeight(.semibold)
                .lineLimit(2)

            // Release date or window
            if let date = game.releaseDate {
                Text(date.formatted(.dateTime.day().month(.abbreviated).year()).uppercased())
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
            } else if let window = game.releaseWindow {
                Text(window)
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
            } else {
                Text("TBA")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Small upcoming card

struct UpcomingWishlistCard: View {
    let game: GameRelease

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            AsyncImage(url: URL(string: game.coverImageUrl ?? "")) { image in
                image.resizable().aspectRatio(3/4, contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(game.title.pillColor.opacity(0.2))
                    .overlay {
                        Text(game.title.prefix(2).uppercased())
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(game.title.pillColor.opacity(0.6))
                    }
            }
            .frame(width: 100, height: 133)
            .clipShape(.rect(cornerRadius: 8))

            Text(game.title)
                .font(.caption)
                .fontWeight(.semibold)
                .lineLimit(1)
                .frame(width: 100, alignment: .leading)

            if let date = game.releaseDate {
                Text(date.formatted(.dateTime.day().month(.abbreviated)).uppercased())
                    .font(.system(size: 10))
                    .foregroundStyle(Color.accentColor)
            }
        }
    }
}
