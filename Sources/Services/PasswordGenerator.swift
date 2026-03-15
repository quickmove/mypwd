import Foundation

struct PasswordGeneratorOptions {
    var length: Int = 16
    var includeUppercase: Bool = true
    var includeLowercase: Bool = true
    var includeNumbers: Bool = true
    var includeSymbols: Bool = true

    var characterSet: String {
        var chars = ""
        if includeLowercase { chars += "abcdefghijklmnopqrstuvwxyz" }
        if includeUppercase { chars += "ABCDEFGHIJKLMNOPQRSTUVWXYZ" }
        if includeNumbers { chars += "0123456789" }
        if includeSymbols { chars += "!@#$%^&*()_+-=[]{}|;:,.<>?" }
        return chars
    }
}

final class PasswordGenerator {
    static let shared = PasswordGenerator()

    private init() {}

    func generate(options: PasswordGeneratorOptions = PasswordGeneratorOptions()) -> String {
        let chars = options.characterSet
        guard !chars.isEmpty, options.length > 0 else {
            return ""
        }

        var password = ""
        var randomBytes = [UInt8](repeating: 0, count: options.length)

        let status = randomBytes.withUnsafeMutableBytes { buffer in
            SecRandomCopyBytes(kSecRandomDefault, options.length, buffer.baseAddress!)
        }

        guard status == errSecSuccess else {
            return generateFallback(options: options)
        }

        for byte in randomBytes {
            let index = Int(byte) % chars.count
            let charIndex = chars.index(chars.startIndex, offsetBy: index)
            password.append(chars[charIndex])
        }

        return password
    }

    private func generateFallback(options: PasswordGeneratorOptions) -> String {
        let chars = options.characterSet
        var password = ""

        for _ in 0..<options.length {
            if let randomInt = try? SecRandomCopyBytes(kSecRandomDefault, 1, UnsafeMutablePointer<UInt8>.allocate(capacity: 1)) {
                let index = Int(randomInt) % chars.count
                let charIndex = chars.index(chars.startIndex, offsetBy: index)
                password.append(chars[charIndex])
            }
        }

        return password
    }

    func calculateStrength(_ password: String) -> PasswordStrength {
        guard !password.isEmpty else { return .veryWeak }

        var score = 0

        if password.count >= 8 { score += 1 }
        if password.count >= 12 { score += 1 }
        if password.count >= 16 { score += 1 }

        let hasLowercase = password.range(of: "[a-z]", options: .regularExpression) != nil
        let hasUppercase = password.range(of: "[A-Z]", options: .regularExpression) != nil
        let hasNumbers = password.range(of: "[0-9]", options: .regularExpression) != nil
        let hasSymbols = password.range(of: "[^a-zA-Z0-9]", options: .regularExpression) != nil

        if hasLowercase { score += 1 }
        if hasUppercase { score += 1 }
        if hasNumbers { score += 1 }
        if hasSymbols { score += 1 }

        switch score {
        case 0...2: return .veryWeak
        case 3: return .weak
        case 4...5: return .medium
        case 6...7: return .strong
        default: return .veryStrong
        }
    }
}

enum PasswordStrength: String, CaseIterable {
    case veryWeak = "非常弱"
    case weak = "弱"
    case medium = "中等"
    case strong = "强"
    case veryStrong = "非常强"

    var color: String {
        switch self {
        case .veryWeak: return "red"
        case .weak: return "orange"
        case .medium: return "yellow"
        case .strong: return "green"
        case .veryStrong: return "blue"
        }
    }
}
