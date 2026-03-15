import SwiftUI

struct UnlockView: View {
    @EnvironmentObject var appState: AppState

    @State private var errorMessage: String?
    @State private var isLoading = false

    private let authService = AuthenticationService.shared

    var body: some View {
        VStack(spacing: 32) {
            Image(systemName: "lock.open")
                .font(.system(size: 64))
                .foregroundStyle(.blue)

            Text("Unlock Password Vault")
                .font(.title)
                .fontWeight(.semibold)

            VStack(spacing: 16) {
                if authService.isBiometryAvailable {
                    Button(action: unlockWithBiometrics) {
                        HStack {
                            Image(systemName: biometryIcon)
                                .font(.title2)
                            VStack(alignment: .leading) {
                                Text("Unlock with \(biometryName)")
                                    .font(.headline)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                        .frame(width: 280, height: 60)
                        .padding(.horizontal, 16)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                } else {
                    Text("TouchID not available")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(40)
        .onTapGesture {
            NotificationCenter.default.post(name: .userActivityRecorded, object: nil)
        }
    }

    private var biometryIcon: String {
        switch authService.biometryType {
        case .touchID:
            return "touchid"
        case .faceID:
            return "faceid"
        default:
            return "key"
        }
    }

    private var biometryName: String {
        switch authService.biometryType {
        case .touchID:
            return "Touch ID"
        case .faceID:
            return "Face ID"
        default:
            return "Biometrics"
        }
    }

    private func unlockWithBiometrics() {
        Task {
            do {
                try await appState.unlockWithBiometrics()
            } catch AuthenticationError.cancelled {
                // User cancelled
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
