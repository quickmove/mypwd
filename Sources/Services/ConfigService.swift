import Foundation

struct AppConfig: Codable {
    var customStorePath: String?
    var masterKey: String?
    var gitRepoURL: String?
    var gitUsername: String?
    var gitPassword: String?

    static let keychainKey = "appConfig"

    static var empty: AppConfig {
        AppConfig()
    }
}

final class ConfigService {
    static let shared = ConfigService()

    private var cachedConfig: AppConfig?
    private let keychain = KeychainServiceWithBiometric.shared

    private init() {}

    // 启动时调用，加载配置到缓存（带生物识别验证）
    func loadConfigWithBiometrics() throws {
        guard let data = try keychain.loadKeyWithBiometrics(forKey: AppConfig.keychainKey) else {
            cachedConfig = .empty
            return
        }

        guard let config = try? JSONDecoder().decode(AppConfig.self, from: data) else {
            cachedConfig = .empty
            return
        }

        cachedConfig = config
    }

    // 解锁后调用，加载配置到缓存（不带生物识别，已在 unlockWithBiometrics 中验证过）
    func loadConfig() {
        guard let data = try? keychain.loadKey(forKey: AppConfig.keychainKey) else {
            cachedConfig = .empty
            return
        }

        guard let config = try? JSONDecoder().decode(AppConfig.self, from: data) else {
            cachedConfig = .empty
            return
        }

        cachedConfig = config
    }

    // 保存配置到 Keychain 并更新缓存
    func saveConfig(_ config: AppConfig) throws {
        let data = try JSONEncoder().encode(config)
        try keychain.saveKey(data: data, forKey: AppConfig.keychainKey)
        cachedConfig = config
    }

    // 获取缓存的配置
    func getConfig() -> AppConfig {
        cachedConfig ?? .empty
    }

    // 便捷访问方法
    var customStorePath: String? {
        get { cachedConfig?.customStorePath }
        set {
            var config = getConfig()
            config.customStorePath = newValue
            try? saveConfig(config)
        }
    }

    var masterKey: String? {
        get { cachedConfig?.masterKey }
        set {
            var config = getConfig()
            config.masterKey = newValue
            try? saveConfig(config)
        }
    }

    var gitRepoURL: String? {
        get { cachedConfig?.gitRepoURL }
        set {
            var config = getConfig()
            config.gitRepoURL = newValue
            try? saveConfig(config)
        }
    }

    var gitUsername: String? {
        get { cachedConfig?.gitUsername }
        set {
            var config = getConfig()
            config.gitUsername = newValue
            try? saveConfig(config)
        }
    }

    var gitPassword: String? {
        get { cachedConfig?.gitPassword }
        set {
            var config = getConfig()
            config.gitPassword = newValue
            try? saveConfig(config)
        }
    }

    // 清除所有配置
    func clearConfig() throws {
        try keychain.deleteKey(forKey: AppConfig.keychainKey)
        cachedConfig = .empty
    }
}
