import SwiftUI
import SwiftData

struct AddToListPopover: View {
    let game: GameRelease
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GameList.sortOrder) private var lists: [GameList]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Legg til i liste")
                .font(.headline)
                .padding(.bottom, 4)

            ForEach(lists) { list in
                let isInList = list.entries.contains { $0.gameExternalId == game.externalId }
                Button {
                    toggleList(list, isInList: isInList)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: list.icon)
                            .foregroundStyle(list.color)
                            .frame(width: 20)
                        Text(list.name)
                            .font(.callout)
                        Spacer()
                        if isInList {
                            Image(systemName: "checkmark")
                                .font(.caption)
                                .foregroundStyle(list.color)
                        }
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .background(isInList ? list.color.opacity(0.1) : Color.clear, in: .rect(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .frame(width: 240)
    }

    private func toggleList(_ list: GameList, isInList: Bool) {
        if isInList {
            if let entry = list.entries.first(where: { $0.gameExternalId == game.externalId }) {
                modelContext.delete(entry)
            }
        } else {
            let entry = GameListEntry(list: list, gameExternalId: game.externalId)
            list.entries.append(entry)
        }
    }
}
