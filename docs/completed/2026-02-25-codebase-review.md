# SubTrkr iOS — Codebase Review & Roadmap

> Generated 2026-02-25. Based on a full read of every file in the project.

---

## Current State Summary

The app is a SwiftUI MVVM subscription/bill tracker backed by Supabase. Five tabs: Dashboard, Subscriptions, Bills, Analytics, Settings. Auth is complete (email, OTP, OAuth). Core CRUD for items, categories, and status changes works end-to-end. The UI is polished — shimmer loading, charts, status badges, pull-to-refresh, empty states.

The main gaps fall into three buckets: **half-wired features** (code exists but isn't connected), **data correctness bugs**, and **missing table-stakes features** for a billing app.

---

## Priority 1 — Broken / Incorrect Behavior

These are bugs that affect data accuracy for anyone using the app today.

### 1.1 Multi-currency math is wrong

All analytics sum item amounts as raw numbers and format as USD regardless of each item's `currency` field. A €10/mo subscription shows as $10 in totals. Affects: `DashboardViewModel`, `AnalyticsViewModel`, `ItemListView` monthly total.

**Fix:** Either enforce single-currency (remove the field, always USD) or add conversion rates and sum per-currency. Enforcing single-currency is simpler and honest — most users operate in one currency.

### 1.2 Spending trend chart is always flat

`AnalyticsService.getMonthlySpendingTrend` applies the *current* active items to all 6 past months. It never reflects actual historical changes. The chart gives a false impression of stability.

**Fix:** Query `item_status_history` to reconstruct which items were active in each month, or track monthly snapshots server-side.

### 1.3 Expired trials are logged but not acted on

`ItemService.handleExpiredTrials` writes a status history record but never changes the item's status. Expired trials remain in "trial" status indefinitely.

**Fix:** Either auto-cancel or auto-archive expired trials, or surface a prominent "trial expired" alert that forces the user to decide.

### 1.4 Notification toggle doesn't persist

`NotificationSettingsView` requests system permission on toggle but stores nothing in `@AppStorage`. On relaunch, the toggle resets to off.

**Fix:** Persist with `@AppStorage("notificationsEnabled")`.

---

## Priority 2 — Half-Built Features to Finish

Code exists for all of these. They need wiring, not design.

### 2.1 Wire up local notifications

`NotificationService` has complete scheduling logic (`scheduleRenewalReminder`, `scheduleTrialExpirationReminder`, `rescheduleAllNotifications`). None of it is ever called.

**Wire:** Call `rescheduleAllNotifications` after item create/update/delete and after the user changes reminder preferences. Call `cancelNotifications(for:)` on item delete.

### 2.2 Add "Record Payment" UI

`PaymentService.recordPayment` exists and works. `ItemDetailView` shows payment history. But there's no button to record one.

**Wire:** Add a "Record Payment" button in `ItemDetailView` that opens a sheet with amount (pre-filled from item), date (default today), and a save button. Auto-advance `nextBillingDate` after recording.

### 2.3 Display status history in item detail

`StatusHistory` model exists. Status changes are written to `item_status_history` on every status transition. `ItemDetailView` declares `@State private var statusHistory: [StatusHistory] = []` but never populates or renders it.

**Wire:** Fetch via `ItemService` and show a timeline below payment history.

### 2.4 Enable category editing

`SettingsViewModel` has `editingCategory` state. `CategoryManagementView` only supports add and delete — not edit.

**Wire:** Add a tap-to-edit gesture on category rows that opens `AddCategorySheet` pre-filled for editing. Add the category `icon` picker while you're in there (the model supports it, the UI doesn't).

### 2.5 Connect `SettingsViewModel.loadNotifications()`

The method exists (fetches channels, preferences, log from Supabase) but is never called. `NotificationSettingsView` shows static placeholder rows for Telegram/Discord/Slack.

**Wire:** Call `loadNotifications()` in `SettingsView.task` and conditionally show real channel data.

---

## Priority 3 — Missing Table-Stakes Features

Things users expect from a billing tracker that don't exist yet.

### 3.1 Mark a bill as paid / payment tracking

Beyond just recording a payment (2.2), the app needs a "paid this cycle" concept. Users should see at a glance which bills are paid vs outstanding for the current period. Consider a `paidThisCycle` computed property or a `lastPaidDate` field.

### 3.2 Currency picker in item form

`ItemFormViewModel.currency` defaults to `"USD"` with no way to change it. The model supports per-item currency but the form has no picker. Add a currency selector (at minimum the major currencies: USD, EUR, GBP, CAD, AUD).

### 3.3 Auto-calculate next billing date

When a user sets a start date and billing cycle, `nextBillingDate` should auto-compute. Currently it stays at `Date.now` regardless of what start date is picked.

### 3.4 Haptic feedback

No `UIFeedbackGenerator` or `.sensoryFeedback` anywhere. Add light haptics on: item save, status change, swipe delete, pull-to-refresh complete, payment recorded.

