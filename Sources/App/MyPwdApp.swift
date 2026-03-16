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
    @Published var isPaused: Bool = false  // Pause auto-lock
    @Published var isLocking: Bool = false  // Prevent duplicate locking

    private var idleTimer: Timer?
    private var countdownTimer: Timer?
    private var lastActivityTime: Date = Date()

    // Auto-lock timeout in seconds
    private let autoLockTimeout: TimeInterval = 30

    init() {
        // Load config to cache at app startup (with biometrics)
        try? ConfigService.shared.loadConfigWithBiometrics()

        isSetup = PasswordStorageService.shared.isSetup
        startIdleMonitor()

        // Listen for user activity notifications
        NotificationCenter.default.addObserver(forName: .userActivityRecorded, object: nil, queue: .main) { [weak self] _ in
            self?.recordActivity()
        }

        // Listen for pause/resume auto-lock
        NotificationCenter.default.addObserver(forName: .pauseAutoLock, object: nil, queue: .main) { [weak self] _ in
            self?.isPaused = true
        }

        NotificationCenter.default.addObserver(forName: .resumeAutoLock, object: nil, queue: .main) { [weak self] _ in
            self?.isPaused = false
            self?.recordActivity()
        }
    }

    // Periodically check idle time
    private func startIdleMonitor() {
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self, self.isUnlocked else { return }

            // If paused, don't decrement seconds
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

    // Record user activity (called from view layer)
    func recordActivity() {
        lastActivityTime = Date()
    }

    func setup(masterPassword: String, customPath: URL? = nil) throws {
        // Set custom path if provided
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

        // If Git is configured and is a Git repository, perform pull
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
        try await AuthenticationService.shared.authenticateWithBiometrics(reason: "Unlock password vault")

        await MainActor.run {
            do {
                try PasswordStorageService.shared.unlockWithBiometrics()
                isUnlocked = true
                isLocking = false
                lastActivityTime = Date()
                remainingSeconds = Int(autoLockTimeout)

                // If Git is configured and login after first pull, perform pull
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
                errorMessage = "TouchID unlock failed: \(error.localizedDescription)"
            }
        }
    }

    func lock() {
        // Prevent duplicate locking
        guard !isLocking else {
            return
        }
        isLocking = true

        idleTimer?.invalidate()
        idleTimer = nil
        remainingSeconds = 0
        PasswordStorageService.shared.lock()
        isUnlocked = false

        // Minimize app when locking
        DispatchQueue.main.async {
            NSApp.keyWindow?.miniaturize(nil)
        }
    }

    func triggerRefresh() {
        refreshTrigger.toggle()
    }

    var errorMessage: String = ""
}
