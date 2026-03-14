import SwiftUI
import SwiftData

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

    private var isWishlisted: Bool {
        !game.wishlistEntries.isEmpty
    }

    var body: some View {
        Button {
            toggleWishlist()
        } label: {
            Image(systemName: isWishlisted ? "heart.fill" : "heart")
                .font(.system(size: 13))
                .foregroundStyle(isWishlisted ? .red : .white)
                .shadow(color: .black.opacity(0.5), radius: 2)
                .padding(6)
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
    }

    private func toggleWishlist() {
        if let entry = game.wishlistEntries.first {
            modelContext.delete(entry)
        } else {
            modelContext.insert(WishlistEntry(game: game))
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

            // Heart button (top-right)
            HeartOverlayButton(game: game)
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
            "X-WR-CALNAME:Spillønskeliste",
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
        NSApplication.shared.keyWindow?.toggleFullScreen(nil)
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
