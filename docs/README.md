# SubTrkr Docs Guide

Use this folder as a queue, not a dump.

## Start Here

1. Read `docs/ROADMAP.md` for the current product priorities and the recommended next session.
2. Read `docs/TASKS.md` for the current operational queue and any spawned follow-up work.
3. Open the matching file in `docs/plans/` for the active spec or implementation guide.
4. Use `docs/completed-plans/` and `docs/completed/` only for historical context or past implementation details.

## Current Active Plans

- `docs/plans/2026-03-08-billing-anchor-accuracy-implementation-spec.md` — recurring date correctness and due-date rollover
- `docs/plans/2026-03-11-status-history-effective-date-migration-guide.md` — lifecycle history schema and retroactive effective dates
- `docs/plans/2026-03-15-status-history-rollout-follow-ups.md` — post-rollout fixes, parity gaps, and cleanup tasks discovered during review
- `docs/plans/2026-03-08-autopay-first-payment-tracking-design.md` — autopay-first product behavior and UI semantics

## Structure

- `docs/ROADMAP.md` — source of truth for completed work, remaining priorities, and what to tackle next
- `docs/TASKS.md` — action queue for concrete tasks, follow-ups, and deferred hardening items
- `docs/MOBILE_TESTING_STRATEGY.md` — lean release testing bar, simulator/device gates, and when to add more automation
- `docs/SUPABASE_BACKEND_WORKFLOW.md` — backend safety rules, migration workflow, and Supabase CLI usage for this repo
- `docs/plans/` — active or upcoming plans only
- `docs/PLAN_TEMPLATE.md` — starter structure for new plan docs, including follow-up tracking
- `docs/completed-plans/` — finished design docs and implementation plans
- `docs/completed/` — completed reviews, session summaries, and audit artifacts
- `docs/app-store/` — release and submission reference docs
- `docs/IOS_DESIGN_HANDOFF.md` — visual/design source of truth

## Workflow

- `docs/ROADMAP.md` answers: what matters next?
- `docs/TASKS.md` answers: what concrete tasks exist right now?
- `docs/MOBILE_TESTING_STRATEGY.md` answers: what test bar is required before shipping?
- `docs/plans/` answers: how should a selected task be executed?

## Tracking Rule

- If implementation work spawns later follow-ups, add them to `docs/TASKS.md` immediately.
- If a follow-up needs deeper context, create a new plan in `docs/plans/` and keep the task row as the pointer back to it.
- Active plan docs should include a `## Spawned Follow-Ups` section so future sessions can see what that plan generated.

## Working Rule

If you ask what to do next, start with `docs/ROADMAP.md`, then `docs/TASKS.md`, then open the highest-priority file still in `docs/plans/`.
