import SwiftUI

struct CalendarNavigationBar: View {
    @Bindable var state: AppState
    @FocusState private var searchFieldFocused: Bool

    var body: some View {
        ZStack {
            // Center: Search field (always centered in bar)
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                TextField("Søk spill...", text: $state.searchQuery)
                    .textFieldStyle(.plain)
                    .font(.callout)
                    .focused($searchFieldFocused)

                if !state.searchQuery.isEmpty {
                    Button {
                        state.searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.gray.opacity(0.12), in: .rect(cornerRadius: 8))
            .frame(maxWidth: 400)

            // Left: Calendar mode buttons
            HStack(spacing: 2) {
                ForEach(ViewType.calendarModes, id: \.self) { mode in
                    calendarModeButton(for: mode)
                }
                Spacer()
            }

            // Right: Date navigation + Today
            HStack(spacing: 2) {
                Spacer()

                if state.showsDateNav {
                    HStack(spacing: 2) {
                        Button { state.navigateBack() } label: {
                            Image(systemName: "chevron.left").font(.callout)
                        }
                        .buttonStyle(.plain)
                        .padding(6)

                        Text(state.focusDateLabel)
                            .font(.callout)
                            .fontWeight(.semibold)
                            .frame(minWidth: 180)

                        Button { state.navigateForward() } label: {
                            Image(systemName: "chevron.right").font(.callout)
                        }
                        .buttonStyle(.plain)
                        .padding(6)
                    }
                    .padding(.trailing, 8)
                }

                Button("I dag") {
                    state.goToToday()
                }
                .buttonStyle(.plain)
                .font(.callout)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(.quaternary, in: .rect(cornerRadius: 7))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
        .background {
            Button("") { searchFieldFocused = true }
                .keyboardShortcut("f", modifiers: .command)
                .hidden()
        }
    }

    @ViewBuilder
    private func calendarModeButton(for mode: ViewType) -> some View {
        let isActive = state.viewType == mode
        Button {
            state.switchToCalendarMode(mode)
        } label: {
            Text(mode.label)
                .font(.callout)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(isActive ? Color.accentColor.opacity(0.12) : Color.clear,
                            in: .rect(cornerRadius: 7))
                .foregroundStyle(isActive ? Color.accentColor : Color.primary)
                .fontWeight(isActive ? .semibold : .regular)
        }
        .buttonStyle(.plain)
    }
}
