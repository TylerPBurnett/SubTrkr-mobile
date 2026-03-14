# Analytics Charts Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix the flat spending trend chart with historical reconstruction, add category spending over time, subscription count over time, and projected annual spend.

**Architecture:** All reconstruction logic lives in `AnalyticsService`. New model structs in `AnalyticsModels.swift`. `AnalyticsViewModel` loads payments and exposes new computed properties. Views use Swift Charts with the existing card/color system.

**Tech Stack:** Swift, SwiftUI, Swift Charts, Supabase Swift SDK

**SwiftUI guidelines:**
- `@State` must be `private`
- Extract complex views into subviews for optimal diffing
- Pass only needed values to subviews
- ForEach uses stable identity (UUID-based Identifiable)
- No object creation in view `body` — use cached formatters from `DateHelper`
- Use `.animation(_:value:)` with value parameter

---

### Task 1: Add New Analytics Model Structs

**Files:**
- Modify: `SubTrkr/SubTrkr/Models/AnalyticsModels.swift`

**Changes:**

Add two new model structs and fix `MonthlySpending` to use a `Date` directly (eliminates per-render `DateFormatter` allocations in `monthDate` and `shortMonth`):

Replace the entire file content with:

```swift
import Foundation

struct SpendingByCategory: Identifiable {
    let id = UUID()
    let category: String
    let color: String
    let total: Double
    let count: Int
}

struct MonthlySpending: Identifiable {
    let id = UUID()
    let month: Date
    let total: Double

    var shortMonth: String {
        DateHelper.formatShortMonth(month)
    }
}

struct CategoryMonthlySpending: Identifiable {
    let id = UUID()
    let month: Date
    let category: String
    let color: String
    let total: Double

    var shortMonth: String {
        DateHelper.formatShortMonth(month)
    }
}

struct MonthlyItemCount: Identifiable {
    let id = UUID()
    let month: Date
    let count: Int

    var shortMonth: String {
        DateHelper.formatShortMonth(month)
    }
}

struct TopExpense: Identifiable {
    let id: String
    let name: String
    let monthlyAmount: Double
    let logoUrl: String?
    let categoryColor: String
}
```

Also add `formatShortMonth` to `DateHelper` in `SubTrkr/SubTrkr/Extensions/Date+Helpers.swift`:

```swift
private static let shortMonthFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "MMM"
    return f
}()

static func formatShortMonth(_ date: Date) -> String {
    shortMonthFormatter.string(from: date)
}
```

**Verify:** Build succeeds.

**Commit:** `feat: add analytics model structs for category and item count trends`

---

### Task 2: Rewrite AnalyticsService Reconstruction Logic

**Files:**
- Modify: `SubTrkr/SubTrkr/Services/AnalyticsService.swift`

**Changes:**

Replace the `// MARK: - Monthly Trend` section (the broken `getMonthlySpendingTrend` method) with four new methods. Keep all other methods unchanged.

