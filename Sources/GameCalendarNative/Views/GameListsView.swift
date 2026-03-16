import SwiftUI
import SwiftData

struct GameListsView: View {
    let state: AppState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GameList.sortOrder) private var lists: [GameList]
    @Query private var allGames: [GameRelease]

    @State private var selectedList: GameList? = nil

    /// Count only entries that have a matching GameRelease in the database
    private func validCount(for list: GameList) -> Int {
        let gameIds = Set(allGames.map(\.externalId))
        return list.entries.filter { gameIds.contains($0.gameExternalId) }.count
    }

    var body: some View {
        Group {
            if let list = selectedList {
                GameListDetailView(list: list, state: state, onBack: { selectedList = nil })
            } else {
                listsGrid
            }
        }
    }

    private var listsGrid: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Mine lister")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 20)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160, maximum: 240), spacing: 16)], spacing: 16) {
                    ForEach(lists) { list in
                        listCard(list)
                            .onTapGesture { selectedList = list }
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.vertical, 20)
        }
    }

    private func listCard(_ list: GameList) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: list.icon)
                    .font(.title2)
                    .foregroundStyle(list.color)
                Spacer()
                Text("\(validCount(for: list))")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
            }

            Text(list.name)
                .font(.callout)
                .fontWeight(.semibold)

            Text("\(validCount(for: list)) spill")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.quaternary, in: .rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(list.color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - List detail view

struct GameListDetailView: View {
    let list: GameList
    let state: AppState
    let onBack: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Query private var allGames: [GameRelease]

    private let columns = [GridItem(.adaptive(minimum: 130, maximum: 220), spacing: 16)]

    private var gamesInList: [GameRelease] {
        let entryIds = Set(list.entries.map(\.gameExternalId))
        return allGames
            .filter { entryIds.contains($0.externalId) }
            .sorted { $0.popularity > $1.popularity }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Button(action: onBack) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Tilbake")
                        }
                        .font(.callout)
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }

                HStack(spacing: 10) {
                    Image(systemName: list.icon)
                        .font(.title)
                        .foregroundStyle(list.color)
                    VStack(alignment: .leading) {
                        Text(list.name)
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("\(gamesInList.count) spill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if gamesInList.isEmpty {
                    ContentUnavailableView(
                        "Ingen spill ennå",
                        systemImage: list.icon,
                        description: Text("Legg til spill via spilldetaljer")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                } else {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(gamesInList, id: \.externalId) { game in
                            ListGameCard(game: game, list: list)
                                .onTapGesture { state.selectedGame = game }
                        }
                    }
                }
            }
            .padding(20)
        }
    }
}

// MARK: - Card for game in a list

struct ListGameCard: View {
    let game: GameRelease
    let list: GameList
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
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

                // Remove from list button
                Button {
                    removeFromList()
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.red)
                        .padding(7)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .padding(8)
            }

            Text(game.title)
                .font(.callout)
                .fontWeight(.semibold)
                .lineLimit(2)

            if let date = game.releaseDate {
                Text(date.formatted(.dateTime.day().month(.abbreviated).year()).uppercased())
                    .font(.caption)
                    .foregroundStyle(list.color)
            }
        }
    }

    private func removeFromList() {
        if let entry = list.entries.first(where: { $0.gameExternalId == game.externalId }) {
            modelContext.delete(entry)
        }
    }
}
