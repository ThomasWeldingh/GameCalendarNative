import SwiftUI
import SwiftData

struct WishlistView: View {
    let state: AppState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WishlistEntry.addedAt, order: .reverse) private var entries: [WishlistEntry]

    var body: some View {
        Group {
            if entries.isEmpty {
                ContentUnavailableView(
                    "Ønskeliste er tom",
                    systemImage: "heart",
                    description: Text("Trykk på hjertet i et spills detaljer for å legge det til")
                )
            } else {
                List(entries) { entry in
                    WishlistRow(game: entry.game, onRemove: { remove(entry) })
                        .onTapGesture { state.selectedGame = entry.game }
                }
            }
        }
    }

    private func remove(_ entry: WishlistEntry) {
        modelContext.delete(entry)
    }
}

struct WishlistRow: View {
    let game: GameRelease
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: game.coverImageUrl ?? "")) { image in
                image.resizable().aspectRatio(3/4, contentMode: .fill)
            } placeholder: {
                Rectangle().fill(game.title.pillColor.opacity(0.2))
            }
            .frame(width: 36, height: 48)
            .clipShape(.rect(cornerRadius: 4))

            VStack(alignment: .leading, spacing: 3) {
                Text(game.title)
                    .fontWeight(.medium)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if let date = game.releaseDate {
                        Text(date.formatted(date: .abbreviated, time: .omitted))
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    } else {
                        Text("TBA").foregroundStyle(.secondary).font(.caption)
                    }
                    if !game.platforms.isEmpty {
                        Text(game.platforms.joined(separator: " · "))
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                }
            }

            Spacer()

            Button(action: onRemove) {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .help("Fjern fra ønskeliste")
        }
        .padding(.vertical, 2)
    }
}
