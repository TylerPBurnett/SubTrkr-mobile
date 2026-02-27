import Foundation

@Observable
@MainActor
final class AnalyticsViewModel {
    private let itemService = ItemService()
    private let paymentService = PaymentService()
    private let analyticsService = AnalyticsService()

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
            async let fetchedItems = itemService.getItems()
            async let fetchedPayments = paymentService.getPayments()
            let (i, p) = try await (fetchedItems, fetchedPayments)
            items = i
            payments = p
            recomputeTrends()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}
