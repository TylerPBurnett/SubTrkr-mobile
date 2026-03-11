# SubTrkr iOS — Autopay-First Payment Tracking Design

> Date: 2026-03-08
> Scope: Align mobile payment tracking with the desktop app's autopay-first mental model

---

## Overview

SubTrkr should treat recurring subscriptions and bills as **automatically ongoing charges by default** while an item is active. Users should not need to manually confirm every cycle just to keep the app accurate.

The current mobile app mixes two models:

- `nextBillingDate` already behaves like an expected recurring schedule
- `Payment` records only exist when the user manually taps Record Payment

That mismatch creates product confusion. The app partially assumes recurring charges happen automatically, but the UI still suggests payments are only tracked when manually recorded.

This spec defines a simpler default:

- **Recurring charges are tracked automatically**
- **Manual payment records are optional**
- **Status changes control whether charges continue**

This matches the desktop product direction and should require only small UI changes.

## Problem

Today on mobile:

- An item can advance its `nextBillingDate` automatically during maintenance
- Analytics can reconstruct spending without payment records
- But the only true payment rows come from a manual "Record" action

That leads to an awkward product story:

- Users may think they must mark every cycle as paid
- The app may move a bill or subscription forward without telling the user whether the last cycle was actually paid
- Payment history can look empty even when the app is already treating the item like an ongoing recurring cost

For a recurring-cost tracker, that is too much manual bookkeeping for the default case.

## Product Decision

SubTrkr iOS should adopt the same core assumption as desktop for **both subscriptions and bills**:

- If an item is **active**, it is assumed to continue billing on schedule
- If an item is **paused**, **cancelled**, or **archived**, future charges stop according to that status
- If an item is in **trial**, it is not assumed to charge until converted to active
- Users may still log a real payment when they want a confirmed record, a corrected amount, or a one-off exception

The app is therefore a **recurring charge tracker first** and a **manual payment ledger second**.

## Goals

- Match the desktop mental model
- Remove the expectation that users must manually mark every cycle
- Keep the UI nearly unchanged
- Preserve manual payment history for users who want it
- Let analytics prefer real payment records when available
- Avoid fabricating noisy payment history rows for every recurring cycle

## Non-Goals

- Building a full accounts-payable workflow
- Requiring users to reconcile every bill each month
- Introducing bank sync or charge verification
- Adding a complex paid/unpaid task manager in the first pass
- Reworking the dashboard, lists, or analytics UI in a major way

## Core Model

### 1. `nextBillingDate` = next expected charge

`nextBillingDate` should be treated as the next scheduled recurring charge date, not proof of whether the last cycle was manually confirmed.

If the item remains active and that date passes, the app can safely advance it forward to the next cycle. That is schedule maintenance, not payment entry.

### 1a. Billing dates must be calendar-accurate

Recurring schedules should advance by real calendar units, not fixed day counts:

- Weekly: add 1 calendar week
- Monthly: add 1 calendar month
- Quarterly: add 3 calendar months
- Yearly: add 1 calendar year

This matches the current implementation and avoids obvious drift such as treating "monthly" as "30 days later."

However, there are two important edge cases that need explicit product rules:

- **End-of-month anchors**: a subscription started on January 31 should not silently drift to the 28th forever after February
- **Due-today handling**: a billing date stored as a date-only value should remain due for the full day, not roll forward early because the current time is later than midnight

Recommendation:

- Preserve the original billing anchor semantics for recurring items
- Compare recurring due dates at day granularity, not timestamp granularity

Phase 1 implementation rule:

- Use `startDate` as the recurring anchor when it exists
- Fall back to the earliest known scheduled date already stored on the item when `startDate` is missing
- For monthly, quarterly, and yearly cycles, preserve the anchor day when possible and only clamp in shorter months
- If a user intentionally changes the billing cadence in edit UI, the saved schedule date becomes the new practical anchor until a dedicated anchor field exists

### 2. `Payment` records = optional confirmed charges

The `payments` table should remain useful, but its role changes:

- A payment row means a user explicitly logged or confirmed a charge
- No payment row does **not** mean the charge did not happen
- When a payment row exists, analytics should prefer that real amount/date over assumptions

