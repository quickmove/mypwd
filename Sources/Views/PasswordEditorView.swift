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
            // Title bar
            HStack {
                Text(isEditing ? LocalizedStrings.editPassword : LocalizedStrings.addPassword)
                    .font(.headline)

                Spacer()

                Button(LocalizedStrings.cancel) {
                    onDismiss(false)
                }
                .buttonStyle(.borderless)
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // Form
            Form {
                Section {
                    TextField(LocalizedStrings.title, text: $title)
                        .textFieldStyle(.roundedBorder)

                    TextField(LocalizedStrings.url, text: $url)
                        .textFieldStyle(.roundedBorder)

                    TextField(LocalizedStrings.usernameField, text: $username)
                        .textFieldStyle(.roundedBorder)

                    HStack {
                        SecureField(LocalizedStrings.password, text: $password)
                            .textFieldStyle(.roundedBorder)

                        Button(action: { showGenerator = true }) {
                            Image(systemName: "wand.and.stars")
                        }
                        .buttonStyle(.bordered)
                        .help("Generate password")
                    }

                    TextField(LocalizedStrings.notes, text: $note, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...5)
                }

                if !password.isEmpty {
                    Section(LocalizedStrings.passwordStrength) {
                        PasswordStrengthIndicator(password: password)
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            // Bottom buttons
            HStack {
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Spacer()

                Button(LocalizedStrings.save) {
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
            // Reset activity timer and pause auto-lock when editing
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
            // Resume auto-lock
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
            errorMessage = LocalizedStrings.pleaseEnterAPassword
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

            Text(strength.localized)
                .font(.caption)
                .foregroundStyle(color)
        }
    }
}
