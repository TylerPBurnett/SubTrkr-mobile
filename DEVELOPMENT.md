# SubTrkr iOS — Development Guide

## Opening the project

Always open the `.xcodeproj`, not `Package.swift`:

```
File → Open → SubTrkr-mobile/SubTrkr/SubTrkr.xcodeproj
```

Or from terminal:

```bash
open SubTrkr/SubTrkr.xcodeproj
```

On first open Xcode will resolve the Supabase package dependency automatically (~30 seconds).

---

## Running in the simulator

1. Confirm the scheme is **SubTrkr** and destination is an **iOS 18+ simulator**
2. **⌘R** to build and run
3. **⌘.** to stop

### From the terminal (no Xcode GUI needed)

```bash
# Build
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project SubTrkr/SubTrkr.xcodeproj \
  -scheme SubTrkr \
  -destination 'platform=iOS Simulator,id=7E4DF3CA-3821-43D5-8444-DB0ECB82C91C' \
  -derivedDataPath /tmp/SubTrkr-build \
  build

# Install
xcrun simctl install 7E4DF3CA-3821-43D5-8444-DB0ECB82C91C \
  /tmp/SubTrkr-build/Build/Products/Debug-iphonesimulator/SubTrkr.app

# Launch
xcrun simctl launch 7E4DF3CA-3821-43D5-8444-DB0ECB82C91C com.subtrkr.app
```

### Simulator UUIDs

| Device | UUID |
|---|---|
| iPhone 17 Pro | `7E4DF3CA-3821-43D5-8444-DB0ECB82C91C` |
| iPhone 17 Pro Max | `000E3A84-DD1A-4FC4-8972-C4D1A4498AFF` |
| iPhone 17 | `D0FD67ED-4D29-4362-B557-3DF29AB551A8` |
| iPhone Air | `79EC0D9C-88B4-401B-B1D1-D14164C0B840` |

---

## Project structure

```
SubTrkr-mobile/
├── .gitignore
├── README.md
├── PLAN.md
├── DEVELOPMENT.md          ← this file
└── SubTrkr/
    ├── SubTrkr.xcodeproj/  ← open this in Xcode
    ├── Package.swift       ← SPM (kept for CI/tooling, not for running)
    └── SubTrkr/            ← all source files
        ├── SubTrkrApp.swift       ← @main entry point
        ├── Info.plist             ← bundle config, URL scheme
        ├── Assets.xcassets/       ← AppIcon, AccentColor
        ├── Extensions/
        │   ├── Color+Theme.swift  ← semantic color tokens + ShapeStyle extensions
        │   ├── Date+Helpers.swift
        │   └── Double+Currency.swift
        ├── Models/                ← Codable data types
        │   ├── Item.swift
        │   ├── Category.swift
        │   ├── Payment.swift
        │   ├── StatusHistory.swift
        │   ├── AnalyticsModels.swift
        │   ├── Enums.swift        ← ItemType, ItemStatus, BillingCycle
        │   └── NotificationChannel.swift
        ├── Resources/
        │   └── KnownServices.swift  ← 50+ service names for autocomplete
        ├── Services/              ← all Supabase API calls live here
        │   ├── SupabaseManager.swift
        │   ├── AuthService.swift
        │   ├── ItemService.swift
        │   ├── CategoryService.swift
        │   ├── PaymentService.swift
        │   ├── AnalyticsService.swift
        │   └── NotificationService.swift
        ├── ViewModels/            ← @Observable state, one per screen
        │   ├── AuthViewModel.swift
        │   ├── DashboardViewModel.swift
        │   ├── ItemListViewModel.swift
        │   ├── ItemFormViewModel.swift
        │   ├── AnalyticsViewModel.swift
        │   └── SettingsViewModel.swift
        └── Views/                 ← SwiftUI views organized by feature
            ├── ContentView.swift  ← auth gate + main tab view
            ├── Analytics/
            ├── Auth/
            ├── Components/        ← reusable: EmptyState, StatusBadge, ServiceLogo, CurrencyText
            ├── Dashboard/
            ├── Items/             ← list, detail, form, status sheet
            └── Settings/
```

---

## Making changes

### The data flow pattern

```
Model (Models/) → Service (Services/) → ViewModel (ViewModels/) → View (Views/)
```

- **Data shape change** — edit the Model, update `CodingKeys` if the DB column name differs from the Swift property name
- **New API call** — add a method to the relevant Service file
- **UI state** — add a property to the ViewModel, never directly to the View
- **New screen** — create `FeatureView.swift` in `Views/`, `FeatureViewModel.swift` in `ViewModels/`, add navigation or a tab entry in the parent view

