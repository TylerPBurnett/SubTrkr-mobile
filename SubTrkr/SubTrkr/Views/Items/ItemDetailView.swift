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
        }
        .task {
            await loadPayments()
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
                let formatter = DateFormatter()
                DetailRow(label: "Start Date", value: {
                    let f = DateFormatter()
                    f.dateStyle = .medium
                    return f.string(from: date)
                }())
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
                let f = DateFormatter()
                DetailRow(label: "Cancellation Date", value: {
                    let f = DateFormatter()
                    f.dateStyle = .medium
                    return f.string(from: date)
                }())
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
            Text("Payment History")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.textSecondary)

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
                            let f = DateFormatter()
                            Text({
                                let f = DateFormatter()
                                f.dateStyle = .medium
                                return f.string(from: date)
                            }())
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
