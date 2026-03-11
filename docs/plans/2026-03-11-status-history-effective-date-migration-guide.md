# Cross-Platform Status History Effective-Date Migration Guide

> Date: 2026-03-11
> Scope: Shared backend schema change plus mobile and desktop follow-up work

---

## Summary

SubTrkr should persist two different timestamps for lifecycle history:

- `changed_at`: when the user recorded the change in the app
- `effective_date`: when the real-world change actually took effect

Right now `item_status_history` only stores the resulting `status`, optional `reason` and `notes`, and `changed_at`. That is not enough for reliable retroactive lifecycle tracking.

This guide recommends an additive schema migration plus small follow-up changes in both apps so mobile and desktop share one durable lifecycle-history contract.

## Why This Is Needed

### 1. Retroactive lifecycle changes are a real product requirement

Users do not always update SubTrkr on the day something happens.

Examples:

- a subscription was cancelled two months ago, but the user updates it today
- a paused item was actually resumed last week, but the user catches up later
- a trial converted to paid on an earlier date, and analytics should count charges only after that point

Those cases require the system to know both:

- when the user entered the change
- when the change actually became effective

`changed_at` alone cannot represent both facts.

### 2. The current history table loses important meaning

The current schema in the desktop repo creates `item_status_history` like this:

- `status`
- `reason`
- `notes`
- `changed_at`

That means a history row can tell us the resulting status, but not the lifecycle event that produced it or the date the event became real.

This becomes a problem when the current item row has already moved on. After an item is active again, the app cannot reliably reconstruct when it was paused, cancelled, reactivated, or converted without additional historical data.

### 3. Mobile is currently using a compatibility shim

Mobile already needed this distinction, so it temporarily stores hidden metadata inside `item_status_history.notes`.

That closes the immediate product gap, but it is not a good long-term contract because:

- it overloads a user-facing text field with machine data
- desktop does not know about that encoding
- direct SQL inspection becomes harder to trust
- future analytics and admin tooling would have to parse notes to understand history

### 4. Desktop already has the UI inputs, but not durable persistence

Desktop already captures retroactive dates in its status-change flow for pause, cancel, resume/reactivate, and trial conversion. But those effective dates are not currently written as first-class history fields.

So the backend schema is now the limiting factor.

## Recommended Schema Change

Add two nullable columns to `public.item_status_history`:

- `action TEXT NULL`
- `effective_date DATE NULL`

Keep the existing fields unchanged:

- `status`
- `reason`
- `notes`
- `changed_at`

### Data semantics

- `status`: the resulting item status after the action
- `action`: the lifecycle event that occurred
- `effective_date`: the real-world date the lifecycle event took effect
- `changed_at`: the audit timestamp for when the row was inserted

### Why nullable

These new columns should start nullable so the rollout is safe:

- old rows remain valid
- older app builds do not immediately break
- the migration can ship before both clients are updated
- backfill can happen later if needed

Do not make these columns required in the first pass.

### Recommended migration SQL

This migration should live in the desktop repo because that repo owns the Supabase migrations:

- `/Users/tyler/Development/SubTrkr/supabase/migrations/20260311_add_item_status_history_effective_date.sql`

Recommended contents:

```sql
ALTER TABLE public.item_status_history
  ADD COLUMN action TEXT,
  ADD COLUMN effective_date DATE;

CREATE INDEX idx_item_status_history_item_effective_date
  ON public.item_status_history (item_id, effective_date DESC)
  WHERE effective_date IS NOT NULL;

COMMENT ON COLUMN public.item_status_history.action IS
  'Canonical lifecycle action for this history row.';

COMMENT ON COLUMN public.item_status_history.effective_date IS
  'Date the lifecycle change took effect in the real world.';
```

## Canonical Action Vocabulary

Do not add a `CHECK` constraint in the first migration. Mobile and desktop do not use exactly the same action names yet, and the first goal is safe shared persistence.

Target canonical values:

- `pause`
- `cancel`
- `edit_cancellation`
- `resume`
- `reactivate`
- `archive`
- `start_trial`
- `convert_trial`
- `trial_expired`

### Cross-platform normalization rule