### 3.5 App icon

`AppIcon.appiconset` slot exists but is empty. Need a 1024x1024 PNG.

### 3.6 Account management

No password change or account deletion in Settings. Both are App Store review requirements for apps with account creation.

---

## Priority 4 — Code Quality & Architecture

Issues that don't affect users today but will cause pain as the app grows.

### 4.1 Hardcoded Supabase credentials

`SupabaseManager.swift` commits the anon key and project URL as fallback values. The anon key is public-facing and not secret, but the fallback pattern means debug builds silently use production credentials.

**Fix:** Remove hardcoded fallback. Fail loudly if env vars or plist values are missing.

### 4.2 Services instantiated inside views

`ItemDetailView.refreshItem()` and `StatusChangeSheet.executeChange()` create `ItemService()` inline, bypassing the ViewModel. Works but inconsistent.

**Fix:** Route all service calls through the owning ViewModel.

### 4.3 Expensive formatters created per-render

`ItemDetailView` creates `DateFormatter` instances inside `ViewBuilder` closures (new allocation every render). `Double+Currency.swift` creates a `NumberFormatter` on every call.

**Fix:** Use static/cached formatters like `DateHelper` already does.

### 4.4 Duplicate `availableActions` logic

`ItemDetailView` and `StatusChangeSheet` both compute available actions for a status, with inconsistent results (`"convert"` vs `"convert_trial"`, different action sets for the same status).

**Fix:** Single source of truth — put `availableActions` on the `ItemStatus` enum or in a shared helper.

### 4.5 No error tracking

All `catch` blocks either show `error.localizedDescription` to the user or `print()`. No remote logging.

**Fix:** Integrate Sentry, Bugsnag, or Firebase Crashlytics before any public release.

### 4.6 `@Observable` on `SupabaseManager` is unnecessary

It's a singleton accessed by property, not observed by SwiftUI views. The macro adds overhead without benefit. Remove it.

---

## Priority 5 — Future Features (Nice-to-Have)

These add real value but aren't blockers.

### 5.1 Widgets (WidgetKit)

Home-screen widget showing upcoming payments or monthly spend total. High visibility, low complexity for a read-only widget.

### 5.2 Budget / spending limits

Let users set a monthly spending cap. Show a progress bar on the dashboard. Alert when approaching the limit.

### 5.3 Offline caching

Every screen fetches from Supabase on load. No local persistence. The app is unusable without internet. SwiftData or a simple JSON cache would solve this.

### 5.4 Supabase Realtime

Subscribe to item/category changes so edits from the desktop app appear instantly without pull-to-refresh.

### 5.5 Export / sharing

Export spending data as CSV or PDF. Share a monthly summary.

### 5.6 iPad optimization

Info.plist includes iPad orientations but the UI is phone-only. A split-view layout (list + detail sidebar) would work well.

### 5.7 Filter persistence

Filters/sort reset on every view appearance. Persist with `@AppStorage`.

### 5.8 Deep linking

The `subtrkr://` scheme only handles OAuth. Support linking to specific items or screens (useful for notifications and widgets).

---

## Feature Inventory (What Works Today)

For reference — everything that is fully functional:

| Feature | Status |
|---|---|
| Email/password sign-in & sign-up | Complete |
| Magic link / OTP auth | Complete |
| Google & GitHub OAuth | Complete |
| Password reset flow | Complete |
| Dashboard with spending cards | Complete |
| Category donut chart | Complete |
| Upcoming payments list | Complete |
| Subscription & bill lists | Complete |
| Search, filter, sort | Complete |
| Swipe-to-delete | Complete |
| Item create & edit form | Complete |
| Service autocomplete (50 services) | Complete |
| Item detail with payment history | Complete |
| Status changes (pause/cancel/archive/resume/trial) | Complete |
| Analytics: overview, categories, trends | Complete (trend data inaccurate) |
| Category management (add/delete) | Complete (no edit) |
| Pull-to-refresh | Complete |
| Loading skeletons & empty states | Complete |
| Background maintenance (advance dates, auto-archive) | Complete |
| Settings with sign-out | Complete |

---

## Suggested Implementation Order

If starting tomorrow, this is the sequence that maximizes value with minimal wasted work:

1. Fix currency bug (1.1) — decide single vs multi-currency now, it affects everything
2. Wire notifications (2.1 + 1.4) — highest user-perceived value for minimal code
3. Add payment recording (2.2 + 3.1) — core feature gap
4. Fix expired trials (1.3) — small fix, prevents data rot
5. Auto-calc next billing date (3.3) — small UX win
6. Account management (3.6) — App Store requirement
7. Category editing + icon picker (2.4) — finish what's started
8. Status history display (2.3) — finish what's started
9. Code quality pass (4.1–4.6) — before public release
10. App icon (3.5) — before public release
11. Haptics (3.4) — polish pass
12. Fix trend chart (1.2) — requires more backend work
13. Widgets, budgets, offline, export — post-launch features
