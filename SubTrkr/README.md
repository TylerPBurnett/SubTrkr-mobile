# SubTrkr iOS

Native iOS companion app for [SubTrkr](https://github.com/TylerPBurnett/SubTrkr) — track your subscriptions and bills.

## Setup

1. Clone this repository
2. Open `SubTrkr/Package.swift` in Xcode
3. Configure your Supabase credentials:
   - Create `Secrets.xcconfig` in the project root (gitignored)
   - Add your Supabase URL and anon key
   - Or set them in `SupabaseManager.swift`

4. Build and run on iOS 17+ simulator or device

## Architecture

- **SwiftUI** with iOS 17+ features (@Observable, NavigationStack)
- **MVVM** architecture
- **Supabase Swift SDK** — shared backend with the desktop app
- **Swift Charts** — native charting
- **No offline mode** — always-connected, Supabase is source of truth

## Shared Backend

This app connects to the same Supabase project as the desktop app. All data (subscriptions, bills, categories, payments) syncs across platforms via RLS-protected tables scoped to `auth.uid()`.

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.10+
- Active Supabase project (shared with desktop app)
