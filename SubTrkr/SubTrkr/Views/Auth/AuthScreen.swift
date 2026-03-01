import SwiftUI

struct AuthScreen: View {
    @Environment(AuthService.self) private var authService
    @State private var viewModel: AuthViewModel?

    var body: some View {
        Group {
            if let viewModel {
                authContent(viewModel)
            } else {
                ProgressView()
            }
        }
        .task {
            if viewModel == nil {
                viewModel = AuthViewModel(authService: authService)
            }
        }
    }

    @ViewBuilder
    private func authContent(_ vm: AuthViewModel) -> some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Logo & Title
                    VStack(spacing: 12) {
                        Image(systemName: "creditcard.fill")
                            .font(.system(.largeTitle))
                            .foregroundStyle(.brand)
                            .accessibilityHidden(true)

                        Text("SubTrkr")
                            .font(.system(.title, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundStyle(.textPrimary)

                        Text("Track your subscriptions & bills")
                            .font(.subheadline)
                            .foregroundStyle(.textSecondary)
                    }
                    .padding(.top, 40)

                    // Auth Mode Picker
                    @Bindable var bindableVM = vm
                    Picker("", selection: $bindableVM.mode) {
                        ForEach(AuthViewModel.AuthMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .onChange(of: vm.mode) { _, _ in
                        vm.errorMessage = nil
                        vm.successMessage = nil
                    }

                    switch vm.step {
                    case .credentials:
                        credentialsForm(vm)
                    case .otp:
                        otpForm(vm)
                    case .resetPassword:
                        resetPasswordForm(vm)
                    }
                }
                .padding()
            }
            .background(Color.bgBase)
            .scrollDismissesKeyboard(.interactively)
        }
    }

    @ViewBuilder
    private func credentialsForm(_ vm: AuthViewModel) -> some View {
        @Bindable var bindableVM = vm
        VStack(spacing: 20) {
            // Email & Password
            VStack(spacing: 14) {
                AuthTextField(
                    icon: "envelope.fill",
                    placeholder: "Email",
                    text: $bindableVM.email,
                    keyboardType: .emailAddress,
                    textContentType: .emailAddress
                )

                AuthTextField(
                    icon: "lock.fill",
                    placeholder: "Password",
                    text: $bindableVM.password,
                    isSecure: true,
                    textContentType: vm.mode == .signUp ? .newPassword : .password
                )

                // Password strength (sign up only)
                if vm.mode == .signUp && !vm.password.isEmpty {
                    PasswordStrengthBar(strength: vm.passwordStrength, label: vm.passwordStrengthLabel, color: vm.passwordStrengthColor)
                }
            }

            // Messages
            if let error = vm.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .accessibilityHidden(true)
                    Text(error)
                }
                .font(.caption)
                .foregroundStyle(.accentRed)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
            }

