# SubTrkr — Code Quality Pass Design

> Date: 2026-02-26
> Scope: Roadmap items #15-19 — pre-release code quality cleanup

---

## #15: Remove Hardcoded Supabase Credentials

**Problem:** `SupabaseManager.swift` falls back to hardcoded production URL and anon key if env vars / Info.plist are missing. This silently works in dev but risks shipping credentials in source.

**Fix:** Remove hardcoded fallback strings. Use `guard let` for both values, `fatalError` if either is missing. Keep the env var → Info.plist lookup chain.

**File:** `Services/SupabaseManager.swift`

## #16: Route Service Calls Through Shared Instances

**Problem:** Views create `ItemService()` and `PaymentService()` inline per call. Each `ItemService()` also creates a `NotificationService()`.

**Fix:** Use `@State` service properties so instances persist across re-renders. Affected views:
- `ItemDetailView` — 4 inline `ItemService()` + 2 `PaymentService()` calls
- `StatusChangeSheet` — 1 inline `ItemService()` call
- `NotificationSettingsView` — 1 inline `ItemService()` call

**Files:** `Views/Items/ItemDetailView.swift`, `Views/Items/StatusChangeSheet.swift`, `Views/Settings/NotificationSettingsView.swift`

## #17: Cache DateFormatters

**Problem:** `ItemDetailView` creates `DateFormatter()` in closures per render (lines 174-179, 200-206, 300-304). Also `DateHelper.relativeDateString` creates one in its default branch (line 59).

**Fix:** Add a `private static let mediumDateFormatter` to `DateHelper` and use it everywhere. Replace inline formatter closures in `ItemDetailView` with `DateHelper.formatMediumDate(_:)`.

**Files:** `Extensions/Date+Helpers.swift`, `Views/Items/ItemDetailView.swift`

## #18: Deduplicate `availableActions`

**Problem:** `ItemDetailView` and `StatusChangeSheet` independently compute action lists with inconsistent results:
- ItemDetailView `.trial` → `["convert", "cancel"]`
- StatusChangeSheet `.trial` → `["convert_trial", "cancel", "archive"]`
- ItemDetailView `.active` → `["pause", "cancel", "archive"]`
- StatusChangeSheet `.active` → `["pause", "cancel", "archive", "start_trial"]`

**Fix:** Add `var availableActions: [String]` computed property on `ItemStatus` enum using StatusChangeSheet's canonical list (it performs the actual changes). Update both views to use `item.status.availableActions`. Move `iconForAction`, `colorForAction`, `labelForAction` to a shared helper or extend on `String` / new `StatusAction` type.

**Files:** `Models/Enums.swift`, `Views/Items/ItemDetailView.swift`, `Views/Items/StatusChangeSheet.swift`

## #19: Remove `@Observable` from `SupabaseManager`

**Problem:** `SupabaseManager` has `@Observable` macro but is a singleton accessed via `.shared.client` — no SwiftUI view observes it.

**Fix:** Remove `@Observable` from the class declaration.

**File:** `Services/SupabaseManager.swift`
