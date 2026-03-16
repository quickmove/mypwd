import Foundation
import Security

enum StorageError: Error, LocalizedError {
    case notSetup
    case loadFailed
    case saveFailed
    case invalidPassword

    var errorDescription: String? {
        switch self {
        case .notSetup:
            return "Please set master password first"
        case .loadFailed:
            return "Failed to load password vault"
        case .saveFailed:
            return "Failed to save password vault"
        case .invalidPassword:
            return "Invalid password"
        }
    }
}

final class PasswordStorageService {
    static let shared = PasswordStorageService()

    private var cryptoService: CryptoService?
    private var currentStore: PasswordStore?

    private let fileManager = FileManager.default

    // Default path
    private var defaultStoreURL: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("MyPwd", isDirectory: true)

        if !fileManager.fileExists(atPath: appDir.path) {
            try? fileManager.createDirectory(at: appDir, withIntermediateDirectories: true)
        }

        return appDir.appendingPathComponent("mypwd.json")
    }

    // User custom path
    var customStoreURL: URL? {
        get {
            guard let pathString = ConfigService.shared.customStorePath,
                  let url = URL(string: pathString) else {
                return nil
            }
            return url
        }
        set {
            ConfigService.shared.customStorePath = newValue?.absoluteString
        }
    }

    var storeURL: URL {
        customStoreURL ?? defaultStoreURL
    }

    var isSetup: Bool {
        ConfigService.shared.masterKey != nil
    }

    private init() {}

    func setup(masterPassword: String, customPath: URL? = nil) throws {
        // Save custom path
        if let path = customPath {
            customStoreURL = path
        }

        // Store master key in ConfigService (protected by TouchID via Keychain)
        ConfigService.shared.masterKey = masterPassword

        // Ensure directory exists
        let directory = storeURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        // Create empty store (plain JSON format)
        let crypto = try CryptoService(masterPassword: masterPassword)
        let emptyStore = PasswordStore()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        let jsonData = try encoder.encode(emptyStore)
        try jsonData.write(to: storeURL)

        self.cryptoService = crypto
        self.currentStore = emptyStore
    }

    // Import existing password vault file
    func importExistingStore(masterPassword: String) throws {
        // Ensure file exists
        guard fileManager.fileExists(atPath: storeURL.path) else {
            throw StorageError.loadFailed
        }

        // Store master key in ConfigService (protected by TouchID via Keychain)
        ConfigService.shared.masterKey = masterPassword

        // Decrypt and load existing data
        let crypto = try CryptoService(masterPassword: masterPassword)

        // Read plain JSON
        let jsonData = try Data(contentsOf: storeURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let store = try decoder.decode(PasswordStore.self, from: jsonData)

        // Decrypt each password
        var decryptedStore = store
        for i in 0..<decryptedStore.items.count {
            if !decryptedStore.items[i].password.isEmpty {
                decryptedStore.items[i].password = try crypto.decryptString(decryptedStore.items[i].password)
            }
        }

        self.cryptoService = crypto
        self.currentStore = decryptedStore
    }

    func unlock(masterPassword: String) throws {
        try unlockWithBiometrics()
    }

    func unlockWithBiometrics() throws {
        // Ensure config is loaded (without biometrics, already authenticated)
        ConfigService.shared.loadConfig()

        // Get master key from ConfigService
        guard let masterKey = ConfigService.shared.masterKey else {
            throw StorageError.notSetup
        }

        let crypto = try CryptoService(masterPassword: masterKey)

        guard fileManager.fileExists(atPath: storeURL.path) else {
            let emptyStore = PasswordStore()
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let jsonData = try encoder.encode(emptyStore)
            try jsonData.write(to: storeURL)
            self.cryptoService = crypto
            self.currentStore = emptyStore
            return
        }

        // Read plain JSON
        let jsonData = try Data(contentsOf: storeURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let store = try decoder.decode(PasswordStore.self, from: jsonData)

        // Decrypt each password
        var decryptedStore = store
        for i in 0..<decryptedStore.items.count {
            if !decryptedStore.items[i].password.isEmpty {
                decryptedStore.items[i].password = try crypto.decryptString(decryptedStore.items[i].password)
            }
        }

        self.cryptoService = crypto
        self.currentStore = decryptedStore
    }

    func lock() {
        cryptoService = nil
        currentStore = nil
    }

    func getStore() -> PasswordStore {
        currentStore ?? PasswordStore()
    }

    func saveItem(_ item: PasswordItem) throws {
        guard let crypto = cryptoService else {
            throw StorageError.notSetup
        }

        var store = getStore()

        // Prepare encrypted version to save to file
        var encryptedItem = item
        encryptedItem.password = try crypto.encryptString(item.password)

        let isNewItem = !store.items.contains { $0.id == item.id }

        if let index = store.items.firstIndex(where: { $0.id == item.id }) {
            var updatedItem = item
            updatedItem.updatedAt = Date()
            store.items[index] = updatedItem
        } else {
            store.items.append(item)
        }
        store.lastUpdated = Date()

        // Prepare encrypted store for saving to file
        var encryptedStore = store
        for i in 0..<encryptedStore.items.count {
            if !encryptedStore.items[i].password.isEmpty {
                encryptedStore.items[i].password = try crypto.encryptString(encryptedStore.items[i].password)
            }
        }

        // Save as plain JSON (password fields already encrypted)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        let jsonData = try encoder.encode(encryptedStore)
        try jsonData.write(to: storeURL)

        // currentStore keeps decrypted state
        currentStore = store

        // Auto-commit and push to Git
        if GitService.shared.isConfigured && GitService.shared.isGitRepository {
            Task {
                let message = isNewItem ? "Add password: \(item.title)" : "Update password: \(item.title)"
                do {
                    try await GitService.shared.sync(message: message)
                } catch {
                    print("Git sync failed: \(error.localizedDescription)")
                }
            }
        }
    }

    func deleteItem(id: UUID) throws {
        guard let crypto = cryptoService else {
            throw StorageError.notSetup
        }

        var store = getStore()

        // Find the password item to delete for logging
        let itemToDelete = store.items.first { $0.id == id }

        store.items.removeAll { $0.id == id }
        store.lastUpdated = Date()

        // Prepare encrypted store for saving to file
        var encryptedStore = store
        for i in 0..<encryptedStore.items.count {
            if !encryptedStore.items[i].password.isEmpty {
                encryptedStore.items[i].password = try crypto.encryptString(encryptedStore.items[i].password)
            }
        }

        // Save as plain JSON (password fields already encrypted)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        let jsonData = try encoder.encode(encryptedStore)
        try jsonData.write(to: storeURL)

        // currentStore keeps decrypted state
        currentStore = store

        // Auto-commit and push to Git
        if GitService.shared.isConfigured && GitService.shared.isGitRepository {
            Task {
                let message = "Delete password: \(itemToDelete?.title ?? "Unknown")"
                do {
                    try await GitService.shared.sync(message: message)
                } catch {
                    print("Git sync failed: \(error.localizedDescription)")
                }
            }
        }
    }
}
