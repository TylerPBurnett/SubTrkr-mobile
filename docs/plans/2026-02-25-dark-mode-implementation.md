# Dark Mode & Theme System Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement a full light/dark adaptive color system matching the SubTrkr desktop design language, with card depth treatments, border system, and an appearance toggle in Settings.

**Architecture:** Replace all color tokens in `Color+Theme.swift` with adaptive `UIColor { traitCollection in }` wrappers. Add border and shadow view modifiers for card depth. Wire appearance preference via `@AppStorage` on the root `ContentView`. Every view file gets updated to use the new tokens — no new Swift files needed.

**Tech Stack:** SwiftUI, UIKit (for `UIColor` dynamic provider), `@AppStorage` for persistence

---

### Task 1: Rewrite Color+Theme.swift — Background & Text Tokens

**Files:**
- Modify: `SubTrkr/SubTrkr/Extensions/Color+Theme.swift`

**Step 1: Replace the adaptive color helper and background tokens**

Replace the entire contents of `Color+Theme.swift` with the new adaptive color system. Start with the foundation: hex init, adaptive helper, backgrounds, and text.

```swift
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
```

**Step 2: Build to verify no compile errors**

Run:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project SubTrkr/SubTrkr.xcodeproj \
  -scheme SubTrkr \
  -destination 'platform=iOS Simulator,id=7E4DF3CA-3821-43D5-8444-DB0ECB82C91C' \
  -derivedDataPath /tmp/SubTrkr-build \
  build 2>&1 | tail -20
```
Expected: BUILD SUCCEEDED (there will be warnings in views using old `textTertiary` token — this is fine, we'll fix those next)

**Step 3: Commit**

```bash
git add SubTrkr/SubTrkr/Extensions/Color+Theme.swift
git commit -m "feat: replace color tokens with adaptive light/dark theme system

Adds explicit hex values from design handoff for both light and dark
appearances. Introduces border tokens, accent colors, status muted
variants, and a cardStyle() view modifier for consistent card depth."
```

---

### Task 2: Fix textTertiary References

The old theme had `textTertiary` (from UIKit's `.tertiaryLabel`). The new design uses `textMuted` instead. Many views reference `.textTertiary` — we need to replace them all.

**Files:**
- Modify: All view files that reference `textTertiary`

**Step 1: Find all references**

Run:
```bash
grep -rn "textTertiary" SubTrkr/SubTrkr/
```

**Step 2: Replace all `textTertiary` → `textMuted`**

In every file found, replace `.textTertiary` with `.textMuted`. The semantic mapping is the same (placeholders, disabled, de-emphasized hints). Files expected:
- `DashboardView.swift` — category legend counts, upcoming dates, billing cycle labels
- `ItemListView.swift` — billing dates, cycle labels, filter icons
- `ItemDetailView.swift` — section labels, payment dates
- `ItemFormView.swift` — search icon
- `AuthScreen.swift` — dividers, input borders, icons
- `AnalyticsView.swift` — chart axis labels, category counts, subtitles
- `SettingsView.swift` — version/platform values, channel labels
- `NotificationSettingsView.swift` — "Desktop only" labels
- `EmptyState.swift` — icon color (but this should stay — empty state icons should be muted)

**Step 3: Build to verify**

Run the xcodebuild command. Expected: BUILD SUCCEEDED with no references to `textTertiary`.

**Step 4: Commit**

```bash
git add -A
git commit -m "refactor: rename textTertiary to textMuted across all views

Aligns with the design handoff token naming. Semantic meaning unchanged."
```

---

### Task 3: Add Appearance Toggle to Settings

**Files:**
- Modify: `SubTrkr/SubTrkr/Views/ContentView.swift`
- Modify: `SubTrkr/SubTrkr/Views/Settings/SettingsView.swift`

**Step 1: Add appearance mode to ContentView**

In `ContentView.swift`, add `@AppStorage` and apply `.preferredColorScheme`:

```swift
import SwiftUI

struct ContentView: View {
    @Environment(AuthService.self) private var authService
    @AppStorage("appearanceMode") private var appearanceMode: String = "system"

