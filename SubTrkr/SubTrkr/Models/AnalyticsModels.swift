import Foundation

struct SpendingByCategory: Identifiable {
    let id = UUID()
    let category: String
    let color: String
    let total: Double
    let count: Int
}

struct MonthlySpending: Identifiable {
    let id = UUID()
    let month: Date
    let total: Double

    var shortMonth: String {
        DateHelper.formatShortMonth(month)
    }
}

struct TopExpense: Identifiable {
    let id: String
    let name: String
    let monthlyAmount: Double
    let logoUrl: String?
    let categoryColor: String
}