### Adding a new Swift file

**In Xcode (recommended):** right-click the target folder in the Project Navigator → New File → Swift File. Xcode adds it to the build target automatically.

**Outside Xcode (e.g. via editor or Claude Code):** create the file on disk, then in Xcode drag it into the Project Navigator and check the **SubTrkr** target checkbox. Files added to disk only will not compile until they're in the target.

---

## Credentials and config

Supabase credentials are resolved by `Services/SupabaseManager.swift` in this order:

1. `SUPABASE_URL` / `SUPABASE_ANON_KEY` environment variables (CI/CD use)
2. `Info.plist` keys populated by build settings

### Debug vs Release

- **Debug** uses `SubTrkr/Debug.xcconfig`, which is intentionally blank unless you opt into a backend.
- **Release** uses `SubTrkr/Release.xcconfig`, which keeps the current production project values.

To run a Debug build against a backend, use one of these:

1. Set `SUPABASE_URL` and `SUPABASE_ANON_KEY` in the Xcode scheme environment.
2. Create `SubTrkr/Secrets.xcconfig` from `SubTrkr/Secrets.example.xcconfig` and set your target values there.

If you do neither, Debug will fail fast on launch instead of silently talking to production. The anon key is safe to commit; do not commit the service role key.

## Supabase CLI workflow

- The repo is linked to Supabase project `bpgsfyallqqvvtjorybl` (`SubTrkr`).
- Existing remote migration history has been fetched into `supabase/migrations/`.
- `supabase db pull` currently needs Docker Desktop on this machine because the CLI creates a shadow database for schema diffing.

Use these commands from the repo root:

```bash
# See local vs remote migration history
supabase migration list

# Create a new migration file
supabase migration new add_feature_name

# Fetch migration history that already exists in the remote project
supabase migration fetch

# Preview a remote apply before touching the linked project
supabase db push --dry-run

# Dump a pre-change backup from the linked remote database
supabase db dump --linked --file supabase/backups/pre_change.sql
```

---

## Debugging

**Console output** — open the Debug area (⌘⇧Y). All `print()` statements and errors appear here.

**Network requests** — Supabase SDK doesn't log HTTP by default. Use Charles Proxy or set a breakpoint in `SupabaseManager.swift` to inspect requests.

**SwiftUI Previews** — add a `#Preview` macro to any view:

```swift
#Preview {
    DashboardView()
        .environment(AuthService())
}
```

Toggle the canvas with **⌥⌘↩**. Note: previews that use `AuthService` or `ItemService` will make real Supabase calls unless you stub the data.

**Live view hierarchy** — the debug bar has a hierarchy inspector button that shows live SwiftUI view state during a simulator run.

**Crash on launch** — check the Xcode console immediately. Common causes:
- Supabase client init failure (malformed URL in credentials)
- Force-unwrap on a nil optional in a ViewModel `.task` block

---

## Updating the Supabase SDK

```
Xcode → File → Packages → Update to Latest Package Versions
```

Or pin to a specific version:
```
Project Navigator → Package Dependencies → supabase-swift → edit version rule
```

---

## Common terminal commands

```bash
# Clear derived data if build behaves strangely
rm -rf ~/Library/Developer/Xcode/DerivedData/SubTrkr-*

# Wipe all simulator data (resets app state, login, etc.)
xcrun simctl erase 7E4DF3CA-3821-43D5-8444-DB0ECB82C91C

# Stream live app logs from the simulator
xcrun simctl spawn 7E4DF3CA-3821-43D5-8444-DB0ECB82C91C \
  log stream --predicate 'subsystem == "com.subtrkr.app"'

# List all available simulators
xcrun simctl list devices available

# List booted simulators
xcrun simctl list devices booted
```

---

## What's not implemented yet

| Feature | Status | Notes |
|---|---|---|
| Push notifications | Structure only | `NotificationService.swift` has no scheduling logic |
| OAuth deep links | Registered | `subtrkr://` scheme in `Info.plist`, handler in `SubTrkrApp.swift`, needs device testing |
| Offline mode | Not started | All screens hit Supabase on load, no caching layer |
| App icon | Slot ready | `Assets.xcassets/AppIcon.appiconset` exists, needs a 1024×1024 PNG |
| Unit tests | Not started | Services need constructor DI to be mockable |