```swift
// MARK: - Historical Reconstruction

/// Determines if an item was actively costing money during a given month.
/// Checks startDate, cancelledAt, archivedAt, pausedAt/pausedUntil.
private func wasItemActive(item: Item, monthStart: Date, monthEnd: Date) -> Bool {
    // Must have started before month end
    guard let startDateStr = item.startDate,
          let startDate = DateHelper.parseDate(startDateStr),
          startDate <= monthEnd else {
        return false
    }

    // Trial items don't cost money
    // But if they converted (status is now active and trialStartedAt exists), count post-conversion
    if item.status == .trial {
        return false
    }

    // Check if cancelled before this month started
    if let cancelledAtStr = item.cancelledAt,
       let cancelledAt = DateHelper.parseISO8601(cancelledAtStr),
       cancelledAt < monthStart {
        return false
    }

    // Check if archived before this month started
    if let archivedAtStr = item.archivedAt,
       let archivedAt = DateHelper.parseISO8601(archivedAtStr),
       archivedAt < monthStart {
        return false
    }

    // Check if paused for the entire month
    if let pausedAtStr = item.pausedAt,
       let pausedAt = DateHelper.parseISO8601(pausedAtStr),
       pausedAt < monthStart {
        // Was paused before month started — check if still paused through end
        if let pausedUntilStr = item.pausedUntil,
           let pausedUntil = DateHelper.parseDate(pausedUntilStr) {
            if pausedUntil > monthEnd {
                return false // paused for entire month
            }
        } else if item.status == .paused {
            return false // still paused with no resume date
        }
    }

    return true
}

/// Month start/end helpers
private func monthRange(for date: Date) -> (start: Date, end: Date) {
    let calendar = Calendar.current
    let start = calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
    let end = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: start)!
    return (start, end)
}

/// Reconstructed monthly spending using item metadata + real payments when available.
func reconstructMonthlySpending(items: [Item], payments: [Payment], months: Int) -> [MonthlySpending] {
    let calendar = Calendar.current
    let now = Date.now

    // Index payments by itemId + month for O(1) lookup
    var paymentIndex: [String: [String: Double]] = [:] // [itemId: [yyyy-MM: totalPaid]]
    for payment in payments {
        guard let date = payment.paidDateFormatted else { continue }
        let key = DateHelper.formatYearMonth(date)
        paymentIndex[payment.itemId, default: [:]][key, default: 0] += payment.amount
    }

    var result: [MonthlySpending] = []

    for i in (0..<months).reversed() {
        guard let monthDate = calendar.date(byAdding: .month, value: -i, to: now) else { continue }
        let (monthStart, monthEnd) = monthRange(for: monthDate)
        let monthKey = DateHelper.formatYearMonth(monthStart)

        var total = 0.0
        for item in items {
            if let paidAmount = paymentIndex[item.id]?[monthKey] {
                // Use actual payment amount — ground truth
                total += paidAmount
            } else if wasItemActive(item: item, monthStart: monthStart, monthEnd: monthEnd) {
                total += item.monthlyAmount
            }
        }

        result.append(MonthlySpending(month: monthStart, total: total))
    }

    return result
}

/// Category spending over time (for stacked area chart).
func reconstructCategorySpending(items: [Item], payments: [Payment], months: Int) -> [CategoryMonthlySpending] {
    let calendar = Calendar.current
    let now = Date.now

    var paymentIndex: [String: [String: Double]] = [:]
    for payment in payments {
        guard let date = payment.paidDateFormatted else { continue }
        let key = DateHelper.formatYearMonth(date)
        paymentIndex[payment.itemId, default: [:]][key, default: 0] += payment.amount
    }

    var result: [CategoryMonthlySpending] = []

    for i in (0..<months).reversed() {
        guard let monthDate = calendar.date(byAdding: .month, value: -i, to: now) else { continue }
        let (monthStart, monthEnd) = monthRange(for: monthDate)
        let monthKey = DateHelper.formatYearMonth(monthStart)

        // Group by category
        var categoryTotals: [String: (color: String, total: Double)] = [:]

        for item in items {
            var amount = 0.0
            if let paidAmount = paymentIndex[item.id]?[monthKey] {
                amount = paidAmount
            } else if wasItemActive(item: item, monthStart: monthStart, monthEnd: monthEnd) {
                amount = item.monthlyAmount
            }

            if amount > 0 {
                let name = item.categoryName
                let color = item.categoryColor
                categoryTotals[name, default: (color: color, total: 0)].total += amount
            }
        }

        for (name, data) in categoryTotals {
            result.append(CategoryMonthlySpending(
                month: monthStart,
                category: name,
                color: data.color,
                total: data.total
            ))
        }
    }

    return result
}

/// Active item count per month (for subscription count chart).
func reconstructMonthlyItemCount(items: [Item], months: Int) -> [MonthlyItemCount] {
    let calendar = Calendar.current
    let now = Date.now

    var result: [MonthlyItemCount] = []

    for i in (0..<months).reversed() {
        guard let monthDate = calendar.date(byAdding: .month, value: -i, to: now) else { continue }
        let (monthStart, monthEnd) = monthRange(for: monthDate)

        let count = items.filter { wasItemActive(item: $0, monthStart: monthStart, monthEnd: monthEnd) }.count
        result.append(MonthlyItemCount(month: monthStart, count: count))
    }

    return result
}

/// Forward-looking projected annual spend from currently active items.
func calculateProjectedAnnualSpend(items: [Item]) -> Double {
    items
        .filter { $0.status == .active }
        .reduce(0) { $0 + $1.yearlyAmount }
}
```

Also add `formatYearMonth` to `DateHelper` in `Date+Helpers.swift`:

```swift
private static let yearMonthFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM"
    f.locale = Locale(identifier: "en_US_POSIX")
    return f
}()

static func formatYearMonth(_ date: Date) -> String {
    yearMonthFormatter.string(from: date)
}
```

**Verify:** Build succeeds.

**Commit:** `feat: rewrite analytics with historical reconstruction from item metadata`

---

### Task 3: Update AnalyticsViewModel

**Files:**
- Modify: `SubTrkr/SubTrkr/ViewModels/AnalyticsViewModel.swift`

**Changes:**

Add payment loading, month range state, and new computed properties. Replace the entire file:

