import SwiftUI

struct SettingsView: View {
    @Bindable var state: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Header
            HStack {
                Text("Innstillinger")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Theme mode
            VStack(alignment: .leading, spacing: 10) {
                Text("Utseende")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                HStack(spacing: 8) {
                    ForEach(ThemeMode.allCases, id: \.self) { mode in
                        Button {
                            state.themeMode = mode
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: mode.icon)
                                    .font(.system(size: 12))
                                Text(mode.label)
                                    .font(.callout)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                state.themeMode == mode ? Color.accentColor.opacity(0.2) : Color.clear,
                                in: .rect(cornerRadius: 8)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(
                                        state.themeMode == mode ? Color.accentColor : Color.secondary.opacity(0.3),
                                        lineWidth: 1
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Accent color
            VStack(alignment: .leading, spacing: 10) {
                Text("Aksentfarge")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                HStack(spacing: 10) {
                    ForEach(AppState.accentColorOptions, id: \.name) { option in
                        Button {
                            state.accentColorName = option.name
                        } label: {
                            Circle()
                                .fill(option.color)
                                .frame(width: 28, height: 28)
                                .overlay {
                                    if state.accentColorName == option.name {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                                .overlay(
                                    Circle()
                                        .stroke(
                                            state.accentColorName == option.name ? option.color : .clear,
                                            lineWidth: 2
                                        )
                                        .padding(-3)
                                )
                        }
                        .buttonStyle(.plain)
                        .help(option.label)
                    }
                }
            }

            // API settings
            VStack(alignment: .leading, spacing: 10) {
                Text("API-innstillinger")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                HStack {
                    Text("Backend-URL:")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text(state.apiBaseURL.absoluteString)
                        .font(.callout.monospaced())
                        .foregroundStyle(.primary)
                }

                HStack {
                    Text("Varsler:")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text(UserDefaults.standard.bool(forKey: "notificationsEnabled") ? String(localized: "Aktivert") : String(localized: "Deaktivert"))
                        .font(.callout)
                        .foregroundStyle(UserDefaults.standard.bool(forKey: "notificationsEnabled") ? .green : .secondary)
                }
            }

            Spacer()
        }
        .padding(24)
        .frame(width: 420)
        .frame(minHeight: 340)
    }
}
