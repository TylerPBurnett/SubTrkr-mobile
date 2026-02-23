import SwiftUI
import Charts

struct AnalyticsView: View {
    @State private var viewModel = AnalyticsViewModel()
    @State private var selectedTab = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Tab Picker
                    Picker("", selection: $selectedTab) {
                        Text("Overview").tag(0)
                        Text("Categories").tag(1)
                        Text("Trends").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    switch selectedTab {
                    case 0: overviewTab
                    case 1: categoriesTab
                    case 2: trendsTab
                    default: EmptyView()
                    }
                }
                .padding(.vertical)
            }
            .background(Color.bgBase)
            .navigationTitle("Analytics")
            .refreshable {
                await viewModel.loadData()
            }
        }
        .task {
            await viewModel.loadData()
        }
    }

    // MARK: - Overview Tab

    private var overviewTab: some View {
        VStack(spacing: 16) {
            // Spending summary cards
            HStack(spacing: 12) {
                AnalyticsCard(
                    title: "Monthly",
                    value: viewModel.monthlySpending.formatted(currency: "USD"),
                    icon: "calendar",
                    color: .brand
                )
                AnalyticsCard(
                    title: "Yearly",
                    value: viewModel.yearlySpending.formattedCompact(currency: "USD"),
                    icon: "calendar.badge.clock",
                    color: .blue
                )
            }
            .padding(.horizontal)

            HStack(spacing: 12) {
                AnalyticsCard(
                    title: "Savings",
                    value: viewModel.monthlySavings.formatted(currency: "USD"),
                    subtitle: "from cancelled",
                    icon: "arrow.down.circle",
                    color: .statusPaused
                )
                AnalyticsCard(
                    title: "Active",
                    value: "\(viewModel.totalActiveItems)",
                    subtitle: "items tracked",
                    icon: "checkmark.circle",
                    color: .brand
                )
            }
            .padding(.horizontal)

            // Top Expenses
            if !viewModel.topExpenses.isEmpty {
                topExpensesSection
            }

            // Status Distribution
            if !viewModel.statusCounts.isEmpty {
                statusDistribution
            }
        }
    }

    // MARK: - Categories Tab

    private var categoriesTab: some View {
        VStack(spacing: 20) {
            if !viewModel.spendingByCategory.isEmpty {
                // Donut Chart
                VStack(alignment: .leading, spacing: 12) {
                    Text("Monthly by Category")
                        .font(.headline)
                        .foregroundStyle(.textPrimary)
                        .padding(.horizontal)

                    Chart(viewModel.spendingByCategory) { category in
                        SectorMark(
                            angle: .value("Amount", category.total),
                            innerRadius: .ratio(0.55),
                            angularInset: 2
                        )
                        .foregroundStyle(Color(hex: category.color))
                        .cornerRadius(6)
                    }
                    .frame(height: 240)
                    .padding(.horizontal)

                    // Category List
                    VStack(spacing: 0) {
                        ForEach(viewModel.spendingByCategory) { category in
                            HStack(spacing: 12) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color(hex: category.color))
                                    .frame(width: 4, height: 32)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(category.category)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.textPrimary)
                                    Text("\(category.count) item\(category.count == 1 ? "" : "s")")
                                        .font(.caption)
                                        .foregroundStyle(.textTertiary)
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(category.total.formatted(currency: "USD"))
                                        .font(.system(.subheadline, design: .monospaced))
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.textPrimary)
                                    Text("/month")
                                        .font(.caption2)
                                        .foregroundStyle(.textTertiary)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 10)

                            if category.id != viewModel.spendingByCategory.last?.id {
                                Divider().padding(.leading, 28)
                            }
                        }
                    }
                    .background(Color.bgCard)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal)
                }
            } else {
                EmptyStateView(
                    icon: "chart.pie",
                    title: "No data yet",
                    message: "Add some subscriptions or bills to see category breakdown"
                )
            }
        }
    }

    // MARK: - Trends Tab

    private var trendsTab: some View {
        VStack(spacing: 20) {
            if !viewModel.monthlyTrend.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("6-Month Spending Trend")
                        .font(.headline)
                        .foregroundStyle(.textPrimary)

                    Chart(viewModel.monthlyTrend) { month in
                        AreaMark(
                            x: .value("Month", month.shortMonth),
                            y: .value("Amount", month.total)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.brand.opacity(0.3), .brand.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        LineMark(
                            x: .value("Month", month.shortMonth),
                            y: .value("Amount", month.total)
                        )
                        .foregroundStyle(.brand)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))

                        PointMark(
                            x: .value("Month", month.shortMonth),
                            y: .value("Amount", month.total)
                        )
                        .foregroundStyle(.brand)
                        .symbolSize(30)
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine()
                                .foregroundStyle(Color.textTertiary.opacity(0.2))
                            AxisValueLabel {
                                if let intValue = value.as(Double.self) {
                                    Text(intValue.formattedCompact(currency: "USD"))
                                        .font(.caption2)
                                        .foregroundStyle(.textTertiary)
                                }
                            }
                        }
                    }
                    .frame(height: 220)
                }
                .padding()
                .background(Color.bgCard)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
            }

            // Cancellation history
            if !viewModel.cancelledItems.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Cancellation History")
                        .font(.headline)
                        .foregroundStyle(.textPrimary)

                    ForEach(viewModel.cancelledItems.prefix(10)) { item in
                        HStack(spacing: 12) {
                            ServiceLogo(
                                url: item.logoURL,
                                name: item.name,
                                categoryColor: item.categoryColor,
                                size: 32
                            )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.textPrimary)
                                StatusBadge(status: item.status)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text(item.monthlyAmount.formatted(currency: item.currency))
                                    .font(.system(.caption, design: .monospaced))
                                    .fontWeight(.medium)
                                    .foregroundStyle(.textSecondary)
                                Text("saved/mo")
                                    .font(.caption2)
                                    .foregroundStyle(.textTertiary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding()
                .background(Color.bgCard)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Top Expenses

    private var topExpensesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top Expenses")
                .font(.headline)
                .foregroundStyle(.textPrimary)

            ForEach(viewModel.topExpenses) { expense in
                HStack(spacing: 12) {
                    ServiceLogo(
                        url: expense.logoUrl.flatMap { URL(string: $0) },
                        name: expense.name,
                        categoryColor: expense.categoryColor,
                        size: 36
                    )

                    Text(expense.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.textPrimary)

                    Spacer()

                    Text(expense.monthlyAmount.formatted(currency: "USD"))
                        .font(.system(.subheadline, design: .monospaced))
                        .fontWeight(.semibold)
                        .foregroundStyle(.textPrimary)
                }
                .padding(.vertical, 2)
            }
        }
        .padding()
        .background(Color.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    // MARK: - Status Distribution

    private var statusDistribution: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Status Overview")
                .font(.headline)
                .foregroundStyle(.textPrimary)

            HStack(spacing: 0) {
                ForEach(ItemStatus.allCases) { status in
                    if let count = viewModel.statusCounts[status], count > 0 {
                        let total = Double(viewModel.items.count)
                        let fraction = Double(count) / total

                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.forStatus(status))
                            .frame(maxWidth: .infinity)
                            .frame(height: 8)
                            .scaleEffect(x: fraction * CGFloat(ItemStatus.allCases.count), anchor: .leading)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 4))

            HStack(spacing: 16) {
                ForEach(ItemStatus.allCases) { status in
                    if let count = viewModel.statusCounts[status], count > 0 {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.forStatus(status))
                                .frame(width: 8, height: 8)
                            Text("\(count) \(status.displayName)")
                                .font(.caption2)
                                .foregroundStyle(.textSecondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
}

// MARK: - Analytics Card

struct AnalyticsCard: View {
    let title: String
    let value: String
    var subtitle: String?
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.textSecondary)
            }

            Text(value)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundStyle(.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            if let subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
