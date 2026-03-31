# Async Startup Tightening Pass Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reduce the bootstrap refactor to the production-used startup contract without reintroducing any first-frame blocking.

**Architecture:** Keep the two-stage startup boundary in `main.dart`: run only `critical` startup before `runApp()`, then continue the remaining phases after the first frame. Trim `StartupCoordinator` APIs and tests that only support synthetic diagnostics or late-registration behavior that production does not use.

**Tech Stack:** Flutter, Dart, Flutter test

---

## Chunk 1: Trim StartupCoordinator To The Used Contract

### Task 1: Remove production-unused coordinator APIs and align tests

**Files:**
- Modify: `mobile/lib/features/app/startup/startup_coordinator.dart`
- Modify: `mobile/lib/features/app/startup/startup_phase.dart`
- Modify: `mobile/test/features/app/startup/startup_coordinator_test.dart`
- Modify: `mobile/test/startup/startup_diagnostics_test.dart`
- Test: `mobile/test/startup/app_first_frame_startup_test.dart`

- [ ] **Step 1: Write the failing test updates**

Reduce the coordinator tests to the contract production still uses:
- keep `initializeThrough(StartupPhase.critical)` before `runApp()`
- keep `initializeRemaining()` after first frame
- keep dependency ordering within a phase
- keep optional-service behavior
- drop tests that only justify `initializeProgressive()`, `waitForPhase()`, phase streams, progress streams, or late registration

- [ ] **Step 2: Run the reduced test targets to verify they fail for the right reason**

Run:

```bash
flutter test --no-pub \
  test/features/app/startup/startup_coordinator_test.dart \
  test/startup/startup_diagnostics_test.dart \
  test/startup/app_first_frame_startup_test.dart
```

Expected: failures because the test surface and coordinator implementation still mention APIs we intend to remove.

- [ ] **Step 3: Write the minimal implementation**

In `startup_coordinator.dart`:
- remove late-registration support and `_pendingLateServices`
- remove `phaseCompleted`, `progress`, `waitForPhase()`, and `initializeProgressive()`
- keep `registerService()`, `initialize()`, `initializeThrough()`, `initializeRemaining()`, optional-service handling, metrics, and dependency ordering

In `startup_phase.dart`:
- remove helper methods that only support the deleted coordinator paths, while keeping the enum values and `priority`

In the tests:
- delete or rewrite the cases that only covered removed APIs
- keep direct assertions for first-frame safety and phased continuation

- [ ] **Step 4: Run the targeted tests and analyzer**

Run:

```bash
flutter analyze \
  lib/features/app/startup/startup_coordinator.dart \
  lib/features/app/startup/startup_phase.dart \
  test/features/app/startup/startup_coordinator_test.dart \
  test/startup/startup_diagnostics_test.dart \
  test/startup/app_first_frame_startup_test.dart
```

```bash
flutter test --no-pub \
  test/features/app/startup/startup_coordinator_test.dart \
  test/startup/startup_diagnostics_test.dart \
  test/startup/app_first_frame_startup_test.dart
```

- [ ] **Step 5: Commit**

```bash
git add \
  mobile/lib/features/app/startup/startup_coordinator.dart \
  mobile/lib/features/app/startup/startup_phase.dart \
  mobile/test/features/app/startup/startup_coordinator_test.dart \
  mobile/test/startup/startup_diagnostics_test.dart \
  mobile/test/startup/app_first_frame_startup_test.dart \
  docs/superpowers/plans/2026-03-31-async-startup-tightening-pass.md
git commit -m "refactor(startup): trim coordinator scaffolding"
```
