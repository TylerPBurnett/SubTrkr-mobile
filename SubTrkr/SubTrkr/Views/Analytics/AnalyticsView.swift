import SwiftUI
import Charts

struct AnalyticsView: View {
    @Environment(AuthService.self) private var authService
    @State private var viewModel = AnalyticsViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.items.isEmpty {
                    analyticsLoadingView
                } else if viewModel.items.isEmpty {
                    EmptyStateView(
                        icon: "chart.bar",
                        title: "No analytics yet",
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
        .task(id: authService.currentUser?.id) {
            await viewModel.loadData()
            guard let userId = authService.currentUser?.id.uuidString else { return }

            let shouldReload = await viewModel.runMaintenance(userId: userId)
            if shouldReload {
                await viewModel.loadData()
            }
        }
    }

    private var analyticsContent: some View {
        ScrollView {
            VStack(spacing: 18) {
                scopePicker

                if viewModel.filteredItems.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: viewModel.selectedScope.emptyIcon)
                            .font(.title2)
                            .foregroundStyle(.textMuted)
                            .accessibilityHidden(true)
                        Text(viewModel.selectedScope.emptyTitle)
                            .font(.headline)
                            .foregroundStyle(.textPrimary)
                        Text(viewModel.selectedScope.emptyMessage)
                            .font(.subheadline)
                            .foregroundStyle(.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(28)
                    .cardStyle()
                    .padding(.horizontal)
                } else {
                    summaryGrid
                    rangePicker

                    if showsMissingHistoryState {
                        missingHistoryCard
                    } else {
                        SpendingTrendChart(
                            title: "Monthly Spending Trend",
                            data: viewModel.monthlyTrend
                        )
                    }

                    if !viewModel.spendingByCategory.isEmpty {
                        CategoryBreakdownChart(data: viewModel.spendingByCategory)
                    }

                    if !viewModel.topExpenses.isEmpty {
                        TopExpensesCard(
                            title: "Most Expensive \(viewModel.selectedScope.pluralLabel)",
                            expenses: viewModel.topExpenses
                        )
                    }

                    CancellationHistoryCard(
                        items: viewModel.cancelledItems,
                        monthlySavings: viewModel.monthlySavings,
                        scopeLabel: viewModel.selectedScope.pluralLabel
                    )
                }
            }
            .padding(.vertical)
        }
    }

    private var scopePicker: some View {
        Picker("Scope", selection: $viewModel.selectedScope) {
            ForEach(AnalyticsScope.allCases) { scope in
                Text(scope.title).tag(scope)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
    }

    private var summaryGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ], spacing: 12) {
            AnalyticsCard(
                title: "Monthly",
                value: viewModel.monthlySpending.formatted(currency: "USD"),
                subtitle: monthOverMonthSummary,
                icon: "chart.line.uptrend.xyaxis",
                color: .brand
            )
            AnalyticsCard(
                title: "Savings",
                value: viewModel.monthlySavings.formatted(currency: "USD"),
                subtitle: "\(viewModel.cancelledItems.count) ended item\(viewModel.cancelledItems.count == 1 ? "" : "s")",
                icon: "arrow.down.circle",
                color: .accentEmerald
            )
            AnalyticsCard(
                title: "Yearly",
                value: viewModel.yearlySpending.formattedCompact(currency: "USD"),
                subtitle: "Projected \(viewModel.projectedAnnualSpend.formattedCompact(currency: "USD")) next 12 months",
                icon: "calendar.badge.clock",
                color: .accentPurple
            )
            AnalyticsCard(
                title: "Active",
                value: "\(viewModel.totalActiveItems)",
                subtitle: viewModel.selectedScope.pluralLabel.lowercased(),
                icon: "checkmark.circle",
                color: .accentBlue
            )
        }
        .padding(.horizontal)
    }

    private var rangePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Time Range")
                    .font(.headline)
                    .foregroundStyle(.textPrimary)
                Spacer()
                Text("\(viewModel.selectedMonthRange) months")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.textMuted)
            }

            Picker("Time Range", selection: $viewModel.selectedMonthRange) {
                Text("3 Mo").tag(3)
                Text("6 Mo").tag(6)
                Text("12 Mo").tag(12)
            }
            .pickerStyle(.segmented)
        }
        .padding()
        .cardStyle()
        .padding(.horizontal)
    }

    private var missingHistoryCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.title2)
                .foregroundStyle(.textMuted)
                .accessibilityHidden(true)
            Text("Not enough history yet")
                .font(.headline)
                .foregroundStyle(.textPrimary)
            Text("Trends will become more useful as billing and status history builds up.")
                .font(.subheadline)
                .foregroundStyle(.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .cardStyle()
        .padding(.horizontal)
    }

    private var monthOverMonthSummary: String? {
        guard viewModel.monthlyTrend.count >= 2 else { return nil }

        let current = viewModel.monthlyTrend[viewModel.monthlyTrend.count - 1].total
        let previous = viewModel.monthlyTrend[viewModel.monthlyTrend.count - 2].total

        guard previous > 0 else {
            return current > 0 ? "New spend recorded this month" : "No change from prior month"
        }

        let change = ((current - previous) / previous) * 100
        if abs(change) < 0.5 {
            return "Flat vs prior month"
        }

        let direction = change > 0 ? "Up" : "Down"
        let percentText = abs(change).formatted(.number.precision(.fractionLength(1)))
        return "\(direction) \(percentText)% vs prior month"
    }

    private var showsMissingHistoryState: Bool {
        viewModel.monthlyTrend.allSatisfy { $0.total == 0 }
    }

    private var analyticsLoadingView: some View {
        ScrollView {
            VStack(spacing: 16) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.bgCard)
                    .frame(height: 32)
                    .shimmer()
                    .padding(.horizontal)

                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 12) {
                    ForEach(0..<4, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.bgCard)
                            .frame(height: 100)
                            .shimmer()
                    }
                }
                .padding(.horizontal)

                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.bgCard)
                    .frame(height: 74)
                    .shimmer()
                    .padding(.horizontal)

                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.bgCard)
                    .frame(height: 240)
                    .shimmer()
                    .padding(.horizontal)

                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.bgCard)
                    .frame(height: 220)
                    .shimmer()
                    .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }

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
}

