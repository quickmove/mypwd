import SwiftUI

struct PasswordEditorView: View {
    let item: PasswordItem?
    let onDismiss: (Bool) -> Void

    @State private var title: String = ""
    @State private var url: String = ""
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var note: String = ""

    @State private var showGenerator = false
    @State private var generatorLength = 16
    @State private var includeUppercase = true
    @State private var includeLowercase = true
    @State private var includeNumbers = true
    @State private var includeSymbols = true

    @State private var errorMessage: String?

    var isEditing: Bool {
        item != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text(isEditing ? "编辑密码" : "添加密码")
                    .font(.headline)

                Spacer()

                Button("取消") {
                    onDismiss(false)
                }
                .buttonStyle(.borderless)
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // 表单
            Form {
                Section {
                    TextField("标题", text: $title)
                        .textFieldStyle(.roundedBorder)

                    TextField("URL", text: $url)
                        .textFieldStyle(.roundedBorder)

                    TextField("用户名", text: $username)
                        .textFieldStyle(.roundedBorder)

                    HStack {
                        SecureField("密码", text: $password)
                            .textFieldStyle(.roundedBorder)

                        Button(action: { showGenerator = true }) {
                            Image(systemName: "wand.and.stars")
                        }
                        .buttonStyle(.bordered)
                        .help("生成密码")
                    }

                    TextField("备注", text: $note, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...5)
                }

                if !password.isEmpty {
                    Section("密码强度") {
                        PasswordStrengthIndicator(password: password)
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            // 底部按钮
            HStack {
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Spacer()

                Button("保存") {
                    save()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
            }
            .padding()
        }
        .frame(width: 500, height: 450)
        .onTapGesture {
            NotificationCenter.default.post(name: .userActivityRecorded, object: nil)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    NotificationCenter.default.post(name: .userActivityRecorded, object: nil)
                }
        )
        .onAppear {
            // 编辑时重置活动计时并暂停自动锁定
            NotificationCenter.default.post(name: .userActivityRecorded, object: nil)
            NotificationCenter.default.post(name: .pauseAutoLock, object: nil)

            if let item = item {
                title = item.title
                url = item.url
                username = item.username
                password = item.password
                note = item.note
            }
        }
        .onDisappear {
            // 恢复自动锁定
            NotificationCenter.default.post(name: .resumeAutoLock, object: nil)
        }
        .sheet(isPresented: $showGenerator) {
            PasswordGeneratorView(
                length: $generatorLength,
                includeUppercase: $includeUppercase,
                includeLowercase: $includeLowercase,
                includeNumbers: $includeNumbers,
                includeSymbols: $includeSymbols
            ) { generatedPassword in
                password = generatedPassword
                showGenerator = false
            }
        }
    }

    private var isValid: Bool {
        !password.isEmpty
    }

    private func save() {
        guard isValid else {
            errorMessage = "请输入密码"
            return
        }

        var newItem = item ?? PasswordItem()
        newItem.title = title
        newItem.url = url
        newItem.username = username
        newItem.password = password
        newItem.note = note

        do {
            try PasswordStorageService.shared.saveItem(newItem)
            onDismiss(true)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct PasswordStrengthIndicator: View {
    let password: String

    private var strength: PasswordStrength {
        PasswordGenerator.shared.calculateStrength(password)
    }

    private var progress: Double {
        switch strength {
        case .veryWeak: return 0.2
        case .weak: return 0.4
        case .medium: return 0.6
        case .strong: return 0.8
        case .veryStrong: return 1.0
        }
    }

    private var color: Color {
        switch strength {
        case .veryWeak: return .red
        case .weak: return .orange
        case .medium: return .yellow
        case .strong: return .green
        case .veryStrong: return .blue
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .tint(color)

            Text(strength.rawValue)
                .font(.caption)
                .foregroundStyle(color)
        }
    }
}
