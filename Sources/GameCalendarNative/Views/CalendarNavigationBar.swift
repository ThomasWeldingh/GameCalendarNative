import SwiftUI

struct CalendarNavigationBar: View {
    @Bindable var state: AppState

    var body: some View {
        HStack(spacing: 2) {
            // Calendar mode buttons: Måned | Uke | Dag
            ForEach(ViewType.calendarModes, id: \.self) { mode in
                calendarModeButton(for: mode)
            }

            Spacer()

            // Date navigation (conditional on calendar mode)
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

            // Today button
            Button("I dag") {
                state.goToToday()
            }
            .buttonStyle(.plain)
            .font(.callout)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.quaternary, in: .rect(cornerRadius: 7))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
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
