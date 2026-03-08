import SwiftUI
import LocalAuthentication

struct BiometricLockScreen: View {
    let onUnlocked: () -> Void
    let onSignOut: () -> Void

    @State private var authFailed = false
    private let biometricService = BiometricService()

    var body: some View {
        ZStack {
            Color.bgBase.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 12) {
                    Image("AppLogoMark")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 72, height: 72)
                        .accessibilityHidden(true)

                    Text("SubTrkr")
                        .font(.system(.title, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundStyle(.textPrimary)
                }

                Spacer()

                VStack(spacing: 16) {
                    Button {
                        Task { await authenticate() }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "faceid")
                                .font(.title2)
                            Text("Unlock with Face ID")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(.brand)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)

                    if authFailed {
                        Text("Authentication failed. Try again or sign in.")
                            .font(.caption)
                            .foregroundStyle(.accentRed)
                    }

                    Button("Sign in with another account") {
                        onSignOut()
                    }
                    .font(.caption)
                    .foregroundStyle(.brand)
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)
                .padding(.bottom, 60)
            }
        }
        .task {
            await authenticate()
        }
    }

    private func authenticate() async {
        do {
            let success = try await biometricService.authenticate()
            if success {
                authFailed = false
                onUnlocked()
            } else {
                authFailed = true
            }
        } catch let error as LAError where error.code == .userCancel {
            // User tapped Cancel — don't show error, just stay on screen
        } catch {
            authFailed = true
        }
    }
}
