# Analytics Tab Fix — Design & Implementation

> Date: 2026-02-27
> Status: Completed

## Problem

The Analytics tab appeared broken — no loading feedback, errors swallowed silently, blank screens when data was empty, and potential threading issues from missing `@MainActor` on ViewModels.

## Root Causes

1. **No loading indicator** — user sees blank screen while Supabase fetches
2. **No error display** — fetch failures silently swallowed
3. **No empty states** for Overview and Trends tabs
4. **Missing `@MainActor`** on all ViewModels — property updates from async contexts may not trigger SwiftUI observation reliably
5. **Heavy computed properties** — trend reconstruction ran on every body evaluation
6. **`wasItemActive` returns false for items without `startDate`** — items missing this field invisible to trend charts

## Changes Made

### 1. `@MainActor` on all ViewModels

Added `@MainActor` annotation to all 6 ViewModel classes:
- `AnalyticsViewModel`
- `DashboardViewModel`
- `ItemListViewModel`
- `ItemFormViewModel`
- `SettingsViewModel`
- `AuthViewModel`

Per Apple's SwiftUI best practices, `@Observable` classes should be marked `@MainActor` to ensure thread-safe property updates.

### 2. Cached Trend Computations

Replaced 5 expensive computed properties in `AnalyticsViewModel` with stored properties:
- `monthlyTrend`, `categoryTrend`, `itemCountTrend`, `projectedAnnualSpend`, `cancelledItems`

Added `recomputeTrends()` method called:
- At end of `loadData()` after setting `items` and `payments`
- On `selectedMonthRange` `didSet`

### 3. startDate Fallback

`wasItemActive` in `AnalyticsService` now falls back to `createdAt` (ISO8601) when `startDate` is nil, ensuring items without explicit start dates still appear in trend charts.

### 4. Loading, Error, and Empty States

- **Loading:** Shimmer skeleton matching card layout (reuses existing `ShimmerModifier` from `ItemListView`)
- **Empty state:** `EmptyStateView` with chart icon when user has no items
- **Error:** Dismissible banner overlay at top with amber warning icon
- **Pull-to-refresh:** Already existed, now works alongside new states

### 5. Contextual Trend Empty States

When all trend arrays are empty but items exist, shows "Not enough history" message with explanation.

### 6. Extracted Chart Subviews

Extracted into 6 standalone structs for optimal SwiftUI diffing:
- `SpendingTrendChart(data:)`
- `CategoryTrendChart(data:)`
- `ItemCountChart(data:)`
- `CancellationHistoryCard(items:)`
- `TopExpensesCard(expenses:)`
- `StatusDistributionCard(statusCounts:totalCount:)`

All receive `let` properties only — no ViewModel dependency, enabling fast equality checks.

## Files Modified

- `SubTrkr/SubTrkr/ViewModels/AnalyticsViewModel.swift` — `@MainActor`, cached trends
- `SubTrkr/SubTrkr/ViewModels/DashboardViewModel.swift` — `@MainActor`
- `SubTrkr/SubTrkr/ViewModels/ItemListViewModel.swift` — `@MainActor`
- `SubTrkr/SubTrkr/ViewModels/ItemFormViewModel.swift` — `@MainActor`
- `SubTrkr/SubTrkr/ViewModels/SettingsViewModel.swift` — `@MainActor`
- `SubTrkr/SubTrkr/ViewModels/AuthViewModel.swift` — `@MainActor`
- `SubTrkr/SubTrkr/Services/AnalyticsService.swift` — `createdAt` fallback
- `SubTrkr/SubTrkr/Views/Analytics/AnalyticsView.swift` — loading/error/empty states, extracted chart structs
