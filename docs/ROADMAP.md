# SubTrkr iOS — Roadmap & Next Steps

> Last updated: 2026-02-26

---

## Completed

### Dark Mode & Adaptive Theme System ✓
*Completed 2026-02-25. See `docs/session-2026-02-25-dark-mode-theme.md` for details.*

- Full light/dark adaptive color system with 30+ semantic tokens matching desktop design handoff
- Card depth treatment (borders, shadows) across all views
- Appearance toggle (System/Light/Dark) in Settings
- Auth screen brutalist border treatment
- Adaptive status badge backgrounds
- Heavy font weight on stat numbers

### Bugfixes & Notifications ✓
*Completed 2026-02-25. See `docs/plans/2026-02-25-bugfixes-notifications-design.md` for details.*

- Enforced single-currency (USD) — form always writes USD, resolves multi-currency math bug
- Expired trials auto-cancel — `handleExpiredTrials` now transitions to `.cancelled` status, flows through archive pipeline
- Notification toggle persists — `@AppStorage` for `notificationsEnabled` and `defaultReminderDays`
- Local notifications wired — schedule on create, reschedule on update, cancel on delete, bulk reschedule after maintenance

### Record Payment & Auto-Calc Billing Date ✓
*Completed 2026-02-25. See `docs/plans/2026-02-25-payment-billing-design.md` for details.*

- Record Payment sheet in ItemDetailView — pre-filled amount, date picker, auto-advances nextBillingDate by one cycle
- Auto-calculate next billing date in item form — rolls startDate forward by billingCycle until future, respects manual overrides

### Status History, Category Editing & Haptics ✓
*Completed 2026-02-25.*

- Status history timeline in ItemDetailView — fetches from `item_status_history`, shows status icon, reason, relative date
- Category tap-to-edit — edit sheet for name and color on existing categories
- Haptic feedback — `.sensoryFeedback(.success)` on save/status change/payment, `.warning` on delete

### Account Management ✓
*Completed 2026-02-25. See `docs/plans/2026-02-25-account-management-design.md` for details.*

- Change password — sheet with new/confirm fields, calls `client.auth.update(user:)`
- Delete account — two-step confirmation (alert + type "DELETE"), calls `client.rpc("delete_user")`, signs out
- Requires `delete_user` RPC deployed to Supabase (SQL in design doc)

### Code Quality Pass ✓
*Completed 2026-02-26. See `docs/plans/2026-02-26-code-quality-design.md` for details.*

- Removed hardcoded Supabase credentials — `fatalError` if env/plist missing
- Removed `@Observable` from `SupabaseManager` — singleton, not observed by views
- Cached `DateFormatter` instances — static `mediumDateFormatter` in `DateHelper`, eliminated per-render allocations
- Deduplicated `availableActions` — single source of truth on `ItemStatus` enum + `StatusActionHelper`
- Routed service calls through `@State` instances — no more inline `ItemService()`/`PaymentService()` per call

---

## Up Next — Prioritized

### Phase 1: Data Correctness (Bugs)

| # | Issue | Effort | Impact |
|---|-------|--------|--------|
| ~~1~~ | ~~Multi-currency math~~ | | ✓ Fixed — enforced single-currency (USD) |
| ~~2~~ | ~~Expired trials never transition~~ | | ✓ Fixed — auto-cancel |
| ~~3~~ | ~~Notification toggle doesn't persist~~ | | ✓ Fixed — @AppStorage |
| 4 | **Spending trend chart is flat** — applies current items to all past months. Needs historical reconstruction. | Large | Medium |

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
| 14 | **App icon** — `AppIcon.appiconset` slot is empty. Need 1024x1024 PNG. | Small | Required before submission |

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
| 20 | **WidgetKit** — home screen widget for upcoming payments or monthly spend. High visibility, read-only. |
| 21 | **Budget / spending limits** — monthly cap with progress bar on dashboard. |
| 22 | **Offline caching** — SwiftData or JSON cache. App is unusable without internet today. |
| 23 | **Supabase Realtime** — live sync with desktop app edits. |
| 24 | **Export / sharing** — CSV or PDF export of spending data. |
| 25 | **iPad optimization** — split-view layout (list + detail sidebar). |
| 26 | **Filter persistence** — save filter/sort state with `@AppStorage`. |
| 27 | **Deep linking** — extend `subtrkr://` scheme beyond OAuth to specific items/screens (for notifications, widgets). |

---

## Suggested Next Session

Remaining items before App Store submission:

1. **App icon** (#14) — need 1024×1024 PNG design asset
2. **Spending trend chart** (#4) — historical reconstruction (large effort)
3. **Privacy policy URL** — needed in App Store Connect
4. **Physical device testing** + accessibility audit

---

## App Store Readiness Checklist

Before submitting to App Store Review:

- [ ] Dark mode support ✓ (done)
- [x] Account deletion option (#12) ✓
- [x] Password change option (#12) ✓
- [ ] App icon (#14)
- [x] Remove hardcoded credentials (#15) ✓
- [ ] Privacy policy URL in App Store Connect
- [ ] Test on physical device
- [ ] Accessibility audit (VoiceOver, Dynamic Type)
