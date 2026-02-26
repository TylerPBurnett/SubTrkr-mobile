import Foundation

extension Double {
    private static let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 2
        return f
    }()

    private static let currencyCompactFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = 0
        return f
    }()

    func formatted(currency: String = "USD") -> String {
        Double.currencyFormatter.string(from: NSNumber(value: self)) ?? "$\(String(format: "%.2f", self))"
    }

    func formattedCompact(currency: String = "USD") -> String {
        if self >= 1000 {
            return Double.currencyCompactFormatter.string(from: NSNumber(value: self)) ?? "$\(Int(self))"
        }
        return formatted(currency: currency)
    }
}
