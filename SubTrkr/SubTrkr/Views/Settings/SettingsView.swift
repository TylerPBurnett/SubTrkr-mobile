import SwiftUI

struct SettingsView: View {
    @Environment(AuthService.self) private var authService
    @State private var viewModel = SettingsViewModel()
    @State private var showSignOutAlert = false
    @State private var showChangePassword = false
    @State private var showDeleteAlert = false
    @State private var deleteConfirmText = ""
    @State private var showDeleteConfirm = false
    @State private var accountError: String?
    @State private var accountSuccess: String?
    @AppStorage("appearanceMode") private var appearanceMode: String = "system"

    var body: some View {
        NavigationStack {
            List {
                // Appearance
                Section {
                    Picker(selection: $appearanceMode) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    } label: {
                        Label("Appearance", systemImage: "circle.lefthalf.filled")
                            .foregroundStyle(.textPrimary)
                    }
                } header: {
                    Text("Appearance")
                }

                // Account
                Section {
                    if let email = authService.currentUser?.email {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(.brand.opacity(0.15))
                                    .frame(width: 44, height: 44)
                                Text(String(email.prefix(1)).uppercased())
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundStyle(.brand)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(email)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.textPrimary)
                                    .lineLimit(1)
                                HStack(spacing: 4) {
                                    Image(systemName: authService.isEmailVerified ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                                        .font(.caption2)
                                    Text(authService.isEmailVerified ? "Verified" : "Not verified")
                                        .font(.caption)
                                }
                                .foregroundStyle(authService.isEmailVerified ? .brand : .statusPaused)
                            }
                        }
                    }

                    if authService.currentUser?.email != nil {
                        Button {
                            showChangePassword = true
                        } label: {
                            Label("Change Password", systemImage: "key.fill")
                                .foregroundStyle(.textPrimary)
                        }
                    }
                } header: {
                    Text("Account")
                }

                // Categories
                Section {
                    NavigationLink {
                        CategoryManagementView(viewModel: viewModel)
                    } label: {
                        Label("Categories", systemImage: "folder.fill")
                            .foregroundStyle(.textPrimary)
                    }
                } header: {
                    Text("Manage")
                }

                // Notifications
                Section {
                    NavigationLink {
                        NotificationSettingsView()
                    } label: {
                        Label("Notifications", systemImage: "bell.fill")
                            .foregroundStyle(.textPrimary)
                    }
                }

                // About
                Section {
                    HStack {
                        Label("Version", systemImage: "info.circle")
                            .foregroundStyle(.textPrimary)
                        Spacer()
                        Text("1.0.0")
                            .font(.subheadline)
                            .foregroundStyle(.textMuted)
                    }

                    HStack {
                        Label("Platform", systemImage: "iphone")
                            .foregroundStyle(.textPrimary)
                        Spacer()
                        Text("iOS")
                            .font(.subheadline)
                            .foregroundStyle(.textMuted)
                    }

                    Link(destination: URL(string: "https://subtrkr.app/privacy")!) {
                        Label("Privacy Policy", systemImage: "hand.raised.fill")
                            .foregroundStyle(.textPrimary)
                    }
                } header: {
                    Text("About")
                }

                // Actions
                Section {
                    if !authService.isEmailVerified {
                        Button {
                            Task { try? await authService.resendVerificationEmail() }
                        } label: {
                            Label("Resend Verification Email", systemImage: "envelope.badge")
                                .foregroundStyle(.brand)
                        }
                    }

                    Button {
                        showSignOutAlert = true
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                            .foregroundStyle(.accentRed)
                    }
                }

                // Danger Zone
                Section {
                    Button {
                        showDeleteAlert = true
                    } label: {
                        Label("Delete Account", systemImage: "trash.fill")
                            .foregroundStyle(.accentRed)
                    }
                } footer: {
                    Text("Permanently delete your account and all associated data.")
                }
            }
            .navigationTitle("Settings")
            .alert("Sign Out?", isPresented: $showSignOutAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Sign Out", role: .destructive) {
                    Task {
                        try? await authService.signOut()
                    }
                }
            } message: {
                Text("You'll need to sign in again to access your data.")
            }
            .sheet(isPresented: $showChangePassword) {
                ChangePasswordSheet(authService: authService)
            }
            .alert("Delete Account?", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Continue", role: .destructive) {
                    showDeleteConfirm = true
                }
            } message: {
                Text("This will permanently delete your account and all your data. This cannot be undone.")
            }
            .alert("Confirm Deletion", isPresented: $showDeleteConfirm) {
                TextField("Type DELETE to confirm", text: $deleteConfirmText)
                Button("Cancel", role: .cancel) {
                    deleteConfirmText = ""
                }
                Button("Delete Forever", role: .destructive) {
                    guard deleteConfirmText == "DELETE" else { return }
                    Task {
                        do {
                            try await authService.deleteAccount()
                        } catch {
                            accountError = error.localizedDescription
                        }
                    }
                    deleteConfirmText = ""
                }
            } message: {
                Text("Type DELETE to permanently remove your account.")
            }
        }
        .task {
            if let userId = authService.currentUser?.id.uuidString {
                await viewModel.seedDefaults(userId: userId)
            }
            await viewModel.loadData()
        }
    }
}

// MARK: - Category Management

struct CategoryManagementView: View {
    @Environment(AuthService.self) private var authService
    let viewModel: SettingsViewModel
    @State private var showAddCategory = false
    @State private var editingCategory: Category?

