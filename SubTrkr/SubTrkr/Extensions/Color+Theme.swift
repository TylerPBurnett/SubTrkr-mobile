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
            (r, g, b, a) = (100, 116, 139, 255)
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

// MARK: - Adaptive Color Helper

extension Color {
    /// Creates a color that adapts between light and dark mode using explicit hex values.
    static func adaptive(light: String, dark: String) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(Color(hex: dark))
                : UIColor(Color(hex: light))
        })
    }

    /// Creates a color that adapts using explicit Color values.
    static func adaptive(light: Color, dark: Color) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(dark)
                : UIColor(light)
        })
    }
}

// MARK: - Background Tokens

extension Color {
    static let bgBase = Color.adaptive(light: "#e3e5e8", dark: "#0c0d0e")
    static let bgSurface = Color.adaptive(light: "#edeef2", dark: "#131415")
    static let bgCard = Color.adaptive(light: "#ffffff", dark: "#1e2022")
    static let bgInput = Color.adaptive(light: "#ffffff", dark: "#252729")
    static let bgHover = Color.adaptive(light: "#e4e6ea", dark: "#252729")
    static let bgActive = Color.adaptive(light: "#d8dbe1", dark: "#2e3032")
}

// MARK: - Text Tokens

extension Color {
    static let textPrimary = Color.adaptive(light: "#171717", dark: "#fafafa")
    static let textSecondary = Color.adaptive(light: "#525252", dark: "#a3a3a3")
    static let textMuted = Color.adaptive(light: "#a3a3a3", dark: "#525252")
    static let textInverse = Color.adaptive(light: "#ffffff", dark: "#171717")
}

// MARK: - Border Tokens

extension Color {
    static let borderDefault = Color.adaptive(light: "#e5e5e5", dark: "#2e2e2e")
    static let borderMuted = Color.adaptive(light: "#f5f5f5", dark: "#262626")
    static let borderStrong = Color.adaptive(light: "#d4d4d4", dark: "#404040")
}

// MARK: - Brand Tokens

extension Color {
    static let brand = Color(hex: "#22c55e")
    static let brandDark = Color.adaptive(light: "#16a34a", dark: "#4ade80")
    static let brandMuted = Color.adaptive(
        light: Color(hex: "#f0fdf4"),
        dark: Color(hex: "#22c55e").opacity(0.15)
    )
    static let brandText = Color.adaptive(light: "#166534", dark: "#4ade80")
}

// MARK: - Accent Colors

extension Color {
    static let accentBlue = Color.adaptive(light: "#3b82f6", dark: "#60a5fa")
    static let accentBlueMuted = Color.adaptive(
        light: Color(hex: "#dbeafe"),
        dark: Color(hex: "#3b82f6").opacity(0.2)
    )
    static let accentPurple = Color.adaptive(light: "#8b5cf6", dark: "#a78bfa")
    static let accentPurpleMuted = Color.adaptive(
        light: Color(hex: "#ede9fe"),
        dark: Color(hex: "#8b5cf6").opacity(0.2)
    )
    static let accentAmber = Color.adaptive(light: "#f59e0b", dark: "#fbbf24")
    static let accentAmberMuted = Color.adaptive(
        light: Color(hex: "#fef3c7"),
        dark: Color(hex: "#f59e0b").opacity(0.2)
    )
    static let accentRed = Color.adaptive(light: "#ef4444", dark: "#f87171")
    static let accentRedMuted = Color.adaptive(
        light: Color(hex: "#fee2e2"),
        dark: Color(hex: "#ef4444").opacity(0.2)
    )
    static let accentEmerald = Color.adaptive(light: "#10b981", dark: "#34d399")
    static let accentEmeraldMuted = Color.adaptive(
        light: Color(hex: "#d1fae5"),
        dark: Color(hex: "#10b981").opacity(0.2)
    )
    static let accentPink = Color.adaptive(light: "#ec4899", dark: "#f472b6")
    static let accentCyan = Color.adaptive(light: "#06b6d4", dark: "#22d3ee")
    static let accentGray = Color.adaptive(light: "#6b7280", dark: "#9ca3af")
}

// MARK: - Status Colors (mapped to accents)

extension Color {
    static let statusActive = Color.accentEmerald
    static let statusPaused = Color.accentAmber
    static let statusCancelled = Color.accentRed
    static let statusArchived = Color.accentGray
    static let statusTrial = Color.accentPurple

    static let statusActiveMuted = Color.accentEmeraldMuted
    static let statusPausedMuted = Color.accentAmberMuted
    static let statusCancelledMuted = Color.accentRedMuted
    static let statusTrialMuted = Color.accentPurpleMuted

    static func forStatus(_ status: ItemStatus) -> Color {
        switch status {
        case .active: return .statusActive
        case .paused: return .statusPaused
        case .cancelled: return .statusCancelled
        case .archived: return .statusArchived
        case .trial: return .statusTrial
        }
    }

    static func forStatusMuted(_ status: ItemStatus) -> Color {
        switch status {
        case .active: return .statusActiveMuted
        case .paused: return .statusPausedMuted
        case .cancelled: return .statusCancelledMuted
        case .archived: return .bgHover
        case .trial: return .statusTrialMuted
        }
    }

    // Category Color Palette (18 options matching desktop)
    static let categoryColors: [String] = [
        "#ef4444", "#f97316", "#f59e0b", "#eab308",
        "#84cc16", "#22c55e", "#10b981", "#14b8a6",
        "#06b6d4", "#0ea5e9", "#3b82f6", "#6366f1",
        "#8b5cf6", "#a855f7", "#d946ef", "#ec4899",
        "#f43f5e", "#64748b"
    ]
}

// MARK: - ShapeStyle Extensions

extension ShapeStyle where Self == Color {
    static var brand: Color { Color.brand }
    static var brandDark: Color { Color.brandDark }
    static var brandMuted: Color { Color.brandMuted }
    static var brandText: Color { Color.brandText }
    static var bgBase: Color { Color.bgBase }
    static var bgSurface: Color { Color.bgSurface }
    static var bgCard: Color { Color.bgCard }
    static var bgInput: Color { Color.bgInput }
    static var bgHover: Color { Color.bgHover }
    static var bgActive: Color { Color.bgActive }
    static var textPrimary: Color { Color.textPrimary }
    static var textSecondary: Color { Color.textSecondary }
    static var textMuted: Color { Color.textMuted }
    static var textInverse: Color { Color.textInverse }
    static var borderDefault: Color { Color.borderDefault }
    static var borderMuted: Color { Color.borderMuted }
    static var borderStrong: Color { Color.borderStrong }
    static var accentBlue: Color { Color.accentBlue }
    static var accentPurple: Color { Color.accentPurple }
    static var accentAmber: Color { Color.accentAmber }
    static var accentRed: Color { Color.accentRed }
    static var accentEmerald: Color { Color.accentEmerald }
    static var accentPink: Color { Color.accentPink }
    static var accentCyan: Color { Color.accentCyan }
    static var accentGray: Color { Color.accentGray }
    static var statusActive: Color { Color.statusActive }
    static var statusPaused: Color { Color.statusPaused }
    static var statusCancelled: Color { Color.statusCancelled }
    static var statusArchived: Color { Color.statusArchived }
    static var statusTrial: Color { Color.statusTrial }
}

// MARK: - Card Style Modifier

extension View {
    /// Standard card styling: bgCard background, border, corner radius, and depth.
    /// Use on VStack/HStack containers that act as cards.
    func cardStyle(cornerRadius: CGFloat = 16) -> some View {
        self
            .background(Color.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.borderDefault, lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.06), radius: 3, y: 1)
    }
}
