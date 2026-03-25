# SubTrkr Task Index

> Last updated: 2026-03-24
> Purpose: Track actionable work. `docs/ROADMAP.md` sets priorities, `docs/plans/` holds execution context, and this file is the concrete queue.

## Rules

- Every task should point back to one source doc.
- If a task needs more than a short note, create a plan in `docs/plans/` and keep the task row as the pointer to it.
- If plan execution spawns follow-up work, add it here immediately.
- When work is finished, update the source doc and move any finished plan into `docs/completed-plans/` if appropriate.

## Status Definitions

| Status | Meaning |
|---|---|
| Inbox | Captured, but not yet committed for near-term execution |
| Next | Approved for the next few sessions |
| Active | Currently being worked |
| Blocked | Waiting on another task, repo, or product decision |
| Done | Recently completed; keep only long enough to close the loop in docs |

## Next

| ID | Pri | Area | Task | Source | Note |
|---|---|---|---|---|---|
| TASK-003 | P1 | iOS | Autopay-first behavioral cleanup | [docs/plans/2026-03-08-autopay-first-payment-tracking-design.md](plans/2026-03-08-autopay-first-payment-tracking-design.md) | Demote manual payment logging and align detail-view copy with recurring tracking |
| TASK-004 | P1 | Release | Privacy policy URL and App Store nutrition labels | [docs/app-store/PRIVACY_POLICY.md](app-store/PRIVACY_POLICY.md) | Manual App Store Connect follow-through |
| TASK-005 | P1 | QA | Physical device testing pass | [docs/MOBILE_TESTING_STRATEGY.md](MOBILE_TESTING_STRATEGY.md) | Execute the release smoke checklist on real hardware before TestFlight/App Store submission |

## Inbox

| ID | Pri | Area | Task | Source | Note |
|---|---|---|---|---|---|
| TASK-006 | P1 | Backend | Transactional status-change write path | [docs/plans/2026-03-11-status-history-effective-date-migration-guide.md](plans/2026-03-11-status-history-effective-date-migration-guide.md) | Deferred hardening: item updates and history inserts should succeed or fail together |
| TASK-013 | P3 | Backend / iOS / Desktop | Status-history legacy cleanup | [docs/plans/2026-03-24-status-history-legacy-cleanup.md](plans/2026-03-24-status-history-legacy-cleanup.md) | Deferred cross-repo cleanup: backfill legacy rows first, then remove notes-metadata compatibility after release-critical work |
| TASK-007 | P3 | Desktop | Notification channels wiring | [docs/ROADMAP.md](ROADMAP.md) | Low-priority desktop channel integration for existing notification loading path |
| TASK-008 | P3 | Product | Optional per-item automatic/manual payment mode | [docs/plans/2026-03-08-autopay-first-payment-tracking-design.md](plans/2026-03-08-autopay-first-payment-tracking-design.md) | Only revisit if real-world bill workflows need stricter manual confirmation |
| TASK-009 | P3 | Data Model | Explicit stored billing anchor field | [docs/plans/2026-03-08-billing-anchor-accuracy-implementation-spec.md](plans/2026-03-08-billing-anchor-accuracy-implementation-spec.md) | Only add if legacy items prove too inconsistent for `startDate` fallback |

## Active

No active tasks right now.

## Blocked

No blocked tasks right now.

## Done

| ID | Pri | Area | Task | Source | Note |
|---|---|---|---|---|---|
| TASK-001 | P0 | iOS | Billing anchor accuracy rollout | [docs/plans/2026-03-08-billing-anchor-accuracy-implementation-spec.md](plans/2026-03-08-billing-anchor-accuracy-implementation-spec.md) | Implemented on 2026-03-19; recurring anchors now hold across short months, due-today logic is fixed, and Xcode unit/UI coverage exists for the main regression paths |
| TASK-011 | P1 | Desktop | Status-history parity pass | [docs/plans/2026-03-15-status-history-rollout-follow-ups.md](plans/2026-03-15-status-history-rollout-follow-ups.md) | Implemented on 2026-03-24; desktop analytics now reconstructs from status-history effective dates, the visible history timeline is live, and lifecycle actions cover archive, start trial, and edit cancellation |
| TASK-010 | P1 | iOS | Fix reactivation bound after auto-expired trial | [docs/plans/2026-03-15-status-history-rollout-follow-ups.md](plans/2026-03-15-status-history-rollout-follow-ups.md) | Implemented on 2026-03-18; reactivation now clamps to the effective cancellation date instead of the later maintenance timestamp |
| TASK-012 | P3 | iOS | Status-history cleanup pass | [docs/plans/2026-03-15-status-history-rollout-follow-ups.md](plans/2026-03-15-status-history-rollout-follow-ups.md) | Implemented on 2026-03-18; history reads now scope by `user_id` and expired-trial writes use the shared insert helper |
| TASK-002 | P0 | Backend / iOS / Desktop | Effective-date history rollout | [docs/plans/2026-03-11-status-history-effective-date-migration-guide.md](plans/2026-03-11-status-history-effective-date-migration-guide.md) | First-pass rollout shipped; review follow-ups TASK-010, TASK-011, and TASK-012 are complete, with only TASK-006 intentionally left as separate backend hardening |
