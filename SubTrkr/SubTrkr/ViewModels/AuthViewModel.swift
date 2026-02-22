import Foundation
import SwiftUI

@Observable
final class AuthViewModel {
    enum AuthMode: String, CaseIterable {
        case signIn = "Sign In"
        case signUp = "Sign Up"
    }

    enum AuthStep {
        case credentials
        case otp
        case resetPassword
    }

    let authService: AuthService

    var mode: AuthMode = .signIn
    var step: AuthStep = .credentials
    var email = ""
    var password = ""
    var otpCode = ""

    var isLoading = false
    var errorMessage: String?
    var successMessage: String?

    // Password strength
    var passwordStrength: Int {
        var score = 0
        if password.count >= 8 { score += 1 }
        if password.count >= 12 { score += 1 }
        if password.rangeOfCharacter(from: .lowercaseLetters) != nil { score += 1 }
        if password.rangeOfCharacter(from: .uppercaseLetters) != nil { score += 1 }
        if password.rangeOfCharacter(from: .decimalDigits) != nil { score += 1 }
        if password.rangeOfCharacter(from: CharacterSet(charactersIn: "!@#$%^&*()_+-=[]{}|;:',.<>?/`~")) != nil { score += 1 }
        return score
    }

    var passwordStrengthLabel: String {
        switch passwordStrength {
        case 0...1: return "Weak"
        case 2...3: return "Fair"
        case 4...5: return "Strong"
        case 6: return "Very Strong"
        default: return ""
        }
    }

    var passwordStrengthColor: Color {
        switch passwordStrength {
        case 0...1: return .red
        case 2...3: return .orange
        case 4...5: return .brand
        case 6: return .brand
        default: return .gray
        }
    }

    init(authService: AuthService) {
        self.authService = authService
    }

    var isAuthenticated: Bool { authService.isAuthenticated }
    var isAuthLoading: Bool { authService.isLoading }

    // MARK: - Actions

    func signIn() async {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please fill in all fields"
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            try await authService.signIn(email: email, password: password)
        } catch {
            errorMessage = friendlyError(error)
        }
        isLoading = false
    }

    func signUp() async {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please fill in all fields"
            return
        }
        guard passwordStrength >= 2 else {
            errorMessage = "Please use a stronger password"
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            try await authService.signUp(email: email, password: password)
            successMessage = "Check your email to verify your account"
        } catch {
            errorMessage = friendlyError(error)
        }
        isLoading = false
    }

    func sendOTP() async {
        guard !email.isEmpty else {
            errorMessage = "Please enter your email"
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            try await authService.signInWithOTP(email: email)
            step = .otp
            successMessage = "Check your email for a 6-digit code"
        } catch {
            errorMessage = friendlyError(error)
        }
        isLoading = false
    }

    func verifyOTP() async {
        guard !otpCode.isEmpty else {
            errorMessage = "Please enter the verification code"
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            try await authService.verifyOTP(email: email, token: otpCode)
        } catch {
            errorMessage = friendlyError(error)
        }
        isLoading = false
    }

    func signInWithGoogle() async {
        isLoading = true
        errorMessage = nil
        do {
            try await authService.signInWithGoogle()
        } catch {
            errorMessage = friendlyError(error)
        }
        isLoading = false
    }

    func signInWithGitHub() async {
        isLoading = true
        errorMessage = nil
        do {
            try await authService.signInWithGitHub()
        } catch {
            errorMessage = friendlyError(error)
        }
        isLoading = false
    }

    func resetPassword() async {
        guard !email.isEmpty else {
            errorMessage = "Please enter your email"
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            try await authService.resetPassword(email: email)
            successMessage = "Password reset email sent"
            step = .credentials
        } catch {
            errorMessage = friendlyError(error)
        }
        isLoading = false
    }

    func signOut() async {
        do {
            try await authService.signOut()
        } catch {
            errorMessage = friendlyError(error)
        }
    }

    // MARK: - Helpers

    private func friendlyError(_ error: Error) -> String {
        let message = error.localizedDescription.lowercased()
        if message.contains("invalid login") || message.contains("invalid credentials") {
            return "Invalid email or password"
        }
        if message.contains("rate limit") || message.contains("too many") {
            return "Too many attempts. Please wait a moment."
        }
        if message.contains("weak password") {
            return "Password is too weak. Use at least 8 characters with mixed types."
        }
        if message.contains("already registered") || message.contains("already exists") {
            return "An account with this email already exists"
        }
        if message.contains("email not confirmed") {
            return "Please verify your email before signing in"
        }
        return error.localizedDescription
    }

    func reset() {
        email = ""
        password = ""
        otpCode = ""
        errorMessage = nil
        successMessage = nil
        step = .credentials
    }
}
