# SubTrkr iOS Companion App — Implementation Plan

## Overview
Native iOS companion app (Swift + SwiftUI, iOS 17+, iPhone) that shares the same Supabase backend as the desktop SubTrkr app. Users see the same subscriptions, bills, categories, and analytics on both platforms.

---

## Tech Stack

| Layer | Technology | Rationale |
|-------|-----------|-----------|
| **UI Framework** | SwiftUI (iOS 17+) | Latest APIs: NavigationStack, Observable macro, `.searchable`, animations |
| **Architecture** | MVVM + @Observable | Clean separation, native SwiftUI pattern, no 3rd-party state management |
| **Backend** | Supabase Swift SDK | Official SDK, same project as desktop — shared data & auth |
| **Auth** | Supabase Auth + ASWebAuthenticationSession | Google/GitHub OAuth, magic link, email/password |
| **Charts** | Swift Charts (Apple) | Native, performant, great SwiftUI integration (iOS 16+) |
| **Networking** | Supabase SDK (PostgREST) | Direct client calls matching desktop's pattern |
| **Local Notifications** | UserNotifications framework | Bill reminders, trial expiration alerts |
| **Image Loading** | AsyncImage + cache | Service logos from Logo.dev API |
| **Package Manager** | Swift Package Manager | Standard, no CocoaPods/Carthage needed |
| **Deep Linking** | Custom URL scheme `subtrkr://` | OAuth callbacks, universal links |

### Dependencies (Swift Packages)
1. `supabase-swift` — Supabase client (auth, database, realtime)
2. That's it. Keeping dependencies minimal — Apple frameworks cover charts, notifications, auth sessions, and image loading.

---

## Architecture

```
SubTrkr/
├── SubTrkrApp.swift                    # App entry, deep link handling, auth gate
├── Models/                             # Codable structs matching Supabase schema
│   ├── Item.swift                      # Subscription/Bill model
│   ├── Category.swift
│   ├── Payment.swift
│   ├── StatusHistory.swift
│   ├── NotificationChannel.swift
│   └── Enums.swift                     # BillingCycle, ItemType, ItemStatus, etc.
├── Services/                           # Supabase communication layer
│   ├── SupabaseManager.swift           # Client singleton, realtime subscriptions
│   ├── AuthService.swift               # Sign in/up, OAuth, OTP, session management
│   ├── ItemService.swift               # CRUD + status changes + maintenance
│   ├── CategoryService.swift           # CRUD + default seeding
│   ├── PaymentService.swift            # Record & fetch payments
│   ├── AnalyticsService.swift          # Spending calculations (monthly/yearly/by-category)
│   └── NotificationService.swift       # Local notifications + channel management
├── ViewModels/                         # @Observable classes
│   ├── AuthViewModel.swift
│   ├── DashboardViewModel.swift
│   ├── ItemListViewModel.swift
│   ├── ItemFormViewModel.swift
│   ├── AnalyticsViewModel.swift
│   ├── SettingsViewModel.swift
│   └── CategoryViewModel.swift
├── Views/
│   ├── ContentView.swift               # Root: auth gate → TabView
│   ├── Auth/
│   │   ├── AuthScreen.swift            # Sign in / Sign up / OTP flow
│   │   └── OTPVerificationView.swift
│   ├── Dashboard/
│   │   ├── DashboardView.swift         # Stats cards, upcoming payments, category chart
│   │   ├── StatsCard.swift
│   │   └── UpcomingPaymentRow.swift
│   ├── Items/
│   │   ├── ItemListView.swift          # Filterable, sortable list
│   │   ├── ItemRow.swift               # Row with logo, name, amount, status badge
│   │   ├── ItemDetailView.swift        # Full detail + status actions + payment history
│   │   ├── ItemFormView.swift          # Add/Edit form with service autocomplete
│   │   ├── StatusChangeSheet.swift     # Pause/cancel/resume/archive actions
│   │   └── SearchFilterBar.swift       # Search + category/status filters + sort
│   ├── Analytics/
│   │   ├── AnalyticsView.swift         # Tabbed: overview, categories, trends
│   │   ├── SpendingOverview.swift      # Monthly/yearly totals, savings
│   │   ├── CategoryBreakdown.swift     # Donut chart + list
│   │   └── SpendingTrend.swift         # 6-month area/bar chart
│   ├── Settings/
│   │   ├── SettingsView.swift          # Grouped list
│   │   ├── CategoryManagement.swift    # Add/edit/delete categories
│   │   ├── NotificationSettings.swift  # Reminders, channels, timezone
│   │   └── AccountSettings.swift       # Profile, sign out, delete account
│   └── Components/                     # Reusable UI pieces
│       ├── ServiceLogo.swift           # AsyncImage with Logo.dev
│       ├── StatusBadge.swift           # Colored pill badge
│       ├── EmptyState.swift
│       ├── CurrencyText.swift          # Formatted currency display
│       └── SegmentedPicker.swift
├── Extensions/
│   ├── Color+Theme.swift               # Brand colors, semantic tokens
│   ├── Date+Helpers.swift              # Billing date calculations
│   └── Double+Currency.swift           # Currency formatting
├── Resources/
│   ├── Assets.xcassets/                # App icon, colors, images
│   └── KnownServices.swift            # 50+ pre-populated services
└── Configuration/
    ├── Info.plist                       # URL schemes, permissions
    └── Secrets.xcconfig                # Supabase URL + anon key (gitignored)
```

---

## Implementation Phases

### Phase 1: Project Setup & Auth (Steps 1-3)

