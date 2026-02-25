# Dark Mode & Theme System Design

**Date:** 2026-02-25
**Source:** `docs/IOS_DESIGN_HANDOFF.md` with iOS-specific adjustments

---

## Summary

Implement a full light/dark adaptive color system matching the SubTrkr desktop design language. Replace the current Apple system color tokens with explicit hex values from the design handoff, add missing tokens (borders, accents, input backgrounds), add card depth treatments, and wire up an appearance toggle in Settings.

---

## Adjustments from Design Handoff

1. **Skip noise texture overlay** — marginal value on mobile, complex to implement
2. **Dark mode shadows** — rely on inner highlights + borders for card depth rather than drop shadows (near-invisible on dark backgrounds)
3. **Font weights** — use `.bold` (700) for headings, `.heavy` (800) only for dashboard stat numbers; `.semibold` (600) for section headers
4. **Appearance toggle** — add System/Light/Dark picker in Settings, persisted via `@AppStorage`
5. **Code-based colors** — all tokens defined in `Color+Theme.swift` using `UIColor { traitCollection in }`, not asset catalog

---

## Color Token Map

### Backgrounds

| Token | Light | Dark |
|-------|-------|------|
| `bgBase` | `#e3e5e8` | `#0c0d0e` |
| `bgSurface` | `#edeef2` | `#131415` |
| `bgCard` | `#ffffff` | `#1e2022` |
| `bgInput` | `#ffffff` | `#252729` |
| `bgHover` | `#e4e6ea` | `#252729` |
| `bgActive` | `#d8dbe1` | `#2e3032` |

### Text

| Token | Light | Dark |
|-------|-------|------|
| `textPrimary` | `#171717` | `#fafafa` |
| `textSecondary` | `#525252` | `#a3a3a3` |
| `textMuted` | `#a3a3a3` | `#525252` |
| `textInverse` | `#ffffff` | `#171717` |

### Borders

| Token | Light | Dark |
|-------|-------|------|
| `borderDefault` | `#e5e5e5` | `#2e2e2e` |
| `borderMuted` | `#f5f5f5` | `#262626` |
| `borderStrong` | `#d4d4d4` | `#404040` |

### Brand

| Token | Light | Dark |
|-------|-------|------|
| `brand` | `#22c55e` | `#22c55e` |
| `brandDark` | `#16a34a` | `#4ade80` |
| `brandMuted` | `#f0fdf4` | `rgba(34,197,94,0.15)` |
| `brandText` | `#166534` | `#4ade80` |

### Accent Colors

| Token | Light | Dark |
|-------|-------|------|
| `accentBlue` | `#3b82f6` | `#60a5fa` |
| `accentBlueMuted` | `#dbeafe` | `rgba(59,130,246,0.2)` |
| `accentPurple` | `#8b5cf6` | `#a78bfa` |
| `accentPurpleMuted` | `#ede9fe` | `rgba(139,92,246,0.2)` |
| `accentAmber` | `#f59e0b` | `#fbbf24` |
| `accentAmberMuted` | `#fef3c7` | `rgba(245,158,11,0.2)` |
| `accentRed` | `#ef4444` | `#f87171` |
| `accentRedMuted` | `#fee2e2` | `rgba(239,68,68,0.2)` |
| `accentEmerald` | `#10b981` | `#34d399` |
| `accentEmeraldMuted` | `#d1fae5` | `rgba(16,185,129,0.2)` |
| `accentPink` | `#ec4899` | `#f472b6` |
| `accentCyan` | `#06b6d4` | `#22d3ee` |
| `accentGray` | `#6b7280` | `#9ca3af` |

### Status Color Mapping

| Status | Color Token | Muted Token |
|--------|------------|-------------|
| Active | `accentEmerald` | `accentEmeraldMuted` |
| Paused | `accentAmber` | `accentAmberMuted` |
| Cancelled | `accentRed` | `accentRedMuted` |
| Archived | `accentGray` | — |
| Trial | `accentPurple` | `accentPurpleMuted` |

---

## Card Depth Treatment

Cards get:
- Background: `bgCard`
- Border: 1px `borderDefault`
- Corner radius: 16pt (kept from current)
- Inner highlight: top-edge white line at 0.06 opacity (dark) / 1.0 opacity (light)
- Shadow: light mode only — `shadow(color: .black.opacity(0.07), radius: 3, y: 1)`

Dark mode relies on border + inner highlight for depth (drop shadows invisible on near-black).

---

## Typography Adjustments

| Role | Current | New |
|------|---------|-----|
| Dashboard stat numbers | `.system(size: 20, weight: .bold, design: .monospaced)` | `.system(size: 20, weight: .heavy, design: .monospaced)` |
| Detail view hero price | `.system(size: 32, weight: .bold, design: .monospaced)` | `.system(size: 32, weight: .heavy, design: .monospaced)` |
| Section headers | `.headline` | `.headline` (no change, already semibold) |
| All other headings | `.bold` | `.bold` (no change) |

Minimal font changes — the current type hierarchy is already close to the handoff.

---

## Appearance Toggle

- Add `AppearanceMode` enum: `.system`, `.light`, `.dark`
- Store in `@AppStorage("appearanceMode")`
- Apply via `.preferredColorScheme()` on root `ContentView`
- Add picker row in `SettingsView` under a new "Appearance" section

---

## Files to Modify

1. `Color+Theme.swift` — complete rewrite of color tokens
2. `ContentView.swift` — apply `preferredColorScheme` from AppStorage
3. `SettingsView.swift` — add appearance picker section
4. `DashboardView.swift` — card borders, shadows, font weight tweaks
5. `ItemListView.swift` — card borders, shimmer update for dark mode
6. `ItemDetailView.swift` — card borders, depth treatment
7. `AnalyticsView.swift` — card borders, depth treatment
8. `AuthScreen.swift` — input borders using `borderStrong`, depth treatment
9. `StatusBadge.swift` — use accent muted tokens for backgrounds
10. `ItemFormView.swift` — input styling with new border tokens
11. `AccentColor.colorset/Contents.json` — add dark appearance variant
