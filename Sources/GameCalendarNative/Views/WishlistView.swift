import SwiftUI
import SwiftData

struct WishlistView: View {
    let state: AppState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WishlistEntry.addedAt, order: .reverse) private var entries: [WishlistEntry]

    private let columns = [GridItem(.adaptive(minimum: 160, maximum: 220), spacing: 16)]

    private var upcomingGames: [GameRelease] {
        let now = Date()
        return entries.compactMap { entry -> GameRelease? in
            guard let date = entry.game.releaseDate, date > now else { return nil }
            return entry.game
        }
        .sorted { ($0.releaseDate ?? .distantFuture) < ($1.releaseDate ?? .distantFuture) }
    }

    var body: some View {
        Group {
            if entries.isEmpty {
                ContentUnavailableView(
                    "Ønskeliste er tom",
                    systemImage: "heart",
                    description: Text("Åpne et spill og trykk hjertet for å legge det til")
                )
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Upcoming section
                        if !upcomingGames.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("SPILL SOM KOMMER SNART")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
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

                        // All wishlisted games grid
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("\(entries.count) spill")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 20)
                                Spacer()
                            }

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
        modelContext.delete(entry)
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
                AsyncImage(url: URL(string: game.coverImageUrl ?? "")) { image in
                    image.resizable().aspectRatio(3/4, contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(game.title.pillColor.opacity(0.2))
                        .overlay {
                            Image(systemName: "gamecontroller")
                                .font(.largeTitle)
                                .foregroundStyle(game.title.pillColor.opacity(0.4))
                        }
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(3/4, contentMode: .fit)
                .clipShape(.rect(cornerRadius: 10))

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

            // Release date
            if let date = game.releaseDate {
                Text(date.formatted(.dateTime.day().month(.abbreviated).year()).uppercased())
                    .font(.caption)
                    .foregroundStyle(.accentColor)
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
                Rectangle().fill(game.title.pillColor.opacity(0.2))
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
                    .foregroundStyle(.accentColor)
            }
        }
    }
}
