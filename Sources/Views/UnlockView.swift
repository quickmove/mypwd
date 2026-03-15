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

            Text(LocalizedStrings.unlockPasswordVault)
                .font(.title)
                .fontWeight(.semibold)

            VStack(spacing: 16) {
                if authService.isBiometryAvailable {
                    Button(action: unlockWithBiometrics) {
                        HStack {
                            Image(systemName: biometryIcon)
                                .font(.title2)
                            VStack(alignment: .leading) {
                                Text(biometryDisplayName)
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
                    Text(LocalizedStrings.touchIDNotAvailable)
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

    private var biometryDisplayName: String {
        switch authService.biometryType {
        case .touchID:
            return LocalizedStrings.unlockWithTouchID
        case .faceID:
            return LocalizedStrings.unlockWithFaceID
        default:
            return LocalizedStrings.unlockWithBiometrics
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
