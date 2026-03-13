import Foundation

enum IgdbError: Error, LocalizedError {
    case tokenFetchFailed(Int)
    case missingCredentials
    case requestFailed(Int)

    var errorDescription: String? {
        switch self {
        case .tokenFetchFailed(let code): return "Klarte ikke å hente IGDB-token (HTTP \(code))"
        case .missingCredentials: return "IGDB API-nøkler mangler. Åpne innstillinger og legg dem inn."
        case .requestFailed(let code): return "IGDB API svarte med feil \(code)"
        }
    }
}

/// Thread-safe actor that fetches and caches the Twitch/IGDB OAuth token.
actor IgdbTokenService {
    private var cachedToken: String?
    private var expiresAt: Date = .distantPast

    func getToken(clientId: String, clientSecret: String) async throws -> String {
        if let token = cachedToken, Date() < expiresAt {
            return token
        }

        var components = URLComponents(string: "https://id.twitch.tv/oauth2/token")!
        components.queryItems = [
            .init(name: "client_id", value: clientId),
            .init(name: "client_secret", value: clientSecret),
            .init(name: "grant_type", value: "client_credentials"),
        ]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"

        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard statusCode == 200 else {
            throw IgdbError.tokenFetchFailed(statusCode)
        }

        let tokenResponse = try JSONDecoder().decode(TwitchTokenResponse.self, from: data)
        cachedToken = tokenResponse.accessToken
        // Subtract 60 s so we refresh before actual expiry
        expiresAt = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn - 60))
        return tokenResponse.accessToken
    }
}
