import Foundation
import CryptoKit

enum CryptoError: Error, LocalizedError {
    case encryptionFailed
    case decryptionFailed
    case invalidData
    case keyDerivationFailed

    var errorDescription: String? {
        switch self {
        case .encryptionFailed:
            return "Encryption failed"
        case .decryptionFailed:
            return "Decryption failed"
        case .invalidData:
            return "Invalid data"
        case .keyDerivationFailed:
            return "Key derivation failed"
        }
    }
}

final class CryptoService {
    private let key: SymmetricKey

    init(masterPassword: String, salt: Data) throws {
        let derivedKey = try Self.deriveKey(from: masterPassword, salt: salt)
        self.key = derivedKey
    }
    
    init(keyData: Data) throws {
        guard keyData.count == 32 else {
            throw CryptoError.keyDerivationFailed
        }
        self.key = SymmetricKey(data: keyData)
    }

    // Simplified version: derive fixed key directly from master password
    init(masterPassword: String) throws {
        let passwordData = masterPassword.data(using: .utf8)!
        let hash = SHA256.hash(data: passwordData)
        self.key = SymmetricKey(data: Data(hash))
    }

    static func generateKeyData() -> Data {
        var keyData = Data(count: 32)
        _ = keyData.withUnsafeMutableBytes { buffer in
            SecRandomCopyBytes(kSecRandomDefault, 32, buffer.baseAddress!)
        }
        return keyData
    }

    static func deriveKey(from password: String, salt: Data) throws -> SymmetricKey {
        guard let passwordData = password.data(using: .utf8) else {
            throw CryptoError.keyDerivationFailed
        }

        let derivedKey = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: passwordData),
            salt: salt,
            info: "MyPwd-v1".data(using: .utf8)!,
            outputByteCount: 32
        )
        return derivedKey
    }

    static func generateSalt() -> Data {
        var salt = Data(count: 32)
        _ = salt.withUnsafeMutableBytes { buffer in
            SecRandomCopyBytes(kSecRandomDefault, 32, buffer.baseAddress!)
        }
        return salt
    }

    // Encrypt data with master password (for backup/restore)
    static func encryptWithPassword(_ password: String, _ data: Data) throws -> Data {
        let salt = generateSalt()
        let key = try deriveKey(from: password, salt: salt)
        
        let sealedBox = try AES.GCM.seal(data, using: key)
        guard let combined = sealedBox.combined else {
            throw CryptoError.encryptionFailed
        }
        
        // Combine salt + encrypted data
        return salt + combined
    }

    // Decrypt data with master password
    static func decryptWithPassword(_ password: String, _ encryptedData: Data) throws -> Data {
        guard encryptedData.count > 32 else {
            throw CryptoError.invalidData
        }
        
        let salt = encryptedData.prefix(32)
        let ciphertext = encryptedData.dropFirst(32)
        
        let key = try deriveKey(from: password, salt: Data(salt))
        let sealedBox = try AES.GCM.SealedBox(combined: ciphertext)
        return try AES.GCM.open(sealedBox, using: key)
    }

    func encrypt(_ data: Data) throws -> Data {
        do {
            let sealedBox = try AES.GCM.seal(data, using: key)
            guard let combined = sealedBox.combined else {
                throw CryptoError.encryptionFailed
            }
            return combined
        } catch {
            throw CryptoError.encryptionFailed
        }
    }

    func decrypt(_ data: Data) throws -> Data {
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            let decryptedData = try AES.GCM.open(sealedBox, using: key)
            return decryptedData
        } catch {
            throw CryptoError.decryptionFailed
        }
    }

    func encryptStore(_ store: PasswordStore) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(store)
        return try encrypt(jsonData)
    }

    func decryptStore(_ data: Data) throws -> PasswordStore {
        let decryptedData = try decrypt(data)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(PasswordStore.self, from: decryptedData)
    }

    // Encrypt string (for password field)
    func encryptString(_ string: String) throws -> String {
        guard let data = string.data(using: .utf8) else {
            throw CryptoError.invalidData
        }
        let encrypted = try encrypt(data)
        return encrypted.base64EncodedString()
    }

    // Decrypt string (for password field)
    func decryptString(_ encryptedString: String) throws -> String {
        guard let data = Data(base64Encoded: encryptedString) else {
            throw CryptoError.invalidData
        }
        let decrypted = try decrypt(data)
        guard let string = String(data: decrypted, encoding: .utf8) else {
            throw CryptoError.invalidData
        }
        return string
    }
}
