import SwiftUI

struct CurrencyText: View {
    let amount: Double
    let currency: String
    var style: CurrencyStyle = .standard

    enum CurrencyStyle {
        case standard
        case large
        case compact
    }

    var body: some View {
        switch style {
        case .standard:
            Text(amount.formatted(currency: currency))
                .font(.system(.body, design: .monospaced))
                .fontWeight(.semibold)
        case .large:
            Text(amount.formatted(currency: currency))
                .font(.system(.title2, design: .monospaced))
                .fontWeight(.bold)
        case .compact:
            Text(amount.formattedCompact(currency: currency))
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.medium)
        }
    }
}
