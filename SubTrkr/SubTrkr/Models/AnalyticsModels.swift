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
    let month: String
    let total: Double

    var monthDate: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.date(from: month)
    }

    var shortMonth: String {
        guard let date = monthDate else { return month }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: date)
    }
}

struct TopExpense: Identifiable {
    let id: String
    let name: String
    let monthlyAmount: Double
    let logoUrl: String?
    let categoryColor: String
}
