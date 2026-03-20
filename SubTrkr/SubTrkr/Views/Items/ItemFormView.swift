import SwiftUI

struct ItemFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthService.self) private var authService

    @State private var viewModel: ItemFormViewModel
    @State private var showDiscardConfirmation = false
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
                    Button("Cancel", action: handleCancelTapped)
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
            .confirmationDialog("Discard changes?", isPresented: $showDiscardConfirmation, titleVisibility: .visible) {
                Button("Discard Changes", role: .destructive, action: discardChanges)
                Button("Keep Editing", role: .cancel) {}
            } message: {
                Text("Your unsaved changes will be lost.")
            }
            .onChange(of: viewModel.isSaved) { _, saved in
                if saved {
                    Task {
                        await onSave?()
                        dismiss()
                    }
                }
            }
            .sensoryFeedback(.success, trigger: viewModel.isSaved)
        }
        .task {
            await viewModel.loadCategories()
        }
        .presentationDetents([.large])
        .interactiveDismissDisabled(viewModel.isDirty)
    }

    private func handleCancelTapped() {
        if viewModel.isDirty {
            showDiscardConfirmation = true
        } else {
            dismiss()
        }
    }

    private func discardChanges() {
        dismiss()
    }

    // MARK: - Service Search

    private var serviceSearchSection: some View {
        @Bindable var vm = viewModel
        return Section("Search Services") {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.textMuted)
                    .accessibilityHidden(true)
                TextField("Search for a service...", text: $vm.serviceSearchText)
                    .textInputAutocapitalization(.never)
                    .onChange(of: viewModel.serviceSearchText) { _, newValue in
                        viewModel.showServiceSuggestions = !newValue.isEmpty
                    }
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
        @Bindable var vm = viewModel
        return Section("Details") {
            HStack {
                Image(systemName: "tag.fill")
                    .foregroundStyle(.brand)
                    .frame(width: 24)
                    .accessibilityHidden(true)
                TextField("Name", text: $vm.name)
            }

            HStack {
                Image(systemName: "dollarsign.circle.fill")
                    .foregroundStyle(.brand)
                    .frame(width: 24)
                    .accessibilityHidden(true)
                TextField("Amount", value: $vm.amount, format: .number.precision(.fractionLength(2)))
                    .keyboardType(.decimalPad)
            }

            if !viewModel.isEditing {
                Picker(selection: $vm.status) {
                    Text("Active").tag(ItemStatus.active)
                    Text("Trial").tag(ItemStatus.trial)
                } label: {
                    HStack {
                        Image(systemName: "circle.dotted")
                            .foregroundStyle(.brand)
                            .frame(width: 24)
                            .accessibilityHidden(true)
                        Text("Status")
                    }
                }
            }
        }
    }

    // MARK: - Billing

    private var billingSection: some View {
        @Bindable var vm = viewModel
        return Section("Billing") {
            Picker(selection: $vm.billingCycle) {
                ForEach(BillingCycle.allCases) { cycle in
                    Text(cycle.displayName).tag(cycle)
                }
            } label: {
                HStack {
                    Image(systemName: "repeat")
                        .foregroundStyle(.brand)
                        .frame(width: 24)
                        .accessibilityHidden(true)
                    Text("Billing Cycle")
                }
            }
            .onChange(of: viewModel.billingCycle) { _, _ in
                viewModel.autoCalcNextBillingDate()
            }

            DatePicker(selection: $vm.startDate, displayedComponents: .date) {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundStyle(.brand)
                        .frame(width: 24)
                        .accessibilityHidden(true)
                    Text("Start Date")
                }
            }
            .onChange(of: viewModel.startDate) { _, _ in
                viewModel.autoCalcNextBillingDate()
            }

            DatePicker(selection: $vm.nextBillingDate, displayedComponents: .date) {
                HStack {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundStyle(.brand)
                        .frame(width: 24)
                        .accessibilityHidden(true)
                    Text("Next Billing Date")
                }
            }
            .onChange(of: viewModel.nextBillingDate) { _, _ in
                if !viewModel.isAutoUpdatingNextBillingDate {
                    viewModel.userEditedNextBillingDate = true
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
                        .accessibilityHidden(true)
                    Text("Category")
                }
            }
        }
    }
    // Note: categorySection keeps Binding(get:set:) because it maps Optional<String> to non-optional String for the Picker tag type.

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
                        .accessibilityHidden(true)
                    Text("Trial End Date")
                }
            }
        }
    }
    // Note: trialSection keeps Binding(get:set:) because it maps Optional<Date> to non-optional Date with a fallback default.

    // MARK: - Additional

    private var additionalSection: some View {
        @Bindable var vm = viewModel
        return Section("Additional") {
            HStack {
                Image(systemName: "link")
                    .foregroundStyle(.brand)
                    .frame(width: 24)
                    .accessibilityHidden(true)
                TextField("Website URL", text: $vm.url)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
            }

            HStack(alignment: .top) {
                Image(systemName: "note.text")
                    .foregroundStyle(.brand)
                    .frame(width: 24)
                    .padding(.top, 4)
                    .accessibilityHidden(true)
                TextField("Notes", text: $vm.notes, axis: .vertical)
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
                        .accessibilityHidden(true)
                    Text("Reminder")
                }
            }
        }
    }
    // Note: reminderDays Picker keeps Binding(get:set:) because it maps Optional<Int> to non-optional Int.
}
