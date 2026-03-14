# SubTrkr iOS — Bugfixes & Notifications Design

> Date: 2026-02-25
> Scope: Phase 1 (data correctness bugs) + Phase 2 item 5 (wire notifications)

---

## 1. Enforce Single-Currency (USD)

**Decision:** Single-currency. Remove multi-currency UI; keep DB column for Codable compatibility.

**Changes:**
- `ItemFormViewModel`: Hardcode `currency = "USD"`, ignore service suggestion currencies
- `Double+Currency.formatted(currency:)`: Default parameter to `"USD"`
- `KnownServices`: Set all service entries to `"USD"`
- No DB migration — existing non-USD items display as USD

**Not changing:** Item model keeps `currency` property (Codable needs it for the DB column). Analytics code already sums raw amounts — with single currency enforced, this is now correct.

---

## 2. Fix Expired Trials → Auto-Cancel

**Current bug:** `handleExpiredTrials` writes a status history record but never changes the item's status.

**Fix in `ItemService.handleExpiredTrials`:**
1. After finding expired trials, update item status to `.cancelled`
2. Set `cancelledAt` and `cancellationDate`
3. Change history record to `status: .cancelled` with reason "Trial expired"
4. Cancelled trials flow through existing `archivePastCancellations()` pipeline

---

## 3. Notification Toggle Persistence

**Current bug:** `NotificationSettingsView` uses `@State` for `notificationsEnabled` and `defaultReminderDays`. Both reset on relaunch.

**Fix:**
- `notificationsEnabled` → `@AppStorage("notificationsEnabled")`
- `defaultReminderDays` → `@AppStorage("defaultReminderDays")`

---

## 4. Wire Local Notifications

**Current state:** `NotificationService` has complete scheduling logic. Never called.

**Wiring points:**
- `ItemService.createItem` → schedule notification for new item
- `ItemService.updateItem` → reschedule if dates/status changed
- `ItemService.deleteItem` → cancel notifications for item
- `ItemService.executeStatusChange` → cancel on deactivate, schedule on activate
- `DashboardViewModel.runMaintenance` → bulk reschedule after maintenance
- `NotificationSettingsView` onChange of reminder days → reschedule all

**Implementation:** Add `NotificationService` instance to `ItemService`. Read `defaultReminderDays` from `UserDefaults` (shared with `@AppStorage`).

---

## Files Modified

| File | Change |
|------|--------|
| `Services/ItemService.swift` | Add NotificationService calls, fix handleExpiredTrials |
| `ViewModels/ItemFormViewModel.swift` | Hardcode currency to USD |
| `Extensions/Double+Currency.swift` | Default currency parameter to USD |
| `Resources/KnownServices.swift` | Set all currencies to USD |
| `Views/Settings/NotificationSettingsView.swift` | @AppStorage for toggle + days, wire reschedule |
| `ViewModels/DashboardViewModel.swift` | Reschedule notifications after maintenance |
| `Services/NotificationService.swift` | Read defaultReminderDays from UserDefaults |

No new files created. No DB migrations.
