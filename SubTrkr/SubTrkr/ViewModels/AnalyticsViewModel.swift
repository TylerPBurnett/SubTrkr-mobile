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

    // Reconstructed trends
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
