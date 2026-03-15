import SwiftUI

struct PasswordGeneratorView: View {
    @Binding var length: Int
    @Binding var includeUppercase: Bool
    @Binding var includeLowercase: Bool
    @Binding var includeNumbers: Bool
    @Binding var includeSymbols: Bool

    let onUse: (String) -> Void

    @State private var generatedPassword = ""
    @State private var showPassword = false

    var body: some View {
        VStack(spacing: 20) {
            Text("密码生成器")
                .font(.headline)

            // 生成结果
            HStack {
                if showPassword {
                    Text(generatedPassword)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                } else {
                    Text(String(repeating: "•", count: min(generatedPassword.count, 16)))
                        .font(.system(.body, design: .monospaced))
                }

                Spacer()

                Button(action: { showPassword.toggle() }) {
                    Image(systemName: showPassword ? "eye.slash" : "eye")
                }
                .buttonStyle(.borderless)

                Button(action: copyToClipboard) {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
            }
            .padding()
            .background(Color(nsColor: .textBackgroundColor))
            .cornerRadius(8)

            // 长度滑块
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("长度")
                    Spacer()
                    Text("\(length)")
                        .foregroundStyle(.secondary)
                }

                Slider(value: Binding(
                    get: { Double(length) },
                    set: { length = Int($0) }
                ), in: 8...32, step: 1)
            }

            // 字符选项
            VStack(alignment: .leading, spacing: 12) {
                Toggle("大写字母 (A-Z)", isOn: $includeUppercase)
                Toggle("小写字母 (a-z)", isOn: $includeLowercase)
                Toggle("数字 (0-9)", isOn: $includeNumbers)
                Toggle("符号 (!@#$%)", isOn: $includeSymbols)
            }
            .toggleStyle(.checkbox)

            // 按钮
            HStack {
                Button("重新生成") {
                    generate()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("使用此密码") {
                    onUse(generatedPassword)
                }
                .buttonStyle(.borderedProminent)
                .disabled(generatedPassword.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 400)
        .onTapGesture {
            NotificationCenter.default.post(name: .userActivityRecorded, object: nil)
        }
        .onAppear {
            generate()
        }
        .onChange(of: length) { _ in generate() }
        .onChange(of: includeUppercase) { _ in generate() }
        .onChange(of: includeLowercase) { _ in generate() }
        .onChange(of: includeNumbers) { _ in generate() }
        .onChange(of: includeSymbols) { _ in generate() }
    }

    private func generate() {
        let options = PasswordGeneratorOptions(
            length: length,
            includeUppercase: includeUppercase,
            includeLowercase: includeLowercase,
            includeNumbers: includeNumbers,
            includeSymbols: includeSymbols
        )
        generatedPassword = PasswordGenerator.shared.generate(options: options)
    }

    private func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(generatedPassword, forType: .string)
    }
}
