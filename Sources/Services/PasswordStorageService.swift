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
            return "请先设置主密码"
        case .loadFailed:
            return "加载密码库失败"
        case .saveFailed:
            return "保存密码库失败"
        case .invalidPassword:
            return "密码错误"
        }
    }
}

final class PasswordStorageService {
    static let shared = PasswordStorageService()

    private var cryptoService: CryptoService?
    private var currentStore: PasswordStore?

    private let fileManager = FileManager.default

    // 默认路径
    private var defaultStoreURL: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("MyPwd", isDirectory: true)

        if !fileManager.fileExists(atPath: appDir.path) {
            try? fileManager.createDirectory(at: appDir, withIntermediateDirectories: true)
        }

        return appDir.appendingPathComponent("mypwd.json")
    }

    // 用户自定义路径
    var customStoreURL: URL? {
        get {
            guard let data = try? KeychainService.shared.load(forKey: KeychainService.Keys.customStorePath),
                  let pathString = String(data: data, encoding: .utf8),
                  let url = URL(string: pathString) else {
                return nil
            }
            return url
        }
        set {
            if let url = newValue {
                let data = url.absoluteString.data(using: .utf8) ?? Data()
                try? KeychainService.shared.save(data: data, forKey: KeychainService.Keys.customStorePath)
            } else {
                try? KeychainService.shared.delete(forKey: KeychainService.Keys.customStorePath)
            }
        }
    }

    var storeURL: URL {
        customStoreURL ?? defaultStoreURL
    }

    var isSetup: Bool {
        KeychainServiceWithBiometric.shared.exists(forKey: "masterKey")
    }

    private init() {}

    func setup(masterPassword: String, customPath: URL? = nil) throws {
        // 保存自定义路径
        if let path = customPath {
            customStoreURL = path
        }

        // 将主密钥存入 Keychain，用 TouchID 保护
        let keyData = masterPassword.data(using: .utf8)!
        try KeychainServiceWithBiometric.shared.saveKey(data: keyData, forKey: "masterKey")

        // 确保目录存在
        let directory = storeURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        // 创建空存储（明文 JSON 格式）
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

    // 导入已存在的密码库文件
    func importExistingStore(masterPassword: String) throws {
        // 确保文件存在
        guard fileManager.fileExists(atPath: storeURL.path) else {
            throw StorageError.loadFailed
        }

        // 将主密钥存入 Keychain，用 TouchID 保护
        let keyData = masterPassword.data(using: .utf8)!
        try KeychainServiceWithBiometric.shared.saveKey(data: keyData, forKey: "masterKey")

        // 解密并加载现有数据
        let crypto = try CryptoService(masterPassword: masterPassword)

        // 读取明文 JSON
        let jsonData = try Data(contentsOf: storeURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let store = try decoder.decode(PasswordStore.self, from: jsonData)

        // 解密每个密码
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
        // 从 Keychain 获取主密钥（TouchID 保护）
        guard let masterKeyData = try KeychainServiceWithBiometric.shared.loadKeyWithBiometrics(forKey: "masterKey"),
              let masterKey = String(data: masterKeyData, encoding: .utf8) else {
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

        // 读取明文 JSON
        let jsonData = try Data(contentsOf: storeURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let store = try decoder.decode(PasswordStore.self, from: jsonData)

        // 解密每个密码
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

        // 准备保存到文件的加密版本
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

        // 准备加密后的存储用于保存到文件
        var encryptedStore = store
        for i in 0..<encryptedStore.items.count {
            if !encryptedStore.items[i].password.isEmpty {
                encryptedStore.items[i].password = try crypto.encryptString(encryptedStore.items[i].password)
            }
        }

        // 保存为明文 JSON（密码字段已加密）
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        let jsonData = try encoder.encode(encryptedStore)
        try jsonData.write(to: storeURL)

        // currentStore 保持解密状态
        currentStore = store

        // 自动提交并推送到 Git
        if GitService.shared.isConfigured && GitService.shared.isGitRepository {
            Task {
                let message = isNewItem ? "添加密码: \(item.title)" : "更新密码: \(item.title)"
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

        // 找到要删除的密码项以便记录日志
        let itemToDelete = store.items.first { $0.id == id }

        store.items.removeAll { $0.id == id }
        store.lastUpdated = Date()

        // 准备加密后的存储用于保存到文件
        var encryptedStore = store
        for i in 0..<encryptedStore.items.count {
            if !encryptedStore.items[i].password.isEmpty {
                encryptedStore.items[i].password = try crypto.encryptString(encryptedStore.items[i].password)
            }
        }

        // 保存为明文 JSON（密码字段已加密）
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        let jsonData = try encoder.encode(encryptedStore)
        try jsonData.write(to: storeURL)

        // currentStore 保持解密状态
        currentStore = store

        // 自动提交并推送到 Git
        if GitService.shared.isConfigured && GitService.shared.isGitRepository {
            Task {
                let message = "删除密码: \(itemToDelete?.title ?? "未知")"
                do {
                    try await GitService.shared.sync(message: message)
                } catch {
                    print("Git sync failed: \(error.localizedDescription)")
                }
            }
        }
    }
}
