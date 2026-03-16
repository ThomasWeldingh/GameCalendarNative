import SwiftUI
import SwiftData
import WebKit

// MARK: - Rating Badge (color-coded, matches web)

struct RatingBadge: View {
    let score: Double

    private var color: Color {
        let rounded = Int(score.rounded())
        if rounded >= 85 { return Color(red: 0.133, green: 0.773, blue: 0.369) }  // #22c55e
        if rounded >= 70 { return Color(red: 0.518, green: 0.8, blue: 0.086) }    // #84cc16
        if rounded >= 55 { return Color(red: 0.976, green: 0.451, blue: 0.086) }   // #f97316
        return Color(red: 0.937, green: 0.267, blue: 0.267)                        // #ef4444
    }

    var body: some View {
        Text("\(Int(score.rounded()))")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color, in: RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - Heart Overlay Button (for card overlays)
// Uses the game's relationship instead of @Query to avoid N concurrent queries

struct HeartOverlayButton: View {
    let game: GameRelease
    @Environment(\.modelContext) private var modelContext
    @State private var wishlisted = false

    var body: some View {
        Button {
            toggleWishlist()
        } label: {
            Image(systemName: wishlisted ? "heart.fill" : "heart")
                .font(.system(size: 13))
                .foregroundStyle(wishlisted ? .red : .white)
                .shadow(color: .black.opacity(0.5), radius: 2)
                .padding(6)
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .help(wishlisted ? String(localized: "Fjern fra ønskeliste") : String(localized: "Legg til ønskeliste"))
        .onAppear { wishlisted = !game.wishlistEntries.isEmpty }
        .onChange(of: game.wishlistEntries.count) { _, newCount in
            wishlisted = newCount > 0
        }
    }

    private func toggleWishlist() {
        if let entry = game.wishlistEntries.first {
            modelContext.delete(entry)
            wishlisted = false
            Task { await NotificationService.shared.removeAllNotifications(for: game.externalId) }
        } else {
            modelContext.insert(WishlistEntry(game: game))
            wishlisted = true
            Task { await NotificationService.shared.scheduleReleaseNotifications(for: game) }
        }
        try? modelContext.save()
    }
}

// MARK: - Calendar Overlay Button (for card overlays, matches heart style)

struct CalendarOverlayButton: View {
    let game: GameRelease

    var body: some View {
        if game.releaseDate != nil {
            Button {
                exportIcs()
            } label: {
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 12))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 2)
                    .padding(6)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .help("Legg til i kalender")
        }
    }

    private func exportIcs() {
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
        #endif
    }
}

// MARK: - Combined card overlay buttons (heart + calendar)

struct CardOverlayButtons: View {
    let game: GameRelease

    var body: some View {
        VStack(spacing: 4) {
            HeartOverlayButton(game: game)
            CalendarOverlayButton(game: game)
        }
    }
}

// MARK: - Cover Image with Overlays (heart + rating)

struct GameCoverImage: View {
    let game: GameRelease
    let height: CGFloat?
    let aspectRatio: CGFloat

    init(game: GameRelease, height: CGFloat? = nil, aspectRatio: CGFloat = 3.0/4.0) {
        self.game = game
        self.height = height
        self.aspectRatio = aspectRatio
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ZStack(alignment: .bottomLeading) {
                coverContent

                // Rating badge (bottom-left)
                if let rating = game.rating {
                    RatingBadge(score: rating)
                        .padding(6)
                }
            }

            // Heart + calendar buttons (top-right)
            CardOverlayButtons(game: game)
                .padding(4)
        }
    }

    @ViewBuilder
    private var coverContent: some View {
        let image = AsyncImage(url: URL(string: game.coverImageUrl ?? "")) { img in
            img.resizable().aspectRatio(aspectRatio, contentMode: .fill)
        } placeholder: {
            Rectangle()
                .fill(game.title.pillColor.opacity(0.2))
                .overlay {
                    Text(game.title.prefix(2).uppercased())
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(game.title.pillColor.opacity(0.6))
                }
        }

        if let height {
            image.frame(height: height).clipped()
        } else {
            image.aspectRatio(aspectRatio, contentMode: .fit)
        }
    }
}

// MARK: - ICS Calendar Export

