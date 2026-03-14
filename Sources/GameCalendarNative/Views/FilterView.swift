import SwiftUI
import SwiftData

struct FilterView: View {
    @Bindable var state: AppState

    // Hardcoded lists matching web exactly (display label → DB value)
    private let popularityPresets: [(label: String, value: Int)] = [
        ("Alle", 0),
        ("Kjente", 5),
        ("Populære", 20),
        ("Topp", 100)
    ]

    private let publishers: [(label: String, value: String)] = [
        ("Bandai Namco", "Bandai Namco Entertainment"),
        ("Sega", "Sega"),
        ("Sony", "Sony Interactive Entertainment"),
        ("Xbox", "Xbox Game Studios"),
        ("Ubisoft", "Ubisoft Entertainment"),
        ("EA", "Electronic Arts"),
        ("Square Enix", "Square Enix"),
        ("2K", "2K"),
        ("Konami", "Konami"),
        ("Capcom", "Capcom"),
        ("THQ Nordic", "THQ Nordic"),
        ("Nintendo", "Nintendo"),
    ]

    private let genres: [(label: String, value: String)] = [
        ("Action", "Action"),
        ("Adventure", "Adventure"),
        ("RPG", "Role-playing (RPG)"),
        ("Shooter", "Shooter"),
        ("Simulation", "Simulator"),
        ("Strategy", "Strategy"),
        ("Sports", "Sport"),
        ("Platform", "Platform"),
        ("Racing", "Racing"),
        ("Fighting", "Fighting"),
        ("Puzzle", "Puzzle"),
    ]

    private var hasActiveFilters: Bool {
        state.minPopularity > 0
        || !state.showIndie
        || !state.selectedPublishers.isEmpty
        || !state.selectedGenres.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Filtrer spill")
                    .font(.headline)
                Spacer()
                if hasActiveFilters {
                    Button("Nullstill") {
                        state.minPopularity = 0
                        state.showIndie = true
                        state.selectedPublishers = []
                        state.selectedGenres = []
                    }
                    .font(.caption)
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
                }
            }

            // Popularity
            filterSection("POPULARITET") {
                WrappingHStack(spacing: 6) {
                    ForEach(popularityPresets, id: \.value) { preset in
                        FilterChip(
                            label: preset.label,
                            isActive: state.minPopularity == preset.value
                        ) {
                            state.minPopularity = preset.value
                        }
                    }
                }
            }

            // Game type (indie)
            filterSection("SPILLTYPE") {
                FilterChip(
                    label: "Vis indie games",
                    isActive: state.showIndie
                ) {
                    state.showIndie.toggle()
                }
            }

            // Publishers
            filterSection("UTGIVER") {
                WrappingHStack(spacing: 6) {
                    ForEach(publishers, id: \.value) { pub in
                        FilterChip(
                            label: pub.label,
                            isActive: state.selectedPublishers.contains(pub.value)
                        ) {
                            if state.selectedPublishers.contains(pub.value) {
                                state.selectedPublishers.remove(pub.value)
                            } else {
                                state.selectedPublishers.insert(pub.value)
                            }
                        }
                    }
                }
            }

            // Genres
            filterSection("SJANGER") {
                WrappingHStack(spacing: 6) {
                    ForEach(genres, id: \.value) { genre in
                        FilterChip(
                            label: genre.label,
                            isActive: state.selectedGenres.contains(genre.value)
                        ) {
                            if state.selectedGenres.contains(genre.value) {
                                state.selectedGenres.remove(genre.value)
                            } else {
                                state.selectedGenres.insert(genre.value)
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 320)
    }

    @ViewBuilder
    private func filterSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(.secondary)

            content()
        }
    }
}

// MARK: - Filter Chip (matches web's filter-chip)

struct FilterChip: View {
    let label: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isActive ? Color.accentColor.opacity(0.15) : Color.clear, in: Capsule())
                .foregroundStyle(isActive ? Color.accentColor : .primary)
                .overlay(
                    Capsule().stroke(
                        isActive ? Color.accentColor.opacity(0.4) : Color.secondary.opacity(0.3),
                        lineWidth: 0.5
                    )
                )
        }
        .buttonStyle(.plain)
    }
}
