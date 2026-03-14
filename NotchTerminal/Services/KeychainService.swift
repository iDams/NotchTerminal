import Foundation
import Security

public enum KeychainError: LocalizedError {
    case itemNotFound
    case unexpectedData
    case duplicateItem
    case invalidStatus(OSStatus)
    case encodingError

    public var errorDescription: String? {
        switch self {
        case .itemNotFound:
            return "Keychain item not found"
        case .unexpectedData:
            return "Unexpected data in keychain"
        case .duplicateItem:
            return "Keychain item already exists"
        case .invalidStatus(let status):
            return "Keychain operation failed with status: \(status)"
        case .encodingError:
            return "Failed to encode data for keychain"
        }
    }
}

public enum KeychainService {
    private static let service = "com.notchterminal.aiprovider"

    public static func saveAPIKey(for providerID: UUID, apiKey: String) throws {
        guard let data = apiKey.data(using: .utf8) else {
            throw KeychainError.encodingError
        }

        let key = keyIdentifier(for: providerID)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        if status == errSecDuplicateItem {
            let updateQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: key
            ]

            let updateAttributes: [String: Any] = [
                kSecValueData as String: data
            ]

            let updateStatus = SecItemUpdate(updateQuery as CFDictionary, updateAttributes as CFDictionary)
            if updateStatus != errSecSuccess {
                throw KeychainError.invalidStatus(updateStatus)
            }
        } else if status != errSecSuccess {
            throw KeychainError.invalidStatus(status)
        }
    }

    public static func loadAPIKey(for providerID: UUID) throws -> String {
        let key = keyIdentifier(for: providerID)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.itemNotFound
            }
            throw KeychainError.invalidStatus(status)
        }

        guard let data = result as? Data, let apiKey = String(data: data, encoding: .utf8) else {
            throw KeychainError.unexpectedData
        }

        return apiKey
    }

    public static func deleteAPIKey(for providerID: UUID) throws {
        let key = keyIdentifier(for: providerID)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)

        if status != errSecSuccess && status != errSecItemNotFound {
            throw KeychainError.invalidStatus(status)
        }
    }

    public static func getAPIKey(for providerID: UUID) -> String? {
        do {
            return try loadAPIKey(for: providerID)
        } catch {
            return nil
        }
    }

    public static func saveAPIKeyIfNotEmpty(for providerID: UUID, apiKey: String) {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        try? saveAPIKey(for: providerID, apiKey: trimmed)
    }

    public static func deleteAPIKeySilently(for providerID: UUID) {
        try? deleteAPIKey(for: providerID)
    }

    private static func keyIdentifier(for providerID: UUID) -> String {
        "apikey.\(providerID.uuidString)"
    }
}