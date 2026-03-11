import SwiftUI

struct ItemDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthService.self) private var authService

    let item: Item
    var onUpdate: (() async -> Void)?

    @State private var showEditForm = false
    @State private var showStatusSheet = false
    @State private var currentItem: Item
    @State private var payments: [Payment] = []
    @State private var statusHistory: [StatusHistory] = []
    @State private var showPaymentSheet = false
    @State private var paymentAmount: Double = 0
    @State private var paymentDate = Date.now
    @State private var isRecordingPayment = false
    @State private var paymentRecorded = false
    @State private var itemService = ItemService()
    @State private var paymentService = PaymentService()

    init(item: Item, onUpdate: (() async -> Void)? = nil) {
        self.item = item
        self.onUpdate = onUpdate
        _currentItem = State(initialValue: item)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerSection
                    detailsSection
                    statusSection
                    notesSection
                    paymentHistorySection
                    statusHistorySection
                }
                .padding()
            }
            .background(Color.bgBase)
            .navigationTitle(currentItem.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { showEditForm = true } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        if canLogPayment {
                            Button(action: presentPaymentSheet) {
                                Label("Log Payment", systemImage: "plus.circle")
                            }
                        }
                        Button { showStatusSheet = true } label: {
                            Label("Change Status", systemImage: "arrow.triangle.2.circlepath")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(.brand)
                    }
                    .accessibilityLabel("More options")
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.brand)
                }
            }
            .sheet(isPresented: $showEditForm) {
                ItemFormView(
                    itemType: currentItem.itemType,
                    editingItem: currentItem,
                    onSave: {
                        await refreshItem()
                        await onUpdate?()
                    }
                )
            }
            .sheet(isPresented: $showStatusSheet) {
                StatusChangeSheet(
                    item: currentItem,
                    onStatusChanged: {
                        await refreshItem()
                        await onUpdate?()
                    }
                )
            }
            .sheet(isPresented: $showPaymentSheet) {
                NavigationStack {
                    Form {
                        Section("Payment Details") {
                            HStack {
                                Image(systemName: "dollarsign.circle.fill")
                                    .foregroundStyle(.brand)
                                    .frame(width: 24)
                                    .accessibilityHidden(true)
                                TextField("Amount", value: $paymentAmount, format: .number.precision(.fractionLength(2)))
                                    .keyboardType(.decimalPad)
                            }

                            DatePicker(selection: $paymentDate, displayedComponents: .date) {
                                HStack {
                                    Image(systemName: "calendar")
                                        .foregroundStyle(.brand)
                                        .frame(width: 24)
                                        .accessibilityHidden(true)
                                    Text("Date")
                                }
                            }
                        }
                    }
                    .navigationTitle("Log Payment")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Cancel") { showPaymentSheet = false }
                                .foregroundStyle(.brand)
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Save") {
                                Task { await recordPayment() }
                            }
                            .fontWeight(.semibold)
                            .foregroundStyle(.brand)
                            .disabled(paymentAmount <= 0 || isRecordingPayment)
                        }
                    }
                }
                .presentationDetents([.medium])
            }
        }
        .sensoryFeedback(.success, trigger: paymentRecorded)
        .task {
            await loadPayments()
            await loadStatusHistory()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 16) {
            ServiceLogo(
                url: currentItem.logoURL,
                name: currentItem.name,
                categoryColor: currentItem.categoryColor,
                size: 72
            )

            VStack(spacing: 4) {
                Text(currentItem.amount.formatted(currency: currentItem.currency))
                    .font(.system(.title, design: .monospaced))
                    .fontWeight(.heavy)
                    .foregroundStyle(.textPrimary)

                Text(currentItem.billingCycle.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.textSecondary)
            }

            StatusBadge(status: currentItem.status)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - Details

    private var detailsSection: some View {
        VStack(spacing: 0) {
            DetailRow(label: "Category", value: currentItem.categoryName, color: Color(hex: currentItem.categoryColor))
            Divider().padding(.leading)
            DetailRow(label: "Monthly Cost", value: currentItem.monthlyAmount.formatted(currency: currentItem.currency))
            Divider().padding(.leading)
            DetailRow(label: "Yearly Cost", value: currentItem.yearlyAmount.formatted(currency: currentItem.currency))
            Divider().padding(.leading)

            if let date = currentItem.nextBillingDateFormatted {
                DetailRow(label: "Next Billing", value: DateHelper.relativeDateString(date))
                Divider().padding(.leading)
            }

            if let startDate = currentItem.startDate, let date = DateHelper.parseDate(startDate) {
                DetailRow(label: "Start Date", value: DateHelper.formatMediumDate(date))
            }

            if currentItem.status == .trial, let trialEnd = currentItem.trialEndDateFormatted {
                Divider().padding(.leading)
                DetailRow(
                    label: "Trial Ends",
                    value: DateHelper.relativeDateString(trialEnd),
                    valueColor: (currentItem.daysUntilTrialEnds ?? 0) <= 3 ? .statusCancelled : nil
                )
            }

            if currentItem.status == .paused, let date = currentItem.pausedUntilFormatted {
                Divider().padding(.leading)
                DetailRow(label: "Resumes", value: DateHelper.relativeDateString(date))
            }

            if currentItem.status == .cancelled, let date = currentItem.cancellationDateFormatted {
                Divider().padding(.leading)
                DetailRow(label: "Cancellation Date", value: DateHelper.formatMediumDate(date))
            }

            if let url = currentItem.url, !url.isEmpty {
                Divider().padding(.leading)
                DetailRow(label: "Website", value: url, isLink: true)
            }
        }
        .cardStyle(cornerRadius: 14)
    }

    // MARK: - Status Actions

    private var statusSection: some View {
        VStack(spacing: 10) {
            Text("Quick Actions")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 10) {
                ForEach(currentItem.status.availableActions, id: \.self) { action in
                    Button {
                        showStatusSheet = true
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: StatusActionHelper.icon(for: action))
                                .font(.system(.body))
                                .accessibilityHidden(true)
                            Text(StatusActionHelper.label(for: action))
                                .font(.caption2.weight(.medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundStyle(StatusActionHelper.color(for: action))
                        .cardStyle(cornerRadius: 12)
                    }
                }
            }
        }
    }

    // MARK: - Notes

    @ViewBuilder
    private var notesSection: some View {
        if let notes = currentItem.notes, !notes.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Notes")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.textSecondary)

                Text(notes)
                    .font(.subheadline)
                    .foregroundStyle(.textPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .cardStyle(cornerRadius: 14)
        }
    }

    // MARK: - Payment History

    private var paymentHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Payment History")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if payments.isEmpty {
                VStack(spacing: 4) {
                    Text("No confirmed payments logged")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.textSecondary)
                    Text("Recurring charges are tracked automatically while this item is active.")
                        .font(.caption)
                        .foregroundStyle(.textMuted)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
            } else {
                ForEach(payments.prefix(10)) { payment in
                    HStack {
                        if let date = payment.paidDateFormatted {
                            Text(DateHelper.formatMediumDate(date))
                            .font(.subheadline)
                            .foregroundStyle(.textSecondary)
                        }
                        Spacer()
                        Text(payment.amount.formatted(currency: currentItem.currency))
                            .font(.system(.subheadline, design: .monospaced))
                            .fontWeight(.medium)
                            .foregroundStyle(.textPrimary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .cardStyle(cornerRadius: 14)
    }

    // MARK: - Status History

    @ViewBuilder
    private var statusHistorySection: some View {
        if !statusHistory.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Status History")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.textSecondary)

                ForEach(statusHistory.prefix(10)) { entry in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Image(systemName: entry.status.iconName)
                                    .font(.caption)
                                    .foregroundStyle(Color.forStatus(entry.status))
                                    .accessibilityHidden(true)
                                Text(entry.status.displayName)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.textPrimary)
                            }
                            if let reason = entry.reason, !reason.isEmpty {
                                Text(reason)
                                    .font(.caption)
                                    .foregroundStyle(.textSecondary)
                            }
                        }
                        Spacer()
                        if let date = entry.changedAtFormatted {
                            Text(DateHelper.relativeDateString(date))
                                .font(.caption)
                                .foregroundStyle(.textMuted)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .cardStyle(cornerRadius: 14)
        }
    }

    // MARK: - Helpers

    private var canLogPayment: Bool {
        currentItem.status != .trial && currentItem.status != .archived
    }

    private func refreshItem() async {
        do {
            currentItem = try await itemService.getItemById(currentItem.id)
        } catch {
            // Item may have been deleted
        }
    }

    private func loadPayments() async {
        do {
            payments = try await paymentService.getPayments(itemId: currentItem.id)
        } catch {
            // Non-critical
        }
    }

    private func loadStatusHistory() async {
        do {
            statusHistory = try await itemService.getStatusHistory(itemId: currentItem.id)
        } catch {
            // Non-critical
        }
    }

    private func presentPaymentSheet() {
        paymentAmount = currentItem.amount
        paymentDate = Date.now
        showPaymentSheet = true
    }

    private func recordPayment() async {
        guard let userId = authService.currentUser?.id.uuidString else { return }
        isRecordingPayment = true

        do {
            // Record the payment
            _ = try await paymentService.recordPayment(
                userId: userId,
                itemId: currentItem.id,
                amount: paymentAmount,
                paidDate: paymentDate
            )

            if let nextDate = currentItem.nextBillingDateAfterLoggingPayment(on: paymentDate) {
                let update = ItemUpdate(nextBillingDate: DateHelper.formatDate(nextDate))
                _ = try await itemService.updateItem(id: currentItem.id, data: update)
            }

            // Refresh data
            await refreshItem()
            await loadPayments()
            await onUpdate?()
            paymentRecorded = true
            showPaymentSheet = false
        } catch {
            // Payment failed — sheet stays open so user can retry
        }

        isRecordingPayment = false
    }
}

// MARK: - Detail Row

struct DetailRow: View {
    let label: String
    let value: String
    var color: Color?
    var valueColor: Color?
    var isLink: Bool = false

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.textSecondary)

            Spacer()

            HStack(spacing: 6) {
                if let color {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                }
                Text(value)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(valueColor ?? .textPrimary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
}
