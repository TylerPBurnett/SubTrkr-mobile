# SubTrkr iOS — Roadmap & Next Steps

> Last updated: 2026-03-19
> Navigation: `docs/TASKS.md` is the operational queue for actionable work. `docs/plans/` contains active work only. Finished implementation/design docs live in `docs/completed-plans/`; completed summaries and audits live in `docs/completed/`.

---

## Completed

### Dark Mode & Adaptive Theme System ✓
*Completed 2026-02-25. See `docs/completed/session-2026-02-25-dark-mode-theme.md` for details.*

- Full light/dark adaptive color system with 30+ semantic tokens matching desktop design handoff
- Card depth treatment (borders, shadows) across all views
- Appearance toggle (System/Light/Dark) in Settings
- Auth screen brutalist border treatment
- Adaptive status badge backgrounds
- Heavy font weight on stat numbers

### Bugfixes & Notifications ✓
*Completed 2026-02-25. See `docs/completed-plans/2026-02-25-bugfixes-notifications-design.md` for details.*

- Enforced single-currency (USD) — form always writes USD, resolves multi-currency math bug
- Expired trials auto-cancel — `handleExpiredTrials` now transitions to `.cancelled` status, flows through archive pipeline
- Notification toggle persists — `@AppStorage` for `notificationsEnabled` and `defaultReminderDays`
- Local notifications wired — schedule on create, reschedule on update, cancel on delete, bulk reschedule after maintenance

### Record Payment & Auto-Calc Billing Date ✓
*Completed 2026-02-25. See `docs/completed-plans/2026-02-25-payment-billing-design.md` for details.*

- Record Payment sheet in ItemDetailView — pre-filled amount, date picker, auto-advances nextBillingDate by one cycle
- Auto-calculate next billing date in item form — rolls startDate forward by billingCycle until future, respects manual overrides

Note: product direction has since shifted to an autopay-first model for both subscriptions and bills. Manual payment logging is now considered optional/secondary. See `docs/plans/2026-03-08-autopay-first-payment-tracking-design.md`.

### Status History, Category Editing & Haptics ✓
*Completed 2026-02-25.*

- Status history timeline in ItemDetailView — fetches from `item_status_history`, shows status icon, reason, relative date
- Category tap-to-edit — edit sheet for name and color on existing categories
- Haptic feedback — `.sensoryFeedback(.success)` on save/status change/payment, `.warning` on delete

### Account Management ✓
*Completed 2026-02-25. See `docs/completed-plans/2026-02-25-account-management-design.md` for details.*

- Change password — sheet with new/confirm fields, calls `client.auth.update(user:)`
- Delete account — two-step confirmation (alert + type "DELETE"), calls `client.rpc("delete_user")`, signs out
- Requires `delete_user` RPC deployed to Supabase (SQL in design doc)

### Code Quality Pass ✓
*Completed 2026-02-26. See `docs/completed-plans/2026-02-26-code-quality-design.md` for details.*

- Removed hardcoded Supabase credentials — `fatalError` if env/plist missing
- Removed `@Observable` from `SupabaseManager` — singleton, not observed by views
- Cached `DateFormatter` instances — static `mediumDateFormatter` in `DateHelper`, eliminated per-render allocations
- Deduplicated `availableActions` — single source of truth on `ItemStatus` enum + `StatusActionHelper`
- Routed service calls through `@State` instances — no more inline `ItemService()`/`PaymentService()` per call

### Analytics Charts & Historical Reconstruction ✓
*Completed 2026-02-26. See `docs/completed-plans/2026-02-26-analytics-charts-design.md` for details.*

- Fixed flat spending trend chart — historical reconstruction from item metadata (`startDate`, `cancelledAt`, `archivedAt`, `pausedAt/pausedUntil`), prefers real payment records when available
- Segmented time range picker (3/6/12 months) on Analytics Trends tab
- Category spending over time — stacked area chart with per-category colors and legend
- Subscription count over time — line chart tracking active item count per month
- Projected annual spend — forward-looking `yearlyAmount` sum on Dashboard and Analytics Overview
- Cached `NumberFormatter` instances in `Double+Currency` — eliminated per-render allocations
- `AnalyticsViewModel` now loads payments in parallel via `async let`

### Analytics Tab Fixes ✓
*Completed 2026-02-27. See `docs/completed-plans/2026-02-27-analytics-fix-design.md` for details.*

