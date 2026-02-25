# Bugfixes & Notifications Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix all data correctness bugs (currency, expired trials, notification persistence) and wire up the existing local notification system.

**Architecture:** Four independent changes to existing files. No new files or DB migrations. Currency is enforced at the form/display layer. Expired trials auto-cancel. Notifications are wired by adding `NotificationService` calls to `ItemService` and `DashboardViewModel`.

**Tech Stack:** SwiftUI, Supabase Swift SDK, UserNotifications framework

---

### Task 1: Enforce Single-Currency (USD) in ItemFormViewModel

**Files:**
- Modify: `SubTrkr/SubTrkr/ViewModels/ItemFormViewModel.swift:45`
- Modify: `SubTrkr/SubTrkr/ViewModels/ItemFormViewModel.swift:82`

**Step 1: Force currency to USD when loading an existing item**

In `ItemFormViewModel.init`, line 45, change:

```swift
// Before:
currency = item.currency

// After:
currency = "USD"
```

**Step 2: Force currency to USD when selecting a known service**

In `ItemFormViewModel.selectService`, line 82, change:

```swift
// Before:
currency = service.currency

// After:
currency = "USD"
```

**Step 3: Verify build succeeds**

Run:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project SubTrkr/SubTrkr.xcodeproj \
  -scheme SubTrkr \
  -destination 'platform=iOS Simulator,id=7E4DF3CA-3821-43D5-8444-DB0ECB82C91C' \
  -derivedDataPath /tmp/SubTrkr-build \
  build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

**Step 4: Commit**

```bash
git add SubTrkr/SubTrkr/ViewModels/ItemFormViewModel.swift
git commit -m "fix: enforce single-currency (USD) in item form"
```

---

### Task 2: Fix Expired Trials — Auto-Cancel

**Files:**
- Modify: `SubTrkr/SubTrkr/Services/ItemService.swift:205-223`

**Step 1: Rewrite `handleExpiredTrials` to auto-cancel**

Replace lines 205-223 of `ItemService.swift` with:

```swift
func handleExpiredTrials(userId: String) async throws {
    let items = try await getItems()
    let today = DateHelper.formatDate(Date.now)

    for item in items where item.status == .trial {
        guard let trialEndDate = item.trialEndDate, trialEndDate < today else { continue }

        // Auto-cancel the expired trial
        let update = ItemUpdate(
            status: .cancelled,
            cancelledAt: DateHelper.formatISO8601(Date.now),
            cancellationDate: today
        )
        _ = try await updateItem(id: item.id, data: update)

        // Record the automatic transition
        let history = StatusHistoryInsert(
            itemId: item.id,
            userId: userId,
            status: .cancelled,
            reason: "Trial expired",
            notes: "Trial ended on \(trialEndDate)"
        )
        try await client.from("item_status_history")
            .insert(history)
            .execute()
    }
}
```

Key changes from original:
- Added `ItemUpdate` with `status: .cancelled`, `cancelledAt`, and `cancellationDate`
- Called `updateItem` to persist the status change
- Changed history `status` from `.trial` to `.cancelled`

**Step 2: Verify build succeeds**

Run:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project SubTrkr/SubTrkr.xcodeproj \
  -scheme SubTrkr \
  -destination 'platform=iOS Simulator,id=7E4DF3CA-3821-43D5-8444-DB0ECB82C91C' \
  -derivedDataPath /tmp/SubTrkr-build \
  build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

**Step 3: Commit**

```bash
git add SubTrkr/SubTrkr/Services/ItemService.swift
git commit -m "fix: auto-cancel expired trials instead of just logging"
```

---

### Task 3: Fix Notification Toggle Persistence

**Files:**
- Modify: `SubTrkr/SubTrkr/Views/Settings/NotificationSettingsView.swift:4-5`

**Step 1: Change `@State` to `@AppStorage` for both settings**

Replace lines 4-5:

```swift
// Before:
@State private var notificationsEnabled = false
@State private var defaultReminderDays = 3

// After:
@AppStorage("notificationsEnabled") private var notificationsEnabled = false
@AppStorage("defaultReminderDays") private var defaultReminderDays = 3
```

**Step 2: Add `rescheduleAllNotifications` call when settings change**

After the existing `onChange(of: notificationsEnabled)` block (line 25), and after the `Picker` closing brace (line 41), add onChange handlers that reschedule notifications:

Replace the `if notificationsEnabled` section (lines 32-42) with:

```swift
if notificationsEnabled {
    Section("Default Reminder") {
        Picker("Remind me", selection: $defaultReminderDays) {
            Text("1 day before").tag(1)
            Text("3 days before").tag(3)
            Text("7 days before").tag(7)
            Text("14 days before").tag(14)
            Text("30 days before").tag(30)
        }
        .onChange(of: defaultReminderDays) { _, newValue in
            Task {
                let items = try? await ItemService().getItems()
                await NotificationService().rescheduleAllNotifications(
                    items: items ?? [],
                    daysBefore: newValue
                )
            }
        }
    }
}
```

**Step 3: Update the `.task` block to not override `@AppStorage` on launch**

Replace lines 76-80:

```swift
// Before:
.task {
    let settings = await UNUserNotificationCenter.current().notificationSettings()
    hasPermission = settings.authorizationStatus == .authorized
    notificationsEnabled = hasPermission
}

// After:
.task {
    let settings = await UNUserNotificationCenter.current().notificationSettings()
    hasPermission = settings.authorizationStatus == .authorized
    // If the user previously enabled notifications but OS permission was revoked, sync the toggle
    if notificationsEnabled && !hasPermission {
        notificationsEnabled = false
    }
}
```

