import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Bindable var state: AppState
    var onComplete: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var step = 0
    @State private var selectedPlatforms: Set<String> = []

    private let platforms = ["PC", "PlayStation", "Xbox", "Switch"]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Group {
                switch step {
                case 0: welcomeStep
                case 1: platformStep
                case 2: importStep
                default: EmptyView()
                }
            }
            .frame(maxWidth: 480)

            Spacer()

            // Step indicator
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(i == step ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }

    // MARK: - Step 0: Welcome

    private var welcomeStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tint)

            Text("Velkommen til Spillkalender")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)

            Text("Hold oversikt over kommende spillutgivelser, lag ønskelister og få varsler når favorittspillene dine lanseres.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            Button {
                withAnimation { step = 1 }
            } label: {
                Text("Kom i gang")
                    .font(.headline)
                    .frame(maxWidth: 200)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.top, 8)
        }
    }

    // MARK: - Step 1: Platforms

    private var platformStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "rectangle.stack.fill")
                .font(.system(size: 48))
                .foregroundStyle(.tint)

            Text("Velg plattformer")
                .font(.title.bold())

            Text("Hvilke plattformer spiller du på? Du kan endre dette senere.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                ForEach(platforms, id: \.self) { platform in
                    let isSelected = selectedPlatforms.contains(platform)
                    Button {
                        if isSelected {
                            selectedPlatforms.remove(platform)
                        } else {
                            selectedPlatforms.insert(platform)
                        }
                    } label: {
                        let color = platformColor(platform)
                        VStack(spacing: 8) {
                            Image(systemName: platformIcon(platform))
                                .font(.title2)
                            Text(platform)
                                .font(.caption.bold())
                        }
                        .frame(width: 90, height: 80)
                        .background(isSelected ? color.opacity(0.15) : Color.secondary.opacity(0.1))
                        .foregroundStyle(isSelected ? color : .secondary)
                        .clipShape(.rect(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(isSelected ? color : .clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            Button {
                state.activePlatforms = selectedPlatforms
                withAnimation { step = 2 }
            } label: {
                Text("Neste")
                    .font(.headline)
                    .frame(maxWidth: 200)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.top, 8)
        }
    }

    // MARK: - Step 2: Import

    private var importStep: some View {
        VStack(spacing: 24) {
            if state.isImporting {
                ProgressView()
                    .controlSize(.large)
                    .padding(.bottom, 8)

                Text("Henter spill...")
                    .font(.title2.bold())

                if let phase = state.importPhase {
                    Text(phase)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            } else if let stats = state.lastImportStats {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.green)

                Text("Klar!")
                    .font(.title.bold())

                Text("\(stats.inserted + stats.updated) spill er nå i kalenderen din.")
                    .font(.body)
                    .foregroundStyle(.secondary)

                Button {
                    state.hasCompletedOnboarding = true
                    onComplete()
                } label: {
                    Text("Ferdig")
                        .font(.headline)
                        .frame(maxWidth: 200)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, 8)
            } else if let error = state.importError {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.orange)

                Text("Noe gikk galt")
                    .font(.title2.bold())

                Text(error)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                HStack(spacing: 16) {
                    Button("Prøv igjen") {
                        Task {
                            await state.runImport(container: modelContext.container)
                        }
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Hopp over") {
                        state.hasCompletedOnboarding = true
                        onComplete()
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.top, 8)
            } else {
                ProgressView()
                    .controlSize(.large)

                Text("Starter import...")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .task {
            await state.runImport(container: modelContext.container)
        }
    }

    // MARK: - Helpers

    private func platformIcon(_ platform: String) -> String {
        switch platform {
        case "PC": return "desktopcomputer"
        case "PlayStation": return "gamecontroller.fill"
        case "Xbox": return "xmark.circle.fill"
        case "Switch": return "rectangle.on.rectangle"
        default: return "gamecontroller"
        }
    }

    private func platformColor(_ platform: String) -> Color {
        switch platform {
        case "PC":          return .blue
        case "PlayStation": return .indigo
        case "Xbox":        return .green
        case "Switch":      return .red
        default:            return .gray
        }
    }
}
