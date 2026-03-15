import SwiftUI
import AppKit

struct PasswordDetailView: View {
    let item: PasswordItem
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var showPassword = false
    @State private var copiedField: String?
    @State private var showingEditor = false
    @State private var timer: Timer?
    @State private var showingDeleteAlert = false

    // Auto-hide timeout in seconds
    private let autoHideTimeout: TimeInterval = 30

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Title
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.displayTitle)
                            .font(.title)
                            .fontWeight(.bold)

                        if !item.url.isEmpty {
                            Text(item.url)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Button(action: {
                        NotificationCenter.default.post(name: .pauseAutoLock, object: nil)
                        showingEditor = true
                    }) {
                        Label("Edit", systemImage: "pencil")
                    }
                    .buttonStyle(.bordered)

                    Button(action: {
                        showingDeleteAlert = true
                    }) {
                        Label("Delete", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }

                Divider()

                // Username
                DetailField(title: "Username", value: item.username, isSensitive: false, copiedFieldName: $copiedField)

                // Password
                DetailField(title: "Password", value: item.password, isSensitive: !showPassword, copiedFieldName: $copiedField) {
                    AnyView(
                        Button(action: togglePassword) {
                            Image(systemName: showPassword ? "eye.slash" : "eye")
                        }
                        .buttonStyle(.borderless)
                    )
                }

                // Notes
                if !item.note.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text(item.note)
                            .font(.body)
                    }
                }

                // Time information
                VStack(alignment: .leading, spacing: 4) {
                    Text("Created: \(item.createdAt.formatted())")
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    Text("Updated: \(item.updatedAt.formatted())")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.top, 16)
            }
            .padding(24)
        }
        .sheet(isPresented: $showingEditor) {
            PasswordEditorView(item: item) { didSave in
                showingEditor = false
            }
            .onAppear {
                NotificationCenter.default.post(name: .pauseAutoLock, object: nil)
            }
            .onDisappear {
                NotificationCenter.default.post(name: .resumeAutoLock, object: nil)
            }
        }
        .alert("Confirm Delete", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                try? PasswordStorageService.shared.deleteItem(id: item.id)
                onDelete()
            }
        } message: {
            Text("Are you sure you want to delete \"\(item.displayTitle)\"? This action cannot be undone.")
        }
        // Hide password when password item changes
        .onChange(of: item.id) { _ in
            hidePassword()
        }
        // Hide password and cancel timer when view disappears
        .onDisappear {
            hidePassword()
        }
        .onTapGesture {
            NotificationCenter.default.post(name: .userActivityRecorded, object: nil)
        }
    }

    private func togglePassword() {
        if showPassword {
            hidePassword()
        } else {
            showPassword = true
            startTimer()
        }
    }

    private func hidePassword() {
        showPassword = false
        timer?.invalidate()
        timer = nil
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: autoHideTimeout, repeats: false) { _ in
            showPassword = false
        }
    }
}

struct DetailField: View {
    let title: String
    let value: String
    let isSensitive: Bool
    @Binding var copiedFieldName: String?
    var trailingButton: (() -> AnyView)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                if isSensitive {
                    Text(String(repeating: "•", count: min(value.count, 12)))
                        .font(.body)
                } else {
                    Text(value)
                        .font(.body)
                }

                Spacer()

                if let trailingButton = trailingButton {
                    trailingButton()
                }

                Button(action: copyToClipboard) {
                    Image(systemName: copiedFieldName == title ? "checkmark" : "doc.on.doc")
                        .foregroundStyle(copiedFieldName == title ? .green : .secondary)
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(value, forType: .string)

        copiedFieldName = title

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if copiedFieldName == title {
                copiedFieldName = nil
            }
        }
    }
}
