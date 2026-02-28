import Foundation

@Observable
@MainActor
final class AnalyticsViewModel {
    private let itemService = ItemService()
    private let paymentService = PaymentService()
    private let analyticsService = AnalyticsService()
    private let notificationService = NotificationService()

    var items: [Item] = []
    var payments: [Payment] = []
    var isLoading = false
    var error: String?

    var selectedMonthRange: Int = 6 {
        didSet { recomputeTrends() }
    }

    // Existing analytics (lightweight — no history reconstruction)
    var monthlySpending: Double { analyticsService.calculateMonthlySpending(items: items) }
    var yearlySpending: Double { analyticsService.calculateYearlySpending(items: items) }
    var monthlySavings: Double { analyticsService.calculateMonthlySavings(items: items) }
    var spendingByCategory: [SpendingByCategory] { analyticsService.getSpendingByCategory(items: items) }
    var topExpenses: [TopExpense] { analyticsService.getTopExpenses(items: items) }
    var statusCounts: [ItemStatus: Int] { analyticsService.getStatusCounts(items: items) }

    var totalActiveItems: Int {
        items.filter { $0.status == .active }.count
    }

    // Cached trend data (recomputed on data change or range change)
    private(set) var monthlyTrend: [MonthlySpending] = []
    private(set) var categoryTrend: [CategoryMonthlySpending] = []
    private(set) var itemCountTrend: [MonthlyItemCount] = []
    private(set) var projectedAnnualSpend: Double = 0
    private(set) var cancelledItems: [Item] = []

    private func recomputeTrends() {
        monthlyTrend = analyticsService.reconstructMonthlySpending(items: items, payments: payments, months: selectedMonthRange)
        categoryTrend = analyticsService.reconstructCategorySpending(items: items, payments: payments, months: selectedMonthRange)
        itemCountTrend = analyticsService.reconstructMonthlyItemCount(items: items, months: selectedMonthRange)
        projectedAnnualSpend = analyticsService.calculateProjectedAnnualSpend(items: items)
        cancelledItems = items.filter { $0.status == .cancelled || $0.status == .archived }
    }

    // MARK: - Actions

    func loadData() async {
        isLoading = true
        error = nil
        do {
            items = try await itemService.getItems()

            // Payment history enriches trends, but summary metrics should still load without it.
            do {
                payments = try await paymentService.getPayments()
            } catch {
                payments = []
                self.error = "Payment history unavailable: \(error.localizedDescription)"
            }
            recomputeTrends()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func runMaintenance(userId: String) async {
        do {
            try await itemService.advancePastDueItems()
            try await itemService.archivePastCancellations()
            try await itemService.resumePausedItems()
            try await itemService.handleExpiredTrials(userId: userId)

            // Keep notification schedule in sync with any maintenance-driven item changes.
            if UserDefaults.standard.bool(forKey: "notificationsEnabled") {
                let allItems = try await itemService.getItems()
                let days = UserDefaults.standard.integer(forKey: "defaultReminderDays")
                await notificationService.rescheduleAllNotifications(
                    items: allItems,
                    daysBefore: days > 0 ? days : 3
                )
            }
        } catch {
            self.error = "Maintenance failed: \(error.localizedDescription)"
        }
    }
}
