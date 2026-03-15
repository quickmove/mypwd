import SwiftUI
import AppKit

struct SetupView: View {
    @EnvironmentObject var appState: AppState

    @State private var currentStep = 0  // 0: Set password, 1: Choose path, 2: Git config
    @State private var masterPassword = ""
    @State private var confirmPassword = ""
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var storePath: URL?
    @State private var showExistingFileAlert = false
    @State private var existingFileChoice: Bool? = nil  // nil: Not chosen, true: Use existing, false: Create new

    // Git config
    @State private var isGitEnabled = false
    @State private var repoURL = ""
    @State private var username = ""
    @State private var password = ""
    @State private var showPassword = false

    // Default storage location
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

            Text(currentStep == 0 ? "Set Master Password" : (currentStep == 1 ? "Choose Storage Location" : "Git Repository Configuration"))
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
                // Step 1: Set master password
                stepOneView
            } else if currentStep == 1 {
                // Step 2: Choose storage location
                stepTwoView
            } else {
                // Step 3: Git configuration
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
        .alert("Existing Password Vault Found", isPresented: $showExistingFileAlert) {
            Button("Use Existing File") {
                existingFileChoice = true
            }
            Button("Create New File") {
                existingFileChoice = false
            }
        } message: {
            Text("A password vault file already exists at this location. Use existing file or create new?")
        }
    }

    // Step 1: Set master password
    private var stepOneView: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Master Password")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                SecureField("Enter master password", text: $masterPassword)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Confirm Password")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                SecureField("Enter master password again", text: $confirmPassword)
                    .textFieldStyle(.roundedBorder)
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button(action: {
                guard isValidPassword else {
                    errorMessage = "Password must be at least 6 characters and match"
                    return
                }
                errorMessage = nil
                currentStep = 1
            }) {
                Text("Next")
                    .frame(width: 200)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!isPasswordEntered)

            Text("Please keep your master password safe. It cannot be recovered if forgotten.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: 350)
    }

    // Step 2: Choose storage location
    private var stepTwoView: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Storage Location")
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
                Button("Previous") {
                    currentStep = 0
                }
                .buttonStyle(.bordered)

                Button(action: {
                    // Check and handle existing file
                    proceedFromStep2()
                }) {
                    if isLoading {
                        ProgressIndicator()
                    } else {
                        Text("Next")
                            .frame(width: 100)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoading)
            }

            Text("Please keep your master password safe. It cannot be recovered if forgotten.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: 350)
    }

    // Step 3: Git configuration
    private var stepThreeView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Git Repository Configuration")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Repository URL")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    TextField("https://github.com/user/repo.git", text: $repoURL)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Username")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    TextField("GitHub username or Token", text: $username)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Password / Personal Access Token")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack {
                        if showPassword {
                            TextField("Password or Token", text: $password)
                                .textFieldStyle(.roundedBorder)
                        } else {
                            SecureField("Password or Token", text: $password)
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

                Text("Private repositories require username and password or Personal Access Token")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack(spacing: 16) {
                Button("Previous") {
                    currentStep = 1
                }
                .buttonStyle(.bordered)

                Button(action: finishSetupWithGit) {
                    if isLoading {
                        ProgressIndicator()
                    } else {
                        Text("Finish & Sync")
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
        panel.prompt = "Select"
        panel.message = "Choose password file storage directory"

        if panel.runModal() == .OK, let url = panel.url {
            storePath = url.appendingPathComponent("mypwd.json")
            checkExistingFile()
        }
    }

    // Shorten path display, use ~ instead of user directory
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
            // No path selected, proceed to next step
            currentStep = 2
            return
        }

        if FileManager.default.fileExists(atPath: path.path) {
            // Existing file exists, show alert
            showExistingFileAlert = true
            // Stay on current step, wait for user selection
        } else {
            // No existing file, proceed to next step
            currentStep = 2
        }
    }

    // Handle "Next" button click on step 2
    private func proceedFromStep2() {
        // If already have a choice, use it; otherwise check file
        if let choice = existingFileChoice {
            // User has made a choice before, use previous choice, proceed
            currentStep = 2
        } else {
            // Check if there's an existing file
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

        // Use user's choice from step 2
        let importExisting = existingFileChoice ?? false

        // Complete basic setup
        do {
            try finishSetup(importExisting: importExisting)

            // Configure Git and clone repository
            GitService.shared.configure(repoURL: repoURL, username: username, password: password)

            Task {
                do {
                    try await GitService.shared.clone()
                } catch {
                    await MainActor.run {
                        errorMessage = "Git clone failed: \(error.localizedDescription)"
                        isLoading = false
                    }
                }
            }
        } catch {
            errorMessage = "Setup failed: \(error.localizedDescription)"
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
            errorMessage = "Setup failed: \(error.localizedDescription)"
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