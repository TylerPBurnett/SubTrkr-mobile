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

    // MARK: - Historical Reconstruction

    /// Determines if an item was actively costing money during a given month.
    private func wasItemActive(item: Item, monthStart: Date, monthEnd: Date) -> Bool {
        guard let startDateStr = item.startDate,
              let startDate = DateHelper.parseDate(startDateStr),
              startDate <= monthEnd else {
            return false
        }

        // Trial items don't cost money
        if item.status == .trial {
            return false
        }

        // Cancelled before this month started
        if let cancelledAtStr = item.cancelledAt,
           let cancelledAt = DateHelper.parseISO8601(cancelledAtStr),
           cancelledAt < monthStart {
            return false
        }

        // Archived before this month started
        if let archivedAtStr = item.archivedAt,
           let archivedAt = DateHelper.parseISO8601(archivedAtStr),
           archivedAt < monthStart {
            return false
        }

        // Paused for the entire month
        if let pausedAtStr = item.pausedAt,
           let pausedAt = DateHelper.parseISO8601(pausedAtStr),
           pausedAt < monthStart {
            if let pausedUntilStr = item.pausedUntil,
               let pausedUntil = DateHelper.parseDate(pausedUntilStr) {
                if pausedUntil > monthEnd {
                    return false
                }
            } else if item.status == .paused {
                return false
            }
        }

        return true
    }

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

        var paymentIndex: [String: [String: Double]] = [:]
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

    /// Active item count per month.
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