    var body: some View {
        Group {
            if authService.isLoading {
                LaunchScreen()
            } else if authService.isAuthenticated {
                MainTabView()
            } else {
                AuthScreen()
            }
        }
        .animation(.smooth(duration: 0.3), value: authService.isAuthenticated)
        .animation(.smooth(duration: 0.3), value: authService.isLoading)
        .preferredColorScheme(colorScheme)
    }

    private var colorScheme: ColorScheme? {
        switch appearanceMode {
        case "light": return .light
        case "dark": return .dark
        default: return nil // system
        }
    }
}
```

The `LaunchScreen` and `MainTabView` stay unchanged.

**Step 2: Add Appearance section to SettingsView**

In `SettingsView.swift`, add a new section before the Account section:

```swift
// Appearance
Section {
    Picker(selection: $appearanceMode) {
        Text("System").tag("system")
        Text("Light").tag("light")
        Text("Dark").tag("dark")
    } label: {
        Label("Appearance", systemImage: "circle.lefthalf.filled")
            .foregroundStyle(.textPrimary)
    }
} header: {
    Text("Appearance")
}
```

Add the `@AppStorage` property at the top of `SettingsView`:
```swift
@AppStorage("appearanceMode") private var appearanceMode: String = "system"
```

**Step 3: Build and verify**

Run xcodebuild. Expected: BUILD SUCCEEDED.

**Step 4: Commit**

```bash
git add SubTrkr/SubTrkr/Views/ContentView.swift SubTrkr/SubTrkr/Views/Settings/SettingsView.swift
git commit -m "feat: add appearance toggle (System/Light/Dark) in Settings

