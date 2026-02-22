import SwiftUI

struct ItemFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthService.self) private var authService

    @State private var viewModel: ItemFormViewModel
    var onSave: (() async -> Void)?

    init(itemType: ItemType, editingItem: Item? = nil, onSave: (() async -> Void)? = nil) {
        _viewModel = State(initialValue: ItemFormViewModel(itemType: itemType, editingItem: editingItem))
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                // Service Search (only for new items)
                if !viewModel.isEditing {
                    serviceSearchSection
                }

                basicInfoSection
                billingSection
                categorySection

                if viewModel.status == .trial {
                    trialSection
                }

                additionalSection
            }
            .navigationTitle(viewModel.isEditing ? "Edit \(viewModel.itemType.displayName)" : "New \(viewModel.itemType.displayName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.brand)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        Task {
                            guard let userId = authService.currentUser?.id.uuidString else { return }
                            await viewModel.save(userId: userId)
                        }
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(.brand)
                    .disabled(!viewModel.isValid || viewModel.isLoading)
                }
            }
            .alert("Error", isPresented: .init(
                get: { viewModel.error != nil },
                set: { if !$0 { viewModel.error = nil } }
            )) {
                Button("OK") { viewModel.error = nil }
            } message: {
                Text(viewModel.error ?? "")
            }
            .onChange(of: viewModel.isSaved) { _, saved in
                if saved {
                    Task {
                        await onSave?()
                        dismiss()
                    }
                }
            }
        }
        .task {
            await viewModel.loadCategories()
        }
        .presentationDetents([.large])
    }

    // MARK: - Service Search

    private var serviceSearchSection: some View {
        Section("Search Services") {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.textTertiary)
                TextField("Search for a service...", text: Binding(
                    get: { viewModel.serviceSearchText },
                    set: {
                        viewModel.serviceSearchText = $0
                        viewModel.showServiceSuggestions = !$0.isEmpty
                    }
                ))
                .textInputAutocapitalization(.never)
            }

            if viewModel.showServiceSuggestions && !viewModel.serviceSuggestions.isEmpty {
                ForEach(viewModel.serviceSuggestions.prefix(5)) { service in
                    Button {
                        viewModel.selectService(service)
                    } label: {
                        HStack(spacing: 12) {
                            ServiceLogo(
                                url: URL(string: service.logoUrl),
                                name: service.name,
                                categoryColor: "#6366f1",
                                size: 32
                            )
                            VStack(alignment: .leading) {
                                Text(service.name)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.textPrimary)
                                Text("\(service.defaultPrice.formatted(currency: service.currency)) / \(service.billingCycle.displayName.lowercased())")
                                    .font(.caption)
                                    .foregroundStyle(.textSecondary)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Basic Info

    private var basicInfoSection: some View {
        Section("Details") {
            HStack {
                Image(systemName: "tag.fill")
                    .foregroundStyle(.brand)
                    .frame(width: 24)
                TextField("Name", text: Binding(
                    get: { viewModel.name },
                    set: { viewModel.name = $0 }
                ))
            }

            HStack {
                Image(systemName: "dollarsign.circle.fill")
                    .foregroundStyle(.brand)
                    .frame(width: 24)
                TextField("Amount", value: Binding(
                    get: { viewModel.amount },
                    set: { viewModel.amount = $0 }
                ), format: .number.precision(.fractionLength(2)))
                .keyboardType(.decimalPad)
            }

            if !viewModel.isEditing {
                Picker(selection: Binding(
                    get: { viewModel.status },
                    set: { viewModel.status = $0 }
                )) {
                    Text("Active").tag(ItemStatus.active)
                    Text("Trial").tag(ItemStatus.trial)
                } label: {
                    HStack {
                        Image(systemName: "circle.dotted")
                            .foregroundStyle(.brand)
                            .frame(width: 24)
                        Text("Status")
                    }
                }
            }
        }
    }

    // MARK: - Billing

    private var billingSection: some View {
        Section("Billing") {
            Picker(selection: Binding(
                get: { viewModel.billingCycle },
                set: { viewModel.billingCycle = $0 }
            )) {
                ForEach(BillingCycle.allCases) { cycle in
                    Text(cycle.displayName).tag(cycle)
                }
            } label: {
                HStack {
                    Image(systemName: "repeat")
                        .foregroundStyle(.brand)
                        .frame(width: 24)
                    Text("Billing Cycle")
                }
            }

            DatePicker(selection: Binding(
                get: { viewModel.startDate },
                set: { viewModel.startDate = $0 }
            ), displayedComponents: .date) {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundStyle(.brand)
                        .frame(width: 24)
                    Text("Start Date")
                }
            }

            DatePicker(selection: Binding(
                get: { viewModel.nextBillingDate },
                set: { viewModel.nextBillingDate = $0 }
            ), displayedComponents: .date) {
                HStack {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundStyle(.brand)
                        .frame(width: 24)
                    Text("Next Billing Date")
                }
            }
        }
    }

    // MARK: - Category

    private var categorySection: some View {
        Section("Category") {
            Picker(selection: Binding(
                get: { viewModel.categoryId ?? "" },
                set: { viewModel.categoryId = $0.isEmpty ? nil : $0 }
            )) {
                Text("None").tag("")
                ForEach(viewModel.relevantCategories) { category in
                    HStack {
                        Circle()
                            .fill(category.swiftColor)
                            .frame(width: 8, height: 8)
                        Text(category.name)
                    }
                    .tag(category.id)
                }
            } label: {
                HStack {
                    Image(systemName: "folder.fill")
                        .foregroundStyle(.brand)
                        .frame(width: 24)
                    Text("Category")
                }
            }
        }
    }

    // MARK: - Trial

    private var trialSection: some View {
        Section("Trial") {
            DatePicker(selection: Binding(
                get: { viewModel.trialEndDate ?? Date.now.addingTimeInterval(30 * 86400) },
                set: { viewModel.trialEndDate = $0 }
            ), displayedComponents: .date) {
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundStyle(.statusTrial)
                        .frame(width: 24)
                    Text("Trial End Date")
                }
            }
        }
    }

    // MARK: - Additional

    private var additionalSection: some View {
        Section("Additional") {
            HStack {
                Image(systemName: "link")
                    .foregroundStyle(.brand)
                    .frame(width: 24)
                TextField("Website URL", text: Binding(
                    get: { viewModel.url },
                    set: { viewModel.url = $0 }
                ))
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
            }

            HStack(alignment: .top) {
                Image(systemName: "note.text")
                    .foregroundStyle(.brand)
                    .frame(width: 24)
                    .padding(.top, 4)
                TextField("Notes", text: Binding(
                    get: { viewModel.notes },
                    set: { viewModel.notes = $0 }
                ), axis: .vertical)
                .lineLimit(3...6)
            }

            Picker(selection: Binding(
                get: { viewModel.reminderDays ?? 0 },
                set: { viewModel.reminderDays = $0 == 0 ? nil : $0 }
            )) {
                Text("No reminder").tag(0)
                Text("1 day before").tag(1)
                Text("3 days before").tag(3)
                Text("7 days before").tag(7)
                Text("14 days before").tag(14)
                Text("30 days before").tag(30)
            } label: {
                HStack {
                    Image(systemName: "bell.fill")
                        .foregroundStyle(.brand)
                        .frame(width: 24)
                    Text("Reminder")
                }
            }
        }
    }
}
