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
            return "保存密钥失败"
        case .loadFailed:
            return "加载密钥失败"
        case .notFound:
            return "密钥未找到"
        case .authenticationFailed:
            return "生物识别验证失败"
        }
    }
}

final class KeychainServiceWithBiometric {
    static let shared = KeychainServiceWithBiometric()
    
    private let service = "com.mypwd.app"
    private let accessGroup = "com.mypwd.app"

    private init() {}

    func saveKey(data: Data, forKey key: String) throws {
        // 先尝试删除已存在的项
        try? deleteKey(forKey: key)
        
        // 使用普通方式存储（首次设置时可能没有注册生物识别）
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
        // 先删除旧的
        try? deleteKey(forKey: key)
        
        // 创建访问控制，要求生物识别
        var error: Unmanaged<CFError>?
        guard let accessControl = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .biometryCurrentSet,
            &error
        ) else {
            // 如果创建失败，用普通方式保存
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
        
        // 如果失败（可能是没有注册生物识别），用普通方式保存
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
        context.localizedReason = "解锁密码库"
        
        // 先尝试用生物识别加载
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
        
        // 如果生物识别成功
        if status == errSecSuccess {
            return result as? Data
        }
        
        // 如果是 authFailed 或 userCanceled，抛出错误
        if status == errSecAuthFailed || status == errSecUserCanceled {
            throw KeychainBiometricError.authenticationFailed
        }
        
        // 其他错误，尝试普通加载
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