Persisted via @AppStorage, applied via preferredColorScheme on root view."
```

---

### Task 4: Update DashboardView with Card Depth

**Files:**
- Modify: `SubTrkr/SubTrkr/Views/Dashboard/DashboardView.swift`

**Step 1: Apply cardStyle() to cards and update stat colors**

Changes:
1. In `StatsCard.body`: replace `.background(Color.bgCard).clipShape(...)` with `.cardStyle(cornerRadius: 14)`
2. In `categoryChart`: replace `.background(Color.bgCard).clipShape(...)` with `.cardStyle()`
3. In `upcomingSection`: replace `.background(Color.bgCard).clipShape(...)` with `.cardStyle()`
4. In `StatsCard`: change `.font(.system(size: 20, weight: .bold, design: .monospaced))` to `.font(.system(size: 20, weight: .heavy, design: .monospaced))` for the brutalist stat number feel
5. Replace `.foregroundStyle(.textTertiary)` with `.foregroundStyle(.textMuted)` (if not already done in Task 2)

**Step 2: Build and verify**

**Step 3: Commit**

```bash
git add SubTrkr/SubTrkr/Views/Dashboard/DashboardView.swift
git commit -m "feat: apply card depth treatment and heavy font to dashboard"
```

---

### Task 5: Update ItemListView with Card Depth

**Files:**
- Modify: `SubTrkr/SubTrkr/Views/Items/ItemListView.swift`

**Step 1: Apply cardStyle() and fix shimmer for dark mode**

Changes:
1. In `ItemRow.body`: replace `.background(Color.bgCard).clipShape(RoundedRectangle(cornerRadius: 14))` with `.cardStyle(cornerRadius: 14)`
2. In `itemsList`: change `.listRowBackground(Color.bgCard)` to `.listRowBackground(Color.clear)` (the card itself handles its own background now)
3. In `loadingView`: replace `.fill(Color.bgCard)` with `.fill(Color.bgCard)` and add border overlay — or better, apply cardStyle to each shimmer placeholder
4. In `ShimmerModifier`: change `.white.opacity(0.1)` to `Color.adaptive(light: .white.opacity(0.15), dark: .white.opacity(0.06))` for better dark mode shimmer

**Step 2: Build and verify**

**Step 3: Commit**

```bash
git add SubTrkr/SubTrkr/Views/Items/ItemListView.swift
git commit -m "feat: apply card depth to item list rows and fix dark mode shimmer"
```

---

### Task 6: Update ItemDetailView with Card Depth

**Files:**
- Modify: `SubTrkr/SubTrkr/Views/Items/ItemDetailView.swift`

**Step 1: Apply cardStyle() to all card containers**

Changes:
1. `detailsSection`: replace `.background(Color.bgCard).clipShape(...)` with `.cardStyle(cornerRadius: 14)`
2. `notesSection`: same replacement
3. `paymentHistorySection`: same replacement
4. Status action buttons: replace `.background(Color.bgCard).clipShape(...)` with `.cardStyle(cornerRadius: 12)`
5. Hero price: change `.font(.system(size: 32, weight: .bold, design: .monospaced))` to `.font(.system(size: 32, weight: .heavy, design: .monospaced))`

**Step 2: Build and verify**

**Step 3: Commit**

```bash
git add SubTrkr/SubTrkr/Views/Items/ItemDetailView.swift
git commit -m "feat: apply card depth and heavy price font to item detail"
```

---

### Task 7: Update AnalyticsView with Card Depth

**Files:**
- Modify: `SubTrkr/SubTrkr/Views/Analytics/AnalyticsView.swift`

**Step 1: Apply cardStyle() and update stat accent colors**

Changes:
1. All `.background(Color.bgCard).clipShape(...)` → `.cardStyle()` (6 instances: top expenses, status distribution, trends card, cancellation history, category list)
2. `AnalyticsCard.body`: replace `.background(Color.bgCard).clipShape(...)` with `.cardStyle(cornerRadius: 14)`
3. `AnalyticsCard`: change stat value font to `.heavy` weight
4. Update the chart gradient colors: keep `.brand` for the line, gradient should use `.brand.opacity(0.3)` to `.brand.opacity(0.02)` (slightly lower floor for dark mode)

**Step 2: Build and verify**

**Step 3: Commit**

```bash
git add SubTrkr/SubTrkr/Views/Analytics/AnalyticsView.swift
git commit -m "feat: apply card depth to analytics view"
```

---

### Task 8: Update AuthScreen with Border Treatment

**Files:**
- Modify: `SubTrkr/SubTrkr/Views/Auth/AuthScreen.swift`

**Step 1: Update input and button styling**

Changes:
1. `AuthTextField`: replace `.background(Color.bgSurface)` with `.background(Color.bgInput)` and update border from `.stroke(Color.textTertiary.opacity(0.2))` to `.stroke(Color.borderStrong, lineWidth: 1.5)` for the brutalist 2px-ish border feel
2. `OAuthButton`: same border update — `.stroke(Color.borderDefault, lineWidth: 1)`
3. Magic link button: same border update
4. Divider lines: change `Color.textTertiary.opacity(0.3)` to `Color.borderDefault`
5. `PasswordStrengthBar`: change track from `Color.textTertiary.opacity(0.2)` to `Color.borderMuted`

**Step 2: Build and verify**

**Step 3: Commit**

```bash
git add SubTrkr/SubTrkr/Views/Auth/AuthScreen.swift
git commit -m "feat: update auth screen with design handoff border treatment"
```

---

### Task 9: Update StatusBadge with Muted Accent Backgrounds

**Files:**
- Modify: `SubTrkr/SubTrkr/Views/Components/StatusBadge.swift`

**Step 1: Use the muted status tokens**

Replace the hardcoded `.opacity(0.15)` background with the proper muted token:

```swift
struct StatusBadge: View {
    let status: ItemStatus

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.iconName)
                .font(.system(size: 9))
            Text(status.displayName)
                .font(.system(size: 11, weight: .semibold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.forStatusMuted(status))
        .foregroundStyle(Color.forStatus(status))
        .clipShape(Capsule())
    }
}
```

**Step 2: Build and verify**

**Step 3: Commit**

```bash
git add SubTrkr/SubTrkr/Views/Components/StatusBadge.swift
git commit -m "feat: use adaptive muted backgrounds for status badges"
```

---

### Task 10: Update AccentColor Asset Catalog

**Files:**
- Modify: `SubTrkr/SubTrkr/Assets.xcassets/AccentColor.colorset/Contents.json`

**Step 1: Add dark appearance variant**

Replace the contents with:

```json
{
  "colors" : [
    {
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "alpha" : "1.000",
          "blue" : "0.369",
          "green" : "0.773",
          "red" : "0.133"
        }
      },
      "idiom" : "universal"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "dark"
        }
      ],
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "alpha" : "1.000",
          "blue" : "0.369",
          "green" : "0.773",
          "red" : "0.133"
        }
      },
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

