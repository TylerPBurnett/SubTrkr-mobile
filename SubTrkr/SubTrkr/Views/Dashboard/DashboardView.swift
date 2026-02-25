import SwiftUI
import Charts

struct DashboardView: View {
    @Environment(AuthService.self) private var authService
    @State private var viewModel = DashboardViewModel()
    @State private var hasRunMaintenance = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Stats Cards
                    statsSection

                    // Category Breakdown
                    if !viewModel.spendingByCategory.isEmpty {
                        categoryChart
                    }

                    // Upcoming Payments
                    if !viewModel.upcomingPayments.isEmpty {
                        upcomingSection
                    }
                }
                .padding()
            }
            .background(Color.bgBase)
            .navigationTitle("Dashboard")
            .refreshable {
                await viewModel.loadData()
            }
        }
        .task {
            await viewModel.loadData()
            if !hasRunMaintenance, let userId = authService.currentUser?.id.uuidString {
                hasRunMaintenance = true
                await viewModel.runMaintenance(userId: userId)
                await viewModel.loadData()
            }
        }
    }

    // MARK: - Stats Cards

    private var statsSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                StatsCard(
                    title: "Monthly",
                    value: viewModel.monthlySpending.formatted(currency: "USD"),
                    icon: "calendar",
                    color: .brand
                )
                StatsCard(
                    title: "Yearly",
                    value: viewModel.yearlySpending.formattedCompact(currency: "USD"),
                    icon: "calendar.badge.clock",
                    color: .accentPurple
                )
            }

            HStack(spacing: 12) {
                StatsCard(
                    title: "Active",
                    value: "\(viewModel.activeCount)",
                    subtitle: "\(viewModel.subscriptionCount) subs, \(viewModel.billCount) bills",
                    icon: "checkmark.circle",
                    color: .brand
                )
                StatsCard(
                    title: "Savings",
                    value: viewModel.monthlySavings.formatted(currency: "USD"),
                    subtitle: "per month",
                    icon: "arrow.down.circle",
                    color: .statusPaused
                )
            }
        }
    }

    // MARK: - Category Chart

    private var categoryChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Spending by Category")
                .font(.headline)
                .foregroundStyle(.textPrimary)

            Chart(viewModel.spendingByCategory) { category in
                SectorMark(
                    angle: .value("Amount", category.total),
                    innerRadius: .ratio(0.6),
                    angularInset: 2
                )
                .foregroundStyle(Color(hex: category.color))
                .cornerRadius(4)
            }
            .frame(height: 200)

            // Legend
            VStack(spacing: 8) {
                ForEach(viewModel.spendingByCategory) { category in
                    HStack {
                        Circle()
                            .fill(Color(hex: category.color))
                            .frame(width: 10, height: 10)
                        Text(category.category)
                            .font(.subheadline)
                            .foregroundStyle(.textPrimary)
                        Spacer()
                        Text("\(category.count) items")
                            .font(.caption)
                            .foregroundStyle(.textMuted)
                        Text(category.total.formatted(currency: "USD"))
                            .font(.system(.subheadline, design: .monospaced))
                            .fontWeight(.medium)
                            .foregroundStyle(.textPrimary)
                    }
                }
            }
        }
        .padding()
        .cardStyle()
    }

    // MARK: - Upcoming Payments

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Upcoming Payments")
                    .font(.headline)
                    .foregroundStyle(.textPrimary)
                Spacer()
                Text("Next 30 days")
                    .font(.caption)
                    .foregroundStyle(.textMuted)
            }

            ForEach(viewModel.upcomingPayments.prefix(8)) { item in
                UpcomingPaymentRow(item: item)
            }
        }
        .padding()
        .cardStyle()
    }
}

// MARK: - Stats Card

struct StatsCard: View {
    let title: String
    let value: String
    var subtitle: String?
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.textSecondary)
            }

            Text(value)
                .font(.system(size: 20, weight: .heavy, design: .monospaced))
                .foregroundStyle(.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            if let subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.textMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .cardStyle(cornerRadius: 14)
    }
}

// MARK: - Upcoming Payment Row

struct UpcomingPaymentRow: View {
    let item: Item

    var body: some View {
        HStack(spacing: 12) {
            ServiceLogo(
                url: item.logoURL,
                name: item.name,
                categoryColor: item.categoryColor,
                size: 36
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.textPrimary)
                    .lineLimit(1)

                if let date = item.nextBillingDateFormatted {
                    Text(DateHelper.relativeDateString(date))
                        .font(.caption)
                        .foregroundStyle(
                            (item.daysUntilDue ?? 0) <= 3 ? .statusCancelled : .textMuted
                        )
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                CurrencyText(amount: item.amount, currency: item.currency)
                    .font(.subheadline)

                Text(item.billingCycle.displayName)
                    .font(.caption2)
                    .foregroundStyle(.textMuted)
            }
        }
        .padding(.vertical, 4)
    }
}
