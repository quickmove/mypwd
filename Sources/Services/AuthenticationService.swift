import Foundation
import LocalAuthentication

enum AuthenticationError: Error, LocalizedError {
    case biometryNotAvailable
    case biometryNotEnrolled
    case biometryLockout
    case failed
    case cancelled
    case systemCancel
    case passcodeNotSet

    var errorDescription: String? {
        switch self {
        case .biometryNotAvailable:
            return "Biometry not available"
        case .biometryNotEnrolled:
            return "Biometry not enrolled"
        case .biometryLockout:
            return "Biometry locked out"
        case .failed:
            return "Authentication failed"
        case .cancelled:
            return "User cancelled"
        case .systemCancel:
            return "System cancelled"
        case .passcodeNotSet:
            return "Passcode not set"
        }
    }
}

final class AuthenticationService {
    static let shared = AuthenticationService()

    private let context = LAContext()

    private init() {}

    var biometryType: LABiometryType {
        var error: NSError?
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        return context.biometryType
    }

    var isBiometryAvailable: Bool {
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    func authenticateWithBiometrics(reason: String) async throws {
        let context = LAContext()
        context.localizedCancelTitle = "Use Password"

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            if let error = error {
                throw mapLAError(error)
            }
            throw AuthenticationError.biometryNotAvailable
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            if !success {
                throw AuthenticationError.failed
            }
        } catch let error as LAError {
            throw mapLAError(error)
        }
    }

    func authenticateWithDeviceOwner(reason: String) async throws {
        let context = LAContext()

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            if let error = error {
                throw mapLAError(error)
            }
            throw AuthenticationError.biometryNotAvailable
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )
            if !success {
                throw AuthenticationError.failed
            }
        } catch let error as LAError {
            throw mapLAError(error)
        }
    }

    private func mapLAError(_ error: Error) -> AuthenticationError {
        guard let laError = error as? LAError else {
            return .failed
        }

        switch laError.code {
        case .biometryNotAvailable:
            return .biometryNotAvailable
        case .biometryNotEnrolled:
            return .biometryNotEnrolled
        case .biometryLockout:
            return .biometryLockout
        case .userCancel:
            return .cancelled
        case .systemCancel:
            return .systemCancel
        case .passcodeNotSet:
            return .passcodeNotSet
        default:
            return .failed
        }
    }
}