            if let success = vm.successMessage {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .accessibilityHidden(true)
                    Text(success)
                }
                .font(.caption)
                .foregroundStyle(.brand)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
            }

            // Primary Action
            Button {
                Task {
                    if vm.mode == .signIn {
                        await vm.signIn()
                    } else {
                        await vm.signUp()
                    }
                }
            } label: {
                HStack {
                    if vm.isLoading {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(vm.mode == .signIn ? "Sign In" : "Create Account")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(.brand)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(vm.isLoading)

            // Magic Link
            Button {
                Task { await vm.sendOTP() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "wand.and.stars")
                    Text("Sign in with Magic Link")
                }
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.bgSurface)
                .foregroundStyle(.textPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.borderDefault, lineWidth: 1)
                )
            }

            // Divider
            HStack {
                Rectangle().fill(Color.borderDefault).frame(height: 1)
                Text("or continue with")
                    .font(.caption)
                    .foregroundStyle(.textMuted)
                Rectangle().fill(Color.borderDefault).frame(height: 1)
            }

            // OAuth Buttons
            HStack(spacing: 12) {
                OAuthButton(icon: "g.circle.fill", label: "Google") {
                    Task { await vm.signInWithGoogle() }
                }
                OAuthButton(icon: "chevron.left.forwardslash.chevron.right", label: "GitHub") {
                    Task { await vm.signInWithGitHub() }
                }
            }

            // Forgot password
            if vm.mode == .signIn {
                Button {
                    vm.step = .resetPassword
                } label: {
                    Text("Forgot password?")
                        .font(.caption)
                        .foregroundStyle(.brand)
                }
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private func otpForm(_ vm: AuthViewModel) -> some View {
        VStack(spacing: 20) {
            Text("Enter the 6-digit code sent to")
                .font(.subheadline)
                .foregroundStyle(.textSecondary)
            Text(vm.email)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.textPrimary)

            @Bindable var bindableVM = vm
            AuthTextField(
                icon: "number",
                placeholder: "6-digit code",
                text: $bindableVM.otpCode,
                keyboardType: .numberPad,
                textContentType: .oneTimeCode
            )

            if let error = vm.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.accentRed)
            }

            Button {
                Task { await vm.verifyOTP() }
            } label: {
                HStack {
                    if vm.isLoading { ProgressView().tint(.white) }
                    Text("Verify Code")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(.brand)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(vm.isLoading)

            Button("Back") {
                vm.step = .credentials
                vm.otpCode = ""
                vm.errorMessage = nil
            }
            .font(.subheadline)
            .foregroundStyle(.brand)
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private func resetPasswordForm(_ vm: AuthViewModel) -> some View {
        VStack(spacing: 20) {
            Text("Enter your email to receive a password reset link")
                .font(.subheadline)
                .foregroundStyle(.textSecondary)
                .multilineTextAlignment(.center)

            @Bindable var bindableVM = vm
            AuthTextField(
                icon: "envelope.fill",
                placeholder: "Email",
                text: $bindableVM.email,
                keyboardType: .emailAddress,
                textContentType: .emailAddress
            )

            if let error = vm.errorMessage {
                Text(error).font(.caption).foregroundStyle(.accentRed)
            }
            if let success = vm.successMessage {
                Text(success).font(.caption).foregroundStyle(.brand)
            }

            Button {
                Task { await vm.resetPassword() }
            } label: {
                HStack {
                    if vm.isLoading { ProgressView().tint(.white) }
                    Text("Send Reset Link")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(.brand)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(vm.isLoading)

            Button("Back to Sign In") {
                vm.step = .credentials
                vm.errorMessage = nil
                vm.successMessage = nil
            }
            .font(.subheadline)
            .foregroundStyle(.brand)
        }
        .padding(.horizontal)
    }
}

// MARK: - Auth Text Field

struct AuthTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var isSecure: Bool = false
    var textContentType: UITextContentType? = nil

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.textMuted)
                .frame(width: 20)
                .accessibilityHidden(true)

            if isSecure {
                SecureField(placeholder, text: $text)
                    .textContentType(textContentType)
            } else {
                TextField(placeholder, text: $text)
                    .keyboardType(keyboardType)
                    .textContentType(textContentType)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
        }
        .padding()
        .background(Color.bgInput)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.borderStrong, lineWidth: 1.5)
        )
    }
}

// MARK: - Password Strength Bar

struct PasswordStrengthBar: View {
    let strength: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.borderMuted)
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(strength) / 6.0, height: 6)
                        .animation(.spring(duration: 0.3), value: strength)
                }
            }
            .frame(height: 6)

            Text(label)
                .font(.caption2)
                .foregroundStyle(color)
        }
    }
}

// MARK: - OAuth Button

struct OAuthButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(label)
                    .fontWeight(.medium)
            }
            .font(.subheadline)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.bgSurface)
            .foregroundStyle(.textPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.borderDefault, lineWidth: 1)
            )
        }
    }
}