- Added `@MainActor` to all ViewModels for thread-safe SwiftUI observation
- Cached trend computations — stored properties + `recomputeTrends()` instead of per-render computed properties
- `createdAt` fallback in `wasItemActive` — items without `startDate` now appear in trend charts
- Loading shimmer skeleton, error banner, and empty states on Analytics tab
- Contextual "Not enough history" message when trend data is empty
- Extracted chart views into standalone structs for optimal SwiftUI diffing

### Calendar View ✓
*Completed 2026-02-28. See `docs/completed-plans/2026-02-28-calendar-view-design.md` for details.*

- Monthly calendar grid as Dashboard sub-tab (segmented control: Overview/Calendar)
- Billing date projection — forward-advances `nextBillingDate` by billing cycle to populate future months
- Colored dot indicators (up to 3) showing items due on each day
- Day-detail card with item list, navigation to ItemDetailView
- Month summary card showing total spend and payment count
- Handles weekly items with multiple billing dates per month
- CalendarViewModel hoisted into DashboardView to prevent recreation on tab switch
- Cached stored properties with explicit recomputation (matching AnalyticsViewModel pattern)

### SwiftUI Review & Fixes ✓
*Completed 2026-02-27. Review against SwiftUI Expert skill checklist.*

- Shared `NotificationService` via injection — `ItemService` accepts it via init, `NotificationSettingsView` uses `@State` instance instead of inline creation
- Fixed unstructured `Task` in `SubTrkrApp` — `observeAuthChanges()` now runs in structured `.task` block for proper cancellation
- Cached `NumberFormatter` in `Double+Currency` — two static formatters replace per-call allocations
- Cached `DateFormatter` in `AnalyticsModels` — static formatters with POSIX locale for `MonthlySpending.monthDate`/`shortMonth`
- Hoisted `DateFormatter` out of loop in `AnalyticsService.getMonthlySpendingTrend`
- Replaced ~16 `Binding(get:set:)` wrappers with `@Bindable` in `ItemFormView`, `AuthScreen`, `SettingsView`
- Fixed `AuthScreen` deferred ViewModel init — `ProgressView` replaces blank `Color.clear` flash
- Extracted `GridItem` array to file-level `let` constant in `SettingsView`
- Surfaced maintenance errors to UI in `DashboardViewModel` — `self.error` instead of `print()`
- Guarded unknown status actions in `ItemService.executeStatusChange` — no fabricated `.active` history records
- Cleared stale error in `SettingsViewModel.loadData` — `error = nil` at start

### Billing Anchor Accuracy & Xcode Test Coverage ✓
*Completed 2026-03-19. See `docs/plans/2026-03-08-billing-anchor-accuracy-implementation-spec.md` and `docs/MOBILE_TESTING_STRATEGY.md`.*

- Preserved recurring billing anchors across short months and leap-year boundaries
- Kept due-today items visible through the full day instead of rolling them forward early
- Fixed future-start form recalculation so auto-filled next billing dates do not block later updates
- Added shared Xcode unit and UI test targets for billing and lifecycle regression coverage

---

## Up Next — Prioritized

### Phase 1: Data Correctness (Bugs)

| # | Issue | Effort | Impact |
|---|-------|--------|--------|
| ~~1~~ | ~~Multi-currency math~~ | | ✓ Fixed — enforced single-currency (USD) |
| ~~2~~ | ~~Expired trials never transition~~ | | ✓ Fixed — auto-cancel |
| ~~3~~ | ~~Notification toggle doesn't persist~~ | | ✓ Fixed — @AppStorage |
| ~~4~~ | ~~Spending trend chart is flat~~ | | ✓ Fixed — historical reconstruction + 3 new charts |

### Phase 2: Wire Half-Built Features

| # | Feature | Effort | Notes |
|---|---------|--------|-------|
| ~~5~~ | ~~Local notifications~~ | | ✓ Wired to item CRUD + maintenance |
| ~~6~~ | ~~Record Payment UI~~ | | ✓ Sheet with auto-advance billing date |
| ~~7~~ | ~~Status history display~~ | | ✓ Timeline in ItemDetailView |
| ~~8~~ | ~~Category editing~~ | | ✓ Tap-to-edit with name + color |
| 9 | **Notification channels** — `loadNotifications()` exists but is never called. Wire up real channel data. | Small | Desktop-only channels, low priority |

### Phase 3: Missing Table-Stakes Features