This keeps payment history valuable without making it mandatory.

### 3. Status drives recurring behavior

Recurring billing should stop or resume based on item status:

- `active`: recurring charges continue automatically
- `paused`: no assumed charges while paused
- `cancelled`: no future charges after the cancellation date
- `archived`: no future charges
- `trial`: no assumed charges until conversion to active

This makes status the primary control for "does this keep charging?"

### 4. Effective dates must be retroactively editable

Users will not always update SubTrkr on the exact day something changes in real life.

Example:

- A user cancels ChatGPT Plus in January
- They forget to update SubTrkr until March
- They should still be able to set the cancellation date to January
- Analytics, upcoming payments, and yearly totals should then recompute as if the subscription ended in January

This means SubTrkr must distinguish between:

- **Recorded date**: when the user updated the app
- **Effective date**: when the real-world change actually took effect

Business logic should use the effective date. Audit/history UI may still show the recorded date.

Phase 1 scope clarification:

- `cancellationDate` is the authoritative effective date for cancellation logic
- `cancelledAt`, `pausedAt`, and `archivedAt` remain recorded timestamps for audit/history
- `pausedUntil` remains the effective resume date when present
- Retroactive effective dates are a phase-1 requirement for cancellation, resume/reactivate, and trial conversion to active
- Future-dated scheduled cancellations, reactivations, and conversions are out of scope for phase 1; these dates are historical or same-day only
- Pause and archive continue using recorded timestamps in phase 1 unless the product later adds dedicated effective-date fields for those actions

## UX Direction

The UI should communicate that SubTrkr tracks recurring charges automatically.

### Quick Actions

The current `Record` quick action is misleading because it implies manual logging is the main way the app knows a payment happened.

Recommended change:

- Remove `Record` from Quick Actions in phase 1
- Keep lifecycle actions focused on pause, cancel, archive, and status changes
- Preserve the underlying payment model/service so manual logging can return later if needed
- Keep a secondary `Log Payment` entry point in the overflow menu so manual confirmation remains available without implying it is the primary workflow

If a user-facing entry point is kept at all, it should be secondary:

- Overflow menu or payment history section
- Labeled **Log Payment**, not **Record**
- Clearly framed as optional

### Payment History Section

The empty state should no longer imply the app is missing payment tracking.

Recommended empty-state copy:

- "No confirmed payments logged"
- Supporting text: "Recurring charges are tracked automatically while this item is active."

This is the smallest UI change with the biggest clarity gain.

### Detail View Messaging

The detail screen should make the distinction between schedule and confirmation clearer:

- `Next Billing` remains a schedule field
- Payment history becomes a confirmation/exception layer
- No extra badges or cycle widgets are required in phase 1

## Behavioral Rules

### Active items

- If an item is active, the app assumes the recurring charge continues
- When maintenance sees `nextBillingDate` in the past, it advances it forward
- This does not require creating a payment record
- Items due **today** should still count as due today until the day ends

### Manual payment logging

If the user logs a payment:

- Store the payment row as usual
- Do not make users log every cycle
- Prefer the logged value in analytics for that period

Open implementation note:

- Logging a payment is confirmation-first, not schedule-first
- If the logged payment date is before the current `nextBillingDate`, do not move the schedule
- If the logged payment date is on or after the current due date, advance `nextBillingDate` forward until it becomes the next charge after the logged payment date
- Schedule advancement from payment logging is therefore conditional and should never skip extra cycles because of backfilled history

### Paused items

- No assumed charges while paused
- If an auto-resume date exists, recurring tracking resumes after that date

### Resume / Reactivate / Convert To Active

- When a paused, cancelled, archived, or trial item becomes active again, the effective activation date should be historical or same-day only in phase 1
- The app should recalculate `nextBillingDate` from that effective activation date instead of leaving the old schedule in place
- In phase 1, that activation date becomes the new practical billing anchor until the app has a dedicated lifecycle-anchor model

### Cancelled items

- No future charges after the cancellation date
- Historical assumed charges remain valid for prior periods
- Users must be able to retroactively edit the cancellation date later if they forgot to update the app at the time
- Phase 1 should not auto-archive cancelled items during maintenance; archiving remains an explicit user action so cancellation timing stays editable

