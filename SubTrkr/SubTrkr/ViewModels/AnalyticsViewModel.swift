import Foundation

enum AnalyticsScope: String, CaseIterable, Identifiable {
    case all
    case bills
    case subscriptions

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All"
        case .bills: return "Bills"
        case .subscriptions: return "Subscriptions"
        }
    }

    var itemType: ItemType? {
        switch self {
        case .all: return nil
        case .bills: return .bill
        case .subscriptions: return .subscription
        }
    }

    var pluralLabel: String {
        switch self {
        case .all: return "Items"
        case .bills: return "Bills"
        case .subscriptions: return "Subscriptions"
        }
    }

    var emptyTitle: String {
        switch self {
        case .all: return "No analytics yet"
        case .bills: return "No bills yet"
        case .subscriptions: return "No subscriptions yet"
        }
    }

    var emptyMessage: String {
        switch self {
        case .all: return "Add subscriptions or bills to see your analytics"
        case .bills: return "Add a bill to see its spending trend and history"
        case .subscriptions: return "Add a subscription to see its spending trend and history"
        }
    }

    var emptyIcon: String {
        switch self {
        case .all: return "chart.bar"
        case .bills: return "receipt"
        case .subscriptions: return "creditcard"
        }
    }
}

@Observable
@MainActor
final class AnalyticsViewModel {
    private let itemService = ItemService()
    private let paymentService = PaymentService()
    private let analyticsService = AnalyticsService()
    private let maintenanceService = MaintenanceService.shared

    var items: [Item] = []
    var payments: [Payment] = []
    var isLoading = false
    var error: String?
    private var statusHistoryByItem: [String: [StatusHistory]] = [:]

    var selectedMonthRange: Int = 6 {
        didSet { recomputeTrends() }
    }

    var selectedScope: AnalyticsScope = .all {
        didSet { recomputeTrends() }
    }

    var filteredItems: [Item] {
        guard let itemType = selectedScope.itemType else { return items }
        return items.filter { $0.itemType == itemType }
    }

    var monthlySpending: Double { analyticsService.calculateMonthlySpending(items: filteredItems) }
    var yearlySpending: Double { analyticsService.calculateYearlySpending(items: filteredItems) }
    var monthlySavings: Double { analyticsService.calculateMonthlySavings(items: filteredItems) }
    var spendingByCategory: [SpendingByCategory] { analyticsService.getSpendingByCategory(items: filteredItems) }
    var topExpenses: [TopExpense] { analyticsService.getTopExpenses(items: filteredItems) }

    var totalActiveItems: Int {
        filteredItems.filter { $0.status == .active }.count
    }

    // Cached trend data (recomputed on data change or range change)
    private(set) var monthlyTrend: [MonthlySpending] = []
    private(set) var projectedAnnualSpend: Double = 0
    private(set) var cancelledItems: [Item] = []

    private func recomputeTrends() {
        let scopedItems = filteredItems

        monthlyTrend = analyticsService.reconstructMonthlySpending(
            items: scopedItems,
            payments: payments,
            statusHistoryByItem: statusHistoryByItem,
            months: selectedMonthRange
        )
        projectedAnnualSpend = analyticsService.calculateProjectedAnnualSpend(items: scopedItems)
        cancelledItems = scopedItems
            .filter { $0.status == .cancelled || $0.status == .archived }
            .sorted { lhs, rhs in
                let lhsDate = lhs.cancellationDateFormatted ?? lhs.cancelledAtFormatted ?? lhs.archivedAtFormatted ?? .distantPast
                let rhsDate = rhs.cancellationDateFormatted ?? rhs.cancelledAtFormatted ?? rhs.archivedAtFormatted ?? .distantPast
                return lhsDate > rhsDate
            }
    }

    // MARK: - Actions

    func loadData() async {
        isLoading = true
        error = nil
        do {
            async let fetchedItems = itemService.getItems()
            async let fetchedStatusHistory = itemService.getAllStatusHistory()
            items = try await fetchedItems

            // Payment history enriches trends, but summary metrics should still load without it.
            do {
                payments = try await paymentService.getPayments()
            } catch {
                payments = []
                self.error = "Payment history unavailable: \(error.localizedDescription)"
            }

            do {
                let statusHistory = try await fetchedStatusHistory
                statusHistoryByItem = Dictionary(grouping: statusHistory, by: \.itemId)
            } catch {
                statusHistoryByItem = [:]
                if self.error == nil {
                    self.error = "Status history unavailable: \(error.localizedDescription)"
                }
            }

            recomputeTrends()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func runMaintenance(userId: String) async -> Bool {
        do {
            return try await maintenanceService.runIfNeeded(userId: userId)
        } catch {
            self.error = "Maintenance failed: \(error.localizedDescription)"
            return false
        }
    }
}
