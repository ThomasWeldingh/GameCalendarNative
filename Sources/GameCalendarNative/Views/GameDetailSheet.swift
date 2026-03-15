import SwiftUI
import SwiftData
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct GameDetailSheet: View {
    let game: GameRelease
    @Bindable var state: AppState

    @Environment(\.modelContext) private var modelContext
    @Query private var wishlistEntries: [WishlistEntry]

    @State private var lightboxIndex: Int? = nil
    @State private var activeVideoId: String? = nil

    private var isWishlisted: Bool {
        wishlistEntries.contains { $0.game.externalId == game.externalId }
    }

    private func toggleWishlist() {
        if let entry = wishlistEntries.first(where: { $0.game.externalId == game.externalId }) {
            modelContext.delete(entry)
            Task { await NotificationService.shared.removeAllNotifications(for: game.externalId) }
        } else {
            modelContext.insert(WishlistEntry(game: game))
            Task { await NotificationService.shared.scheduleReleaseNotifications(for: game) }
        }
    }

    private func close() {
        state.selectedGame = nil
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Custom header bar (replaces toolbar)
                headerBar

                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header: cover + info
                        HStack(alignment: .top, spacing: 20) {
                            coverImage
                            headerInfo
                        }

                        Divider()

                        // Description
                        if let desc = game.gameDescription, !desc.isEmpty {
                            Text(desc)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        // Trailers (inline player + thumbnail grid)
                        if !game.videoIds.isEmpty {
                            trailerSection
                        }

                        // Screenshots (clickable, opens lightbox)
                        if !game.screenshotUrls.isEmpty {
                            screenshotSection
                        }

                        // Action buttons (website only)
                        actionButtons
                    }
                    .padding(24)
                }
            }

            // Screenshot lightbox overlay
            if let index = lightboxIndex {
                ScreenshotLightbox(
                    urls: game.screenshotUrls,
                    currentIndex: Binding(
                        get: { index },
                        set: { lightboxIndex = $0 }
                    ),
                    onClose: { lightboxIndex = nil }
                )
            }
        }
        .onKeyPress(.escape) {
            // Don't close the modal if a YouTube video is playing —
            // let the WKWebView handle Esc (exit fullscreen) instead.
            if activeVideoId != nil { return .ignored }
            close()
            return .handled
        }
    }

    // MARK: - Header bar

    private var headerBar: some View {
        HStack(spacing: 12) {
            Text(game.title)
                .font(.headline)
                .lineLimit(1)

            Spacer()

            // Heart (wishlist)
            Button(action: toggleWishlist) {
                Image(systemName: isWishlisted ? "heart.fill" : "heart")
                    .font(.system(size: 14))
                    .foregroundStyle(isWishlisted ? .red : .primary)
            }
            .buttonStyle(.plain)
            .help(isWishlisted ? "Fjern fra ønskeliste" : "Legg til ønskeliste")

            // Calendar export
            if game.releaseDate != nil {
                Button(action: exportSingleIcs) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .help("Legg til i kalender")
            }

            // Website link
            if let url = game.websiteUrl.flatMap({ URL(string: $0) }) {
                Link(destination: url) {
                    Image(systemName: "safari")
                        .font(.system(size: 14))
                }
                .help("Åpne nettside")
            }

            // Close button
            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(6)
                    .background(.quaternary, in: Circle())
            }
            .buttonStyle(.plain)
            .help("Lukk")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Cover

    private var coverImage: some View {
        AsyncImage(url: URL(string: game.coverImageUrl ?? "")) { image in
            image.resizable().aspectRatio(3/4, contentMode: .fit)
        } placeholder: {
            RoundedRectangle(cornerRadius: 8)
                .fill(game.title.pillColor.opacity(0.2))
                .overlay {
                    Text(game.title.prefix(2).uppercased())
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(game.title.pillColor.opacity(0.4))
                }
                .aspectRatio(3/4, contentMode: .fit)
        }
        .frame(width: 120)
        .clipShape(.rect(cornerRadius: 8))
        .shadow(radius: 4)
    }

    // MARK: - Header info

    private var headerInfo: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(game.title)
                .font(.title2)
                .fontWeight(.bold)

            // Release date
            HStack {
                Image(systemName: "calendar")
                if let date = game.releaseDate {
                    Text(date.formatted(date: .long, time: .omitted))
                } else if let window = game.releaseWindow {
                    Text(window)
                } else {
                    Text("TBA")
                }
            }
            .font(.callout)
            .foregroundStyle(.secondary)

            // Platforms
            if !game.platforms.isEmpty {
                HStack(spacing: 6) {
                    ForEach(game.platforms, id: \.self) { platform in
                        Text(platform)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.quaternary, in: Capsule())
                    }
                }
            }

            // Rating (color-coded badge, matches web)
            if let rating = game.rating {
                HStack(spacing: 6) {
                    RatingBadge(score: rating)
                    Text("/ 100")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    if game.popularity > 0 {
                        Text("(\(game.popularity) vurderinger)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Developer / Publisher
            if let dev = game.developer {
                HStack(spacing: 4) {
                    Text("Utvikler").font(.caption).foregroundStyle(.secondary).fontWeight(.semibold)
                    Text(dev).font(.caption).foregroundStyle(.secondary)
                }
            }
            if let pub = game.publisher {
                HStack(spacing: 4) {
                    Text("Utgiver").font(.caption).foregroundStyle(.secondary).fontWeight(.semibold)
                    Text(pub).font(.caption).foregroundStyle(.secondary)
                }
            }

            // Genres
            if !game.genres.isEmpty {
                HStack(spacing: 4) {
                    ForEach(game.genres.prefix(5), id: \.self) { genre in
                        Text(genre)
                            .font(.system(size: 10))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(game.title.pillColor.opacity(0.15), in: Capsule())
                            .foregroundStyle(game.title.pillColor)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Trailers (inline YouTube player + thumbnail grid)

    private var trailerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Trailere")
                .font(.headline)

            // Inline player (shows when a trailer is selected)
            #if os(macOS)
            if let videoId = activeVideoId {
                ZStack(alignment: .topTrailing) {
                    YouTubePlayerView(videoId: videoId)
                        .aspectRatio(16/9, contentMode: .fit)
                        .frame(maxWidth: 640)
                        .clipShape(.rect(cornerRadius: 8))

                    // Close player button
                    Button {
                        activeVideoId = nil
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption)
                            .foregroundStyle(.white)
                            .padding(6)
                            .background(.black.opacity(0.6), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                }
            }
            #endif

            // Thumbnail grid
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(game.videoIds.prefix(4), id: \.self) { videoId in
                        Button {
                            #if os(macOS)
                            activeVideoId = videoId
                            #else
                            if let url = URL(string: "https://www.youtube.com/watch?v=\(videoId)") {
                                UIApplication.shared.open(url)
                            }
                            #endif
                        } label: {
                            ZStack {
                                AsyncImage(url: URL(string: "https://img.youtube.com/vi/\(videoId)/mqdefault.jpg")) { image in
                                    image.resizable().aspectRatio(16/9, contentMode: .fill)
                                } placeholder: {
                                    Rectangle().fill(.quaternary)
                                }
                                .frame(width: 240, height: 135)
                                .clipShape(.rect(cornerRadius: 6))

                                // Play button overlay
                                Circle()
                                    .fill(.black.opacity(0.5))
                                    .frame(width: 44, height: 44)
                                    .overlay {
                                        Image(systemName: "play.fill")
                                            .font(.title3)
                                            .foregroundStyle(.white)
                                            .offset(x: 2)
                                    }
                            }
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(activeVideoId == videoId ? Color.accentColor : .clear, lineWidth: 2)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Screenshots (clickable, opens lightbox)

    private var screenshotSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Skjermbilder")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(game.screenshotUrls.enumerated()), id: \.offset) { index, url in
                        Button {
                            lightboxIndex = index
                        } label: {
                            AsyncImage(url: URL(string: url)) { image in
                                image.resizable().aspectRatio(16/9, contentMode: .fill)
                            } placeholder: {
                                Rectangle().fill(.quaternary)
                            }
                            .frame(width: 240, height: 135)
                            .clipShape(.rect(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Action buttons (website link — heart + calendar are in toolbar)

    private var actionButtons: some View {
        HStack(spacing: 12) {
            // Website link
            if let urlString = game.websiteUrl, let url = URL(string: urlString) {
                Link(destination: url) {
                    HStack(spacing: 4) {
                        Image(systemName: "globe")
                            .font(.caption)
                        Text("Nettside")
                            .font(.callout)
                    }
                }
                .buttonStyle(.bordered)
            }
        }
    }

    // MARK: - ICS export

    private func exportSingleIcs() {
        guard let icsContent = ICSExporter.buildIcs(for: game) else { return }
        let filename = "\(game.title.replacingOccurrences(of: "[^a-zA-Z0-9]", with: "-", options: .regularExpression)).ics"
        guard let fileURL = ICSExporter.saveToFile(content: icsContent, filename: filename) else { return }

        #if os(macOS)
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.calendarEvent]
        panel.nameFieldStringValue = filename
        panel.begin { response in
            if response == .OK, let dest = panel.url {
                try? FileManager.default.copyItem(at: fileURL, to: dest)
            }
        }
        #else
        let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
        #endif
    }
}