struct SpendingTrendChart: View {
    let title: String
    let data: [MonthlySpending]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.textPrimary)

            Chart(data) { month in
                AreaMark(
                    x: .value("Month", month.shortMonth),
                    y: .value("Amount", month.total)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [.brand.opacity(0.28), .brand.opacity(0.04)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value("Month", month.shortMonth),
                    y: .value("Amount", month.total)
                )
                .foregroundStyle(.brand)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))

                PointMark(
                    x: .value("Month", month.shortMonth),
                    y: .value("Amount", month.total)
                )
                .foregroundStyle(.brand)
                .symbolSize(28)
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                        .foregroundStyle(Color.textMuted.opacity(0.18))
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text(amount.formattedCompact(currency: "USD"))
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

struct CategoryBreakdownChart: View {
    let data: [SpendingByCategory]

    private var chartHeight: CGFloat {
        CGFloat(max(220, data.count * 40 + 60))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Spending by Category")
                .font(.headline)
                .foregroundStyle(.textPrimary)

            Chart(data) { category in
                BarMark(
                    x: .value("Amount", category.total),
                    y: .value("Category", category.category)
                )
                .foregroundStyle(Color(hex: category.color))
                .cornerRadius(6)
            }
            .chartXAxis {
                AxisMarks(position: .bottom) { value in
                    AxisGridLine()
                        .foregroundStyle(Color.textMuted.opacity(0.16))
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text(amount.formattedCompact(currency: "USD"))
                                .font(.caption2)
                                .foregroundStyle(.textMuted)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                        .foregroundStyle(.clear)
                    AxisTick()
                        .foregroundStyle(.clear)
                    AxisValueLabel {
                        if let category = value.as(String.self) {
                            Text(category)
                                .font(.caption)
                                .foregroundStyle(.textSecondary)
                        }
                    }
                }
            }
            .frame(height: chartHeight)

            VStack(spacing: 0) {
                ForEach(data) { category in
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(hex: category.color))
                            .frame(width: 4, height: 30)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(category.category)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.textPrimary)
                            Text("\(category.count) active item\(category.count == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundStyle(.textMuted)
                        }

                        Spacer()

                        Text(category.total.formatted(currency: "USD"))
                            .font(.system(.subheadline, design: .monospaced))
                            .fontWeight(.semibold)
                            .foregroundStyle(.textPrimary)
                    }
                    .padding(.vertical, 10)

                    if category.id != data.last?.id {
                        Divider().padding(.leading, 16)
                    }
                }
            }
        }
        .padding()
        .cardStyle()
        .padding(.horizontal)
    }
}

struct CancellationHistoryCard: View {
    let items: [Item]
    let monthlySavings: Double
    let scopeLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Cancellation History")
                .font(.headline)
                .foregroundStyle(.textPrimary)

            if items.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "arrow.down.circle")
                        .font(.title2)
                        .foregroundStyle(.textMuted)
                        .accessibilityHidden(true)
                    Text("No ended \(scopeLabel.lowercased()) yet")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.textPrimary)
                    Text("Savings will appear here after items are cancelled or archived.")
                        .font(.caption)
                        .foregroundStyle(.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Monthly Savings")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.accentEmerald)
                    Text(monthlySavings.formatted(currency: "USD"))
                        .font(.system(.title2, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundStyle(.accentEmerald)
                    Text("\(items.count) ended item\(items.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.textMuted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.accentEmeraldMuted)
                .clipShape(RoundedRectangle(cornerRadius: 14))

                ForEach(items.prefix(10)) { item in
                    HStack(spacing: 12) {
                        ServiceLogo(
                            url: item.logoURL,
                            name: item.name,
                            categoryColor: item.categoryColor,
                            size: 34
                        )

                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.name)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.textPrimary)
                            if let endedDate = item.cancellationDateFormatted ?? item.cancelledAtFormatted ?? item.archivedAtFormatted {
                                Text("Ended \(DateHelper.formatMediumDate(endedDate))")
                                    .font(.caption)
                                    .foregroundStyle(.textSecondary)
                            } else {
                                StatusBadge(status: item.status)
                            }
                        }

                        Spacer()

                        Text("+\(item.monthlyAmount.formatted(currency: item.currency))/mo")
                            .font(.system(.caption, design: .monospaced))
                            .fontWeight(.semibold)
                            .foregroundStyle(.accentEmerald)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .cardStyle()
        .padding(.horizontal)
    }
}

struct TopExpensesCard: View {
    let title: String
    let expenses: [TopExpense]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
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
                    .accessibilityHidden(true)
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
                .contentTransition(.numericText())
                .animation(.default, value: value)

            if let subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.textMuted)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .cardStyle(cornerRadius: 14)
    }
}
