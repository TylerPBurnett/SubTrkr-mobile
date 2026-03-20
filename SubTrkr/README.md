# SubTrkr iOS

Native iOS companion app for [SubTrkr](https://github.com/TylerPBurnett/SubTrkr) — track your subscriptions and bills.

## Setup

1. Clone this repository
2. Open `SubTrkr/SubTrkr.xcodeproj` in Xcode
3. Configure your Supabase credentials:
   - Copy `Secrets.example.xcconfig` to `Secrets.xcconfig`
   - Add your Supabase URL and anon key
   - Or set `SUPABASE_URL` / `SUPABASE_ANON_KEY` in the Xcode scheme environment

4. Build and run on iOS 17+ simulator or device

## Testing

The shared `SubTrkr` scheme now includes both the app unit tests and the UI harness tests.

- Run unit tests from Xcode with `Product > Test`, or from the terminal:
  `xcodebuild test -project SubTrkr/SubTrkr.xcodeproj -scheme SubTrkr -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:SubTrkrTests`
- Run UI/e2e harness tests:
  `xcodebuild test -project SubTrkr/SubTrkr.xcodeproj -scheme SubTrkr -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:SubTrkrUITests`

The UI test target launches a deterministic billing harness with a fixed test date, so the recurring-billing scenarios stay stable across runs.

## Architecture

- **SwiftUI** with iOS 17+ features (@Observable, NavigationStack)
- **MVVM** architecture
- **Supabase Swift SDK** — shared backend with the desktop app
- **Swift Charts** — native charting
- **No offline mode** — always-connected, Supabase is source of truth

## Shared Backend

This app connects to the same Supabase project as the desktop app. All data (subscriptions, bills, categories, payments) syncs across platforms via RLS-protected tables scoped to `auth.uid()`.

Debug builds do not silently use production anymore. If you have not configured `Secrets.xcconfig` or scheme environment variables, the app will stop on launch with a clear configuration error instead.

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.10+
- Active Supabase project (shared with desktop app)
