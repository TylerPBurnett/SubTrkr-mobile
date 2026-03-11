# SubTrkr iOS — Billing Anchor Accuracy Implementation Spec

> Date: 2026-03-08
> Scope: Keep recurring billing dates accurate over time for autopay-first subscriptions and bills

---

## Overview

SubTrkr's autopay-first model only works if recurring billing dates remain trustworthy over long periods.

For typical dates like March 8, the current app is already close: it uses calendar months, not a fixed 30-day offset. But there are still correctness gaps:

- End-of-month items can drift permanently
- Items due today can roll forward too early
- Calendar projection inherits the same iterative date-drift problem

This spec defines the implementation needed to make recurring dates accurate enough to trust as the source of truth for:

- Upcoming payments
- Calendar projection
- Renewal reminders
- Dashboard totals derived from upcoming billing behavior

## Current Behavior

The app currently advances recurring dates by repeatedly adding calendar units to the last stored date via `DateHelper.advanceDate(_:by:)`.

That logic is used in several places:

- `ItemFormViewModel.autoCalcNextBillingDate()` for new items
- `ItemService.advancePastDueItems()` during maintenance
- `CalendarViewModel.projectBillingDays()` for future month projection
- `ItemDetailView.recordPayment()` when manual payment logging advances a cycle

This is better than fixed day math, but it still has a flaw:

- Repeatedly advancing a clipped date changes the anchor

Example:

- Start date: January 31
- Current logic: January 31 -> February 28 -> March 28 -> April 28
- Expected behavior: January 31 -> February 28 -> March 31 -> April 30

The same class of issue appears for:

- January 30 monthly items
- February 29 yearly items
- Any recurrence whose original day does not exist in some periods

## Product Rules

### 1. Use the original billing anchor

Recurring schedules must preserve the original billing anchor, not the last clipped occurrence.

The billing anchor should come from:

1. `item.startDate` when available
2. Otherwise `item.nextBillingDate`
3. Otherwise `item.createdAt` converted to a date-only value

This avoids a database migration in phase 1 because the app already stores `startDate`.

### 2. Advance by recurrence period, then clamp within the target month/year

For month-based recurrences, compute the target period first, then clamp the anchor day to the last valid day of that period.

Examples:

- Anchor March 8 monthly: April 8, May 8, June 8
- Anchor January 30 monthly: February 28, March 30, April 30
- Anchor January 31 monthly: February 28, March 31, April 30, May 31
- Anchor February 29 yearly: February 28 in non-leap years, February 29 in leap years

### 3. Treat due dates as date-only values

`nextBillingDate` is stored as `yyyy-MM-dd`, so all recurrence comparisons should happen at day granularity.

Implication:

- An item due on March 8 should remain due on March 8 for the full day
- Maintenance should only advance it on March 9
- "Today" should never disappear just because the current time is after midnight

### 4. Apply the same recurrence rules everywhere

The same anchor-preserving logic must drive:

- Form auto-calculation
- Maintenance rollover
- Calendar month projection
- Optional manual payment rollover
- Notification scheduling inputs

SubTrkr cannot have one recurrence rule in the item form and another in the calendar.

## Recommended API

Add recurrence helpers to `DateHelper` instead of scattering calendar math across services and view models.

Recommended helpers:

```swift
static func startOfToday() -> Date
static func startOfDay(_ date: Date) -> Date
static func isBeforeToday(_ date: Date) -> Bool

static func nextRecurringDate(
    anchorDate: Date,
    cycle: BillingCycle,
    onOrAfter referenceDate: Date
) -> Date

static func nextRecurringDate(
    anchorDate: Date,
    cycle: BillingCycle,
    strictlyAfter referenceDate: Date
) -> Date

static func recurringDates(
    anchorDate: Date,
    cycle: BillingCycle,
    in interval: DateInterval
) -> [Date]
```

Key design point:

- `advanceDate(_:by:)` can remain as a low-level helper if useful
- But business logic should stop relying on repeated `advanceDate(current)` loops for month-based recurrence

## Algorithm

### Weekly

- Safe to advance by calendar week
- The weekday remains stable

### Monthly

Given an anchor date:

1. Extract the anchor day-of-month
2. Determine the target month/year based on the number of elapsed monthly periods
3. Build the candidate date in that target month
4. If the month has fewer days than the anchor, clamp to the month's last day

Important:

- Compute from the anchor date and target period index
- Do not derive March from the clipped February date

### Quarterly

- Same rule as monthly, but the period step is 3 months
- Preserve the original day-of-month anchor

### Yearly

1. Preserve the original month/day from the anchor
2. Move to the target year
3. Clamp only when the day is invalid for that year

Example:

- February 29, 2024 -> February 28, 2025 -> February 28, 2026 -> February 28, 2027 -> February 29, 2028

## Touchpoints

### 1. Item creation: `ItemFormViewModel`

Current issue:

- `autoCalcNextBillingDate()` repeatedly advances from `startDate`, which can drift for 29th/30th/31st anchors

