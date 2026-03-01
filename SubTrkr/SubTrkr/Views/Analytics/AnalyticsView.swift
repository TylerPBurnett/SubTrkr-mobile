import SwiftUI
import Charts

struct AnalyticsView: View {
    @Environment(AuthService.self) private var authService
    @State private var viewModel = AnalyticsViewModel()
    @State private var selectedTab = 0
    @State private var hasRunMaintenance = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.items.isEmpty {
                    analyticsLoadingView
                } else if viewModel.items.isEmpty {
                    EmptyStateView(
                        icon: "chart.bar",
                        title: "No data yet",
                        message: "Add subscriptions or bills to see your analytics"
                    )
                } else {
                    analyticsContent
                }
            }
            .background(Color.bgBase)
            .navigationTitle("Analytics")
            .refreshable {
                await viewModel.loadData()
            }
            .overlay(alignment: .top) {
                if let error = viewModel.error {
                    errorBanner(error)
                }
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

    // MARK: - Main Content

    private var analyticsContent: some View {
        ScrollView {
            VStack(spacing: 20) {
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
    }

    // MARK: - Loading View

    private var analyticsLoadingView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Fake segmented picker placeholder
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.bgCard)
                    .frame(height: 32)
                    .shimmer()
                    .padding(.horizontal)

                // Card placeholders
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.bgCard)
                        .frame(height: 90)
                        .shimmer()
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.bgCard)
                        .frame(height: 90)
                        .shimmer()
                }
                .padding(.horizontal)

                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.bgCard)
                        .frame(height: 90)
                        .shimmer()
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.bgCard)
                        .frame(height: 90)
                        .shimmer()
                }
                .padding(.horizontal)

                // Chart placeholder
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.bgCard)
                    .frame(height: 200)
                    .shimmer()
                    .padding(.horizontal)

                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.bgCard)
                    .frame(height: 160)
                    .shimmer()
                    .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }

    // MARK: - Error Banner

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.accentAmber)
                .accessibilityHidden(true)
            Text(message)
                .font(.caption)
                .foregroundStyle(.textPrimary)
                .lineLimit(2)
            Spacer()
            Button {
                viewModel.error = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.textMuted)
            }
            .accessibilityLabel("Dismiss")
        }
        .padding(12)
        .background(Color.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
        .padding(.horizontal)
        .padding(.top, 4)
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.easeInOut(duration: 0.25), value: viewModel.error != nil)
    }

    // MARK: - Overview Tab

    private var overviewTab: some View {
        VStack(spacing: 16) {
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
                    color: .accentPurple
                )
            }
            .padding(.horizontal)

            HStack(spacing: 12) {
                AnalyticsCard(
                    title: "Projected",
                    value: viewModel.projectedAnnualSpend.formattedCompact(currency: "USD"),
                    subtitle: "next 12 months",
                    icon: "chart.line.uptrend.xyaxis",
                    color: .accentAmber
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

            HStack(spacing: 12) {
                AnalyticsCard(
                    title: "Savings",
                    value: viewModel.monthlySavings.formatted(currency: "USD"),
                    subtitle: "from cancelled",
                    icon: "arrow.down.circle",
                    color: .statusPaused
                )
                Spacer()
            }
            .padding(.horizontal)

            if !viewModel.topExpenses.isEmpty {
                TopExpensesCard(expenses: viewModel.topExpenses)
            }

            if !viewModel.statusCounts.isEmpty {
                StatusDistributionCard(
                    statusCounts: viewModel.statusCounts,
                    totalCount: viewModel.items.count
                )
            }
        }
    }

    // MARK: - Categories Tab

    private var categoriesTab: some View {
        VStack(spacing: 20) {
            if !viewModel.spendingByCategory.isEmpty {
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
                                        .foregroundStyle(.textMuted)
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(category.total.formatted(currency: "USD"))
                                        .font(.system(.subheadline, design: .monospaced))
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.textPrimary)
                                    Text("/month")
                                        .font(.caption2)
                                        .foregroundStyle(.textMuted)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 10)

                            if category.id != viewModel.spendingByCategory.last?.id {
                                Divider().padding(.leading, 28)
                            }
                        }
                    }
                    .cardStyle(cornerRadius: 14)
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
            Picker("Time Range", selection: $viewModel.selectedMonthRange) {
                Text("3 Mo").tag(3)
                Text("6 Mo").tag(6)
                Text("12 Mo").tag(12)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            if viewModel.monthlyTrend.isEmpty && viewModel.categoryTrend.isEmpty && viewModel.itemCountTrend.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.title)
                        .foregroundStyle(.textMuted)
                        .accessibilityHidden(true)
                    Text("Not enough history")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.textPrimary)
                    Text("Trends will appear as your subscriptions accumulate billing history")
                        .font(.caption)
                        .foregroundStyle(.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(32)
            } else {
                if !viewModel.monthlyTrend.isEmpty {
                    SpendingTrendChart(data: viewModel.monthlyTrend)
                }

                if !viewModel.categoryTrend.isEmpty {
                    CategoryTrendChart(data: viewModel.categoryTrend)
                }

                if !viewModel.itemCountTrend.isEmpty {
                    ItemCountChart(data: viewModel.itemCountTrend)
                }
            }

            if !viewModel.cancelledItems.isEmpty {
                CancellationHistoryCard(items: viewModel.cancelledItems)
            }
        }
    }
}

