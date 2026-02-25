# SubTrkr iOS — Roadmap & Next Steps

> Last updated: 2026-02-25

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
| 6 | **Record Payment UI** — `PaymentService.recordPayment` works. Add button + sheet in `ItemDetailView`. Auto-advance `nextBillingDate`. | Medium | Core feature gap |
| 7 | **Status history display** — Model + writes exist. Fetch + render timeline in `ItemDetailView`. | Small | |
| 8 | **Category editing** — `SettingsViewModel.editingCategory` exists. Add tap-to-edit on category rows. | Small | |
| 9 | **Notification channels** — `loadNotifications()` exists but is never called. Wire up real channel data. | Small | Desktop-only channels, low priority |

### Phase 3: Missing Table-Stakes Features

Things users expect from a billing tracker.

| # | Feature | Effort | Notes |
|---|---------|--------|-------|
| ~~10~~ | ~~Currency picker~~ | | N/A — single-currency (USD) decision made |
| 11 | **Auto-calculate next billing date** — from start date + billing cycle. Currently stays at `Date.now`. | Small | Quick UX win |
| 12 | **Account management** — password change + account deletion. App Store review requirement. | Medium | Required before submission |
| 13 | **Haptic feedback** — `.sensoryFeedback` on item save, status change, swipe delete, pull-to-refresh, payment recorded. | Small | Polish pass |
| 14 | **App icon** — `AppIcon.appiconset` slot is empty. Need 1024x1024 PNG. | Small | Required before submission |

### Phase 4: Code Quality (Pre-Release)

| # | Issue | Notes |
|---|-------|-------|
| 15 | **Remove hardcoded Supabase credentials** — fail loudly if env/plist missing instead of silent fallback to production. |
| 16 | **Route all service calls through ViewModels** — some views create `ItemService()` inline, bypassing ViewModel. |
| 17 | **Cache DateFormatters** — `ItemDetailView` creates new instances per render. Use static/cached like `DateHelper`. |
| 18 | **Deduplicate `availableActions`** — `ItemDetailView` and `StatusChangeSheet` compute action lists independently with inconsistent results. |
| 19 | **Remove `@Observable` from `SupabaseManager`** — singleton accessed by property, not observed by views. |

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

The highest-impact next batch is **items 6 + 11** together:

1. **Record Payment UI** (#6) — core feature gap, service already works
2. **Auto-calculate next billing date** (#11) — quick UX win, pairs with payment recording

Then: Account management (#12) for App Store readiness.

---

## App Store Readiness Checklist

Before submitting to App Store Review:

- [ ] Dark mode support ✓ (done)
- [ ] Account deletion option (#12)
- [ ] Password change option (#12)
- [ ] App icon (#14)
- [ ] Remove hardcoded credentials (#15)
- [ ] Privacy policy URL in App Store Connect
- [ ] Test on physical device
- [ ] Accessibility audit (VoiceOver, Dynamic Type)
