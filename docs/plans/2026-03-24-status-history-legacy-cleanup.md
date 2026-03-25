# Status-History Legacy Cleanup

> Date: 2026-03-24
> Scope: Deferred cross-repo cleanup after the effective-date rollout is stable

---

## Summary

The status-history rollout is functionally complete across mobile and desktop, but both repos still carry compatibility logic for older rows written before `item_status_history.action` and `item_status_history.effective_date` existed.

This cleanup should stay deferred until after release-critical work and the separate transactional write hardening task.

## Why This Is Deferred

- the current compatibility path is working
- removing it now adds cross-repo risk without strong user-visible payoff
- the safer order is: stabilize writes, backfill old rows, then remove fallback readers

## Goal

Remove the remaining legacy status-history compatibility layer once the shared backend data is fully normalized.

## Non-Goals

- changing the current lifecycle product contract
- bundling this with transactional write hardening
- broad cleanup of unrelated deprecated fields

## Subtasks

1. Backfill legacy `item_status_history` rows so `action` and `effective_date` are populated.
2. Verify both repos can read normalized rows without relying on metadata hidden in `notes`.
3. Remove mobile dual-write of metadata into `notes`.
4. Remove mobile fallback decoding for metadata stored in `notes`.
5. Remove desktop fallback decoding for metadata stored in `notes`.
6. Re-test analytics reconstruction and visible history in both repos.

## Recommended Order

1. Finish higher-priority work first: `TASK-003`, `TASK-005`, and `TASK-006`.
2. Do the backfill from the backend source-of-truth repo: `/Users/tyler/Development/SubTrkr-mobile`.
3. Remove compatibility code only after the backfill has been verified against real data.

## Exit Criteria

- no production rows still depend on notes-embedded metadata
- mobile writes only first-class history fields
- mobile and desktop no longer decode metadata from `notes`
- analytics and history UI still match across both repos
