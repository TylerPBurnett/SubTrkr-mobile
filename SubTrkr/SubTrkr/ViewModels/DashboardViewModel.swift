import Foundation

@Observable
final class DashboardViewModel {
    private let itemService = ItemService()
    private let analyticsService = AnalyticsService()
    private let categoryService = CategoryService()

    var items: [Item] = []
    var categories: [Category] = []
    var isLoading = false
    var error: String?

    // Computed analytics
    var monthlySpending: Double {
        analyticsService.calculateMonthlySpending(items: items)
    }

    var yearlySpending: Double {
        analyticsService.calculateYearlySpending(items: items)
    }

    var monthlySavings: Double {
        analyticsService.calculateMonthlySavings(items: items)
    }

    var spendingByCategory: [SpendingByCategory] {
        analyticsService.getSpendingByCategory(items: items)
    }

    var upcomingPayments: [Item] {
        analyticsService.getUpcomingPayments(items: items, days: 30)
    }

    var activeCount: Int {
        items.filter { $0.status == .active }.count
    }

    var trialCount: Int {
        items.filter { $0.status == .trial }.count
    }

    var subscriptionCount: Int {
        items.filter { $0.itemType == .subscription && $0.status == .active }.count
    }

    var billCount: Int {
        items.filter { $0.itemType == .bill && $0.status == .active }.count
    }

    // MARK: - Actions

    func loadData() async {
        isLoading = true
        error = nil
        do {
            async let fetchedItems = itemService.getItems()
            async let fetchedCategories = categoryService.getCategories()
            let (i, c) = try await (fetchedItems, fetchedCategories)
            items = i
            categories = c
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
        } catch {
            // Maintenance errors are non-critical
            print("Maintenance error: \(error)")
        }
    }
}