**Step 1 — Xcode Project Scaffold**
- Create Swift Package-based Xcode project structure
- Add `supabase-swift` SPM dependency
- Configure `Secrets.xcconfig` for Supabase credentials (gitignored)
- Set up `.gitignore` for Xcode/Swift
- Define color assets and brand theme (`#22c55e` green)

**Step 2 — Data Models**
- Define all `Codable` structs matching Supabase schema exactly
- `Item`, `Category`, `Payment`, `StatusHistory`, `NotificationChannel`
- Enums: `BillingCycle`, `ItemType`, `ItemStatus`, `NotificationChannelType`
- Computed properties for display (formatted amount, days until due, etc.)

**Step 3 — Authentication**
- `AuthService` with all auth methods (email/pass, OTP, Google, GitHub)
- `AuthViewModel` managing auth state
- `AuthScreen` UI: sign in, sign up, magic link, OAuth buttons
- Deep link handling for OAuth callbacks (`subtrkr://auth-callback`)
- Session persistence and auto-refresh
- Auth gate in `ContentView` (authenticated → TabView, else → AuthScreen)

### Phase 2: Core CRUD & Navigation (Steps 4-6)

**Step 4 — Supabase Services**
- `SupabaseManager` singleton with client initialization
- `ItemService`: fetch all, create, update, delete, status change with audit trail
- `CategoryService`: fetch, create, update, delete, seed defaults
- `PaymentService`: fetch, record
- Realtime subscriptions for live sync

**Step 5 — Tab Navigation & Dashboard**
- `TabView` with 4 tabs: Dashboard, Subscriptions, Bills, Settings
- `DashboardView`: monthly/yearly spending cards, upcoming payments list, category donut chart (Swift Charts)
- Pull-to-refresh on all data views

**Step 6 — Item List & CRUD**
- `ItemListView` with two instances (subscriptions tab, bills tab) filtered by `item_type`
- `ItemRow`: service logo, name, amount, billing cycle, status badge, next billing date
- `ItemFormView`: add/edit with service autocomplete from known services list
- Swipe actions: edit, delete (with confirmation)
- `ItemDetailView`: full details, payment history, status actions

### Phase 3: Filtering, Search & Status Management (Steps 7-8)

**Step 7 — Search, Filter & Sort**
- `.searchable` modifier for text search
- Category filter (multi-select)
- Status filter toggles (active, trial, paused, cancelled)
- Sort options: next billing date, name, price, category, status
- Sort direction toggle
- Persist filter preferences with `@AppStorage`

**Step 8 — Status Management**
- `StatusChangeSheet`: pause (with optional resume date), cancel (with effective date), resume, archive, start trial
- Reason and notes fields
- Status history audit trail (writes to `item_status_history`)
- Background maintenance on app launch: advance overdue dates, auto-archive, auto-resume, handle expired trials

### Phase 4: Analytics & Charts (Step 9)

**Step 9 — Analytics Dashboard**
- `AnalyticsView` with segmented control: Overview | Categories | Trends
- **Overview**: monthly total, yearly projection, monthly savings, top 5 expensive items
- **Categories**: donut chart (Swift Charts `SectorMark`), per-category spending list
- **Trends**: 6-month spending trend (Swift Charts `AreaMark` / `BarMark`)
- Calculations match desktop logic: weekly×52/12, quarterly/3, yearly/12

### Phase 5: Notifications & Settings (Steps 10-11)

**Step 10 — Local Notifications**
- Request notification permissions
- Schedule local notifications for upcoming bill/subscription renewals
- Configurable reminder days (1-30 days before)
- Trial expiration alerts
- Reschedule on item update/delete

**Step 11 — Settings**
- **Category Management**: list, add (name + color picker), edit, delete with confirmation
- **Notification Settings**: toggle reminders, set default reminder days, timezone picker
- **Notification Channels**: view/manage Telegram, Discord, Slack configs
- **Account**: display email, sign out, password change (if email auth)
- **About**: app version, link to desktop app

### Phase 6: Polish & Ship (Steps 12-13)

**Step 12 — UI Polish**
- Loading skeletons / shimmer effects
- Empty states with illustrations and CTAs
- Haptic feedback on key actions
- Smooth transitions and animations (matched geometry, spring animations)
- Dark mode support (respecting system setting + brand green accent)
- Dynamic Type support for accessibility
- Error handling with user-friendly alerts

**Step 13 — Final Integration & Testing**
- End-to-end testing with Supabase
- Background app refresh for maintenance tasks
- App icon and launch screen
- Commit and push

---

## Design Direction

- **Apple Human Interface Guidelines** compliant
- **Brand green** (`#22c55e`) as accent color, matching desktop
- **Dark mode first** with full light mode support
- **Native iOS feel**: SF Symbols for icons, system fonts (SF Pro), standard navigation patterns
- **Card-based layouts** for items (similar to desktop but adapted for mobile)
- **Tab bar navigation** (Dashboard, Subscriptions, Bills, Settings) instead of sidebar

---

## Data Flow

```
User Action → SwiftUI View → @Observable ViewModel → Service → Supabase SDK → PostgreSQL
                                                                    ↓
                                                              Realtime Channel
                                                                    ↓
                                                    ViewModel updates → View re-renders
```

---

## Key Design Decisions

1. **Same Supabase project** — no new backend, RLS policies already handle multi-platform
2. **No offline-first** for v1 — keeps complexity low, always-connected mobile use case
3. **Supabase Swift SDK only dependency** — Apple frameworks handle everything else
4. **@Observable macro** (iOS 17) — simpler than ObservableObject + @Published
5. **No Core Data/SwiftData** — Supabase is source of truth, in-memory caching only
6. **Swift Charts** — no 3rd-party charting library needed
7. **ASWebAuthenticationSession** — secure OAuth flow without embedded WebView
