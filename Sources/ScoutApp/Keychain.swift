import Foundation
import Security

/// Armazenamento de segredos no Keychain (login). Uma entrada por provider —
/// melhor que plaintext em UserDefaults. App sem sandbox, então acessa a própria
/// keychain sem entitlement de grupo.
enum Keychain {
    private static let service = "md.chou.scout.apikey"

    static func save(_ value: String, account: String) {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(base as CFDictionary)           // idempotente
        guard !value.isEmpty else { return }          // vazio = só apaga
        var add = base
        add[kSecValueData as String] = Data(value.utf8)
        SecItemAdd(add as CFDictionary, nil)
    }

    static func load(account: String) -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let s = String(data: data, encoding: .utf8) else { return "" }
        return s
    }
}
