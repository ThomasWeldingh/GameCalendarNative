import SwiftUI
import SwiftData

struct FilterView: View {
    @Bindable var state: AppState
    @Environment(\.modelContext) private var modelContext
    @State private var availableGenres: [String] = []

    private let popularityPresets: [(label: String, value: Int)] = [
        ("Alle", 0),
        ("Kjente", 5),
        ("Populære", 20),
        ("Topp", 100)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Popularity
            VStack(alignment: .leading, spacing: 8) {
                Text("Popularitet")
                    .font(.headline)

                HStack(spacing: 8) {
                    ForEach(popularityPresets, id: \.value) { preset in
                        Button(preset.label) {
                            state.minPopularity = preset.value
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(state.minPopularity == preset.value ? Color.accentColor : Color.secondary)
                    }
                }
            }

            Divider()

            // Indie toggle
            Toggle("Vis indie-spill", isOn: $state.showIndie)
                .toggleStyle(.switch)

            Divider()

            // Genres
            if !availableGenres.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Sjangere")
                            .font(.headline)
                        Spacer()
                        if !state.selectedGenres.isEmpty {
                            Button("Nullstill") { state.selectedGenres = [] }
                                .font(.caption)
                                .buttonStyle(.plain)
                                .foregroundStyle(Color.accentColor)
                        }
                    }

                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(availableGenres, id: \.self) { genre in
                                Toggle(genre, isOn: Binding(
                                    get: { state.selectedGenres.contains(genre) },
                                    set: { on in
                                        if on { state.selectedGenres.insert(genre) }
                                        else { state.selectedGenres.remove(genre) }
                                    }
                                ))
                                .toggleStyle(.checkbox)
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                }
            }
        }
        .padding(16)
        .frame(width: 240)
        .task { await loadGenres() }
    }

    private func loadGenres() async {
        let all = (try? modelContext.fetch(FetchDescriptor<GameRelease>())) ?? []
        let genres = Set(all.flatMap(\.genres)).sorted()
        availableGenres = genres
    }
}
