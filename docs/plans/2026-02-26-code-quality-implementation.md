# Code Quality Pass Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Clean up 5 code quality issues before release (#15-19 from roadmap)

**Architecture:** Small, independent refactors — no new features, no behavior changes

**Tech Stack:** Swift, SwiftUI, Supabase Swift SDK

---

### Task 1: Remove hardcoded Supabase credentials (#15)

**Files:**
- Modify: `SubTrkr/SubTrkr/Services/SupabaseManager.swift`

**Changes:**
Replace lines 13-18 with guard-let pattern:

```swift
private init() {
    guard let url = ProcessInfo.processInfo.environment["SUPABASE_URL"]
            ?? Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String else {
        fatalError("Missing SUPABASE_URL — set in environment variables or Info.plist")
    }
    guard let key = ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"]
            ?? Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String else {
        fatalError("Missing SUPABASE_ANON_KEY — set in environment variables or Info.plist")
    }

    client = SupabaseClient(
        supabaseURL: URL(string: url)!,
        supabaseKey: key
    )
}
```

Also remove `@Observable` from the class declaration (#19 — combined here since same file).

**Verify:** Build succeeds (credentials are in Info.plist).

---

### Task 2: Cache DateFormatters (#17)

**Files:**
- Modify: `SubTrkr/SubTrkr/Extensions/Date+Helpers.swift`
- Modify: `SubTrkr/SubTrkr/Views/Items/ItemDetailView.swift`

**Changes in Date+Helpers.swift:**
Add static cached formatter and public method:

```swift
private static let mediumDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateStyle = .medium
    f.timeStyle = .none
    return f
}()

static func formatMediumDate(_ date: Date) -> String {
    mediumDateFormatter.string(from: date)
}
```

Also fix `relativeDateString` default case (line 59-62) to use the cached formatter.

**Changes in ItemDetailView.swift:**
Replace all inline `DateFormatter()` closures with `DateHelper.formatMediumDate(date)`:
- Line 174-179 (Start Date)
- Line 200-206 (Cancellation Date)
- Line 300-304 (Payment dates)

**Verify:** Build succeeds.

---

### Task 3: Deduplicate availableActions (#18)

**Files:**
- Modify: `SubTrkr/SubTrkr/Models/Enums.swift`
- Modify: `SubTrkr/SubTrkr/Views/Items/ItemDetailView.swift`
- Modify: `SubTrkr/SubTrkr/Views/Items/StatusChangeSheet.swift`

**Changes in Enums.swift:**
Add to `ItemStatus`:

```swift
var availableActions: [String] {
    switch self {
    case .active: return ["pause", "cancel", "archive", "start_trial"]
    case .paused: return ["resume", "cancel", "archive"]
    case .cancelled: return ["reactivate", "archive"]
    case .archived: return ["reactivate"]
    case .trial: return ["convert_trial", "cancel", "archive"]
    }
}
```

Add helper functions as static methods or a `StatusActionHelper` enum:

```swift
enum StatusActionHelper {
    static func icon(for action: String) -> String {
        switch action {
        case "pause": return "pause.circle.fill"
        case "resume", "reactivate": return "play.circle.fill"
        case "cancel": return "xmark.circle.fill"
        case "archive": return "archivebox.fill"
        case "start_trial": return "clock.fill"
        case "convert_trial": return "checkmark.circle.fill"
        default: return "circle"
        }
    }

    static func color(for action: String) -> Color {
        switch action {
        case "pause": return .statusPaused
        case "resume", "reactivate", "convert_trial": return .brand
        case "cancel": return .statusCancelled
        case "archive": return .statusArchived
        case "start_trial": return .statusTrial
        default: return .textSecondary
        }
    }

    static func label(for action: String) -> String {
        switch action {
        case "pause": return "Pause"
        case "resume": return "Resume"
        case "reactivate": return "Reactivate"
        case "cancel": return "Cancel"
        case "archive": return "Archive"
        case "start_trial": return "Start Trial"
        case "convert_trial": return "Convert to Active"
        default: return action.capitalized
        }
    }
}
```

**Changes in StatusChangeSheet.swift:**
- Replace `availableActions` computed property with `item.status.availableActions`
- Replace `iconForAction`, `colorForAction`, `labelForAction` with `StatusActionHelper` calls
- Remove the local helper functions

**Changes in ItemDetailView.swift:**
- Replace `availableActions` computed property with `currentItem.status.availableActions`
- Replace `iconForAction`, `colorForAction` with `StatusActionHelper` calls
- Remove the local helper functions
- Fix quick action button label to use `StatusActionHelper.label(for:)` instead of `action.capitalized`

**Verify:** Build succeeds.

---

### Task 4: Route service calls through shared instances (#16)

**Files:**
- Modify: `SubTrkr/SubTrkr/Views/Items/ItemDetailView.swift`
- Modify: `SubTrkr/SubTrkr/Views/Items/StatusChangeSheet.swift`
- Modify: `SubTrkr/SubTrkr/Views/Settings/NotificationSettingsView.swift`

**Changes:**
Add `@State` service properties to each view and replace inline `ItemService()` / `PaymentService()` with them.

ItemDetailView:
```swift
@State private var itemService = ItemService()
@State private var paymentService = PaymentService()
```

StatusChangeSheet:
```swift
@State private var itemService = ItemService()
```

NotificationSettingsView:
```swift
@State private var itemService = ItemService()
```

Then replace all `ItemService()` and `PaymentService()` calls in the function bodies with the `@State` properties.

**Verify:** Build succeeds.