struct ICSExporter {
    static func buildIcs(for game: GameRelease) -> String? {
        guard let date = game.releaseDate else { return nil }
        let start = formatIcsDate(date)
        let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: date)!
        let end = formatIcsDate(nextDay)
        let desc = (game.gameDescription ?? "")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: ",", with: "\\,")
            .replacingOccurrences(of: ";", with: "\\;")

        var lines = [
            "BEGIN:VCALENDAR",
            "VERSION:2.0",
            "PRODID:-//GameCalendar//EN",
            "BEGIN:VEVENT",
            "DTSTART;VALUE=DATE:\(start)",
            "DTEND;VALUE=DATE:\(end)",
            "SUMMARY:\(game.title)",
        ]
        if !desc.isEmpty {
            lines.append("DESCRIPTION:\(desc)")
        }
        lines.append(contentsOf: ["END:VEVENT", "END:VCALENDAR"])
        return lines.joined(separator: "\r\n")
    }

    static func buildBulkIcs(for games: [GameRelease]) -> String {
        let dated = games.filter { $0.releaseDate != nil }
        let events = dated.map { game -> String in
            let start = formatIcsDate(game.releaseDate!)
            let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: game.releaseDate!)!
            let end = formatIcsDate(nextDay)
            let desc = (game.gameDescription ?? "")
                .replacingOccurrences(of: "\n", with: "\\n")
                .replacingOccurrences(of: ",", with: "\\,")
                .replacingOccurrences(of: ";", with: "\\;")
            var lines = [
                "BEGIN:VEVENT",
                "DTSTART;VALUE=DATE:\(start)",
                "DTEND;VALUE=DATE:\(end)",
                "SUMMARY:🎮 \(game.title)",
            ]
            if !desc.isEmpty {
                lines.append("DESCRIPTION:\(desc)")
            }
            lines.append("END:VEVENT")
            return lines.joined(separator: "\r\n")
        }

        var cal = [
            "BEGIN:VCALENDAR",
            "VERSION:2.0",
            "PRODID:-//GameCalendar//Wishlist//EN",
            "X-WR-CALNAME:\(String(localized: "Spillønskeliste"))",
        ]
        cal.append(contentsOf: events)
        cal.append("END:VCALENDAR")
        return cal.joined(separator: "\r\n")
    }

    static func saveToFile(content: String, filename: String) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filename)
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            return nil
        }
    }

    private static func formatIcsDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: date)
    }
}

// MARK: - Screenshot Lightbox

struct ScreenshotLightbox: View {
    let urls: [String]
    @Binding var currentIndex: Int
    let onClose: () -> Void

    var body: some View {
        ZStack {
            // Dark background
            Color.black.opacity(0.93)
                .ignoresSafeArea()
                .onTapGesture { onClose() }

            // Current image
            if currentIndex < urls.count {
                AsyncImage(url: URL(string: urls[currentIndex])) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(40)
                } placeholder: {
                    ProgressView()
                        .tint(.white)
                }
            }

            // Navigation arrows
            HStack {
                if currentIndex > 0 {
                    Button {
                        withAnimation { currentIndex -= 1 }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.title)
                            .foregroundStyle(.white)
                            .padding()
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                if currentIndex < urls.count - 1 {
                    Button {
                        withAnimation { currentIndex += 1 }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.title)
                            .foregroundStyle(.white)
                            .padding()
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)

            // Top bar: fullscreen (left) + close (right)
            VStack {
                HStack {
                    // Fullscreen button (top-left)
                    Button {
                        toggleFullscreen()
                    } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(16)
                    .help("Fullskjerm")

                    Spacer()

                    // Close button (top-right)
                    Button {
                        onClose()
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
                Spacer()
            }

            // Dot indicators (bottom)
            if urls.count > 1 {
                VStack {
                    Spacer()
                    HStack(spacing: 6) {
                        ForEach(0..<urls.count, id: \.self) { index in
                            Circle()
                                .fill(index == currentIndex ? Color.white : Color.white.opacity(0.4))
                                .frame(width: 8, height: 8)
                        }
                    }
                    .padding(.bottom, 24)
                }
            }
        }
        .onKeyPress(.escape) {
            onClose()
            return .handled
        }
        .onKeyPress(.leftArrow) {
            if currentIndex > 0 { withAnimation { currentIndex -= 1 } }
            return .handled
        }
        .onKeyPress(.rightArrow) {
            if currentIndex < urls.count - 1 { withAnimation { currentIndex += 1 } }
            return .handled
        }
        .onKeyPress("f") {
            toggleFullscreen()
            return .handled
        }
    }

    private func toggleFullscreen() {
        #if os(macOS)
        // The lightbox lives inside a SwiftUI overlay, so NSApp.keyWindow
        // and .mainWindow may not resolve correctly. Find the visible main window.
        if let window = NSApp.windows.first(where: { $0.isVisible && $0.canBecomeMain }) {
            window.toggleFullScreen(nil)
        }
        #endif
    }
}

// MARK: - Skeleton loading placeholder

struct SkeletonCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(.quaternary)
                .aspectRatio(3/4, contentMode: .fit)

            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(.quaternary)
                    .frame(height: 12)
                RoundedRectangle(cornerRadius: 3)
                    .fill(.quaternary)
                    .frame(width: 60, height: 10)
            }
            .padding(8)
        }
        .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 10))
        .clipShape(.rect(cornerRadius: 10))
        .redacted(reason: .placeholder)
    }
}

