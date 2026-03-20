# Status History Rollout Follow-Ups

> Date: 2026-03-15
> Scope: Post-rollout fixes and parity follow-up work discovered during review of the effective-date history migration

---

## Summary

The first-pass effective-date rollout shipped the shared migration and dual-write compatibility path, but review uncovered a small set of follow-up items that should now be handled deliberately instead of being left implicit in chat history.

This plan captures one iOS correctness fix, one desktop parity track, and one cleanup pass so they can be tackled one by one.

## Status Update

- Completed on mobile on 2026-03-18:
  - `TASK-010` — reactivation now prefers `cancellationDate` over the later `cancelledAt` audit timestamp
  - `TASK-012` — history reads now scope by `user_id`, and expired-trial writes now go through `makeStatusHistoryInsert(...)`
- Remaining from this follow-up plan:
  - `TASK-011` — desktop status-history parity pass
- Still separate by design:
  - `TASK-006` — transactional status-change write hardening

## Problem

- iOS auto-expired trials now backdate `cancellationDate` correctly, but reactivation still clamps against the later audit timestamp
- desktop now writes richer status history rows, but still does not fully consume or expose that data in analytics and UI
- a couple of cleanup items remain around query scoping and helper reuse

## Goals

- fix the iOS reactivation lower bound so it respects effective lifecycle dates
- define the desktop parity work needed to make the new history contract user-visible
- isolate low-risk cleanup items from larger backend hardening work

## Non-Goals

- redesigning item detail or status-change UI from scratch
- solving the transactional backend write path in this pass
- broad product changes unrelated to lifecycle history parity

## Implementation Notes

### 1. iOS correctness fix

- Update `Item.minimumEffectiveDate(for:)` so reactivation prefers effective lifecycle dates over audit timestamps when both exist.
- Auto-expired trials should allow reactivation from `cancellationDate` / trial end date, not the later `cancelledAt` maintenance timestamp.
- Keep archived-item reactivation rules intact where `archivedAt` is the only meaningful inactive-date bound.

### 2. Desktop parity pass

- Move desktop analytics off item-row heuristics and onto status-history effective dates for lifecycle reconstruction.
- Add a desktop status history timeline so the newly written `action` and `effective_date` fields are visible to users.
- Add desktop action coverage for `archive`, `start_trial`, and `edit_cancellation` where those transitions are part of the shared product contract.
- Keep this aligned with `/Users/tyler/Development/SubTrkr/docs/plans/2026-03-10-desktop-autopay-alignment-recommendations.md`.

### 3. Low-risk cleanup

- Add `user_id` scoping to mobile `getStatusHistory(itemId:)` for defense in depth and cross-platform consistency.
- Route mobile expired-trial history writes through `makeStatusHistoryInsert(...)` so dual-write compatibility logic stays in one place.
- Keep these cleanup items separate from the higher-risk transactional write follow-up.

## Verification

- Create or reuse a trial item that ended yesterday, trigger maintenance, and confirm reactivation can be backdated to the trial end date.
- Verify a cancel/reactivate sequence still reconstructs correctly in mobile analytics after the iOS fix.
- Verify desktop analytics and visible history stay consistent once the parity pass is implemented.
- Confirm mobile history queries still return the same rows after adding explicit `user_id` filtering.

## Spawned Follow-Ups

- `TASK-010` — iOS reactivation bound after auto-expired trials
- `TASK-011` — desktop status-history parity pass
- `TASK-012` — mobile status-history cleanup pass
- `TASK-006` remains the separate transactional write hardening task

## Recommendation

1. Tackle the desktop parity pass next if cross-platform consistency is the immediate goal.
2. Keep the transactional backend write path as a separate hardening task after that.