### Trial items

- Trials are not assumed to generate charges
- Conversion to active begins normal recurring tracking
- Expired trials may still auto-cancel per existing maintenance behavior

## Analytics Impact

Analytics should continue using the existing priority:

1. Use real payment records when they exist for the period
2. Otherwise reconstruct expected recurring spend from active item metadata

This is already close to the current implementation and fits the autopay-first product model.

What changes is the product interpretation:

- Reconstructed spend is no longer a fallback born from missing user input
- It becomes the normal behavior for recurring items
- The UI should not expose a visible "confirmed vs assumed" distinction
- Historical calculations should respect retroactive effective dates when users correct status timing later

Phase 1 analytics contract:

- Summary cards and reconstructed trends remain a normalized recurring-spend view, not an invoice-perfect ledger
- Real payment rows still override the reconstructed amount for the month in which they were logged
- Calendar and upcoming-payment surfaces remain schedule-based and continue to reflect actual recurring due dates
- This keeps analytics behavior stable in phase 1 while aligning the product story with autopay-first tracking

## Data Model Recommendation

### Phase 1

No database changes required.

Use the current model:

- `items` define the recurring schedule and lifecycle
- `payments` remain optional confirmed entries

This keeps the change low-risk and mostly product/UX driven.

Implementation note:

- Phase 1 should still tighten billing-date advancement logic so recurring schedules remain accurate across calendar edge cases
- This is especially important for monthly items created on the 29th, 30th, or 31st, and yearly items created on February 29
- Phase 1 should also ensure analytics and upcoming-payment logic respect effective lifecycle dates such as `cancellationDate`, not just the timestamp when the app was updated
- Phase 1 should exclude trial items from auto-projected recurring charges until they convert to active

### Phase 2 if needed

If users later need stricter bill workflows, add per-item payment behavior:

- `automatic`
- `manual`

That would be most relevant for bills, not subscriptions. It should stay on the roadmap as a future idea, not enter phase 1 scope.

## Why This Is The Right Default

Most recurring subscriptions are effectively autopay from the user's perspective. Many recurring bills are also auto-drafted or otherwise expected to continue unless something changes.

Users open SubTrkr primarily to answer:

- "What am I paying for?"
- "What is coming up next?"
- "How much am I spending?"
- "What should I cancel?"

They do not usually want to complete a monthly bookkeeping task for every recurring line item.

The product should therefore optimize for **low-maintenance truth**:

- Assume recurring charges continue
- Let users intervene only for exceptions

## Likely Implementation Areas

| File | Change |
|------|--------|
| `Views/Items/ItemDetailView.swift` | Remove manual payment from Quick Actions; update payment history copy |
| `Services/ItemService.swift` | Keep schedule maintenance behavior, but frame it as recurring tracking rather than payment confirmation |
| `Services/AnalyticsService.swift` | Respect effective lifecycle dates, especially retroactive cancellations |
| `docs/ROADMAP.md` | Replace "payment tracking" language that implies manual per-cycle logging |

## Open Questions

These should be resolved before implementation:

1. Should manual payment logging be removed from the user-facing UI entirely in phase 1, or kept in a low-prominence overflow/detail location?
2. If kept, should manual payment logging remain available for all items or only appear for bills?
3. What are the exact billing-anchor rules for end-of-month items?
4. Should "due today" remain visible through the end of the day before advancing to the next cycle? Recommended answer: yes.

Resolved product direction:

- Retroactive corrections must be supported for lifecycle changes, especially cancellations
- Effective dates should drive analytics and future billing behavior

## Recommendation

For the next iteration:

- Align mobile with desktop
- Treat active recurring items as automatically tracked for both subscriptions and bills
- Keep analytics unified and invisible with respect to confirmed vs assumed charges
- Remove manual payment from Quick Actions
- Keep manual payment rows as optional confirmations only if a secondary UI entry point remains
- Make only small UI copy and hierarchy changes
- Avoid introducing a new required user task

That gives SubTrkr a more coherent product model without requiring a major redesign.
