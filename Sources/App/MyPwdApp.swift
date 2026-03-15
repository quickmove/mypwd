import SwiftUI
import AppKit
import Combine

extension Notification.Name {
    static let userActivityRecorded = Notification.Name("userActivityRecorded")
    static let pauseAutoLock = Notification.Name("pauseAutoLock")
    static let resumeAutoLock = Notification.Name("resumeAutoLock")
}

@main
struct MyPwdApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 800, height: 600)
    }
}

final class AppState: ObservableObject {
    @Published var isUnlocked = false
    @Published var isSetup = false
    @Published var refreshTrigger = false
    @Published var remainingSeconds: Int = 30
    @Published var isPaused: Bool = false  // 暂停自动锁定
    @Published var isLocking: Bool = false  // 防止重复锁定

    private var idleTimer: Timer?
    private var countdownTimer: Timer?
    private var lastActivityTime: Date = Date()

    // 自动锁定超时时间（秒）
    private let autoLockTimeout: TimeInterval = 30

    init() {
        isSetup = PasswordStorageService.shared.isSetup
        startIdleMonitor()

        // 监听用户活动通知
        NotificationCenter.default.addObserver(forName: .userActivityRecorded, object: nil, queue: .main) { [weak self] _ in
            self?.recordActivity()
        }

        // 监听暂停/恢复自动锁定
        NotificationCenter.default.addObserver(forName: .pauseAutoLock, object: nil, queue: .main) { [weak self] _ in
            self?.isPaused = true
        }

        NotificationCenter.default.addObserver(forName: .resumeAutoLock, object: nil, queue: .main) { [weak self] _ in
            self?.isPaused = false
            self?.recordActivity()
        }
    }

    // 定期检查无操作时间
    private func startIdleMonitor() {
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self, self.isUnlocked else { return }

            // 如果暂停，不减少秒数
            if self.isPaused {
                return
            }

            let idleTime = Date().timeIntervalSince(self.lastActivityTime)
            let remaining = max(0, Int(self.autoLockTimeout - idleTime))
            self.remainingSeconds = remaining

            if idleTime >= self.autoLockTimeout {
                DispatchQueue.main.async {
                    self.lock()
                }
            }
        }
    }

    // 记录用户活动（需要在视图层调用）
    func recordActivity() {
        lastActivityTime = Date()
    }

    func setup(masterPassword: String, customPath: URL? = nil) throws {
        // 设置自定义路径（如果有）
        if let path = customPath {
            PasswordStorageService.shared.customStoreURL = path
        }
        try PasswordStorageService.shared.setup(masterPassword: masterPassword, customPath: nil)
        isSetup = true
        isUnlocked = true
        isLocking = false
        lastActivityTime = Date()
        remainingSeconds = Int(autoLockTimeout)
    }

    func importExistingStore(masterPassword: String, customPath: URL? = nil) throws {
        if let path = customPath {
            PasswordStorageService.shared.customStoreURL = path
        }
        try PasswordStorageService.shared.importExistingStore(masterPassword: masterPassword)
        isSetup = true
        isUnlocked = true
        isLocking = false
        lastActivityTime = Date()
        remainingSeconds = Int(autoLockTimeout)
    }

    func unlock(masterPassword: String) throws {
        try PasswordStorageService.shared.unlock(masterPassword: masterPassword)
        isUnlocked = true
        isLocking = false
        lastActivityTime = Date()
        remainingSeconds = Int(autoLockTimeout)

        // 如果已配置 Git 且是 Git 仓库，执行 pull
        if GitService.shared.isConfigured && GitService.shared.isGitRepository {
            Task {
                do {
                    try await GitService.shared.pull()
                } catch {
                    print("Git pull failed: \(error.localizedDescription)")
                }
            }
        }
    }

    func unlockWithBiometrics() async throws {
        try await AuthenticationService.shared.authenticateWithBiometrics(reason: "解锁密码库")

        await MainActor.run {
            do {
                try PasswordStorageService.shared.unlockWithBiometrics()
                isUnlocked = true
                isLocking = false
                lastActivityTime = Date()
                remainingSeconds = Int(autoLockTimeout)

                // 如果已配置 Git 且是首次拉取后的登录，执行 pull
                if GitService.shared.isConfigured && GitService.shared.isGitRepository {
                    Task {
                        do {
                            try await GitService.shared.pull()
                        } catch {
                            print("Git pull failed: \(error.localizedDescription)")
                        }
                    }
                }
            } catch {
                errorMessage = "TouchID 解锁失败: \(error.localizedDescription)"
            }
        }
    }

    func lock() {
        // 防止重复锁定
        guard !isLocking else {
            return
        }
        isLocking = true

        idleTimer?.invalidate()
        idleTimer = nil
        remainingSeconds = 0
        PasswordStorageService.shared.lock()
        isUnlocked = false

        // 锁定时最小化应用
        DispatchQueue.main.async {
            NSApp.keyWindow?.miniaturize(nil)
        }
    }

    func triggerRefresh() {
        refreshTrigger.toggle()
    }

    var errorMessage: String = ""
}
