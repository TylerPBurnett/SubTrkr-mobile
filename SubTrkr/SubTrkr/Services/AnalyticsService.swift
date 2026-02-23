import Foundation

final class AnalyticsService {

    // MARK: - Spending Calculations

    /// Total monthly spending from all active items
    func calculateMonthlySpending(items: [Item]) -> Double {
        items
            .filter { $0.status == .active }
            .reduce(0) { $0 + $1.monthlyAmount }
    }

    /// Total yearly spending from all active items
    func calculateYearlySpending(items: [Item]) -> Double {
        items
            .filter { $0.status == .active }
            .reduce(0) { $0 + $1.yearlyAmount }
    }

    /// Monthly savings from cancelled/archived items
    func calculateMonthlySavings(items: [Item]) -> Double {
        items
            .filter { $0.status == .cancelled || $0.status == .archived }
            .reduce(0) { $0 + $1.monthlyAmount }
    }

    // MARK: - Category Breakdown

    func getSpendingByCategory(items: [Item]) -> [SpendingByCategory] {
        let activeItems = items.filter { $0.status == .active }

        var categoryMap: [String: (color: String, total: Double, count: Int)] = [:]

        for item in activeItems {
            let name = item.categoryName
            let color = item.categoryColor
            let existing = categoryMap[name] ?? (color: color, total: 0, count: 0)
            categoryMap[name] = (
                color: color,
                total: existing.total + item.monthlyAmount,
                count: existing.count + 1
            )
        }

        return categoryMap.map { key, value in
            SpendingByCategory(
                category: key,
                color: value.color,
                total: value.total,
                count: value.count
            )
        }.sorted { $0.total > $1.total }
    }

    // MARK: - Monthly Trend

    func getMonthlySpendingTrend(items: [Item], months: Int = 6) -> [MonthlySpending] {
        let calendar = Calendar.current
        let now = Date.now

        var result: [MonthlySpending] = []

        for i in (0..<months).reversed() {
            guard let monthDate = calendar.date(byAdding: .month, value: -i, to: now) else { continue }

            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM"
            let monthKey = formatter.string(from: monthDate)

            // For simplicity, use current active items' monthly cost
            // A more sophisticated approach would track historical changes
            let total = items
                .filter { item in
                    guard item.status == .active || item.status == .trial else { return false }
                    // Item must have started before this month
                    if let startDate = item.startDate,
                       let start = DateHelper.parseDate(startDate) {
                        return start <= monthDate
                    }
                    return true
                }
                .reduce(0) { $0 + $1.monthlyAmount }

            result.append(MonthlySpending(month: monthKey, total: total))
        }

        return result
    }

    // MARK: - Top Expenses

    func getTopExpenses(items: [Item], limit: Int = 5) -> [TopExpense] {
        items
            .filter { $0.status == .active }
            .sorted { $0.monthlyAmount > $1.monthlyAmount }
            .prefix(limit)
            .map { item in
                TopExpense(
                    id: item.id,
                    name: item.name,
                    monthlyAmount: item.monthlyAmount,
                    logoUrl: item.logoUrl,
                    categoryColor: item.categoryColor
                )
            }
    }

    // MARK: - Upcoming Payments

    func getUpcomingPayments(items: [Item], days: Int = 30) -> [Item] {
        items
            .filter { $0.status == .active && $0.daysUntilDue != nil }
            .filter { ($0.daysUntilDue ?? Int.max) >= 0 && ($0.daysUntilDue ?? Int.max) <= days }
            .sorted { ($0.daysUntilDue ?? Int.max) < ($1.daysUntilDue ?? Int.max) }
    }

    // MARK: - Counts

    func getStatusCounts(items: [Item]) -> [ItemStatus: Int] {
        var counts: [ItemStatus: Int] = [:]
        for item in items {
            counts[item.status, default: 0] += 1
        }
        return counts
    }
}
