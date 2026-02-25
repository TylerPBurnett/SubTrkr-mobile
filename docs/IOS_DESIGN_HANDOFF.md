# SubTrkr iOS Design Handoff

This document captures the complete visual design language of SubTrkr desktop so the iOS app can achieve visual parity while feeling native to the platform.

---

## Design Identity

**"Financial Precision meets Soft Brutalism"**

SubTrkr uses bold typography, monospace data, generous spacing, and layered depth to make financial tracking feel both trustworthy and modern. Key traits:

- **Bold, confident type** for headings (800 weight)
- **Monospace for all financial data** (prices, dates, counts)
- **3-tier depth system** (shell > surface > card)
- **Green brand accent** (`#22c55e`) throughout
- **Subtle lift + glow micro-interactions**
- **2px borders** on inputs for brutalist structure

---

## Brand Color

| Usage | Value |
|-------|-------|
| Brand primary | `#22c55e` |
| Brand hover (light) | `#16a34a` |
| Brand hover (dark) | `#4ade80` |
| Brand gradient (forms, CTAs) | `linear-gradient(135deg, #22c55e 0%, #16a34a 100%)` |
| Brand glow shadow | `rgba(34, 197, 94, 0.25-0.35)` |

Both bill and subscription forms use the **same green brand color** -- no type-specific accent colors.

---

## Color Tokens

### Light Theme

| Token | Hex | Purpose |
|-------|-----|---------|
| `bg-base` | `#e3e5e8` | Outermost shell/frame |
| `bg-surface` | `#edeef2` | Main content panel |
| `bg-card` | `#ffffff` | Cards sitting on surface |
| `bg-input` | `#ffffff` | Form input backgrounds |
| `bg-hover` | `#e4e6ea` | Hover states |
| `bg-active` | `#d8dbe1` | Active/pressed states |
| `text-primary` | `#171717` | Main text |
| `text-secondary` | `#525252` | De-emphasized text |
| `text-muted` | `#a3a3a3` | Placeholders, disabled |
| `text-inverse` | `#ffffff` | Text on brand backgrounds |
| `border-default` | `#e5e5e5` | Standard borders, card edges |
| `border-muted` | `#f5f5f5` | Subtle borders |
| `border-strong` | `#d4d4d4` | Focus/emphasized borders |
| `brand-primary` | `#22c55e` | Primary buttons, links |
| `brand-muted` | `#f0fdf4` | Active nav background |
| `brand-text` | `#166534` | Brand-colored text |

### Dark Theme (Default)

| Token | Hex | Purpose |
|-------|-----|---------|
| `bg-base` | `#0c0d0e` | Outermost shell/frame |
| `bg-surface` | `#131415` | Main content panel |
| `bg-card` | `#1e2022` | Cards sitting on surface |
| `bg-input` | `#252729` | Form input backgrounds |
| `bg-hover` | `#252729` | Hover states |
| `bg-active` | `#2e3032` | Active/pressed states |
| `text-primary` | `#fafafa` | Main text |
| `text-secondary` | `#a3a3a3` | De-emphasized text |
| `text-muted` | `#525252` | Placeholders, disabled |
| `text-inverse` | `#171717` | Text on brand backgrounds |
| `border-default` | `#2e2e2e` | Standard borders, card edges |
| `border-muted` | `#262626` | Subtle borders |
| `border-strong` | `#404040` | Focus/emphasized borders |
| `brand-primary` | `#22c55e` | Primary buttons, links |
| `brand-muted` | `rgba(34, 197, 94, 0.15)` | Active nav background |
| `brand-text` | `#4ade80` | Brand-colored text |

### Accent Colors (Dark Theme values)