Required change:

- Use `nextRecurringDate(anchorDate: startDate, cycle: billingCycle, strictlyAfter: startOfToday())` when `startDate` is today or in the past
- If `startDate` is in the future, keep `nextBillingDate = startDate`

Why:

- A user who signs up on March 8 should see April 8 as the next charge
- A user entering a future bill starting April 15 should still see April 15 as the next charge

### 2. Maintenance rollover: `ItemService.advancePastDueItems()`

Current issue:

- Uses `nextDate < now`, so items due today can roll forward early
- Repeatedly advances from the current clipped date

Required change:

- Only advance items whose `nextBillingDate` is before `startOfToday`
- Recompute the next billing date from the item's billing anchor
- Advance to the first recurring date on or after `startOfToday`

Why:

- March 8 should still show as due on March 8
- January 31 items should recover to March 31 after February

### 3. Calendar projection: `CalendarViewModel`

Current issue:

- Projects future dates by repeatedly advancing from `nextBillingDate`
- End-of-month items can show the wrong future day dots

Required change:

- Project dates using the anchor-preserving recurrence helper
- Generate all recurring dates that fall inside the displayed month interval

Why:

- The calendar is one of the app's most visible scheduling surfaces
- If the calendar drifts, the whole autopay-first model feels unreliable

### 4. Manual payment rollover: `ItemDetailView`

Current issue:

- If manual logging remains, it advances `nextBillingDate` from the current displayed date

Required change:

- If this path remains in the app, it must use the same anchor-preserving recurrence helper
- If manual payment UI is removed, still keep this in mind for any hidden/admin path using the same behavior

### 5. Notifications: `NotificationService`

Current issue:

- Notifications read `item.nextBillingDate` directly
- They inherit whatever correctness the stored date has

Required change:

- No direct reminder algorithm change is required for phase 1
- But reminders should be considered downstream consumers of corrected `nextBillingDate`

## Legacy Fallback Strategy

Not every existing item may have a reliable `startDate`.

Fallback order:

1. `startDate`
2. `nextBillingDate`
3. `createdAt` date portion

Behavior note:

- Fallbacks 2 and 3 cannot perfectly reconstruct the original anchor if it was already drifted before this fix
- That is acceptable for phase 1
- New and correctly edited items will become stable going forward

## Data Model

Phase 1 requires no schema changes.

Use the existing fields:

- `startDate` as the billing anchor when present
- `nextBillingDate` as the next upcoming occurrence

Future option if needed:

- Add an explicit stored billing anchor field only if real-world data reveals too many legacy items without reliable `startDate`

## Files To Modify

| File | Change |
|------|--------|
| `Extensions/Date+Helpers.swift` | Add anchor-preserving recurrence helpers and day-granularity comparison helpers |
| `Models/Item.swift` | Add a computed billing-anchor accessor if helpful |
| `ViewModels/ItemFormViewModel.swift` | Replace iterative next-date calculation with anchor-preserving helper |
| `Services/ItemService.swift` | Fix overdue advancement to use date-only comparison and anchor-preserving rollover |
| `ViewModels/CalendarViewModel.swift` | Replace iterative month projection with anchor-preserving recurrence generation |
| `Views/Items/ItemDetailView.swift` | If manual payment rollover remains, use the same recurrence helper |

## Example Timelines

### Typical monthly subscription

- Start: 2026-03-08
- Next dates: 2026-04-08, 2026-05-08, 2026-06-08

### 31st-of-month subscription

- Start: 2026-01-31
- Next dates: 2026-02-28, 2026-03-31, 2026-04-30, 2026-05-31

### 30th-of-month subscription

- Start: 2026-01-30
- Next dates: 2026-02-28, 2026-03-30, 2026-04-30

### Leap-day yearly subscription

- Start: 2024-02-29
- Next dates: 2025-02-28, 2026-02-28, 2027-02-28, 2028-02-29

### Due-today maintenance

- Today: 2026-03-08
- Stored `nextBillingDate`: 2026-03-08
- Expected result: item remains due today, does not roll until 2026-03-09

## Verification

Manual verification checklist:

1. Create a monthly item starting today and confirm the next billing date is next month on the same day.
2. Create a monthly item starting on the 31st and verify the next six occurrences recover correctly after shorter months.
3. Create a yearly item anchored on February 29 and verify non-leap and leap-year behavior.
4. Open the app on a due date and verify the item still appears due today throughout the day.
5. Open the calendar several months ahead for a 31st-anchored item and verify the projected dots land on the correct dates.
6. Enable notifications and verify reminder dates follow the corrected `nextBillingDate`.

Code-level verification target:

- Add focused unit coverage for recurrence helper behavior once test infrastructure exists

## Recommendation

This should be implemented as the next data-correctness task after the autopay-first product alignment.

Without it, the product story is right but the recurrence engine is still vulnerable to silent drift. With it, SubTrkr can treat recurring dates as a reliable foundation for upcoming-payment tracking without needing bank-account integration.
