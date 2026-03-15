import SwiftUI
import SwiftData

// MARK: - Game abbreviation / acronym lookup

enum GameAbbreviations {
    /// Well-known abbreviations mapped to canonical title substrings
    static let aliases: [String: [String]] = [
        "gta": ["grand theft auto"],
        "wow": ["world of warcraft"],
        "cod": ["call of duty"],
        "rdr": ["red dead redemption"],
        "tlou": ["the last of us"],
        "botw": ["breath of the wild"],
        "totk": ["tears of the kingdom"],
        "ffvii": ["final fantasy vii", "final fantasy 7"],
        "ff7": ["final fantasy vii", "final fantasy 7"],
        "ff": ["final fantasy"],
        "re": ["resident evil"],
        "mgs": ["metal gear solid"],
        "mhw": ["monster hunter world"],
        "mh": ["monster hunter"],
        "lol": ["league of legends"],
        "ow": ["overwatch"],
        "bg3": ["baldur's gate 3", "baldurs gate 3"],
        "bg": ["baldur's gate", "baldurs gate"],
        "ac": ["assassin's creed", "assassins creed"],
        "nfs": ["need for speed"],
        "tloz": ["the legend of zelda"],
        "zelda": ["legend of zelda"],
        "mk": ["mortal kombat"],
        "sf": ["street fighter"],
        "kh": ["kingdom hearts"],
        "ds": ["dark souls"],
        "er": ["elden ring"],
        "gow": ["god of war"],
        "hzd": ["horizon zero dawn"],
        "hfw": ["horizon forbidden west"],
        "d2": ["destiny 2", "diablo 2", "diablo ii"],
        "d4": ["diablo 4", "diablo iv"],
        "poe": ["path of exile"],
        "dmc": ["devil may cry"],
        "ffxiv": ["final fantasy xiv", "final fantasy 14"],
        "ff14": ["final fantasy xiv", "final fantasy 14"],
        "rdr2": ["red dead redemption 2"],
        "gtav": ["grand theft auto v", "grand theft auto 5"],
        "gta5": ["grand theft auto v", "grand theft auto 5"],
        "gta6": ["grand theft auto vi", "grand theft auto 6"],
        "xcom": ["xcom", "x-com"],
        "civ": ["civilization", "sid meier"],
        "smt": ["shin megami tensei"],
        "p5": ["persona 5"],
        "p3": ["persona 3"],
        "dq": ["dragon quest"],
        "mw": ["modern warfare"],
        "bo": ["black ops"],
        "wz": ["warzone"],
        "apex": ["apex legends"],
        "rl": ["rocket league"],
        "mc": ["minecraft"],
        "r6": ["rainbow six"],
        "fifa": ["ea sports fc", "fifa"],
        "nba2k": ["nba 2k"],
        "tf2": ["team fortress 2"],
        "cs": ["counter-strike", "counter strike"],
        "csgo": ["counter-strike", "counter strike"],
        "cs2": ["counter-strike 2", "counter strike 2"],
        "dos": ["divinity original sin"],
    ]

    /// Expand a query into search terms: the original query plus any alias expansions.
    /// Also generates an acronym pattern from the query for matching titles like
    /// "Grand Theft Auto" from "gta" even if not in the dictionary.
    static func expandQuery(_ query: String) -> [String] {
        let lower = query.lowercased().trimmingCharacters(in: .whitespaces)
        var terms = [lower]

        // Dictionary lookup
        if let expansions = aliases[lower] {
            terms.append(contentsOf: expansions)
        }

        return terms
    }
}

struct SearchResultsView: View {
    @Environment(\.modelContext) private var modelContext
    let query: String
    let state: AppState

    @State private var results: [GameRelease] = []
    @State private var isSearching = false

