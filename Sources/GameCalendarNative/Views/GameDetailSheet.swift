import SwiftUI
import SwiftData
import UniformTypeIdentifiers
#if canImport(WebKit)
import WebKit
#endif
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct GameDetailSheet: View {
    let game: GameRelease
    let state: AppState

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var wishlistEntries: [WishlistEntry]

    @State private var lightboxIndex: Int? = nil
    @State private var trailerVideoId: String? = nil

    private var isWishlisted: Bool {
        wishlistEntries.contains { $0.game.externalId == game.externalId }
    }

    private func toggleWishlist() {
        if let entry = wishlistEntries.first(where: { $0.game.externalId == game.externalId }) {
            modelContext.delete(entry)
        } else {
            modelContext.insert(WishlistEntry(game: game))
        }
    }

    var body: some View {
        ZStack {
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

                    // Trailers (thumbnail grid with play overlay, matches web)
                    if !game.videoIds.isEmpty {
                        trailerSection
                    }

                    // Screenshots (clickable, opens lightbox)
                    if !game.screenshotUrls.isEmpty {
                        screenshotSection
                    }

                    // Action buttons (matches web's modal-actions)
                    actionButtons
                }
                .padding(24)
            }
            .frame(minWidth: 560, minHeight: 400)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Lukk") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(action: toggleWishlist) {
                        Image(systemName: isWishlisted ? "heart.fill" : "heart")
                            .foregroundStyle(isWishlisted ? .red : .primary)
                    }
                    .help(isWishlisted ? "Fjern fra ønskeliste" : "Legg til ønskeliste")
                }
                ToolbarItem(placement: .primaryAction) {
                    if let url = game.websiteUrl.flatMap({ URL(string: $0) }) {
                        Link(destination: url) {
                            Label("Åpne nettside", systemImage: "safari")
                        }
                    }
                }
            }
            .navigationTitle(game.title)

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

            // Trailer player overlay
            if let videoId = trailerVideoId {
                trailerPlayerOverlay(videoId: videoId)
            }
        }
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

    // MARK: - Trailers (thumbnail grid with play overlay, matches web)

    private var trailerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Trailere")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(game.videoIds.prefix(4), id: \.self) { videoId in
                        Button {
                            trailerVideoId = videoId
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

    // MARK: - Action buttons (matches web's modal-actions)

    private var actionButtons: some View {
        HStack(spacing: 12) {
            // Wishlist button with text label
            Button(action: toggleWishlist) {
                HStack(spacing: 6) {
                    Image(systemName: isWishlisted ? "heart.fill" : "heart")
                        .font(.caption)
                    Text(isWishlisted ? "På ønskelisten" : "Legg til ønskeliste")
                        .font(.callout)
                }
            }
            .buttonStyle(.bordered)
            .tint(isWishlisted ? .red : nil)

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

            // ICS calendar download
            if game.releaseDate != nil {
                Button {
                    exportSingleIcs()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.caption)
                        Text("Legg til i kalender")
                            .font(.callout)
                    }
                }
                .buttonStyle(.bordered)
            }
        }
    }

    // MARK: - Trailer player overlay

    private func trailerPlayerOverlay(videoId: String) -> some View {
        ZStack {
            Color.black.opacity(0.93)
                .ignoresSafeArea()
                .onTapGesture { trailerVideoId = nil }

            VStack {
                HStack {
                    Spacer()
                    Button {
                        trailerVideoId = nil
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(16)
                }

                YouTubeView(videoId: videoId)
                    .frame(maxWidth: 800, maxHeight: 450)
                    .clipShape(.rect(cornerRadius: 10))
                    .padding(40)

                Spacer()
            }
        }
        .onKeyPress(.escape) {
            trailerVideoId = nil
            return .handled
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

// MARK: - YouTube WebView

struct YouTubeView: View {
    let videoId: String

    private var embedURL: URL {
        URL(string: "https://www.youtube-nocookie.com/embed/\(videoId)?playsinline=1&rel=0&autoplay=1")!
    }

    var body: some View {
        WebViewRepresentable(url: embedURL)
    }
}

private func makeYouTubeWebView() -> WKWebView {
    let config = WKWebViewConfiguration()
    #if os(iOS)
    config.allowsInlineMediaPlayback = true
    config.mediaTypesRequiringUserActionForPlayback = []
    #endif
    let webView = WKWebView(frame: .zero, configuration: config)
    webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15"
    return webView
}

#if os(macOS)
struct WebViewRepresentable: NSViewRepresentable {
    let url: URL
    func makeNSView(context: Context) -> WKWebView { makeYouTubeWebView() }
    func updateNSView(_ view: WKWebView, context: Context) {
        view.load(URLRequest(url: url))
    }
}
#else
struct WebViewRepresentable: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> WKWebView { makeYouTubeWebView() }
    func updateUIView(_ view: WKWebView, context: Context) {
        view.load(URLRequest(url: url))
    }
}
#endif
