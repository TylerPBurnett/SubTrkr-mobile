import Foundation
import Supabase
import AuthenticationServices

@Observable
final class AuthService {
    private let client: SupabaseClient

    var currentUser: User?
    var currentSession: Session?
    var isAuthenticated: Bool { currentSession != nil }
    var isLoading = true

    init(client: SupabaseClient = SupabaseManager.shared.client) {
        self.client = client
    }

    // MARK: - Session Management

    func initialize() async {
        do {
            let session = try await client.auth.session
            self.currentSession = session
            self.currentUser = session.user
        } catch {
            self.currentSession = nil
            self.currentUser = nil
        }
        self.isLoading = false
    }

    func observeAuthChanges() async {
        for await (event, session) in client.auth.authStateChanges {
            await MainActor.run {
                self.currentSession = session
                self.currentUser = session?.user
                if event == .signedOut {
                    self.currentSession = nil
                    self.currentUser = nil
                }
            }
        }
    }

    // MARK: - Email/Password

    func signUp(email: String, password: String) async throws {
        let response = try await client.auth.signUp(
            email: email,
            password: password,
            redirectTo: URL(string: "subtrkr://auth-callback")
        )
        self.currentSession = response.session
        self.currentUser = response.user
    }

    func signIn(email: String, password: String) async throws {
        let session = try await client.auth.signIn(
            email: email,
            password: password
        )
        self.currentSession = session
        self.currentUser = session.user
    }

    // MARK: - Magic Link / OTP

    func signInWithOTP(email: String) async throws {
        try await client.auth.signInWithOTP(email: email)
    }

    func verifyOTP(email: String, token: String) async throws {
        let response = try await client.auth.verifyOTP(
            email: email,
            token: token,
            type: .email
        )
        self.currentSession = response.session
        self.currentUser = response.user
    }

    // MARK: - OAuth

    func signInWithGoogle() async throws {
        let url = try await client.auth.getOAuthSignInURL(
            provider: .google,
            redirectTo: URL(string: "subtrkr://auth-callback")
        )
        await openOAuthURL(url)
    }

    func signInWithGitHub() async throws {
        let url = try await client.auth.getOAuthSignInURL(
            provider: .github,
            redirectTo: URL(string: "subtrkr://auth-callback")
        )
        await openOAuthURL(url)
    }

    func handleOAuthCallback(url: URL) async throws {
        let session = try await client.auth.session(from: url)
        self.currentSession = session
        self.currentUser = session.user
    }

    @MainActor
    private func openOAuthURL(_ url: URL) {
        UIApplication.shared.open(url)
    }

    // MARK: - Password Reset

    func resetPassword(email: String) async throws {
        try await client.auth.resetPasswordForEmail(
            email,
            redirectTo: URL(string: "subtrkr://auth-callback")
        )
    }

    // MARK: - Sign Out

    func signOut() async throws {
        try await client.auth.signOut()
        self.currentSession = nil
        self.currentUser = nil
    }

    // MARK: - Email Verification

    func resendVerificationEmail() async throws {
        guard let email = currentUser?.email else { return }
        try await client.auth.resend(email: email, type: .signup)
    }

    var isEmailVerified: Bool {
        currentUser?.emailConfirmedAt != nil
    }
}