// MARK: - YouTube In-App Player (WKWebView)

#if os(macOS)
struct YouTubePlayerView: NSViewRepresentable {
    let videoId: String

    func makeNSView(context: Context) -> FocusableWKWebView {
        let config = WKWebViewConfiguration()
        config.allowsAirPlayForMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.preferences.setValue(true, forKey: "fullScreenEnabled")

        // Inject CSS to hide YouTube chrome, keeping only the video player.
        let cleanupScript = WKUserScript(
            source: """
            new MutationObserver(function() {
                if (!document.getElementById('yt-player-css')) {
                    var s = document.createElement('style');
                    s.id = 'yt-player-css';
                    s.textContent = `
                        #masthead-container, #secondary, #comments, #below,
                        ytd-watch-metadata, ytd-merch-shelf-renderer,
                        #related, #chat, tp-yt-app-drawer, #guide,
                        ytd-engagement-panel-section-list-renderer,
                        ytd-mini-guide-renderer, #guide-content,
                        .ytp-ce-element, .ytp-endscreen-content,
                        #description, #meta, #info-container,
                        ytd-watch-info-text { display: none !important; }
                        body, html, ytd-app { background: #000 !important; overflow: hidden !important; }
                        #page-manager { margin: 0 !important; padding: 0 !important; }
                        #primary { max-width: 100% !important; margin: 0 !important; padding: 0 !important; }
                        #player-container-outer { max-width: 100% !important; }
                        #movie_player { position: fixed !important; top: 0; left: 0;
                                        width: 100vw !important; height: 100vh !important; }
                        .html5-video-container { width: 100% !important; height: 100% !important; }
                        video { width: 100% !important; height: 100% !important; object-fit: contain !important; }
                    `;
                    document.head.appendChild(s);
                }
            }).observe(document, { childList: true, subtree: true });
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(cleanupScript)

        // Auto-focus the YouTube player element so keyboard shortcuts work
        // (Space=play/pause, arrows=seek/volume, F=fullscreen, Esc=exit fullscreen, etc.)
        let focusScript = WKUserScript(
            source: """
            var _ytFocusInterval = setInterval(function() {
                var player = document.getElementById('movie_player');
                if (player) {
                    player.focus();
                    clearInterval(_ytFocusInterval);
                }
            }, 300);
            """,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(focusScript)

        let webView = FocusableWKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ webView: FocusableWKWebView, context: Context) {
        guard context.coordinator.lastVideoId != videoId else { return }
        context.coordinator.lastVideoId = videoId
        if let url = URL(string: "https://www.youtube.com/watch?v=\(videoId)") {
            webView.load(URLRequest(url: url))
        }
        // Make the WKWebView first responder so key events reach it
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            webView.window?.makeFirstResponder(webView)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator {
        var lastVideoId: String?
    }
}

/// WKWebView subclass that eagerly accepts first responder, ensuring keyboard
/// events (Space, arrows, Esc, F, etc.) reach YouTube's JS player controls.
class FocusableWKWebView: WKWebView {
    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        window?.makeFirstResponder(self)
    }

    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        // Re-focus the YouTube player element inside the web page
        evaluateJavaScript("document.getElementById('movie_player')?.focus()") { _, _ in }
        return result
    }
}
#endif