| Token | Hex | Usage |
|-------|-----|-------|
| `accent-blue` | `#60a5fa` | Info, "Active Subscriptions" stat |
| `accent-blue-muted` | `rgba(59, 130, 246, 0.2)` | Blue badge background |
| `accent-purple` | `#a78bfa` | "Yearly Spending" stat |
| `accent-purple-muted` | `rgba(139, 92, 246, 0.2)` | Purple badge background |
| `accent-amber` | `#fbbf24` | Warnings, "Due This Week" stat |
| `accent-amber-muted` | `rgba(245, 158, 11, 0.2)` | Amber badge background |
| `accent-red` | `#f87171` | Errors, delete, destructive |
| `accent-red-muted` | `rgba(239, 68, 68, 0.2)` | Red badge background |
| `accent-emerald` | `#34d399` | Success, positive trends |
| `accent-emerald-muted` | `rgba(16, 185, 129, 0.2)` | Green badge background |
| `accent-pink` | `#f472b6` | Category color option |
| `accent-cyan` | `#22d3ee` | Category color option |
| `accent-gray` | `#9ca3af` | Uncategorized items |

### Accent Colors (Light Theme values)

| Token | Hex |
|-------|-----|
| `accent-blue` | `#3b82f6` |
| `accent-blue-muted` | `#dbeafe` |
| `accent-purple` | `#8b5cf6` |
| `accent-purple-muted` | `#ede9fe` |
| `accent-amber` | `#f59e0b` |
| `accent-amber-muted` | `#fef3c7` |
| `accent-red` | `#ef4444` |
| `accent-red-muted` | `#fee2e2` |
| `accent-emerald` | `#10b981` |
| `accent-emerald-muted` | `#d1fae5` |
| `accent-pink` | `#ec4899` |
| `accent-cyan` | `#06b6d4` |
| `accent-gray` | `#6b7280` |

---

## Visual Hierarchy Rule

Cards must be visually distinct from their surface. The app uses a **3-tier background system**:

```
Shell/Frame        <- darkest (outer frame, bg-base)
  +-- Main Panel   <- mid (bg-surface)
       +-- Cards   <- lightest (bg-card)
```

**`bg-card` must differ from `bg-surface` by at least ~10 RGB units.** Less than that and cards dissolve into the background.

| Theme | bg-surface | bg-card | Gap |
|-------|-----------|---------|-----|
| Light | `#edeef2` | `#ffffff` | ~15 units |
| Dark  | `#131415` | `#1e2022` | ~12 units |

Card borders use `border-default` (not `border-muted`) for visible edges.

---

## Typography

### Fonts

| Role | Font | Weights | Letter-spacing |
|------|------|---------|---------------|
| **Display/Headings** | Inter (system fallback: -apple-system, SF Pro) | 700-800 | -0.03em |
| **Body** | Inter | 400-500 | -0.01em |
| **Data/Numbers** | JetBrains Mono | 400-700 | -0.01em |

### iOS Font Mapping

| Desktop Font | iOS Equivalent |
|-------------|---------------|
| Inter 800 | SF Pro Display Bold/Heavy |
| Inter 500 | SF Pro Text Medium |
| JetBrains Mono | SF Mono or bundle JetBrains Mono |

### Type Scale (Hierarchy)

| Level | Size | Weight | Font | Usage |
|-------|------|--------|------|-------|
| Display | 3.5rem (hero numbers) | 800 | Mono | Dashboard stat values |
| H1 | 1.75rem | 800 | Display | Page titles, dialog headers |
| H2 | 1.25rem | 700 | Display | Section headers, card titles |
| Body | 1rem | 500 | Body | General text |
| Label | 0.6875rem | 600, UPPERCASE | Body | Form labels, metadata (letter-spacing: 0.08em) |
| Data | varies | 500-700 | Mono | Numbers, dates, codes, inputs |
| Badge | 0.75rem | 600 | Mono | Status badges |

---

## Spacing

| Element | Value |
|---------|-------|
| Card padding | 1.5rem (24px) |
| Section gaps | 1.5-2rem (24-32px) |
| Input padding (vertical) | 0.875-1rem (14-16px) |
| Border radius (cards) | 1rem (16px) |
| Border radius (inputs) | 0.75rem (12px) |
| Border width (inputs) | 2px |

---

## Shadows

