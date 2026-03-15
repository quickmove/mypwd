import Foundation
import Security
import LocalAuthentication

enum KeychainBiometricError: Error, LocalizedError {
    case saveFailed
    case loadFailed
    case notFound
    case authenticationFailed

    var errorDescription: String? {
        switch self {
        case .saveFailed:
            return "Failed to save key"
        case .loadFailed:
            return "Failed to load key"
        case .notFound:
            return "Key not found"
        case .authenticationFailed:
            return "Biometric authentication failed"
        }
    }
}

final class KeychainServiceWithBiometric {
    static let shared = KeychainServiceWithBiometric()
    
    private let service = "com.mypwd.app"
    private let accessGroup = "com.mypwd.app"

    private init() {}

    func saveKey(data: Data, forKey key: String) throws {
        // Try to delete existing item first
        try? deleteKey(forKey: key)
        
        // Store using normal method (biometrics may not be enrolled during initial setup)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status != errSecSuccess {
            throw KeychainBiometricError.saveFailed
        }
    }
    
    func updateKeyWithBiometricProtection(data: Data, forKey key: String) throws {
        // Delete old one first
        try? deleteKey(forKey: key)
        
        // Create access control requiring biometrics
        var error: Unmanaged<CFError>?
        guard let accessControl = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .biometryCurrentSet,
            &error
        ) else {
            // If creation fails, save with normal method
            try saveKey(data: data, forKey: key)
            return
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessControl as String: accessControl
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        
        // If failed (possibly biometrics not enrolled), save with normal method
        if status != errSecSuccess {
            try saveKey(data: data, forKey: key)
        }
    }

    func loadKey(forKey key: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }
        
        if status != errSecSuccess {
            throw KeychainBiometricError.loadFailed
        }

        return result as? Data
    }
    
    func loadKeyWithBiometrics(forKey key: String) throws -> Data? {
        let context = LAContext()
        context.localizedReason = "Unlock password vault"
        
        // Try to load with biometrics first
        let queryWithBiometric: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseAuthenticationContext as String: context
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(queryWithBiometric as CFDictionary, &result)
        
        // If biometrics succeeded
        if status == errSecSuccess {
            return result as? Data
        }
        
        // If authFailed or userCanceled, throw error
        if status == errSecAuthFailed || status == errSecUserCanceled {
            throw KeychainBiometricError.authenticationFailed
        }
        
        // Other errors, try normal loading
        return try loadKey(forKey: key)
    }

    func deleteKey(forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)

        if status != errSecSuccess && status != errSecItemNotFound {
            throw KeychainBiometricError.loadFailed
        }
    }
    
    func exists(forKey key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: false
        ]

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
}