```swift
import Foundation

@Observable
final class AnalyticsViewModel {
    private let itemService = ItemService()
    private let paymentService = PaymentService()
    private let analyticsService = AnalyticsService()

    var items: [Item] = []
    var payments: [Payment] = []
    var isLoading = false
    var error: String?
    var selectedMonthRange: Int = 6

    // Existing analytics
    var monthlySpending: Double { analyticsService.calculateMonthlySpending(items: items) }
    var yearlySpending: Double { analyticsService.calculateYearlySpending(items: items) }
    var monthlySavings: Double { analyticsService.calculateMonthlySavings(items: items) }
    var spendingByCategory: [SpendingByCategory] { analyticsService.getSpendingByCategory(items: items) }
    var topExpenses: [TopExpense] { analyticsService.getTopExpenses(items: items) }
    var statusCounts: [ItemStatus: Int] { analyticsService.getStatusCounts(items: items) }

    // Reconstructed trends (use selectedMonthRange)
    var monthlyTrend: [MonthlySpending] {
        analyticsService.reconstructMonthlySpending(items: items, payments: payments, months: selectedMonthRange)
    }
    var categoryTrend: [CategoryMonthlySpending] {
        analyticsService.reconstructCategorySpending(items: items, payments: payments, months: selectedMonthRange)
    }
    var itemCountTrend: [MonthlyItemCount] {
        analyticsService.reconstructMonthlyItemCount(items: items, months: selectedMonthRange)
    }
    var projectedAnnualSpend: Double {
        analyticsService.calculateProjectedAnnualSpend(items: items)
    }

    var totalActiveItems: Int {
        items.filter { $0.status == .active }.count
    }

    var cancelledItems: [Item] {
        items.filter { $0.status == .cancelled || $0.status == .archived }
    }

    // MARK: - Actions

    func loadData() async {
        isLoading = true
        error = nil
        do {
            async let fetchedItems = itemService.getItems()
            async let fetchedPayments = paymentService.getPayments()
            let (i, p) = try await (fetchedItems, fetchedPayments)
            items = i
            payments = p
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}
```

**Verify:** Build succeeds.

**Commit:** `feat: update AnalyticsViewModel with payment loading and reconstructed trends`

---

### Task 4: Update DashboardView with Projected Annual Spend

**Files:**
- Modify: `SubTrkr/SubTrkr/Views/Dashboard/DashboardView.swift`
- Modify: `SubTrkr/SubTrkr/ViewModels/DashboardViewModel.swift`

**Changes in DashboardViewModel.swift:**

Add projected annual spend computed property (after `monthlySavings`):

```swift
var projectedAnnualSpend: Double {
    analyticsService.calculateProjectedAnnualSpend(items: items)
}
```

**Changes in DashboardView.swift:**

Replace the second `HStack` in `statsSection` (the one with Savings + Active cards) with a 2×2 grid that includes the projected annual spend:

Replace:
```swift
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
```

With:
```swift
HStack(spacing: 12) {
    StatsCard(
        title: "Projected",
        value: viewModel.projectedAnnualSpend.formattedCompact(currency: "USD"),
        subtitle: "next 12 months",
        icon: "chart.line.uptrend.xyaxis",
        color: .accentAmber
    )
    StatsCard(
        title: "Active",
        value: "\(viewModel.activeCount)",
        subtitle: "\(viewModel.subscriptionCount) subs, \(viewModel.billCount) bills",
        icon: "checkmark.circle",
        color: .brand
    )
}

HStack(spacing: 12) {
    StatsCard(
        title: "Savings",
        value: viewModel.monthlySavings.formatted(currency: "USD"),
        subtitle: "per month",
        icon: "arrow.down.circle",
        color: .statusPaused
    )
    Spacer()
}
```

**Verify:** Build succeeds.

**Commit:** `feat: add projected annual spend card to dashboard`

---

### Task 5: Rewrite AnalyticsView Trends Tab

**Files:**
- Modify: `SubTrkr/SubTrkr/Views/Analytics/AnalyticsView.swift`

**Changes:**

Replace the entire `trendsTab` computed property with a new version featuring:
1. Segmented month range picker (3/6/12)
2. Reconstructed spending trend (area chart)
3. Category spending over time (stacked area chart)
4. Subscription count over time (line chart)
5. Keep cancellation history at the bottom