### Light Theme
| Token | Value |
|-------|-------|
| `shadow-sm` | `0 1px 2px rgba(0,0,0,0.06)` |
| `shadow-card` | `0 1px 3px rgba(0,0,0,0.07), 0 3px 8px rgba(0,0,0,0.06), 0 8px 24px -8px rgba(0,0,0,0.1)` |
| `shadow-elevated` | `0 1px 3px rgba(0,0,0,0.08), 0 4px 12px rgba(0,0,0,0.08), 0 16px 32px -8px rgba(0,0,0,0.14)` |
| `shadow-brand` | `0 4px 14px -3px rgba(34,197,94,0.35)` |

### Dark Theme
| Token | Value |
|-------|-------|
| `shadow-sm` | `0 1px 2px rgba(0,0,0,0.2)` |
| `shadow-card` | `0 1px 2px rgba(0,0,0,0.2), 0 2px 8px rgba(0,0,0,0.15), 0 8px 24px -8px rgba(0,0,0,0.2)` |
| `shadow-elevated` | `0 1px 2px rgba(0,0,0,0.25), 0 4px 12px rgba(0,0,0,0.2), 0 16px 32px -8px rgba(0,0,0,0.3)` |
| `shadow-brand` | `0 4px 14px -3px rgba(34,197,94,0.25)` |

---

## Card Depth Effects

Cards have a subtle gradient + noise texture overlay for a physical feel:

- **Background gradient**: `linear-gradient(145deg, bg-card 0%, slightly-darker 100%)`
- **Inner highlight**: `inset 0 1px 0 0 rgba(255,255,255,0.06)` (dark), `rgba(255,255,255,1)` (light)
- **Noise texture overlay** at low opacity (0.025 dark, 0.03 light)
- **Hover**: adds brand-tinted glow + lift (`translateY(-1px)`)

---

## Component Patterns

### Dashboard Stats Cards
- 4-column horizontal row of stat cards
- Each has: label (uppercase, small), large monospace number, optional trend indicator
- Each stat has its own accent color icon:
  - Monthly Spending: emerald/green
  - Yearly Spending: purple
  - Active Items: blue
  - Due This Week: amber
- Icon sits in a colored muted badge in the top-right corner

### Subscription/Bill Cards (Grid View)
- Card grid layout (responsive, 3 columns on desktop)
- Each card shows:
  - Service logo (fetched from Clearbit by domain) + name + category
  - Large monospace price (`$XX.XX`)
  - Billing cycle label (Monthly, Yearly, etc.)
  - Next billing date in monospace
  - Optional status badge (e.g., "TRIAL") in top-right
- Left border: 6px solid in category color (optional, for list view)
- Cards lift on hover with brand glow

### Subscription/Bill Cards (List View)
- Horizontal row per item
- Logo + name on left, price + next billing on right
- Category color indicator

### Navigation (Sidebar)
- Left sidebar with icon + text nav items
- Active item: brand-muted background + brand-text color + 700 weight
- Hover: slide right 2px + bg-hover
- Items: Dashboard, Subscriptions, Bills, Analytics
- Bottom: theme toggle + settings gear

### Filter Tabs (Segmented Control)
- Pill-shaped segmented control: "All | Bills | Subscriptions"
- Active segment: brand-primary background, inverse text
- Inactive: bg-hover background, secondary text
- Smooth transition between states

### Forms (ItemForm)
- Green gradient header bar at top
- All labels: uppercase, 0.6875rem, 600 weight, 0.08em letter-spacing
- All inputs: monospace font, 2px borders, lift on focus
- Service autocomplete with logo + name + price suggestions
- Amount input emphasized (larger)
- Brand green submit button with glow

### Upcoming Payments
- List within a card
- Each row: service logo, name, price, days until due
- Urgency coloring:
  - Due today: red tint
  - 1-3 days: amber tint
  - 4-7 days: neutral

