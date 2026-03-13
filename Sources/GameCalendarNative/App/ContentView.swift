import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var credentialsSet = KeychainService.hasCredentials
    @State private var appState = AppState()

    var body: some View {
        if credentialsSet {
            MainView(state: appState)
        } else {
            CredentialsSetupView {
                credentialsSet = true
            }
            .frame(width: 420, height: 300)
        }
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

            Text("Du trenger en gratis Twitch Developer-konto på dev.twitch.tv. Registrer en applikasjon og kopier Client ID og Client Secret hit.")
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
                    KeychainService.save(
                        clientId: clientId.trimmingCharacters(in: .whitespaces),
                        clientSecret: clientSecret.trimmingCharacters(in: .whitespaces)
                    )
                    onSaved()
                }
                .buttonStyle(.borderedProminent)
                .disabled(clientId.trimmingCharacters(in: .whitespaces).isEmpty
                    || clientSecret.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .onAppear {
            if let existing = KeychainService.credentials {
                clientId = existing.clientId
                clientSecret = existing.clientSecret
            }
        }
    }
}
