import Foundation

final class AnalyticsService {
    private struct StatusTransition {
        let status: ItemStatus
        let effectiveDate: Date
        let action: String?
        let recordedAt: Date?
    }

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
    private func wasItemActive(item: Item, monthStart: Date, monthEndExclusive: Date, statusHistory: [StatusHistory]) -> Bool {
        guard !statusHistory.isEmpty else {
            return wasItemActiveUsingCurrentFields(item: item, monthStart: monthStart, monthEndExclusive: monthEndExclusive)
        }

        // Try startDate first, fall back to createdAt
        let startDate: Date
        if let parsed = item.startDateFormatted {
            startDate = parsed
        } else if let createdAtStr = item.createdAt, let parsed = DateHelper.parseISO8601(createdAtStr) {
            startDate = parsed
        } else {
            return false  // No date info at all
        }

        let calendar = Calendar.current
        let normalizedStartDate = calendar.startOfDay(for: startDate)

        guard normalizedStartDate < monthEndExclusive else {
            return false
        }

        let transitions = statusTransitions(for: statusHistory)
        var currentStatus = inferredInitialStatus(for: item, transitions: transitions)
        var segmentStart = normalizedStartDate

        for transition in transitions {
            let transitionDate = calendar.startOfDay(for: transition.effectiveDate)

            if transitionDate <= segmentStart {
                currentStatus = transition.status
                continue
            }

            if currentStatus == .active && segmentStart < monthEndExclusive && transitionDate > monthStart {
                return true
            }

            guard transitionDate < monthEndExclusive else { break }

            currentStatus = transition.status
            segmentStart = transitionDate
        }

        return currentStatus == .active && segmentStart < monthEndExclusive
    }

    private func wasItemActiveUsingCurrentFields(item: Item, monthStart: Date, monthEndExclusive: Date) -> Bool {
        let calendar = Calendar.current
        let monthEnd = calendar.date(byAdding: .second, value: -1, to: monthEndExclusive) ?? monthEndExclusive

        let startDate: Date
        if let parsed = item.startDateFormatted {
            startDate = parsed
        } else if let createdAtStr = item.createdAt, let parsed = DateHelper.parseISO8601(createdAtStr) {
            startDate = parsed
        } else {
            return false
        }

        guard startDate <= monthEnd else {
            return false
        }

        if item.status == .trial {
            return false
        }

        if let cancellationDate = item.cancellationDateFormatted,
           DateHelper.isOnOrBeforeDay(cancellationDate, comparedTo: monthStart) {
            return false
        }

        if let cancelledAt = item.cancelledAtFormatted,
           DateHelper.isOnOrBeforeDay(cancelledAt, comparedTo: monthStart) {
            return false
        }

        if let archivedAt = item.archivedAtFormatted,
           DateHelper.isOnOrBeforeDay(archivedAt, comparedTo: monthStart) {
            return false
        }

        if let pausedAt = item.pausedAtFormatted,
           DateHelper.isOnOrBeforeDay(pausedAt, comparedTo: monthStart) {
            if let pausedUntil = item.pausedUntilFormatted {
                if DateHelper.isOnOrBeforeDay(monthEnd, comparedTo: pausedUntil) {
                    return false
                }
            } else if item.status == .paused {
                return false
            }
        }

        return true
    }

    private func monthRange(for date: Date) -> (start: Date, endExclusive: Date) {
        let calendar = Calendar.current
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
        let end = calendar.date(byAdding: .month, value: 1, to: start)!
        return (start, end)
    }

    private func statusTransitions(for statusHistory: [StatusHistory]) -> [StatusTransition] {
        let calendar = Calendar.current

        return statusHistory.compactMap { entry in
            let effectiveDate = entry.effectiveDateFormatted
                ?? entry.changedAtFormatted.map { calendar.startOfDay(for: $0) }

            guard let effectiveDate else { return nil }

            return StatusTransition(
                status: entry.status,
                effectiveDate: calendar.startOfDay(for: effectiveDate),
                action: entry.metadata?.action,
                recordedAt: entry.changedAtFormatted
            )
        }
        .sorted { lhs, rhs in
            if lhs.effectiveDate != rhs.effectiveDate {
                return lhs.effectiveDate < rhs.effectiveDate
            }

            return (lhs.recordedAt ?? lhs.effectiveDate) < (rhs.recordedAt ?? rhs.effectiveDate)
        }
    }

    private func inferredInitialStatus(for item: Item, transitions: [StatusTransition]) -> ItemStatus {
        if let firstTransition = transitions.first, firstTransition.action == "convert_trial" {
            return .trial
        }

        if item.status == .trial || item.trialStartedAtFormatted != nil {
            return .trial
        }

        return .active
    }

    /// Reconstructed monthly spending using item metadata + real payments when available.
    func reconstructMonthlySpending(items: [Item], payments: [Payment], statusHistoryByItem: [String: [StatusHistory]] = [:], months: Int) -> [MonthlySpending] {
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
            let (monthStart, monthEndExclusive) = monthRange(for: monthDate)
            let monthKey = DateHelper.formatYearMonth(monthStart)

            var total = 0.0
            for item in items {
                if let paidAmount = paymentIndex[item.id]?[monthKey] {
                    total += paidAmount
                } else if wasItemActive(
                    item: item,
                    monthStart: monthStart,
                    monthEndExclusive: monthEndExclusive,
                    statusHistory: statusHistoryByItem[item.id] ?? []
                ) {
                    total += item.monthlyAmount
                }
            }

            result.append(MonthlySpending(month: monthStart, total: total))
        }

        return result
    }

    /// Category spending over time (for stacked area chart).
    func reconstructCategorySpending(items: [Item], payments: [Payment], statusHistoryByItem: [String: [StatusHistory]] = [:], months: Int) -> [CategoryMonthlySpending] {
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
            let (monthStart, monthEndExclusive) = monthRange(for: monthDate)
            let monthKey = DateHelper.formatYearMonth(monthStart)

            var categoryTotals: [String: (color: String, total: Double)] = [:]

            for item in items {
                var amount = 0.0
                if let paidAmount = paymentIndex[item.id]?[monthKey] {
                    amount = paidAmount
                } else if wasItemActive(
                    item: item,
                    monthStart: monthStart,
                    monthEndExclusive: monthEndExclusive,
                    statusHistory: statusHistoryByItem[item.id] ?? []
                ) {
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
    func reconstructMonthlyItemCount(items: [Item], statusHistoryByItem: [String: [StatusHistory]] = [:], months: Int) -> [MonthlyItemCount] {
        let calendar = Calendar.current
        let now = Date.now

        var result: [MonthlyItemCount] = []

        for i in (0..<months).reversed() {
            guard let monthDate = calendar.date(byAdding: .month, value: -i, to: now) else { continue }
            let (monthStart, monthEndExclusive) = monthRange(for: monthDate)

            let count = items.filter {
                wasItemActive(
                    item: $0,
                    monthStart: monthStart,
                    monthEndExclusive: monthEndExclusive,
                    statusHistory: statusHistoryByItem[$0.id] ?? []
                )
            }.count
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
