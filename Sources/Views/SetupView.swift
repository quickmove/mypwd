import SwiftUI
import AppKit

struct SetupView: View {
    @EnvironmentObject var appState: AppState

    @State private var currentStep = 0  // 0: 设置密码, 1: 选择路径, 2: Git 配置
    @State private var masterPassword = ""
    @State private var confirmPassword = ""
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var storePath: URL?
    @State private var showExistingFileAlert = false
    @State private var existingFileChoice: Bool? = nil  // nil: 未选择, true: 使用现有, false: 创建新

    // Git 配置
    @State private var isGitEnabled = false
    @State private var repoURL = ""
    @State private var username = ""
    @State private var password = ""
    @State private var showPassword = false

    // 默认存储位置
    private var defaultStoreURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("MyPwd")
        return appDir.appendingPathComponent("mypwd.json")
    }

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "lock.shield")
                .font(.system(size: 64))
                .foregroundStyle(.blue)

            Text(currentStep == 0 ? "设置主密码" : (currentStep == 1 ? "选择存储位置" : "Git 仓库配置"))
                .font(.title)
                .fontWeight(.semibold)

            // 步骤指示器
            HStack(spacing: 8) {
                Circle()
                    .fill(currentStep >= 0 ? Color.blue : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
                Rectangle()
                    .fill(currentStep >= 1 ? Color.blue : Color.gray.opacity(0.3))
                    .frame(width: 30, height: 2)
                Circle()
                    .fill(currentStep >= 1 ? Color.blue : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
                Rectangle()
                    .fill(currentStep >= 2 ? Color.blue : Color.gray.opacity(0.3))
                    .frame(width: 30, height: 2)
                Circle()
                    .fill(currentStep >= 2 ? Color.blue : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
            }

            if currentStep == 0 {
                // 步骤 1: 设置主密码
                stepOneView
            } else if currentStep == 1 {
                // 步骤 2: 选择存储位置
                stepTwoView
            } else {
                // 步骤 3: Git 配置
                stepThreeView
            }
        }
        .padding(40)
        .onTapGesture {
            NotificationCenter.default.post(name: .userActivityRecorded, object: nil)
        }
        .onAppear {
            storePath = defaultStoreURL
        }
        .alert("发现现有密码库", isPresented: $showExistingFileAlert) {
            Button("使用现有文件") {
                existingFileChoice = true
            }
            Button("创建新文件") {
                existingFileChoice = false
            }
        } message: {
            Text("该路径下已存在密码库文件，要使用现有文件还是创建新文件？")
        }
    }

    // 步骤 1: 设置主密码
    private var stepOneView: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("主密码")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                SecureField("请输入主密码", text: $masterPassword)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("确认密码")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                SecureField("请再次输入主密码", text: $confirmPassword)
                    .textFieldStyle(.roundedBorder)
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button(action: {
                guard isValidPassword else {
                    errorMessage = "密码至少6位且两次输入一致"
                    return
                }
                errorMessage = nil
                currentStep = 1
            }) {
                Text("下一步")
                    .frame(width: 200)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!isPasswordEntered)

            Text("请妥善保管主密码，忘记后无法恢复")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: 350)
    }

    // 步骤 2: 选择存储位置
    private var stepTwoView: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("存储位置")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack {
                    Text(shortPath(storePath))
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .foregroundStyle(.primary)

                    Spacer()

                    Button("选择...") {
                        selectPath()
                    }
                    .buttonStyle(.bordered)
                }
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor))
                .cornerRadius(6)
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack(spacing: 16) {
                Button("上一步") {
                    currentStep = 0
                }
                .buttonStyle(.bordered)

                Button(action: {
                    // 检查并处理现有文件
                    proceedFromStep2()
                }) {
                    if isLoading {
                        ProgressIndicator()
                    } else {
                        Text("下一步")
                            .frame(width: 100)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoading)
            }

            Text("请妥善保管主密码，忘记后无法恢复")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: 350)
    }

    // 步骤 3: Git 配置
    private var stepThreeView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Git 仓库配置")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("仓库地址")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    TextField("https://github.com/user/repo.git", text: $repoURL)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("用户名")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    TextField("GitHub 用户名或 Token", text: $username)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("密码 / Personal Access Token")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack {
                        if showPassword {
                            TextField("密码或 Token", text: $password)
                                .textFieldStyle(.roundedBorder)
                        } else {
                            SecureField("密码或 Token", text: $password)
                                .textFieldStyle(.roundedBorder)
                        }

                        Button {
                            showPassword.toggle()
                        } label: {
                            Image(systemName: showPassword ? "eye.slash" : "eye")
                        }
                        .buttonStyle(.borderless)
                    }
                }

                Text("私有仓库需要提供用户名和密码或 Personal Access Token")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack(spacing: 16) {
                Button("上一步") {
                    currentStep = 1
                }
                .buttonStyle(.bordered)

                Button(action: finishSetupWithGit) {
                    if isLoading {
                        ProgressIndicator()
                    } else {
                        Text("完成并同步")
                            .frame(width: 120)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoading || repoURL.isEmpty || username.isEmpty || password.isEmpty)
            }
        }
        .frame(width: 350)
        .onAppear {
            isGitEnabled = true
        }
    }

    private var isPasswordEntered: Bool {
        !masterPassword.isEmpty && !confirmPassword.isEmpty
    }

    private var isValidPassword: Bool {
        masterPassword.count >= 6 && masterPassword == confirmPassword
    }

    private func selectPath() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "选择"
        panel.message = "选择密码文件存储目录"

        if panel.runModal() == .OK, let url = panel.url {
            storePath = url.appendingPathComponent("mypwd.json")
            checkExistingFile()
        }
    }

    // 将路径缩短显示，用 ~ 代替用户目录
    private func shortPath(_ url: URL?) -> String {
        guard let url = url else { return "" }
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        var path = url.path
        if path.hasPrefix(homeDir) {
            path = "~" + path.dropFirst(homeDir.count)
        }
        return path
    }

    private func checkExistingFile() {
        guard let path = storePath else { return }

        if FileManager.default.fileExists(atPath: path.path) {
            showExistingFileAlert = true
        }
    }

    private func checkExistingFileForStep2() {
        guard let path = storePath else {
            // 没有选择路径，直接进入下一步
            currentStep = 2
            return
        }

        if FileManager.default.fileExists(atPath: path.path) {
            // 存在现有文件，弹出 alert
            showExistingFileAlert = true
            // 停留在当前步骤，等待用户选择
        } else {
            // 没有现有文件，直接进入下一步
            currentStep = 2
        }
    }

    // 处理第2步的"下一步"按钮点击
    private func proceedFromStep2() {
        // 如果已有选择，直接使用；否则检查文件
        if let choice = existingFileChoice {
            // 用户已选择过，使用之前的选择，进入下一步
            currentStep = 2
        } else {
            // 检查是否有现有文件
            checkExistingFileForStep2()
        }
    }

    private func finishSetupWithPath() {
        isLoading = true
        errorMessage = nil
        checkExistingFile()

        if showExistingFileAlert {
            isLoading = false
            return
        }

        finishSetup(importExisting: false)
    }

    private func finishSetupWithGit() {
        isLoading = true
        errorMessage = nil

        // 使用用户在第2步的选择
        let importExisting = existingFileChoice ?? false

        // 完成基础设置
        do {
            try finishSetup(importExisting: importExisting)

            // 配置 Git 并克隆仓库
            GitService.shared.configure(repoURL: repoURL, username: username, password: password)

            Task {
                do {
                    try await GitService.shared.clone()
                } catch {
                    await MainActor.run {
                        errorMessage = "Git 克隆失败: \(error.localizedDescription)"
                        isLoading = false
                    }
                }
            }
        } catch {
            errorMessage = "设置失败: \(error.localizedDescription)"
            isLoading = false
        }
    }

    private func finishSetup(importExisting: Bool) {
        isLoading = true
        errorMessage = nil

        do {
            if importExisting {
                try appState.importExistingStore(masterPassword: masterPassword, customPath: storePath)
            } else {
                try appState.setup(masterPassword: masterPassword, customPath: storePath)
            }
        } catch {
            errorMessage = "设置失败: \(error.localizedDescription)"
        }

        isLoading = false
    }
}

struct ProgressIndicator: View {
    var body: some View {
        ProgressView()
            .progressViewStyle(.circular)
            .scaleEffect(0.8)
    }
}