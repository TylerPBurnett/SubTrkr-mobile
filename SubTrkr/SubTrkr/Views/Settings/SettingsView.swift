import SwiftUI

struct SettingsView: View {
    @Environment(AuthService.self) private var authService
    @State private var viewModel = SettingsViewModel()
    @State private var showSignOutAlert = false

    var body: some View {
        NavigationStack {
            List {
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
                            .foregroundStyle(.textTertiary)
                    }

                    HStack {
                        Label("Platform", systemImage: "iphone")
                            .foregroundStyle(.textPrimary)
                        Spacer()
                        Text("iOS")
                            .font(.subheadline)
                            .foregroundStyle(.textTertiary)
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
                            .foregroundStyle(.red)
                    }
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

    var body: some View {
        List {
            // Subscription categories
            Section("Subscription Categories") {
                ForEach(viewModel.subscriptionCategories) { category in
                    CategoryRow(category: category)
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
                    .foregroundStyle(.textTertiary)
            }
        }
    }
}

struct AddCategorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthService.self) private var authService
    let viewModel: SettingsViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Category name", text: Binding(
                        get: { viewModel.newCategoryName },
                        set: { viewModel.newCategoryName = $0 }
                    ))
                }

                Section("Type") {
                    Picker("Type", selection: Binding(
                        get: { viewModel.newCategoryType },
                        set: { viewModel.newCategoryType = $0 }
                    )) {
                        Text("Subscription").tag(ItemType.subscription)
                        Text("Bill").tag(ItemType.bill)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
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