    var body: some View {
        Group {
            if isSearching {
                ProgressView("Søker...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if results.isEmpty && query.count >= 2 {
                ContentUnavailableView.search(text: query)
            } else {
                List(results, id: \.externalId) { game in
                    SearchResultRow(game: game)
                        .onTapGesture { state.selectedGame = game }
                }
            }
        }
        .task(id: query) { await search() }
    }

    private func search() async {
        guard query.count >= 2 else { results = []; return }
        isSearching = true

        // Debounce
        try? await Task.sleep(for: .milliseconds(200))
        guard !Task.isCancelled else { return }

        let searchTerms = GameAbbreviations.expandQuery(query)

        // Build union of results from all expanded terms
        var seen = Set<String>()
        var combined: [GameRelease] = []

        for term in searchTerms {
            let t = term
            let predicate = #Predicate<GameRelease> { game in
                game.title.localizedStandardContains(t)
            }
            var descriptor = FetchDescriptor<GameRelease>(
                predicate: predicate,
                sortBy: [SortDescriptor(\.popularity, order: .reverse)]
            )
            descriptor.fetchLimit = 60
            if let fetched = try? modelContext.fetch(descriptor) {
                for game in fetched where !seen.contains(game.externalId) {
                    seen.insert(game.externalId)
                    combined.append(game)
                }
            }
        }

        // Also try acronym matching: if query is all letters, check if each letter
        // matches the first letter of consecutive words in the title
        let lower = query.lowercased().trimmingCharacters(in: .whitespaces)
        if lower.count >= 2 && lower.allSatisfy(\.isLetter) {
            // Fetch a broader set and filter by acronym
            let firstChar = String(lower.prefix(1))
            let acronymPredicate = #Predicate<GameRelease> { game in
                game.title.localizedStandardContains(firstChar)
            }
            var acronymDescriptor = FetchDescriptor<GameRelease>(
                predicate: acronymPredicate,
                sortBy: [SortDescriptor(\.popularity, order: .reverse)]
            )
            acronymDescriptor.fetchLimit = 500
            if let candidates = try? modelContext.fetch(acronymDescriptor) {
                for game in candidates where !seen.contains(game.externalId) {
                    if titleMatchesAcronym(game.title, acronym: lower) {
                        seen.insert(game.externalId)
                        combined.append(game)
                    }
                }
            }
        }

        // Sort by popularity
        combined.sort { $0.popularity > $1.popularity }
        results = Array(combined.prefix(60))
        isSearching = false
    }

    /// Check if the first letters of words in `title` form the given `acronym`.
    /// e.g. "Grand Theft Auto" matches "gta", "The Last of Us" matches "tlou"
    private func titleMatchesAcronym(_ title: String, acronym: String) -> Bool {
        let words = title.lowercased()
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
        let initials = String(words.compactMap(\.first))
        return initials == acronym

    }
}

struct SearchResultRow: View {
    let game: GameRelease

    var body: some View {
        HStack(spacing: 12) {
            // Larger cover image (matches web proportions)
            AsyncImage(url: URL(string: game.coverImageUrl ?? "")) { image in
                image.resizable().aspectRatio(3/4, contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(game.title.pillColor.opacity(0.2))
                    .overlay {
                        Text(game.title.prefix(2).uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(game.title.pillColor.opacity(0.6))
                    }
            }
            .frame(width: 48, height: 64)
            .clipShape(.rect(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 4) {
                Text(game.title)
                    .fontWeight(.medium)
                    .lineLimit(1)

                if let date = game.releaseDate {
                    Text(date.formatted(date: .abbreviated, time: .omitted))
                        .foregroundStyle(.secondary)
                        .font(.caption)
                } else {
                    Text("TBA").foregroundStyle(.secondary).font(.caption)
                }

                // Platform badges (matches web's styled chips)
                if !game.platforms.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(game.platforms, id: \.self) { platform in
                            Text(platform)
                                .font(.system(size: 9))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(.quaternary, in: Capsule())
                        }
                    }
                }
            }

            Spacer()

            // Heart button
            HeartOverlayButton(game: game)

            if game.popularity > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "flame.fill").font(.caption2)
                    Text("\(game.popularity)").font(.caption)
                }
                .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 4)
    }
}
