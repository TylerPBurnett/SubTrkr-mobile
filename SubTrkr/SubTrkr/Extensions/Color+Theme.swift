import SwiftUI

// MARK: - Hex Color Support

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let r, g, b, a: UInt64
        switch hex.count {
        case 6:
            (r, g, b, a) = (int >> 16, int >> 8 & 0xFF, int & 0xFF, 255)
        case 8:
            (r, g, b, a) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b, a) = (100, 116, 139, 255) // fallback slate
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Theme Colors

extension Color {
    // Brand
    static let brand = Color(hex: "#22c55e")
    static let brandDark = Color(hex: "#16a34a")

    // Backgrounds
    static let bgBase = Color(.systemBackground)
    static let bgSurface = Color(.secondarySystemBackground)
    static let bgCard = Color(.tertiarySystemBackground)

    // Text
    static let textPrimary = Color(.label)
    static let textSecondary = Color(.secondaryLabel)
    static let textTertiary = Color(.tertiaryLabel)

    // Status Colors
    static let statusActive = Color(hex: "#22c55e")
    static let statusPaused = Color(hex: "#f59e0b")
    static let statusCancelled = Color(hex: "#ef4444")
    static let statusArchived = Color(hex: "#64748b")
    static let statusTrial = Color(hex: "#8b5cf6")

    // Category Color Palette (18 options matching desktop)
    static let categoryColors: [String] = [
        "#ef4444", "#f97316", "#f59e0b", "#eab308",
        "#84cc16", "#22c55e", "#10b981", "#14b8a6",
        "#06b6d4", "#0ea5e9", "#3b82f6", "#6366f1",
        "#8b5cf6", "#a855f7", "#d946ef", "#ec4899",
        "#f43f5e", "#64748b"
    ]

    static func forStatus(_ status: ItemStatus) -> Color {
        switch status {
        case .active: return .statusActive
        case .paused: return .statusPaused
        case .cancelled: return .statusCancelled
        case .archived: return .statusArchived
        case .trial: return .statusTrial
        }
    }
}

// MARK: - ShapeStyle Extensions
// Allows short-form syntax: .foregroundStyle(.brand), .foregroundStyle(.textTertiary), etc.

extension ShapeStyle where Self == Color {
    static var brand: Color { .init(hex: "#22c55e") }
    static var brandDark: Color { .init(hex: "#16a34a") }
    static var bgBase: Color { Color(.systemBackground) }
    static var bgSurface: Color { Color(.secondarySystemBackground) }
    static var bgCard: Color { Color(.tertiarySystemBackground) }
    static var textPrimary: Color { Color(.label) }
    static var textSecondary: Color { Color(.secondaryLabel) }
    static var textTertiary: Color { Color(.tertiaryLabel) }
    static var statusActive: Color { .init(hex: "#22c55e") }
    static var statusPaused: Color { .init(hex: "#f59e0b") }
    static var statusCancelled: Color { .init(hex: "#ef4444") }
    static var statusArchived: Color { .init(hex: "#64748b") }
    static var statusTrial: Color { .init(hex: "#8b5cf6") }
}
