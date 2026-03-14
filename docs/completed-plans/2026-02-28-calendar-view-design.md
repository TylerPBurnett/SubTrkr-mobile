# Calendar View Design

> Date: 2026-02-28

## Overview

Add a calendar view to the Dashboard tab via a segmented control toggle (Overview / Calendar). The calendar shows a monthly grid with dot indicators on days that have subscription/bill payments due. Tapping a day shows an inline detail list of items due that day. This is roadmap item #20.

## Placement Decision

The app already has 5 tabs (Dashboard, Subscriptions, Bills, Analytics, Settings) — the Apple HIG maximum. Rather than adding a 6th tab, the calendar lives inside the Dashboard tab behind a segmented control, matching the pattern already used by the Analytics tab (Overview / Categories / Trends).

- Dashboard tab opens to **Overview** by default (no behavior change for existing users)
- User taps **Calendar** segment to see the monthly grid
- Both views answer "what's coming up financially?" from different angles

## Architecture

### New Files

| File | Purpose |
|------|---------|
| `ViewModels/CalendarViewModel.swift` | `@Observable @MainActor` — loads items, projects billing dates, manages month navigation and day selection |
| `Views/Dashboard/CalendarView.swift` | Calendar grid + inline day detail, extracted subviews (`CalendarDayCell`, `CalendarHeader`, `DayDetailList`) |

### Modified Files

| File | Change |
|------|--------|
| `Views/Dashboard/DashboardView.swift` | Add segmented picker (Overview / Calendar), swap content based on selection |

### Data Flow

```
DashboardView
├── Picker("", selection: $selectedTab)
│   ├── "Overview" → existing statsSection + categoryChart + upcomingSection
│   └── "Calendar" → CalendarView (owns its own CalendarViewModel)
```

`CalendarViewModel` owns its own `ItemService` instance and loads items independently. This keeps the Dashboard and Calendar ViewModels decoupled — each manages its own loading state and data.

## Calendar Grid

- Custom `LazyVGrid` with 7 fixed `GridItem(.flexible())` columns (Sun–Sat)
- Month/year header with `chevron.left` / `chevron.right` buttons
- Day cells show:
  - Day number
  - Colored dot indicators (category color) when items are due that day
  - Multiple dots for multiple items (max 3 visible, then `+N` indicator)
- Today: highlighted with `.brand` ring
- Selected day: filled with `.brand` background, white text
- Days outside the current month: dimmed with `.textMuted` color
- `GridItem` array defined as file-level `let` constant (not recreated per render)

## Billing Date Projection

For each **active** or **trial** item with a `nextBillingDate`:

1. Start from `nextBillingDate`
2. If the displayed month is ahead of `nextBillingDate`, project forward by adding billing cycle intervals until reaching the displayed month
3. If the projected date lands in the displayed month, include it

This is computed in `CalendarViewModel` as a `[DateComponents: [Item]]` dictionary keyed by `(year, month, day)`. Recomputed when the displayed month changes via a stored property (not a computed property in the view body).

Only forward-looking — current and future months. No past month reconstruction.

## Day Detail (Inline)

Below the calendar grid, when a day is selected:

- Section header: formatted date (e.g., "Friday, February 28")
- Item rows: `ServiceLogo` + name + amount + billing cycle label
- Tapping a row navigates to `ItemDetailView` via `NavigationLink`
- Empty state: "No payments due" message for days with no items
- Today is auto-selected on initial load

## Month Summary

A card below the day detail showing:

- **Month total**: sum of all items billing in the displayed month
- **Item count**: number of payments due in the month

## SwiftUI Best Practices

- `CalendarViewModel` is `@Observable @MainActor`, held with `@State` in the view
- `DateFormatter` instances are `static let` — never allocated in `body`
- `GridItem` array is a file-level `let` constant
- Extracted subviews (`CalendarDayCell`, `CalendarHeader`, `DayDetailList`) receive only `let` data for optimal SwiftUI diffing
- `ForEach` uses stable identity: date-based IDs for day cells, item `.id` for detail rows
- Items-by-date dictionary is precomputed and cached — no inline filtering in `ForEach`
- All colors from `Color+Theme.swift` semantic tokens, `.cardStyle()` for containers
- Data loaded in `.task` block, `isLoading` / `error` states handled
- No `AnyView` usage
- Structured concurrency — no `Task { }` wrappers inside `.task`

## Edge Cases

- Items with no `nextBillingDate`: excluded from calendar (nothing to show)
- Months with no items: calendar grid still renders, empty month summary
- Paused/cancelled/archived items: excluded (only active + trial shown)
- Weekly billing cycle: may show multiple dots in a single month
- Year boundaries: month navigation wraps correctly (Dec → Jan increments year)