```swift
// MARK: - Trends Tab

private var trendsTab: some View {
    VStack(spacing: 20) {
        // Month range picker
        Picker("Time Range", selection: $viewModel.selectedMonthRange) {
            Text("3 Mo").tag(3)
            Text("6 Mo").tag(6)
            Text("12 Mo").tag(12)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)

        // Spending Trend
        if !viewModel.monthlyTrend.isEmpty {
            spendingTrendChart
        }

        // Category Breakdown Over Time
        if !viewModel.categoryTrend.isEmpty {
            categoryTrendChart
        }

        // Subscription Count
        if !viewModel.itemCountTrend.isEmpty {
            itemCountChart
        }

        // Cancellation history
        if !viewModel.cancelledItems.isEmpty {
            cancellationHistory
        }
    }
}

private var spendingTrendChart: some View {
    VStack(alignment: .leading, spacing: 12) {
        Text("Spending Trend")
            .font(.headline)
            .foregroundStyle(.textPrimary)

        Chart(viewModel.monthlyTrend) { month in
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

private var categoryTrendChart: some View {
    VStack(alignment: .leading, spacing: 12) {
        Text("Spending by Category")
            .font(.headline)
            .foregroundStyle(.textPrimary)

        Chart(viewModel.categoryTrend) { entry in
            AreaMark(
                x: .value("Month", entry.shortMonth),
                y: .value("Amount", entry.total)
            )
            .foregroundStyle(by: .value("Category", entry.category))
        }
        .chartForegroundStyleScale(mapping: categoryColorMapping)
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

        // Legend
        let categories = Dictionary(grouping: viewModel.categoryTrend, by: \.category)
        FlowLayout(spacing: 8) {
            ForEach(Array(categories.keys.sorted()), id: \.self) { name in
                if let entry = categories[name]?.first {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color(hex: entry.color))
                            .frame(width: 8, height: 8)
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

private var categoryColorMapping: KeyValuePairs<String, Color> {
    // Build from current category trend data
    let unique = Dictionary(grouping: viewModel.categoryTrend, by: \.category)
    var pairs: [(String, Color)] = []
    for (name, entries) in unique.sorted(by: { $0.key < $1.key }) {
        if let color = entries.first?.color {
            pairs.append((name, Color(hex: color)))
        }
    }
    // KeyValuePairs cannot be dynamically constructed, so we use chartForegroundStyleScale with a range instead
    // This will be replaced with the range-based approach below
    return [:]
}

private var itemCountChart: some View {
    VStack(alignment: .leading, spacing: 12) {
        Text("Active Subscriptions")
            .font(.headline)
            .foregroundStyle(.textPrimary)

        Chart(viewModel.itemCountTrend) { month in
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

private var cancellationHistory: some View {
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
```

**IMPORTANT NOTE on `categoryColorMapping`:** The `chartForegroundStyleScale(mapping:)` with `KeyValuePairs` cannot be dynamically constructed. Instead, use the `chartForegroundStyleScale(range:)` approach. The implementer should use this pattern instead:

```swift
// In the categoryTrendChart, replace .chartForegroundStyleScale(mapping: categoryColorMapping) with:
.chartForegroundStyleScale(range: categoryColors)
```

And add a helper computed property:
```swift
private var categoryColors: [Color] {
    let unique = Dictionary(grouping: viewModel.categoryTrend, by: \.category)
    return unique.keys.sorted().compactMap { name in
        unique[name]?.first.map { Color(hex: $0.color) }
    }
}
```

Remove the `categoryColorMapping` computed property entirely.

**Also:** The `FlowLayout` doesn't exist in the project. Replace with a simple `HStack` wrapped in `LazyVGrid` or just use a horizontal scroll:

```swift
// Replace FlowLayout with:
LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], alignment: .leading, spacing: 4) {
    ForEach(Array(categories.keys.sorted()), id: \.self) { name in
        // ...
    }
}
```

**Verify:** Build succeeds.

**Commit:** `feat: rewrite analytics trends tab with reconstructed charts and time range picker`

---

### Task 6: Update AnalyticsView Overview Tab with Projected Spend

**Files:**
- Modify: `SubTrkr/SubTrkr/Views/Analytics/AnalyticsView.swift`

**Changes:**

In the `overviewTab`, add a "Projected Annual" card. Replace the second `HStack` (Savings + Active):

Replace:
```swift
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
```

With:
```swift
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
```

**Verify:** Build succeeds.

**Commit:** `feat: add projected annual spend to analytics overview`

---

### Task 7: Final Build Verification and Cleanup

**Files:**
- All modified files

**Steps:**

1. Full clean build:
```bash
rm -rf /tmp/SubTrkr-build
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project SubTrkr/SubTrkr.xcodeproj \
  -scheme SubTrkr \
  -destination 'platform=iOS Simulator,id=7E4DF3CA-3821-43D5-8444-DB0ECB82C91C' \
  -derivedDataPath /tmp/SubTrkr-build \
  build 2>&1 | tail -5
```

2. Verify no regressions:
   - Dashboard loads with projected annual spend card
   - Analytics Overview shows projected annual spend
   - Analytics Trends tab has month range picker (3/6/12)
   - Spending trend chart shows varying amounts per month
   - Category stacked area chart renders with proper colors
   - Subscription count line chart renders

3. If any issues, fix before final commit.

**Commit:** Only if cleanup changes were needed.
