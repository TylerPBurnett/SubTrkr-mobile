# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build and run

**Open in Xcode:**
```bash
open SubTrkr/SubTrkr.xcodeproj
```
Then ⌘R to build and run. Requires Xcode 16+, iOS 18+ simulator.

**Build from terminal:**
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project SubTrkr/SubTrkr.xcodeproj \
  -scheme SubTrkr \
  -destination 'platform=iOS Simulator,id=7E4DF3CA-3821-43D5-8444-DB0ECB82C91C' \
  -derivedDataPath /tmp/SubTrkr-build \
  build
```

**Install and launch on simulator:**
```bash
xcrun simctl install 7E4DF3CA-3821-43D5-8444-DB0ECB82C91C \
  /tmp/SubTrkr-build/Build/Products/Debug-iphonesimulator/SubTrkr.app
xcrun simctl launch 7E4DF3CA-3821-43D5-8444-DB0ECB82C91C com.subtrkr.app
```

**Clear derived data (when builds misbehave):**
```bash
rm -rf ~/Library/Developer/Xcode/DerivedData/SubTrkr-*
```

No linter or test suite is configured yet.

## Architecture

SwiftUI MVVM app sharing a Supabase backend with the desktop SubTrkr app. Single external dependency: `supabase-swift`.

**Data flow:**
```
View → ViewModel (@Observable) → Service → Supabase SDK → PostgreSQL
```

**Layer responsibilities:**
- `Models/` — `Codable` structs matching Supabase table columns exactly. `CodingKeys` map snake_case DB columns to camelCase Swift properties. Separate `Insert`/`Update` structs for API writes. Computed properties (e.g. `monthlyAmount`, `daysUntilDue`) belong on the model.
- `Services/` — all Supabase calls. One service per domain (Item, Category, Payment, Analytics, Auth, Notification). No business logic in views or ViewModels beyond what drives UI state.
- `ViewModels/` — `@Observable` classes. Load data in `.task` blocks. Expose `isLoading`, `error`, and domain data as plain properties. One ViewModel per screen.
- `Views/` — pure SwiftUI. No direct Supabase calls. Receive state from ViewModel, dispatch actions back to it.

**Auth flow:** `SubTrkrApp` injects `AuthService` via `.environment()`. `ContentView` gates on `authService.isAuthenticated` — shows `AuthScreen` or `MainTabView`. OAuth callbacks handled via `subtrkr://` URL scheme in `onOpenURL`.

**Supabase query rules:** Filters (`.eq()`, `.in()`, etc.) must be chained before transforms (`.order()`). The Supabase Swift SDK v2 returns a `PostgrestTransformBuilder` from `.order()` which does not expose filter methods.

## Key files

- `SubTrkr/SubTrkr/SubTrkrApp.swift` — `@main` entry, auth init, OAuth URL handler
- `SubTrkr/SubTrkr/Services/SupabaseManager.swift` — singleton client. Credentials read from env vars → Info.plist → hardcoded fallback
- `SubTrkr/SubTrkr/Extensions/Color+Theme.swift` — adaptive light/dark color tokens using `Color.adaptive(light:dark:)`, `ShapeStyle` extensions for short-form syntax, and `cardStyle()` view modifier. All colors are explicit hex values from `docs/IOS_DESIGN_HANDOFF.md` — do NOT use Apple system colors (`.systemBackground`, `.label`, etc.)
- `SubTrkr/SubTrkr/Models/Enums.swift` — `ItemType`, `ItemStatus`, `BillingCycle` with raw values matching DB
- `SubTrkr/SubTrkr/Views/ContentView.swift` — auth gate and `MainTabView` with iOS 18 `Tab` API

## Project files

The runnable project is `SubTrkr/SubTrkr.xcodeproj`. `SubTrkr/Package.swift` also exists (swift-tools-version 6.0, swiftLanguageModes .v5) and is kept for tooling compatibility — do not use it to run the app.

When adding new Swift files outside Xcode, they must be manually added to the `SubTrkr` target in `SubTrkr.xcodeproj/project.pbxproj` (PBXFileReference + PBXBuildFile + PBXSourcesBuildPhase entry + PBXGroup entry).

## Color system conventions

- All colors defined in `Color+Theme.swift` using `Color.adaptive(light:dark:)` — never use Apple system colors
- `docs/IOS_DESIGN_HANDOFF.md` is the canonical source for all color values
- Card-like containers must use `.cardStyle(cornerRadius:)` modifier (default 16pt, 14pt for smaller cards, 12pt for buttons)
- Use semantic tokens: `.textPrimary`, `.textSecondary`, `.textMuted` — not `.primary`, `.secondary`
- Status colors map to accent tokens: `.statusActive` = `.accentEmerald`, etc.
- Appearance preference stored in `@AppStorage("appearanceMode")` with values `"system"`, `"light"`, `"dark"`

## Currency

Single-currency (USD) enforced. The `currency` field exists in the model/DB for Codable compatibility but `ItemFormViewModel` always writes `"USD"`. Do not add a currency picker.

## Notifications

Local notifications are wired to item CRUD via `NotificationService` calls in `ItemService` (create/update/delete) and `DashboardViewModel` (post-maintenance reschedule). Settings persisted with `@AppStorage("notificationsEnabled")` and `@AppStorage("defaultReminderDays")` — these are read from `UserDefaults` in services.

## What's not implemented

- Offline/caching — every screen fetches fresh from Supabase on load
- Unit tests — services are not constructor-injectable yet
- App icon — `Assets.xcassets/AppIcon.appiconset` slot exists, needs a 1024×1024 PNG
- `delete_user` RPC needs to be deployed to Supabase (SQL in `docs/plans/2026-02-25-account-management-design.md`)
