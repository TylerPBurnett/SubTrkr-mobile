# Session Summary: Dark Mode & Adaptive Theme System
**Date:** February 25, 2026

## Overview

Implemented a full light/dark adaptive color system matching the SubTrkr desktop design language ("Financial Precision meets Soft Brutalism"). Replaced all Apple system colors with explicit hex tokens from the design handoff, added card depth treatments with borders and shadows, and wired up an appearance toggle in Settings.

## Changes

### Color System Rewrite
**1. Adaptive color token foundation**
- Replaced all `UIColor` system colors (`.systemBackground`, `.label`, etc.) with explicit hex values from `docs/IOS_DESIGN_HANDOFF.md`
- Created `Color.adaptive(light:dark:)` helper using `UIColor { traitCollection in }` for automatic light/dark switching
- Added 30+ semantic tokens organized by role: backgrounds (6), text (4), borders (3), brand (4), accents (13 including muted variants), status (10)
- `SubTrkr/SubTrkr/Extensions/Color+Theme.swift`

**2. Token rename: textTertiary → textMuted**
- Renamed across all 9 view files for consistency with the design handoff naming convention
- All views: `DashboardView`, `AnalyticsView`, `ItemListView`, `ItemDetailView`, `ItemFormView`, `AuthScreen`, `SettingsView`, `NotificationSettingsView`, `EmptyState`

**3. Hardcoded color cleanup**
- `.red` → `.accentRed` (AuthScreen errors, StatusChangeSheet, SettingsView sign-out)
- `.blue` → `.accentPurple` (Yearly Spending stat cards in Dashboard and Analytics)

### Card Depth System
**4. `cardStyle()` view modifier**
- New reusable modifier: `bgCard` background + `borderDefault` stroke (0.5pt) + subtle shadow
- Applied to all card-like containers across Dashboard, ItemList, ItemDetail, Analytics
- Replaces the previous `.background(Color.bgCard).clipShape(...)` pattern

**5. Typography refinement**
- Stat number fonts changed from `.bold` to `.heavy` for the "brutalist" feel specified in the design handoff
- Applies to: `StatsCard`, `AnalyticsCard`, `ItemDetailView` hero price

### Auth Screen Border Treatment
**6. Design handoff input styling**
- Input backgrounds: `.bgSurface` → `.bgInput`
- Input borders: `.textMuted.opacity(0.2)` → `.borderStrong` at 1.5pt (brutalist 2px-ish feel)
- Button borders: `.textMuted.opacity(0.3)` → `.borderDefault`
- Divider lines: `Color.textMuted.opacity(0.3)` → `Color.borderDefault`
- Password strength bar track: `Color.textMuted.opacity(0.2)` → `Color.borderMuted`

### Status Badges
**7. Adaptive muted backgrounds**
- Replaced `Color.forStatus(status).opacity(0.15)` with `Color.forStatusMuted(status)`
- Muted variants use the design handoff's per-status background colors (e.g. emerald muted for active, amber muted for paused)

### Appearance Control
**8. System/Light/Dark picker**
- `@AppStorage("appearanceMode")` persists user preference
- `.preferredColorScheme()` applied on root `ContentView` — affects entire app
- New "Appearance" section added as first item in Settings

### Asset Catalog
**9. AccentColor dark variant**
- Added dark appearance entry to `AccentColor.colorset/Contents.json` (same `#22c55e` green — brand color is consistent across modes)

### Shimmer Fix
**10. Dark mode shimmer adjustment**
- Reduced shimmer highlight from `.white.opacity(0.1)` to `.white.opacity(0.05)` for subtlety in both modes

## Files Modified

| File | Changes |
|------|---------|
| `Extensions/Color+Theme.swift` | Complete rewrite — 30+ adaptive tokens, `cardStyle()` modifier |
| `Views/ContentView.swift` | `@AppStorage` + `preferredColorScheme` for appearance toggle |
| `Views/Settings/SettingsView.swift` | Appearance picker section, `.red` → `.accentRed` |
| `Views/Dashboard/DashboardView.swift` | `cardStyle()`, `.heavy` font, `.blue` → `.accentPurple` |
| `Views/Analytics/AnalyticsView.swift` | `cardStyle()` on 6 cards, `.heavy` font, gradient tweak |
| `Views/Items/ItemListView.swift` | `cardStyle()` on rows, clear list background, shimmer fix |
| `Views/Items/ItemDetailView.swift` | `cardStyle()` on 4 sections, `.heavy` hero price |
| `Views/Auth/AuthScreen.swift` | `bgInput`, `borderStrong`, `borderDefault`, `.accentRed` |
| `Views/Components/StatusBadge.swift` | `forStatusMuted()` instead of `.opacity(0.15)` |
| `Views/Items/StatusChangeSheet.swift` | `.red` → `.accentRed` |
| `Views/Items/ItemFormView.swift` | `textTertiary` → `textMuted` |
| `Views/Components/EmptyState.swift` | `textTertiary` → `textMuted` |
| `Views/Settings/NotificationSettingsView.swift` | `textTertiary` → `textMuted` |
| `Assets.xcassets/AccentColor.colorset/Contents.json` | Added dark appearance variant |

## Documents Created

| File | Purpose |
|------|---------|
| `docs/completed-plans/2026-02-25-dark-mode-design.md` | Design decisions and adjustments from handoff |
| `docs/completed-plans/2026-02-25-dark-mode-implementation.md` | 12-task implementation plan (completed) |

## Architectural Notes

### Adaptive Color Pattern
All colors use `Color.adaptive(light:dark:)` which wraps `UIColor { traitCollection in }`. This is the recommended approach for iOS 18+ when you need code-defined dynamic colors. The pattern:

```swift
static let bgCard = Color.adaptive(light: "#ffffff", dark: "#1e2022")
```

Future colors should follow this pattern. Do not use Apple's generic system colors (`.systemBackground`, `.label`) — the design handoff specifies exact hex values.

### Card Style Convention
All card-like containers should use the `.cardStyle(cornerRadius:)` modifier instead of manually applying `.background()` + `.clipShape()`. This ensures consistent borders and shadows. Default corner radius is 16pt; use 14pt for smaller cards (stats, rows) and 12pt for action buttons.

### Design Handoff as Source of Truth
`docs/IOS_DESIGN_HANDOFF.md` is the canonical reference for all visual decisions. Color tokens, typography, spacing, shadows, and component patterns are all documented there. When in doubt, check the handoff.

### Appearance Toggle
The appearance preference uses `@AppStorage("appearanceMode")` with string values `"system"`, `"light"`, `"dark"`. Both `ContentView` and `SettingsView` read the same key. Returning `nil` from `preferredColorScheme` defers to the system setting.