// MARK: - Spending Trend Chart

struct SpendingTrendChart: View {
    let data: [MonthlySpending]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Spending Trend")
                .font(.headline)
                .foregroundStyle(.textPrimary)

            Chart(data) { month in
                AreaMark(
                    x: .value("Month", month.shortMonth),
                    y: .value("Amount", month.total)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [.brand.opacity(0.3), .brand.opacity(0.02)],
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
                        .foregroundStyle(Color.textMuted.opacity(0.2))
                    AxisValueLabel {
                        if let intValue = value.as(Double.self) {
                            Text(intValue.formattedCompact(currency: "USD"))
                                .font(.caption2)
                                .foregroundStyle(.textMuted)
                        }
                    }
                }
            }
            .frame(height: 220)
        }
        .padding()
        .cardStyle()
        .padding(.horizontal)
    }
}

// MARK: - Category Trend Chart

struct CategoryTrendChart: View {
    let data: [CategoryMonthlySpending]

    private var colors: [Color] {
        let unique = Dictionary(grouping: data, by: \.category)
        return unique.keys.sorted().compactMap { name in
            unique[name]?.first.map { Color(hex: $0.color) }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Spending by Category")
                .font(.headline)
                .foregroundStyle(.textPrimary)

            Chart(data) { entry in
                AreaMark(
                    x: .value("Month", entry.shortMonth),
                    y: .value("Amount", entry.total)
                )
                .foregroundStyle(by: .value("Category", entry.category))
            }
            .chartForegroundStyleScale(range: colors)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                        .foregroundStyle(Color.textMuted.opacity(0.2))
                    AxisValueLabel {
                        if let intValue = value.as(Double.self) {
                            Text(intValue.formattedCompact(currency: "USD"))
                                .font(.caption2)
                                .foregroundStyle(.textMuted)
                        }
                    }
                }
            }
            .frame(height: 220)

            let categories = Dictionary(grouping: data, by: \.category)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], alignment: .leading, spacing: 4) {
                ForEach(Array(categories.keys.sorted()), id: \.self) { name in
                    if let entry = categories[name]?.first {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color(hex: entry.color))
                                .frame(width: 8, height: 8)
                                .accessibilityHidden(true)
                            Text(name)
                                .font(.caption2)
                                .foregroundStyle(.textSecondary)
                        }
                    }
                }
            }
        }
        .padding()
        .cardStyle()
        .padding(.horizontal)
    }
}

// MARK: - Item Count Chart

struct ItemCountChart: View {
    let data: [MonthlyItemCount]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active Subscriptions")
                .font(.headline)
                .foregroundStyle(.textPrimary)

            Chart(data) { month in
                LineMark(
                    x: .value("Month", month.shortMonth),
                    y: .value("Count", month.count)
                )
                .foregroundStyle(.brand)
                .lineStyle(StrokeStyle(lineWidth: 2.5))

                PointMark(
                    x: .value("Month", month.shortMonth),
                    y: .value("Count", month.count)
                )
                .foregroundStyle(.brand)
                .symbolSize(30)

                AreaMark(
                    x: .value("Month", month.shortMonth),
                    y: .value("Count", month.count)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [.brand.opacity(0.2), .brand.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                        .foregroundStyle(Color.textMuted.opacity(0.2))
                    AxisValueLabel {
                        if let intValue = value.as(Int.self) {
                            Text("\(intValue)")
                                .font(.caption2)
                                .foregroundStyle(.textMuted)
                        }
                    }
                }
            }
            .frame(height: 180)
        }
        .padding()
        .cardStyle()
        .padding(.horizontal)
    }
}

// MARK: - Cancellation History Card

struct CancellationHistoryCard: View {
    let items: [Item]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cancellation History")
                .font(.headline)
                .foregroundStyle(.textPrimary)

            ForEach(items.prefix(10)) { item in
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
                            .foregroundStyle(.textMuted)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .cardStyle()
        .padding(.horizontal)
    }
}

// MARK: - Top Expenses Card

struct TopExpensesCard: View {
    let expenses: [TopExpense]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top Expenses")
                .font(.headline)
                .foregroundStyle(.textPrimary)

            ForEach(expenses) { expense in
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
        .cardStyle()
        .padding(.horizontal)
    }
}

// MARK: - Status Distribution Card

struct StatusDistributionCard: View {
    let statusCounts: [ItemStatus: Int]
    let totalCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Status Overview")
                .font(.headline)
                .foregroundStyle(.textPrimary)

            HStack(spacing: 0) {
                ForEach(ItemStatus.allCases) { status in
                    if let count = statusCounts[status], count > 0 {
                        let total = Double(totalCount)
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
                    if let count = statusCounts[status], count > 0 {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.forStatus(status))
                                .frame(width: 8, height: 8)
                                .accessibilityHidden(true)
                            Text("\(count) \(status.displayName)")
                                .font(.caption2)
                                .foregroundStyle(.textSecondary)
                        }
                    }
                }
            }
        }
        .padding()
        .cardStyle()
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
                .font(.system(.body, design: .monospaced))
                .fontWeight(.heavy)
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
