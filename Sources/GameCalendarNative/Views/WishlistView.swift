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
    @Query private var steamPrices: [SteamPrice]

    private let columns = [GridItem(.adaptive(minimum: 130, maximum: 220), spacing: 16)]

    private func price(for game: GameRelease) -> SteamPrice? {
        guard let steamId = game.steamAppId else { return nil }
        return steamPrices.first { $0.steamAppId == steamId }
    }

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

                                // Share wishlist
                                Button { shareWishlist() } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "square.and.arrow.up")
                                            .font(.caption)
                                        Text("Del")
                                            .font(.caption)
                                    }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)

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
                                    WishlistCard(game: entry.game, steamPrice: price(for: entry.game), onRemove: { remove(entry) })
                                        .onTapGesture { state.selectedGame = entry.game }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.vertical, 20)
                }
                .task {
                    await SteamPriceService.shared.fetchPricesForWishlist(container: modelContext.container)
                }
            }
        }
    }

    private func remove(_ entry: WishlistEntry) {
        let externalId = entry.game.externalId
        modelContext.delete(entry)
        Task { await NotificationService.shared.removeAllNotifications(for: externalId) }
    }

    private func shareWishlist() {
        var lines = [String(localized: "🎮 Min spillønskeliste:\n")]
        for entry in entries {
            let game = entry.game
            var line = "• \(game.title)"
            if let date = game.releaseDate {
                line += " — \(date.formatted(.dateTime.day().month(.abbreviated).year()))"
            } else {
                line += " — TBA"
            }
            lines.append(line)
        }
        let text = lines.joined(separator: "\n")

        #if os(macOS)
        let picker = NSSharingServicePicker(items: [text as NSString])
        if let window = NSApp.keyWindow, let contentView = window.contentView {
            picker.show(relativeTo: .zero, of: contentView, preferredEdge: .minY)
        }
        #else
        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
        #endif
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
    var steamPrice: SteamPrice? = nil
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

            // Countdown
            if let countdown = UpcomingWishlistCard.countdownText(for: game.releaseDate) {
                Text(countdown.text)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(countdown.isImminent ? .white : Color.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        countdown.isImminent ? Color.accentColor : Color.accentColor.opacity(0.15),
                        in: Capsule()
                    )
            }

            // Steam price
            if let price = steamPrice {
                SteamPriceLabel(price: price)
            }
        }
    }
}

// MARK: - Steam price label

struct SteamPriceLabel: View {
    let price: SteamPrice

    var body: some View {
        HStack(spacing: 6) {
            if price.isFree {
                Text("Gratis")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.green)
            } else {
                if let usd = price.formattedUsd {
                    Text(usd)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.primary)
                }
                if let nok = price.formattedNok {
                    Text(nok)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                if price.discountPercent > 0 {
                    Text("-\(price.discountPercent)%")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(.green, in: .rect(cornerRadius: 3))
                }
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

            // Countdown
            if let countdown = Self.countdownText(for: game.releaseDate) {
                Text(countdown.text)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(countdown.isImminent ? .white : Color.accentColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        countdown.isImminent ? Color.accentColor : Color.accentColor.opacity(0.15),
                        in: Capsule()
                    )
            }
        }
    }

    static func countdownText(for date: Date?) -> (text: String, isImminent: Bool)? {
        guard let date = date else { return nil }
        let today = Calendar.current.startOfDay(for: Date())
        let releaseDay = Calendar.current.startOfDay(for: date)
        guard releaseDay >= today else { return nil }
        let days = Calendar.current.dateComponents([.day], from: today, to: releaseDay).day ?? 0
        switch days {
        case 0: return (String(localized: "I dag!"), true)
        case 1: return (String(localized: "I morgen!"), true)
        default: return (String(localized: "om \(days) dager"), days <= 7)
        }
    }
}
