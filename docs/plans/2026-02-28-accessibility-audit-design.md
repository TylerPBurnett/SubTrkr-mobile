# Accessibility Audit Design
*2026-02-28*

## Objective

Pass Apple App Store accessibility review for VoiceOver and Dynamic Type. The app currently has 40+ SF Symbol images without accessibility labels and 20+ fixed font sizes that don't scale with user text size preferences.

## Scope

Two passes across 15 View files:

1. **VoiceOver pass** — accessibility labels on interactive/informational icons; `.accessibilityHidden(true)` on decorative icons
2. **Dynamic Type pass** — replace all `size: N` fixed font values with semantic equivalents

## Approach

Full compliance sweep (not minimal audit pass). Changes are mechanical and well-scoped. Two-pass structure keeps each change set independently reviewable.

---

## Pass 1: VoiceOver

### Rules

- **Decorative icons** (form field icons, stat card icons, empty state illustrations, legend dots) → `.accessibilityHidden(true)`
- **Interactive or informational icons** (buttons, status indicators, verification states) → `.accessibilityLabel("descriptive string")`
- **Compound elements** where icon + text together convey one idea → `.accessibilityElement(children: .combine)` on the container

### File-by-file changes

#### EmptyState.swift
- Icon illustration → `.accessibilityHidden(true)`
- `+` CTA button → `.accessibilityLabel("Add your first subscription")`

#### ContentView.swift
- Launch creditcard icon → `.accessibilityHidden(true)`

#### StatusBadge.swift
- Wrap container in `.accessibilityElement(children: .combine)` + `.accessibilityLabel("Status: \(status.displayName)")`

#### ItemListView.swift
- Filter button → `.accessibilityLabel(hasActiveFilters ? "Filter, active" : "Filter")`
- Add button → `.accessibilityLabel("Add subscription")`
- Sort checkmarks, option icons, direction arrows → `.accessibilityHidden(true)` (rows have text labels)

#### ItemDetailView.swift
- Ellipsis menu → `.accessibilityLabel("More options")`
- `dollarsign`, `calendar`, `plus.circle` icons in form rows → `.accessibilityHidden(true)`
- Status action icon (line 223) → `.accessibilityHidden(true)` (button has adjacent text label)
- Payment history status icon → `.accessibilityHidden(true)`

#### StatusChangeSheet.swift
- Action option icons → `.accessibilityHidden(true)`
- Selected checkmark → `.accessibilityLabel("Selected")`

#### ItemFormView.swift
- All 12 form field icons → `.accessibilityHidden(true)`

#### AuthScreen.swift
- App logo icon → `.accessibilityHidden(true)`
- Error `exclamationmark.triangle` → `.accessibilityHidden(true)` (announced with adjacent error text)
- Success `checkmark.circle` → `.accessibilityHidden(true)`
- TextField leading icon → `.accessibilityHidden(true)`

#### SettingsView.swift
- Verification shield → `.accessibilityLabel(isVerified ? "Email verified" : "Email not verified")`
- Color picker checkmarks → `.accessibilityLabel("Selected")`

#### CalendarView.swift
- Previous/next month buttons → `.accessibilityLabel("Previous month")` / `.accessibilityLabel("Next month")`
- Day cells with subscriptions → `.accessibilityLabel("March 15, 2 subscriptions due")` (computed from subscriptions due that day)
- Empty state icon → `.accessibilityHidden(true)`

#### DashboardView.swift
- Stats card icons → `.accessibilityHidden(true)`
- Legend dot circles → `.accessibilityHidden(true)`

#### AnalyticsView.swift
- Error banner icon → `.accessibilityHidden(true)`
- Dismiss `xmark` button → `.accessibilityLabel("Dismiss")`
- Empty state icon → `.accessibilityHidden(true)`
- Chart legend dots → `.accessibilityHidden(true)`

---

## Pass 2: Dynamic Type

Replace all fixed `.system(size: N)` font calls with semantic equivalents. Keep `design:` and `weight:` modifiers intact.

| File | Current | Replacement |
|------|---------|-------------|
| `CurrencyText` | `.system(size: 28, weight: .bold, design: .monospaced)` | `.system(.title2, design: .monospaced).weight(.bold)` |
| `EmptyState` | `.system(size: 48)` | `.system(.largeTitle)` |
| `ContentView` | `.system(size: 56)` | `.system(.largeTitle)` |
| `ContentView` | `.system(size: 32, weight: .bold, design: .rounded)` | `.system(.title, design: .rounded).weight(.bold)` |
| `ItemDetailView` | `.system(size: 32, weight: .heavy, design: .monospaced)` | `.system(.title, design: .monospaced).weight(.heavy)` |
| `ItemDetailView` | `.system(size: 18)` | `.system(.body)` |
| `AuthScreen` | `.system(size: 48)` | `.system(.largeTitle)` |
| `AuthScreen` | `.system(size: 36, weight: .bold, design: .rounded)` | `.system(.title, design: .rounded).weight(.bold)` |
| `SettingsView` | `.system(size: 18, weight: .bold, design: .rounded)` | `.system(.body, design: .rounded).weight(.bold)` |
| `CalendarView` | `.system(size: 20, weight: .heavy, design: .monospaced)` (×2) | `.system(.headline, design: .monospaced).weight(.heavy)` |
| `DashboardView` | `.system(size: 20, weight: .heavy, design: .monospaced)` | `.system(.headline, design: .monospaced).weight(.heavy)` |
| `AnalyticsView` | `.system(size: 18, weight: .heavy, design: .monospaced)` | `.system(.body, design: .monospaced).weight(.heavy)` |

### ServiceLogo.swift
No change — `size * 0.4` fallback text is proportional to a frame parameter passed by the caller. Acceptable.

### StatusBadge special case
Converting `size: 9` / `size: 11` to `.caption2` / `.caption`. At largest accessibility sizes the badge pill may overflow. Mitigate with:
- `lineLimit(1)` on the text
- `.minimumScaleFactor(0.75)` on the text
- `.fixedSize(horizontal: true, vertical: false)` on the pill container so it grows horizontally with content

---

## Files not requiring changes

- `NotificationSettingsView.swift` — already uses `Label()` throughout
- `AuthScreen.swift` (OAuth buttons) — already uses `Label()` throughout
- `SettingsView.swift` (menu items) — already uses `Label()` throughout

---

## Out of scope

- Contrast ratios — the color system uses explicit hex values from `IOS_DESIGN_HANDOFF.md`; contrast should be verified visually but is outside this implementation pass
- Focus order customization — SwiftUI default tab order is generally correct; no reordering needed
- Reduce Motion support — no animations currently implemented that would require this
