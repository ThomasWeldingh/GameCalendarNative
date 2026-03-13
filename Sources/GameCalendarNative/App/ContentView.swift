import SwiftUI
import SwiftData

@Observable
@MainActor
class ImportViewModel {
    var isImporting = false
    var importError: String?
    var lastStats: ImportStats?

    private let tokenService = IgdbTokenService()

    func runImport(container: ModelContainer) async {
        guard let credentials = KeychainService.credentials else {
            importError = IgdbError.missingCredentials.localizedDescription
            return
        }

        isImporting = true
        importError = nil
        defer { isImporting = false }

        let client = IgdbClient(credentials: credentials, tokenService: tokenService)
        let actor = ImportActor(modelContainer: container, igdbClient: client)

        do {
            lastStats = try await actor.run()
        } catch {
            importError = error.localizedDescription
        }
    }
}

// MARK: - Main view

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ImportRun.startedAt, order: .reverse) private var importRuns: [ImportRun]
    @Query private var games: [GameRelease]

    @State private var viewModel = ImportViewModel()
    @State private var credentialsSet = KeychainService.hasCredentials
    @State private var showCredentials = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if credentialsSet {
                    mainContent
                } else {
                    CredentialsSetupView {
                        credentialsSet = true
                    }
                }
            }
            .padding()
            .navigationTitle("Game Calendar")
            .toolbar {
                if credentialsSet {
                    ToolbarItem {
                        Button("API-nøkler") { showCredentials = true }
                    }
                }
            }
            .sheet(isPresented: $showCredentials) {
                CredentialsSetupView {
                    showCredentials = false
                }
                .padding()
                .frame(minWidth: 360)
            }
        }
        .frame(minWidth: 480, minHeight: 320)
    }

    @ViewBuilder
    private var mainContent: some View {
        // Stats summary
        HStack(spacing: 32) {
            statBox(label: "Spill totalt", value: "\(games.count)")
            if let run = importRuns.first {
                statBox(label: "Siste import", value: run.startedAt.formatted(date: .abbreviated, time: .shortened))
                statBox(label: "Status", value: run.status)
            }
        }

        // Last import result
        if let stats = viewModel.lastStats {
            HStack(spacing: 16) {
                Label("\(stats.inserted) nye", systemImage: "plus.circle.fill")
                    .foregroundStyle(.green)
                Label("\(stats.updated) oppdaterte", systemImage: "arrow.triangle.2.circlepath")
                    .foregroundStyle(.blue)
                Label("\(stats.filtered) filtrerte", systemImage: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .font(.callout)
        }

        // Error
        if let error = viewModel.importError {
            Text(error)
                .foregroundStyle(.red)
                .font(.callout)
                .multilineTextAlignment(.center)
        }

        // Import button
        Button {
            Task { await viewModel.runImport(container: modelContext.container) }
        } label: {
            if viewModel.isImporting {
                Label("Importerer spill...", systemImage: "arrow.clockwise")
            } else {
                Label("Importer spill fra IGDB", systemImage: "icloud.and.arrow.down")
            }
        }
        .buttonStyle(.borderedProminent)
        .disabled(viewModel.isImporting)
        .controlSize(.large)
    }

    private func statBox(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 100)
        .padding(12)
        .background(.quaternary, in: .rect(cornerRadius: 10))
    }
}

// MARK: - Credentials setup

struct CredentialsSetupView: View {
    let onSaved: () -> Void

    @State private var clientId = ""
    @State private var clientSecret = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("IGDB API-nøkler")
                .font(.headline)

            Text("Du trenger en gratis Twitch Developer-konto på dev.twitch.tv for å bruke IGDB API. Registrer en applikasjon og kopier Client ID og Client Secret hit.")
                .foregroundStyle(.secondary)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)

            TextField("Client ID", text: $clientId)
                .textFieldStyle(.roundedBorder)

            SecureField("Client Secret", text: $clientSecret)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Avbryt") { dismiss() }
                    .buttonStyle(.bordered)
                Spacer()
                Button("Lagre") {
                    KeychainService.save(clientId: clientId, clientSecret: clientSecret)
                    onSaved()
                }
                .buttonStyle(.borderedProminent)
                .disabled(clientId.trimmingCharacters(in: .whitespaces).isEmpty
                    || clientSecret.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding()
        .background(.quaternary, in: .rect(cornerRadius: 12))
        .frame(maxWidth: 400)
        .onAppear {
            if let existing = KeychainService.credentials {
                clientId = existing.clientId
                clientSecret = existing.clientSecret
            }
        }
    }
}
