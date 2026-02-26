# SubTrkr — Analytics Charts Design

> Date: 2026-02-26
> Scope: Fix spending trend chart (#4) + add category breakdown, subscription count, projected annual spend

---

## Problem

The spending trend chart in `AnalyticsView` is flat because `getMonthlySpendingTrend()` retroactively applies current active items to all past months. A user with Netflix ($15/mo) added 3 months ago sees $15 for all 6 displayed months, not just the 3 months it existed.

## Solution

### 1. Fix Spending Trend Chart

Reconstruct monthly spending from item metadata. For each past month, an item's `monthlyAmount` counts if:
- `startDate` <= end of that month
- Not yet cancelled (`cancelledAt` is nil or after that month)
- Not yet archived (`archivedAt` is nil or after that month)
- Not paused during that month (`pausedAt`/`pausedUntil` range doesn't cover it)

If real `Payment` records exist for an item in that month, use the actual payment amount instead (handles mid-cycle price changes).

Visual: Same `AreaMark` + `LineMark` + `PointMark` combo. Add **segmented picker** above (3mo / 6mo / 12mo).

### 2. Category Breakdown Over Time (new — stacked area)

Same reconstructed monthly data, grouped by category. Each category gets a colored area band.

Visual: `AreaMark` with `.foregroundStyle(by: .value("Category", name))` for automatic stacking. Category colors from user's assignments. Legend below.

### 3. Subscription Count Over Time (new — line)

For each month, count active items using the same reconstruction logic.

Visual: `LineMark` + `PointMark`, single line, brand color. Y-axis integers.

### 4. Projected Annual Spend (new — stat card)

Sum of `yearlyAmount` for all active + trial items. Forward-looking from today.

Visual: New stat card on Dashboard. Uses `.accentAmber`.

---

## Architecture

### AnalyticsService changes

Replace `getMonthlySpendingTrend()` with:

```swift
// Accurate historical reconstruction using item metadata + optional payment records
func reconstructMonthlySpending(items: [Item], payments: [Payment], months: Int) -> [MonthlySpending]

// Same data grouped by category
func reconstructCategorySpending(items: [Item], payments: [Payment], months: Int) -> [CategoryMonthlySpending]

// Active item count per month
func reconstructMonthlyItemCount(items: [Item], months: Int) -> [MonthlyItemCount]

// Forward-looking annual projection
func calculateProjectedAnnualSpend(items: [Item]) -> Double
```

Core reconstruction logic (shared by all three methods):

```
for each month in range:
    monthStart = first day of month
    monthEnd = last day of month
    for each item:
        started = item.startDate <= monthEnd
        notCancelled = item.cancelledAt == nil || item.cancelledAt > monthStart
        notArchived = item.archivedAt == nil || item.archivedAt > monthStart
        notPaused = pausedAt/pausedUntil range doesn't fully cover [monthStart, monthEnd]
        if started && notCancelled && notArchived && notPaused:
            include item's monthlyAmount (or real payment if available)
```

### Model additions

```swift
struct CategoryMonthlySpending: Identifiable {
    let id = UUID()
    let month: Date
    let shortMonth: String
    let category: String
    let color: String
    let total: Double
}

struct MonthlyItemCount: Identifiable {
    let id = UUID()
    let month: Date
    let shortMonth: String
    let count: Int
}
```

### View changes

**AnalyticsView** (Trends tab):
- Add `Picker` with `.segmented` style for 3/6/12 month range
- Replace flat spending chart with reconstructed data
- Add category stacked area chart below
- Add subscription count line chart below

**DashboardView**:
- Add projected annual spend stat card (4th becomes 5th, or replace savings if needed)

**AnalyticsViewModel**:
- Add `@State selectedMonthRange: Int = 6`
- Add `allPayments: [Payment]` loaded in `.task`
- Expose: `monthlyTrend`, `categoryTrend`, `itemCountTrend`, `projectedAnnualSpend`

### No new files needed

All changes fit in existing files:
- `Services/AnalyticsService.swift`
- `Models/Analytics.swift` (add new structs)
- `Views/Analytics/AnalyticsView.swift`
- `Views/Dashboard/DashboardView.swift`
- `ViewModels/AnalyticsViewModel.swift` (if exists) or `DashboardViewModel.swift`

---

## Decisions

- **Single-currency (USD)** — no currency conversion needed in aggregations
- **Reconstruction over payment records** — items without payments still show in trends
- **Payment records preferred** when available — handles price changes mid-cycle
- **Trial items excluded** from spending totals (they cost $0 unless converted)
- **Segmented picker** for time range, not custom date range
