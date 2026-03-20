# Mobile Testing Strategy

> Last updated: 2026-03-19
> Goal: Ship quickly without flying blind. Testing should protect billing correctness, lifecycle integrity, and release-critical flows, not become its own long-running project.

## Current Position

- Xcode-native unit tests and UI tests are now configured and runnable from the shared `SubTrkr` scheme.
- The current automated suite protects the highest-risk logic already touched in this rollout: recurring billing anchors, lifecycle/history reconstruction, and deterministic billing form behavior.
- This is enough infrastructure to keep shipping features now.
- This is not yet a full signed-in backend e2e suite. Real-device coverage is still required before release.

## Recommendation

- Do not spend another full session building broad generic test infrastructure right now.
- Keep shipping product work and add targeted tests alongside risky changes.
- Treat testing as a release gate and a per-feature hardening step, not a separate phase that blocks all forward motion.
- The next major testing investment should be a simple CI `xcodebuild test` job, not a large custom framework.

## Required Test Bar By Change Type

- Billing date math, recurrence logic, lifecycle transitions, analytics reconstruction, or destructive service writes: add or update unit tests in `SubTrkrTests`.
- Deterministic UI behavior in the billing form, item detail flow, or status-change UX: add or update focused UI tests in `SubTrkrUITests`.
- Copy-only, spacing-only, or low-risk visual changes: local build plus targeted manual smoke is enough.
- Backend migrations or write-path changes: simulator test pass plus targeted manual validation against a safe environment.

## Automated Coverage Today

### Unit Tests

- `AnalyticsServiceTests` — status history and monthly reconstruction behavior
- `ItemEffectiveDateTests` — lifecycle effective-date lower bounds
- `RecurringBillingTests` — billing anchor preservation, due-today rollover, future-start recalculation

### UI Harness Tests

- Billing harness launch coverage
- Future-start monthly recurrence flow
- Due-today monthly rollover flow

## Commands

- Run the full suite:
  `xcodebuild test -project SubTrkr/SubTrkr.xcodeproj -scheme SubTrkr -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
- Run unit tests only:
  `xcodebuild test -project SubTrkr/SubTrkr.xcodeproj -scheme SubTrkr -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:SubTrkrTests`
- Run UI tests only:
  `xcodebuild test -project SubTrkr/SubTrkr.xcodeproj -scheme SubTrkr -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:SubTrkrUITests`
- In Xcode, use the shared `SubTrkr` scheme and run `Product > Test`.

## Release Gates

### Every Risky Feature Or Follow-Up Task

- Relevant unit tests or UI tests were added or updated.
- The touched test target passes locally.
- The exact changed user flow gets a focused manual smoke check.

### Before TestFlight Or A Release Candidate

- Full simulator suite passes from the shared `SubTrkr` scheme.
Manual simulator smoke should cover:
- sign in / launch
- create item
- edit item
- cancel / reactivate / archive
- calendar projection
- analytics load
- settings and account actions touched by the release

### Before App Store Submission

- Complete the physical-device smoke pass from `TASK-005`.
Physical-device smoke should verify:
- clean install and upgrade path
- biometric unlock if enabled
- notifications permission and delivery if touched
- keyboard-heavy forms
- light and dark mode sanity
- performance on real hardware

## Known Gaps

- No signed-in, network-backed end-to-end UI smoke flow yet
- No CI runner yet
- No snapshot testing
- Real-device testing is still manual

## Next Sensible Test Upgrade

- Add a simple CI job that runs the shared Xcode scheme on simulator.
- Add one seeded-account UI smoke path for create, edit, cancel, and reactivate.
- Do not expand test infrastructure further unless regressions show the current bar is insufficient.
