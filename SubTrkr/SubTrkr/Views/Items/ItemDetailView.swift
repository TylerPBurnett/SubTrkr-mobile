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
                        Button { showStatusSheet = true } label: {
                            Label("Change Status", systemImage: "arrow.triangle.2.circlepath")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(.brand)
                    }
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
                                TextField("Amount", value: $paymentAmount, format: .number.precision(.fractionLength(2)))
                                    .keyboardType(.decimalPad)
                            }

                            DatePicker(selection: $paymentDate, displayedComponents: .date) {
                                HStack {
                                    Image(systemName: "calendar")
                                        .foregroundStyle(.brand)
                                        .frame(width: 24)
                                    Text("Date")
                                }
                            }
                        }
                    }
                    .navigationTitle("Record Payment")
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
                    .font(.system(size: 32, weight: .heavy, design: .monospaced))
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

            if currentItem.status == .paused, let pausedUntil = currentItem.pausedUntil,
               let date = DateHelper.parseDate(pausedUntil) {
                Divider().padding(.leading)
                DetailRow(label: "Resumes", value: DateHelper.relativeDateString(date))
            }

            if currentItem.status == .cancelled, let cancellationDate = currentItem.cancellationDate,
               let date = DateHelper.parseDate(cancellationDate) {
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
                ForEach(availableActions, id: \.self) { action in
                    Button {
                        showStatusSheet = true
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: iconForAction(action))
                                .font(.system(size: 18))
                            Text(action.capitalized)
                                .font(.caption2.weight(.medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundStyle(colorForAction(action))
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
            HStack {
                Text("Payment History")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.textSecondary)

                Spacer()

                if currentItem.status == .active || currentItem.status == .trial {
                    Button {
                        paymentAmount = currentItem.amount
                        paymentDate = Date.now
                        showPaymentSheet = true
                    } label: {
                        Label("Record Payment", systemImage: "plus.circle.fill")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.brand)
                    }
                }
            }

            if payments.isEmpty {
                Text("No payments recorded yet")
                    .font(.caption)
                    .foregroundStyle(.textMuted)
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

    private var availableActions: [String] {
        switch currentItem.status {
        case .active: return ["pause", "cancel", "archive"]
        case .paused: return ["resume", "cancel", "archive"]
        case .cancelled: return ["reactivate", "archive"]
        case .archived: return ["reactivate"]
        case .trial: return ["convert", "cancel"]
        }
    }

    private func iconForAction(_ action: String) -> String {
        switch action {
        case "pause": return "pause.circle"
        case "resume", "reactivate": return "play.circle"
        case "cancel": return "xmark.circle"
        case "archive": return "archivebox"
        case "convert": return "arrow.right.circle"
        default: return "circle"
        }
    }

    private func colorForAction(_ action: String) -> Color {
        switch action {
        case "pause": return .statusPaused
        case "resume", "reactivate", "convert": return .brand
        case "cancel": return .statusCancelled
        case "archive": return .statusArchived
        default: return .textSecondary
        }
    }

    private func refreshItem() async {
        do {
            currentItem = try await ItemService().getItemById(currentItem.id)
        } catch {
            // Item may have been deleted
        }
    }

    private func loadPayments() async {
        do {
            payments = try await PaymentService().getPayments(itemId: currentItem.id)
        } catch {
            // Non-critical
        }
    }

    private func loadStatusHistory() async {
        do {
            statusHistory = try await ItemService().getStatusHistory(itemId: currentItem.id)
        } catch {
            // Non-critical
        }
    }

    private func recordPayment() async {
        guard let userId = authService.currentUser?.id.uuidString else { return }
        isRecordingPayment = true

        do {
            // Record the payment
            _ = try await PaymentService().recordPayment(
                userId: userId,
                itemId: currentItem.id,
                amount: paymentAmount,
                paidDate: paymentDate
            )

            // Auto-advance next billing date by one cycle
            if let currentDate = currentItem.nextBillingDateFormatted {
                let nextDate = DateHelper.advanceDate(currentDate, by: currentItem.billingCycle)
                let update = ItemUpdate(nextBillingDate: DateHelper.formatDate(nextDate))
                _ = try await ItemService().updateItem(id: currentItem.id, data: update)
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
