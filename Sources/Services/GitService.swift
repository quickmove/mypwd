import Foundation

enum GitError: Error, LocalizedError {
    case notConfigured
    case cloneFailed(String)
    case pullFailed(String)
    case commitFailed(String)
    case pushFailed(String)
    case notAGitRepository
    case noRemoteConfigured

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Git 仓库未配置"
        case .cloneFailed(let message):
            return "克隆仓库失败: \(message)"
        case .pullFailed(let message):
            return "拉取更新失败: \(message)"
        case .commitFailed(let message):
            return "提交失败: \(message)"
        case .pushFailed(let message):
            return "推送失败: \(message)"
        case .notAGitRepository:
            return "当前目录不是 Git 仓库"
        case .noRemoteConfigured:
            return "未配置远程仓库"
        }
    }
}

final class GitService {
    static let shared = GitService()

    private let fileManager = FileManager.default

    // Git 配置存储
    private let configKeyRepoURL = "gitRepoURL"
    private let configKeyUsername = "gitUsername"
    private let configKeyPassword = "gitPassword"

    private init() {}

    // 密码库根目录（包含 .git 文件夹）
    var repositoryDirectory: URL {
        PasswordStorageService.shared.storeURL.deletingLastPathComponent()
    }

    // 是否已配置 git
    var isConfigured: Bool {
        repoURL != nil
    }