    var body: some View {
        List {
            // Subscription categories
            Section("Subscription Categories") {
                ForEach(viewModel.subscriptionCategories) { category in
                    CategoryRow(category: category)
                        .contentShape(Rectangle())
                        .onTapGesture { editingCategory = category }
                }
                .onDelete { indices in
                    Task {
                        for index in indices {
                            let category = viewModel.subscriptionCategories[index]
                            await viewModel.deleteCategory(category)
                        }
                    }
                }
            }

            // Bill categories
            Section("Bill Categories") {
                ForEach(viewModel.billCategories) { category in
                    CategoryRow(category: category)
                        .contentShape(Rectangle())
                        .onTapGesture { editingCategory = category }
                }
                .onDelete { indices in
                    Task {
                        for index in indices {
                            let category = viewModel.billCategories[index]
                            await viewModel.deleteCategory(category)
                        }
                    }
                }
            }
        }
        .navigationTitle("Categories")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAddCategory = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.brand)
                }
            }
        }
        .sheet(isPresented: $showAddCategory) {
            AddCategorySheet(viewModel: viewModel)
        }
        .sheet(item: $editingCategory) { category in
            EditCategorySheet(category: category, viewModel: viewModel)
        }
    }
}

struct CategoryRow: View {
    let category: Category

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(category.swiftColor)
                .frame(width: 14, height: 14)

            Text(category.name)
                .font(.subheadline)
                .foregroundStyle(.textPrimary)

            Spacer()

            if let type = category.itemType {
                Text(type.displayName)
                    .font(.caption)
                    .foregroundStyle(.textMuted)
            }
        }
    }
}

private let colorGridColumns = Array(repeating: GridItem(.flexible()), count: 6)

struct AddCategorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthService.self) private var authService
    let viewModel: SettingsViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    @Bindable var vm = viewModel
                    TextField("Category name", text: $vm.newCategoryName)
                }

                Section("Type") {
                    @Bindable var vm = viewModel
                    Picker("Type", selection: $vm.newCategoryType) {
                        Text("Subscription").tag(ItemType.subscription)
                        Text("Bill").tag(ItemType.bill)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Color") {
                    LazyVGrid(columns: colorGridColumns, spacing: 12) {
                        ForEach(Color.categoryColors, id: \.self) { colorHex in
                            Circle()
                                .fill(Color(hex: colorHex))
                                .frame(width: 36, height: 36)
                                .overlay {
                                    if viewModel.newCategoryColor == colorHex {
                                        Image(systemName: "checkmark")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                                .onTapGesture {
                                    viewModel.newCategoryColor = colorHex
                                }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("New Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.brand)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        Task {
                            guard let userId = authService.currentUser?.id.uuidString else { return }
                            await viewModel.createCategory(userId: userId)
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(.brand)
                    .disabled(viewModel.newCategoryName.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

struct EditCategorySheet: View {
    @Environment(\.dismiss) private var dismiss
    let category: Category
    let viewModel: SettingsViewModel

    @State private var name: String
    @State private var color: String

    init(category: Category, viewModel: SettingsViewModel) {
        self.category = category
        self.viewModel = viewModel
        _name = State(initialValue: category.name)
        _color = State(initialValue: category.color)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Category name", text: $name)
                }

                Section("Color") {
                    LazyVGrid(columns: colorGridColumns, spacing: 12) {
                        ForEach(Color.categoryColors, id: \.self) { colorHex in
                            Circle()
                                .fill(Color(hex: colorHex))
                                .frame(width: 36, height: 36)
                                .overlay {
                                    if color == colorHex {
                                        Image(systemName: "checkmark")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                                .onTapGesture { color = colorHex }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Edit Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.brand)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        Task {
                            var updated = category
                            updated.name = name
                            updated.color = color
                            await viewModel.updateCategory(updated)
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(.brand)
                    .disabled(name.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

struct ChangePasswordSheet: View {
    @Environment(\.dismiss) private var dismiss
    let authService: AuthService

    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var error: String?
    @State private var success = false

    var isValid: Bool {
        newPassword.count >= 6 && newPassword == confirmPassword
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("New Password", text: $newPassword)
                    SecureField("Confirm Password", text: $confirmPassword)
                } footer: {
                    if newPassword.count > 0 && newPassword.count < 6 {
                        Text("Password must be at least 6 characters")
                            .foregroundStyle(.accentRed)
                    } else if confirmPassword.count > 0 && newPassword != confirmPassword {
                        Text("Passwords don't match")
                            .foregroundStyle(.accentRed)
                    }
                }

                if let error {
                    Section {
                        Text(error)
                            .foregroundStyle(.accentRed)
                            .font(.caption)
                    }
                }

                if success {
                    Section {
                        Label("Password updated successfully", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.brand)
                    }
                }
            }
            .navigationTitle("Change Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(success ? "Done" : "Cancel") { dismiss() }
                        .foregroundStyle(.brand)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if !success {
                        Button("Save") {
                            Task {
                                isLoading = true
                                error = nil
                                do {
                                    try await authService.updatePassword(newPassword: newPassword)
                                    success = true
                                } catch {
                                    self.error = error.localizedDescription
                                }
                                isLoading = false
                            }
                        }
                        .fontWeight(.semibold)
                        .foregroundStyle(.brand)
                        .disabled(!isValid || isLoading)
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .sensoryFeedback(.success, trigger: success)
    }
}