Desktop currently uses `convert` in its UI payload. It should normalize that value to `convert_trial` when writing history rows. The UI API does not need to be renamed immediately.

## Shared Behavior Contract

Once the schema exists, both apps should treat status history with this contract:

- write `changed_at` implicitly via the database default
- write `effective_date` for every lifecycle action that has a meaningful real-world date
- use `effective_date` for analytics and lifecycle reconstruction
- use `changed_at` for audit/history presentation
- allow `action` and `effective_date` to be `NULL` on legacy rows

Fallback order during the migration window:

1. use `effective_date` when present
2. on mobile only, fall back to the temporary `notes` metadata shim for older rows
3. fall back to the best available item-row dates only when no historical date exists

## Mobile Plan

### Goal

Move mobile from the temporary `notes` metadata shim toward the new first-class history columns without losing backward compatibility.

### Changes

1. Extend the mobile `StatusHistory` model to decode `action` and `effective_date` directly from the table.
2. Extend the mobile insert payload to write `action` and `effective_date` into `item_status_history`.
3. Keep the current `notes` metadata decoder in place for older rows already written by mobile before the migration.
4. Update analytics and lifecycle reconstruction to prefer the real columns first, then fall back to the old metadata path.
5. Keep the current chronology validation in the status sheet and service layer.

### Mobile non-goals for this migration

This schema change should not be bundled with unrelated product work:

- redesigning the item detail screen again
- changing payment logging behavior
- changing upcoming calendar presentation
- removing all legacy fallbacks immediately

## Desktop Plan

### Goal

Persist the lifecycle dates desktop already captures in its UI and align its history model with mobile.

### Changes

1. Add the database migration in the desktop repo.
2. Extend `StatusHistory` in `src/types/index.ts` to include:
   - `action?: string | null`
   - `effective_date?: string | null`
3. Update `executeStatusChange()` in `src/services/database.ts` to write:
   - canonical `action`
   - `effective_date`
4. Update `handleExpiredTrials()` in `src/services/database.ts` to also write:
   - `action = 'trial_expired'`
   - `effective_date = item.trial_end_date`
5. Tighten `StatusChangeDialog.tsx` validation so lifecycle dates follow chronology, not just start-date and future-date bounds.
6. Leave larger desktop product changes as separate follow-up work:
   - stop auto-archiving cancelled items
   - remove trials from projected spend
   - separate upcoming charges from lifecycle events

### Effective-date mapping on desktop

- `pause` -> `pausedOn ?? today`
- `cancel` -> `cancelledOn ?? today`
- `resume` -> `resumedOn ?? today`
- `reactivate` -> `resumedOn ?? today`
- `convert` -> write `action = 'convert_trial'`, `effective_date = convertedOn ?? today`

## Rollout Order

1. Ship the additive database migration.
2. Update desktop writes and types.
3. Update mobile writes and readers to use the new columns.
4. Verify both apps against the same backend data.
5. Leave backward-compatible fallbacks in place for one release cycle.
6. Decide later whether to backfill legacy rows and remove the mobile `notes` metadata shim.

## Verification Checklist

### Database

- migration applies cleanly
- existing rows remain readable
- new rows can be inserted without supplying the new fields

### Desktop

- status changes insert `action` and `effective_date`
- trial expiry maintenance writes the new fields
- no existing status-change flows regress
- chronology validation rejects impossible date ordering

### Mobile

- new status changes insert `action` and `effective_date`
- old rows written before the migration still render correctly
- analytics still reconstruct lifecycle gaps correctly
- item detail history continues to show audit timestamps without regressions

## What This Unlocks

This is not just a schema cleanup. It gives both apps a stable product contract:

- reliable retroactive analytics
- correct lifecycle reconstruction after resume/reactivate/convert flows
- cleaner status-history debugging in SQL
- less drift between mobile and desktop behavior
- a path to remove the temporary metadata shim from mobile later

Without this migration, the apps can still function, but they will keep relying on weaker heuristics or private encoding tricks when history needs to answer real product questions.

## Recommendation

Do the migration now, keep it additive, and keep the follow-up app changes narrowly focused on persistence and validation.

That gives SubTrkr one shared lifecycle-history model without turning this into a large cross-platform refactor.