    // 是否已是 git 仓库
    var isGitRepository: Bool {
        let gitPath = repositoryDirectory.appendingPathComponent(".git")
        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: gitPath.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    // 获取/设置仓库 URL
    var repoURL: String? {
        get {
            guard let data = try? KeychainService.shared.load(forKey: configKeyRepoURL) else {
                return nil
            }
            return String(data: data, encoding: .utf8)
        }
        set {
            if let url = newValue {
                try? KeychainService.shared.save(data: url.data(using: .utf8) ?? Data(), forKey: configKeyRepoURL)
            } else {
                try? KeychainService.shared.delete(forKey: configKeyRepoURL)
            }
        }
    }

    // 获取/设置用户名
    var username: String? {
        get {
            guard let data = try? KeychainService.shared.load(forKey: configKeyUsername) else {
                return nil
            }
            return String(data: data, encoding: .utf8)
        }
        set {
            if let name = newValue {
                try? KeychainService.shared.save(data: name.data(using: .utf8) ?? Data(), forKey: configKeyUsername)
            } else {
                try? KeychainService.shared.delete(forKey: configKeyUsername)
            }
        }
    }

    // 获取/设置密码
    var password: String? {
        get {
            guard let data = try? KeychainService.shared.load(forKey: configKeyPassword) else {
                return nil
            }
            return String(data: data, encoding: .utf8)
        }
        set {
            if let pwd = newValue {
                try? KeychainService.shared.save(data: pwd.data(using: .utf8) ?? Data(), forKey: configKeyPassword)
            } else {
                try? KeychainService.shared.delete(forKey: configKeyPassword)
            }
        }
    }

    // 配置 git 仓库
    func configure(repoURL: String, username: String, password: String) {
        self.repoURL = repoURL
        self.username = username
        self.password = password
    }

    // 清除 git 配置
    func clearConfiguration() {
        repoURL = nil
        username = nil
        password = nil
    }

    // 获取带有凭证的仓库 URL
    private func authenticatedURL() -> String? {
        guard let url = repoURL, let user = username, let pass = password else {
            return nil
        }

        // 解析原始 URL 并插入凭证
        if let urlComponents = URLComponents(string: url) {
            var components = URLComponents()
            components.scheme = urlComponents.scheme
            components.host = urlComponents.host
            components.path = urlComponents.path
            components.user = user
            components.password = pass
            if let port = urlComponents.port {
                components.port = port
            }
            return components.string
        }

        // 如果无法解析，直接替换 protocol 后面的部分
        // https://github.com/user/repo -> https://user:pass@github.com/user/repo
        if url.hasPrefix("https://") {
            let path = String(url.dropFirst(8))
            return "https://\(user):\(pass)@\(path)"
        } else if url.hasPrefix("http://") {
            let path = String(url.dropFirst(7))
            return "http://\(user):\(pass)@\(path)"
        }

        return nil
    }

    // 执行 git 命令
    private func runGitCommand(_ arguments: [String], in directory: URL) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let pipe = Pipe()

            process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            process.arguments = arguments
            process.currentDirectoryURL = directory
            process.standardOutput = pipe
            process.standardError = pipe

            do {
                try process.run()
                process.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""

                if process.terminationStatus == 0 {
                    continuation.resume(returning: output)
                } else {
                    continuation.resume(throwing: GitError.cloneFailed(output))
                }
            } catch {
                continuation.resume(throwing: GitError.cloneFailed(error.localizedDescription))
            }
        }
    }

    // 克隆仓库到密码库目录
    func clone() async throws {
        guard let authURL = authenticatedURL() else {
            throw GitError.notConfigured
        }

        let repoDir = repositoryDirectory

        // 如果目录已存在且是 git 仓库，先删除
        if fileManager.fileExists(atPath: repoDir.path) {
            try? fileManager.removeItem(at: repoDir)
        }

        // 确保父目录存在
        let parentDir = repoDir.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: parentDir.path) {
            try fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true)
        }

        // 执行克隆
        _ = try await runGitCommand(["clone", authURL, repoDir.path], in: parentDir)

        // 检查是否是克隆到了子目录
        let clonedContents = try fileManager.contentsOfDirectory(at: repoDir, includingPropertiesForKeys: nil)
        if clonedContents.count == 1, let firstItem = clonedContents.first {
            // 如果克隆到了一个子目录，移动内容到根目录
            if firstItem.hasDirectoryPath {
                let subDir = firstItem
                for item in try fileManager.contentsOfDirectory(at: subDir, includingPropertiesForKeys: nil) {
                    try fileManager.moveItem(at: item, to: repoDir.appendingPathComponent(item.lastPathComponent))
                }
                try fileManager.removeItem(at: subDir)
            }
        }
    }

    // 拉取最新代码
    func pull() async throws {
        guard isGitRepository else {
            throw GitError.notAGitRepository
        }

        guard let authURL = authenticatedURL() else {
            throw GitError.notConfigured
        }

        // 设置远程 URL（包含凭证）
        _ = try await runGitCommand(["remote", "set-url", "origin", authURL], in: repositoryDirectory)

        // 执行 pull
        do {
            _ = try await runGitCommand(["pull", "origin", "main"], in: repositoryDirectory)
        } catch {
            // 尝试 master 分支
            _ = try await runGitCommand(["pull", "origin", "master"], in: repositoryDirectory)
        }
    }

    // 提交更改
    func commit(message: String) async throws {
        guard isGitRepository else {
            throw GitError.notAGitRepository
        }

        // 添加所有更改
        _ = try await runGitCommand(["add", "-A"], in: repositoryDirectory)

        // 检查是否有更改需要提交
        let statusOutput = try await runGitCommand(["status", "--porcelain"], in: repositoryDirectory)
        if statusOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return // 没有更改，无需提交
        }

        // 执行提交
        _ = try await runGitCommand(["commit", "-m", message], in: repositoryDirectory)
    }

    // 推送到远程
    func push() async throws {
        guard isGitRepository else {
            throw GitError.notAGitRepository
        }

        guard let authURL = authenticatedURL() else {
            throw GitError.notConfigured
        }

        // 设置远程 URL（包含凭证）
        _ = try await runGitCommand(["remote", "set-url", "origin", authURL], in: repositoryDirectory)

        // 执行推送
        do {
            _ = try await runGitCommand(["push", "origin", "main"], in: repositoryDirectory)
        } catch {
            // 尝试 master 分支
            _ = try await runGitCommand(["push", "origin", "master"], in: repositoryDirectory)
        }
    }

    // 自动同步：提交并推送
    func sync(message: String) async throws {
        try await commit(message: message)
        try await push()
    }
}