### Analytics View
- Stats row at top (Monthly Average, Savings, Yearly Total, Active Items)
- Monthly Spending Trend: line chart with green line, dots glow on hover
- Spending by Category: horizontal bar chart, category-colored bars
- Most Expensive Items: ranked list
- Cancellation History: list or empty state

### Charts
- Green primary line/bar color
- Monospace axis labels and tooltip values
- Active dot on line charts: green glow (`drop-shadow`)
- Bar hover: slight scale up (1.03) + opacity change
- Staggered entrance animation for bars

---

## Micro-Interactions & Animation

### Timing
| Type | Duration | Easing |
|------|----------|--------|
| Entrance | 0.3-0.4s | `cubic-bezier(0.16, 1, 0.3, 1)` (expo out) |
| Interactions | 0.2s | `cubic-bezier(0.16, 1, 0.3, 1)` |
| Spring/bounce | 0.2-0.3s | `cubic-bezier(0.34, 1.56, 0.64, 1)` |
| Loading pulse | 2s loop | expo out |
| Stagger delay | 0.05s per item | - |

### Interaction Patterns
- **Cards**: lift on hover/tap (`translateY(-1px)`) + elevated shadow
- **Buttons**: lift on hover + press down on active
- **Nav items**: slide right on hover (`translateX(2px)`)
- **Inputs**: lift on focus + green border + green shadow
- **Lists**: stagger slide-up entrance (each item delayed 0.05s)
- **Modals/sheets**: zoom-in from 95% scale + fade
- **Dropdowns**: slide down + fade in

### iOS-Specific Animation Notes
- Map `translateY(-1px)` hover to subtle scale or haptic on tap
- Use iOS spring animations (`UISpringAnimation`) for the spring easing
- Stagger animations map well to SwiftUI's `.transition` with delays
- Consider iOS-native sheet presentations instead of custom modals

---

## App Icon & Logo

- Brand color: `#22c55e` green
- App name: "SubTrkr" (capital S, capital T)
- Logo uses the brand green as primary

---

## Service Logos

- Fetched dynamically from Clearbit: `https://logo.clearbit.com/{domain}`
- Fallback: first letter of service name in a colored circle
- Displayed at small sizes (32-40px) with rounded corners

---

## Known Services Database

The app has a built-in database of ~100+ known subscription services and bills in `src/data/knownServices.ts`. Each entry has:
- `name`, `domain` (for logo), `defaultPrice`, `defaultCurrency`
- `defaultBillingCycle` (weekly/monthly/quarterly/yearly)
- `suggestedCategory`, `type` (subscription/bill/both)
- `aliases` for search

Categories include: Streaming, Music, Software, Gaming, Fitness, Cloud Storage, News, Security, Food & Delivery, Shopping, Finance, Home & Security, Phone & Internet, Insurance, Utilities.

---

## Screenshots Reference

Three screenshots from the desktop app are available in `docs/Images/`:
- `dashboard-hero.png` - Dashboard view with stats, upcoming payments, spending chart
- `subscriptions-grid.png` - Subscription cards in grid layout
- `analytics-view.png` - Analytics page with charts and stats

---

## iOS Adaptation Notes

1. **Dark mode is the default** - the app was designed dark-first
2. **Use SF Pro / SF Mono** as native equivalents, or bundle JetBrains Mono for data fidelity
3. **Tab bar instead of sidebar** on iOS - map the 4 nav items (Dashboard, Subscriptions, Bills, Analytics) to bottom tabs
4. **Cards should use the same depth system** - SwiftUI Materials or custom backgrounds that maintain the 3-tier hierarchy
5. **Haptics** can replace hover states - light haptic on card tap, medium on actions
6. **Green brand accent** should be consistent with the same `#22c55e` hex
7. **Form inputs**: consider native iOS text fields styled with the 2px border treatment
8. **Pull-to-refresh** can use brand green spinner
9. **The design intentionally avoids gradients on most surfaces** - only forms and status badges use gradients
10. **Supabase backend is shared** - the iOS app connects to the same Supabase project (`bpgsfyallqqvtjorybl`)