**Step 4: Verify build succeeds**

Run the build command. Expected: `** BUILD SUCCEEDED **`

**Step 5: Commit**

```bash
git add SubTrkr/SubTrkr/Views/Settings/NotificationSettingsView.swift
git commit -m "fix: persist notification toggle and reminder days with @AppStorage"
```

---

### Task 4: Wire Local Notifications to Item CRUD

**Files:**
- Modify: `SubTrkr/SubTrkr/Services/ItemService.swift` (add NotificationService property and calls)
- Modify: `SubTrkr/SubTrkr/ViewModels/DashboardViewModel.swift` (reschedule after maintenance)

**Step 1: Add NotificationService to ItemService**

At `ItemService.swift` line 5 (after the `client` property), add:

```swift
private let notificationService = NotificationService()
```

**Step 2: Schedule notifications after item create**

After `createItem` returns (line 66), add notification scheduling. Replace the method:

```swift
func createItem(_ data: ItemInsert) async throws -> Item {
    let item: Item = try await client.from("items")
        .insert(data)
        .select("*, categories(*)")
        .single()
        .execute()
        .value

    // Schedule notification for new item
    if UserDefaults.standard.bool(forKey: "notificationsEnabled") {
        let days = UserDefaults.standard.integer(forKey: "defaultReminderDays")
        if item.status == .active {
            await notificationService.scheduleRenewalReminder(for: item, daysBefore: days > 0 ? days : 3)
        } else if item.status == .trial {
            await notificationService.scheduleTrialExpirationReminder(for: item)
        }
    }

    return item
}
```

**Step 3: Reschedule notifications after item update**

Replace the `updateItem` method:

```swift
func updateItem(id: String, data: ItemUpdate) async throws -> Item {
    let item: Item = try await client.from("items")
        .update(data)
        .eq("id", value: id)
        .select("*, categories(*)")
        .single()
        .execute()
        .value

    // Reschedule notifications for updated item
    if UserDefaults.standard.bool(forKey: "notificationsEnabled") {
        notificationService.cancelNotifications(for: id)
        let days = UserDefaults.standard.integer(forKey: "defaultReminderDays")
        if item.status == .active {
            await notificationService.scheduleRenewalReminder(for: item, daysBefore: days > 0 ? days : 3)
        } else if item.status == .trial {
            await notificationService.scheduleTrialExpirationReminder(for: item)
        }
    }

    return item
}
```

**Step 4: Cancel notifications on item delete**

Replace the `deleteItem` method:

```swift
func deleteItem(id: String) async throws {
    try await client.from("items")
        .delete()
        .eq("id", value: id)
        .execute()

    notificationService.cancelNotifications(for: id)
}
```

**Step 5: Verify build succeeds**

Run the build command. Expected: `** BUILD SUCCEEDED **`

**Step 6: Commit**

```bash
git add SubTrkr/SubTrkr/Services/ItemService.swift
git commit -m "feat: wire local notifications to item create/update/delete"
```

---

### Task 5: Reschedule Notifications After Maintenance

**Files:**
- Modify: `SubTrkr/SubTrkr/ViewModels/DashboardViewModel.swift:68-78`

**Step 1: Add NotificationService and reschedule after maintenance**

Add a `notificationService` property at line 8 (after `categoryService`):

```swift
private let notificationService = NotificationService()
```

Replace `runMaintenance` (lines 68-78):

```swift
func runMaintenance(userId: String) async {
    do {
        try await itemService.advancePastDueItems()
        try await itemService.archivePastCancellations()
        try await itemService.resumePausedItems()
        try await itemService.handleExpiredTrials(userId: userId)

        // Reschedule all notifications after maintenance changes
        if UserDefaults.standard.bool(forKey: "notificationsEnabled") {
            let allItems = try await itemService.getItems()
            let days = UserDefaults.standard.integer(forKey: "defaultReminderDays")
            await notificationService.rescheduleAllNotifications(
                items: allItems,
                daysBefore: days > 0 ? days : 3
            )
        }
    } catch {
        print("Maintenance error: \(error)")
    }
}
```

**Step 2: Verify build succeeds**

Run the build command. Expected: `** BUILD SUCCEEDED **`

**Step 3: Commit**

```bash
git add SubTrkr/SubTrkr/ViewModels/DashboardViewModel.swift
git commit -m "feat: reschedule notifications after background maintenance"
```

---

### Task 6: Final Build Verification and Integration Commit

**Step 1: Full clean build**

```bash
rm -rf /tmp/SubTrkr-build
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project SubTrkr/SubTrkr.xcodeproj \
  -scheme SubTrkr \
  -destination 'platform=iOS Simulator,id=7E4DF3CA-3821-43D5-8444-DB0ECB82C91C' \
  -derivedDataPath /tmp/SubTrkr-build \
  build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

**Step 2: Review all changes**

```bash
git log --oneline -5
git diff HEAD~4 --stat
```

Verify 4 commits covering: currency fix, trial fix, notification persistence, notification wiring, maintenance reschedule.

---

## Summary of All Changes

| File | What Changed |
|------|-------------|
| `ViewModels/ItemFormViewModel.swift` | Force `currency = "USD"` in init and selectService |
| `Services/ItemService.swift` | Fix handleExpiredTrials to auto-cancel; add NotificationService calls to create/update/delete |
| `Views/Settings/NotificationSettingsView.swift` | `@AppStorage` for toggle + days; reschedule on days change; fix .task to not override |
| `ViewModels/DashboardViewModel.swift` | Reschedule notifications after maintenance |
