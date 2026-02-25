# SubTrkr iOS — Record Payment UI & Auto-Calc Billing Date Design

> Date: 2026-02-25
> Scope: Roadmap items #6 (Record Payment UI) and #11 (Auto-calculate next billing date)

---

## Feature A: Record Payment UI

**Location:** `ItemDetailView` — button in payment history section, opens a sheet.

**Sheet contents:**
- Amount field (pre-filled from `item.amount`, editable)
- Date picker (default today)
- Save button

**On save:**
1. Call `PaymentService.recordPayment(userId:itemId:amount:paidDate:)`
2. Auto-advance `nextBillingDate` by one billing cycle using `DateHelper.advanceDate` via `ItemService.updateItem`
3. Refresh the item data and payment list in the detail view

**No separate ViewModel** — the sheet is simple enough to use `@State` properties and call services directly.

---

## Feature B: Auto-Calculate Next Billing Date

**Location:** `ItemFormViewModel` — reactive computation when `startDate` or `billingCycle` changes.

**Logic:**
- Only for new items (not editing)
- When `startDate` or `billingCycle` changes, roll `startDate` forward by the billing cycle until it's in the future
- Track whether the user has manually adjusted `nextBillingDate` — if so, don't override

Uses existing `DateHelper.advanceDate(_:by:)`.

---

## Files Modified

| File | Change |
|------|--------|
| `Views/Items/ItemDetailView.swift` | Add "Record Payment" button, payment sheet, save logic with auto-advance |
| `ViewModels/ItemFormViewModel.swift` | Add auto-calc nextBillingDate from startDate + billingCycle for new items |

No new files. No DB changes.
