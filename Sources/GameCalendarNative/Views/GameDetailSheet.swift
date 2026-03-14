import SwiftUI
import SwiftData
#if canImport(WebKit)
import WebKit
#endif

struct GameDetailSheet: View {
    let game: GameRelease
    let state: AppState

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var wishlistEntries: [WishlistEntry]

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

                // Screenshots
                if !game.screenshotUrls.isEmpty {
                    screenshotGrid
                }

                // Trailers
                if !game.videoIds.isEmpty {
                    trailerSection
                }
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
    }

    // MARK: - Cover

    private var coverImage: some View {
        AsyncImage(url: URL(string: game.coverImageUrl ?? "")) { image in
            image.resizable().aspectRatio(3/4, contentMode: .fit)
        } placeholder: {
            RoundedRectangle(cornerRadius: 8)
                .fill(game.title.pillColor.opacity(0.2))
                .overlay { Image(systemName: "gamecontroller").font(.largeTitle).foregroundStyle(game.title.pillColor.opacity(0.4)) }
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

            // Rating
            if let rating = game.rating {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill").foregroundStyle(.yellow)
                    Text(String(format: "%.0f / 100", rating))
                        .fontWeight(.semibold)
                    if game.popularity > 0 {
                        Text("· \(game.popularity) anmeldelser")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.callout)
            }

            // Developer / Publisher
            if let dev = game.developer {
                Text("Utvikler: \(dev)").font(.caption).foregroundStyle(.secondary)
            }
            if let pub = game.publisher {
                Text("Utgiver: \(pub)").font(.caption).foregroundStyle(.secondary)
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

    // MARK: - Screenshots

    private var screenshotGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Skjermbilder")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(game.screenshotUrls, id: \.self) { url in
                        AsyncImage(url: URL(string: url)) { image in
                            image.resizable().aspectRatio(16/9, contentMode: .fill)
                        } placeholder: {
                            Rectangle().fill(.quaternary)
                        }
                        .frame(width: 240, height: 135)
                        .clipShape(.rect(cornerRadius: 6))
                    }
                }
            }
        }
    }

    // MARK: - Trailers

    private var trailerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Trailere")
                .font(.headline)

            ForEach(game.videoIds.prefix(2), id: \.self) { videoId in
                YouTubeView(videoId: videoId)
                    .frame(height: 240)
                    .clipShape(.rect(cornerRadius: 8))
            }
        }
    }
}

// MARK: - YouTube WebView

struct YouTubeView: View {
    let videoId: String

    var body: some View {
        WebViewRepresentable(url: URL(string: "https://www.youtube.com/embed/\(videoId)")!)
    }
}

#if os(macOS)
struct WebViewRepresentable: NSViewRepresentable {
    let url: URL
    func makeNSView(context: Context) -> WKWebView { WKWebView() }
    func updateNSView(_ view: WKWebView, context: Context) {
        view.load(URLRequest(url: url))
    }
}
#else
struct WebViewRepresentable: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> WKWebView { WKWebView() }
    func updateUIView(_ view: WKWebView, context: Context) {
        view.load(URLRequest(url: url))
    }
}
#endif
