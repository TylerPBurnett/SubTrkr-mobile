import Foundation

@Observable
final class AnalyticsViewModel {
    private let itemService = ItemService()
    private let analyticsService = AnalyticsService()

    var items: [Item] = []
    var isLoading = false
    var error: String?

    // Analytics data
    var monthlySpending: Double { analyticsService.calculateMonthlySpending(items: items) }
    var yearlySpending: Double { analyticsService.calculateYearlySpending(items: items) }
    var monthlySavings: Double { analyticsService.calculateMonthlySavings(items: items) }
    var spendingByCategory: [SpendingByCategory] { analyticsService.getSpendingByCategory(items: items) }
    var monthlyTrend: [MonthlySpending] { analyticsService.getMonthlySpendingTrend(items: items) }
    var topExpenses: [TopExpense] { analyticsService.getTopExpenses(items: items) }
    var statusCounts: [ItemStatus: Int] { analyticsService.getStatusCounts(items: items) }

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
            items = try await itemService.getItems()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}