(Same green `#22c55e` for both — brand color doesn't change between modes.)

**Step 2: Commit**

```bash
git add SubTrkr/SubTrkr/Assets.xcassets/AccentColor.colorset/Contents.json
git commit -m "feat: add dark appearance variant to AccentColor asset"
```

---

### Task 11: Update Remaining Views (ItemFormView, StatusChangeSheet, NotificationSettingsView)

**Files:**
- Modify: `SubTrkr/SubTrkr/Views/Items/ItemFormView.swift`
- Modify: `SubTrkr/SubTrkr/Views/Items/StatusChangeSheet.swift`
- Modify: `SubTrkr/SubTrkr/Views/Settings/NotificationSettingsView.swift`

**Step 1: ItemFormView**

Minimal changes needed — Form already inherits system styling. Just verify:
- `.foregroundStyle(.brand)` references stay (brand is already adaptive-safe)
- `.foregroundStyle(.textTertiary)` → `.textMuted` if not done in Task 2
- `.statusTrial` reference on line 249 — already adaptive via accent system

**Step 2: StatusChangeSheet**

- `.foregroundStyle(.red)` on error text (line 88) → `.foregroundStyle(.accentRed)`
- Status color functions already use `.statusPaused`, `.statusCancelled`, etc. — these are now adaptive via Task 1

**Step 3: NotificationSettingsView**

- `.tint(.brand)` on Toggle — already fine
- `.textTertiary` → `.textMuted` if not done in Task 2

**Step 4: Build full project**

Run xcodebuild. Expected: BUILD SUCCEEDED with zero warnings related to undefined color tokens.

**Step 5: Commit**

```bash
git add SubTrkr/SubTrkr/Views/Items/ItemFormView.swift SubTrkr/SubTrkr/Views/Items/StatusChangeSheet.swift SubTrkr/SubTrkr/Views/Settings/NotificationSettingsView.swift
git commit -m "feat: update remaining views for adaptive theme tokens"
```

---

### Task 12: Final Build Verification & Visual QA

**Step 1: Clean build**

```bash
rm -rf /tmp/SubTrkr-build
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project SubTrkr/SubTrkr.xcodeproj \
  -scheme SubTrkr \
  -destination 'platform=iOS Simulator,id=7E4DF3CA-3821-43D5-8444-DB0ECB82C91C' \
  -derivedDataPath /tmp/SubTrkr-build \
  build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

**Step 2: Install and launch on simulator**

```bash
xcrun simctl install 7E4DF3CA-3821-43D5-8444-DB0ECB82C91C \
  /tmp/SubTrkr-build/Build/Products/Debug-iphonesimulator/SubTrkr.app
xcrun simctl launch 7E4DF3CA-3821-43D5-8444-DB0ECB82C91C com.subtrkr.app
```

**Step 3: Toggle appearance modes**

Test all three appearance modes via the Settings picker:
- Dark mode: verify near-black base, card depth visible, green brand pops
- Light mode: verify light gray base, white cards, proper contrast
- System: verify follows simulator setting

**Step 4: Grep audit for any remaining hardcoded colors**

```bash
grep -rn "\.red\b" SubTrkr/SubTrkr/Views/ --include="*.swift"
grep -rn "\.systemBackground\|\.secondarySystemBackground\|\.tertiarySystemBackground\|\.label\b\|\.secondaryLabel\|\.tertiaryLabel" SubTrkr/SubTrkr/ --include="*.swift"
grep -rn "textTertiary" SubTrkr/SubTrkr/ --include="*.swift"
```

Fix any stragglers found.

**Step 5: Final commit if any fixes needed**

```bash
git add -A
git commit -m "fix: clean up remaining hardcoded color references"
```
