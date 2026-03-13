import Foundation
import Security

struct IgdbCredentials {
    let clientId: String
    let clientSecret: String
}

enum KeychainService {
    private static let service = "no.thomasj.GameCalendarNative"
    private static let clientIdKey = "igdb_client_id"
    private static let clientSecretKey = "igdb_client_secret"

    static var hasCredentials: Bool {
        credentials != nil
    }

    static var credentials: IgdbCredentials? {
        guard
            let clientId = load(key: clientIdKey),
            let clientSecret = load(key: clientSecretKey)
        else { return nil }
        return IgdbCredentials(clientId: clientId, clientSecret: clientSecret)
    }

    static func save(clientId: String, clientSecret: String) {
        save(key: clientIdKey, value: clientId)
        save(key: clientSecretKey, value: clientSecret)
    }

    static func delete() {
        [clientIdKey, clientSecretKey].forEach { delete(key: $0) }
    }

    // MARK: - Private

    private static func save(key: String, value: String) {
        let data = Data(value.utf8)
        delete(key: key)
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecValueData: data,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    private static func load(key: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func delete(key: String) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