Things users expect from a billing tracker.

| # | Feature | Effort | Notes |
|---|---------|--------|-------|
| ~~10~~ | ~~Currency picker~~ | | N/A — single-currency (USD) decision made |
| ~~11~~ | ~~Auto-calculate next billing date~~ | | ✓ Reactive calc from startDate + billingCycle |
| ~~12~~ | ~~Account management~~ | | ✓ Password change + account deletion |
| ~~13~~ | ~~Haptic feedback~~ | | ✓ Save, delete, status change, payment |
| ~~14~~ | ~~App icon~~ | | ✓ Light (green bg + white logo), Dark (black bg + green logo), Tinted (grayscale for iOS tinting) |

### Phase 4: Code Quality (Pre-Release)

| # | Issue | Notes |
|---|-------|-------|
| ~~15~~ | ~~Remove hardcoded Supabase credentials~~ | ✓ `fatalError` if env/plist missing |
| ~~16~~ | ~~Route all service calls through shared instances~~ | ✓ `@State` service properties |
| ~~17~~ | ~~Cache DateFormatters~~ | ✓ Static `mediumDateFormatter` in `DateHelper` |
| ~~18~~ | ~~Deduplicate `availableActions`~~ | ✓ `ItemStatus.availableActions` + `StatusActionHelper` |
| ~~19~~ | ~~Remove `@Observable` from `SupabaseManager`~~ | ✓ Removed |

### Phase 5: Post-Launch Features

| # | Feature | Notes |
|---|---------|-------|
| ~~20~~ | ~~Calendar view~~ | ✓ Dashboard sub-tab with billing date projection, dot indicators, day-detail sheet |
| 21 | **WidgetKit** — home screen widget for upcoming payments or monthly spend. High visibility, read-only. |
| 22 | **Budget / spending limits** — monthly cap with progress bar on dashboard. |
| 23 | **Offline caching** — SwiftData or JSON cache. App is unusable without internet today. |
| 24 | **Supabase Realtime** — live sync with desktop app edits. |
| 25 | **Export / sharing** — CSV or PDF export of spending data. |
| 26 | **iPad optimization** — split-view layout (list + detail sidebar). |
| 27 | **Filter persistence** — save filter/sort state with `@AppStorage`. |
| 28 | **Deep linking** — extend `subtrkr://` scheme beyond OAuth to specific items/screens (for notifications, widgets). |

Future note:
- Consider optional per-item `automatic/manual` payment behavior for edge-case bills only. Do not add this in phase 1; the current product assumption is that all subscriptions and bills are automatically paid while active.

---

## Suggested Next Session

Remaining items before App Store submission:

1. **Autopay-first behavioral cleanup** — align item detail messaging, recurring-charge assumptions, and manual payment semantics with the updated product model. See `docs/plans/2026-03-08-autopay-first-payment-tracking-design.md`.
2. **Status-history hardening** — the mobile follow-up fixes are in; remaining work is desktop parity in the other repo plus the separate transactional backend write hardening task. See `docs/plans/2026-03-15-status-history-rollout-follow-ups.md` and `docs/plans/2026-03-11-status-history-effective-date-migration-guide.md`.
3. **Privacy policy URL / nutrition labels** — manual App Store Connect follow-through remains. See `docs/app-store/PRIVACY_POLICY.md`.
4. **Physical device testing** — use `docs/MOBILE_TESTING_STRATEGY.md` as the release smoke checklist owner.
5. **Notification channels** (#9) — wire up real channel data (low priority)

---

## Phase 6: UI/UX Polish

### Global / Cross-cutting

| # | Issue | Effort |
|---|-------|--------|
| 29 | **Silent error handling** — failed loads show nothing on most screens. Only Analytics has an error banner. Standardize error display across Dashboard, Item List, and Item Detail. | Small |
| ~~30~~ | ~~**No unsaved-changes guard**~~ | ✓ `interactiveDismissDisabled` when `isDirty` |
| ~~31~~ | ~~**Stat number transitions**~~ | ✓ `.contentTransition(.numericText())` on all stat/analytics cards |
| 32 | **Tab switch animations** — no transition between tab content. Add `.animation` or `matchedGeometryEffect` for smoother tab switching. | Medium |
| 33 | **Sheet entrance polish** — default sheet spring is fine but untuned. Evaluate custom `presentationCornerRadius`, drag indicator visibility, and detent behavior across all sheets. | Small |

### Dashboard

| # | Issue | Effort |
|---|-------|--------|
| ~~34~~ | ~~**No loading/skeleton state**~~ | ✓ Dashboard skeleton matches Analytics pattern |
| ~~35~~ | ~~**Donut chart missing center label**~~ | ✓ Total monthly spend via `.chartBackground` overlay |
| 36 | **Stats cards are non-interactive** — tapping a card does nothing. Consider navigating to a relevant filtered view or drilled-down detail on tap. | Medium |
| 37 | **Upcoming Payments truncated** — list is hard-capped at 8 with no "See All" link. Add a "See All" button that navigates to the full filtered item list. | Small |
| 38 | **Segmented picker floats** — Overview/Calendar picker sits directly under the nav bar with no visual separation. Add a subtle divider or background treatment. | Small |

### Item List

| # | Issue | Effort |
|---|-------|--------|
| 39 | **Swipe actions too limited** — only Delete is available on swipe. Add trailing swipe for Archive and a leading swipe for a contextual status action on eligible items. | Medium |
| ~~40~~ | ~~**Shimmer nearly invisible**~~ | ✓ Opacity bumped from 0.05 → 0.15 |
| 41 | **Filter state not persisted** — filters and sort reset on every app load. Persist with `@AppStorage`. | Small |
| 42 | **Monthly total placement** — the `/mo` total in the nav bar leading position looks misplaced. Move it inline below the title or into a subtle header band. | Small |
| 43 | **No grouping option** — flat list with no optional grouping by category or next billing date. Add as a sort/group option in the filter sheet. | Medium |

### Item Detail

| # | Issue | Effort |
|---|-------|--------|
| ~~44~~ | ~~**Manual payment entry is buried**~~ | ✓ Moved into Quick Actions row; may be demoted or removed under the autopay-first model |
| 45 | **Quick Actions all open the same sheet** — every action button opens `StatusChangeSheet` generically. Each should deep-link to its specific action within the sheet. | Small |
| 46 | **Payment history lacks summary** — no total paid to date shown. Add a running total above the payment list. | Small |
| 47 | **No logo/service reassignment** — service search is hidden when editing an item. Add a way to change the logo/service association on edit. | Medium |

### Item Form

| # | Issue | Effort |
|---|-------|--------|
| 48 | **No keyboard-adjacent save** — Save is only in the toolbar. When the keyboard is up, it's out of reach. Add a toolbar input accessory or keyboard dismiss + save button. | Small |
| 49 | **No inline validation** — errors only surface on Save tap. Show inline feedback (e.g., "Name required", "Amount must be > 0") as the user types. | Small |
| 50 | **Category picker color dot broken** — the color dot in the inline category picker label doesn't render in most SwiftUI picker styles. Fix or switch to a custom picker. | Small |

### Analytics

| # | Issue | Effort |
|---|-------|--------|
| ~~51~~ | ~~**Asymmetric Savings card**~~ | ✓ Replaced `Spacer()` with "Avg / Item" card |
| 52 | **Two stacked segmented pickers** — Trends tab has a top-level Overview/Categories/Trends picker plus a 3/6/12 month picker inside, visually busy. Move the time range picker into the Trends tab only, or style it as a smaller inline control. | Small |
| 53 | **Charts have no interactivity** — tapping a chart point does nothing. Add `.chartOverlay` for tap-to-select with a callout showing the exact value. | Medium |
| ~~54~~ | ~~**Cancellation History placement**~~ | ✓ Moved from Trends → Overview tab |

### Settings

| # | Issue | Effort |
|---|-------|--------|
| ~~55~~ | ~~**"Platform: iOS" row is filler**~~ | ✓ Removed |
| ~~56~~ | ~~**Silent "Resend Verification Email"**~~ | ✓ Button label changes to "Sent" and disables on success |

---

## App Store Readiness Checklist

Before submitting to App Store Review:

- [x] Xcode unit/UI test suite configured ✓
- [x] Dark mode support ✓
- [x] Account deletion option (#12) ✓
- [x] Password change option (#12) ✓
- [x] App icon (#14) ✓
- [x] Remove hardcoded credentials (#15) ✓
- [ ] Release-candidate full simulator test pass
- [ ] Privacy policy URL in App Store Connect
- [ ] Physical-device smoke checklist completed
- [x] Accessibility audit (VoiceOver, Dynamic Type) ✓
