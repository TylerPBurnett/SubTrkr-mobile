import Foundation

extension Double {
    func formatted(currency: String = "USD") -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: NSNumber(value: self)) ?? "$\(String(format: "%.2f", self))"
    }

    func formattedCompact(currency: String = "USD") -> String {
        if self >= 1000 {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = currency
            formatter.maximumFractionDigits = 0
            return formatter.string(from: NSNumber(value: self)) ?? "$\(Int(self))"
        }
        return formatted(currency: currency)
    }
}
