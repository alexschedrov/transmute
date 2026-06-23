//
//  KeychainService.swift
//  transmute
//

import Foundation
import Security
import os

/// Stores API keys in the macOS Keychain instead of plaintext UserDefaults.
enum KeychainService {
    private static let service = "com.transmute.apikeys"
    private static let logger = Logger(subsystem: "com.transmute", category: "KeychainService")

    static func save(_ value: String, account: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        if value.isEmpty {
            let status = SecItemDelete(query as CFDictionary)
            if status != errSecSuccess, status != errSecItemNotFound {
                logger.error("Failed to delete keychain item for \(account, privacy: .public): \(status)")
            }
            return
        }

        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let addStatus = SecItemAdd(attributes as CFDictionary, nil)
        if addStatus == errSecDuplicateItem {
            let updateStatus = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
            if updateStatus != errSecSuccess {
                logger.error("Failed to update keychain item for \(account, privacy: .public): \(updateStatus)")
            }
        } else if addStatus != errSecSuccess {
            logger.error("Failed to add keychain item for \(account, privacy: .public): \(addStatus)")
        }
    }

    static func read(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    static func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess, status != errSecItemNotFound {
            logger.error("Failed to delete keychain item for \(account, privacy: .public): \(status)")
        }
    }

    /// One-time move of API keys saved by older versions in plaintext UserDefaults.
    static func migrateFromUserDefaultsIfNeeded() {
        for provider in LLMProvider.allCases {
            let key = provider.apiKeyStorageKey
            guard let plaintextValue = UserDefaults.standard.string(forKey: key), !plaintextValue.isEmpty else {
                continue
            }
            save(plaintextValue, account: key)
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}
