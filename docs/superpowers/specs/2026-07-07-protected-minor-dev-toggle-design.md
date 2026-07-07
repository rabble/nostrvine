# Dev-options toggle for the protected-minor override (divine-mobile#5721)

**Status:** WIP design — implementation follows on this branch.
**Part of:** epic support-trust-safety#173. Deferred from #174 (l10n friction);
unblocks manual QA of the protected-minor protections (#175, later #176)
without a real parent-approved minor account.

## Problem

`ProtectedMinorOverrideService` (`mobile/lib/services/protected_minor_override_service.dart`)
and its `kDebugMode` hook in `protected_minor_providers.dart` already exist, but
nothing in the UI flips them — QA cannot simulate a protected minor.

## Design — copy the adjacent pattern

`developer_options_screen.dart` already has the "Minor Review Simulation"
section (~lines 349-446: simulate teen / under-13 / clear). Add a sibling
"Protected Minor Simulation" section using the same layout and interaction
conventions:

- **Simulate protected minor (13-15)** → `ProtectedMinorOverrideService.setOverride(true)`
- **Simulate non-minor** → `setOverride(false)` (distinct from cleared: exercises
  an explicit negative)
- **Clear override** → `clearOverride()` (back to real keycast-driven state)
- Show the current override state inline, as the minor-review section does.
- Debug builds only (section already lives behind the existing dev-options
  gating; the provider hook is `kDebugMode`-guarded).

l10n: new ARB strings for the three actions + section title, then
`flutter gen-l10n`; run build_runner if any codegen is touched (repo pre-push
convention).

## Out of scope

- Any change to the real keycast-driven protected-minor state or providers.
- Age-review (minor-review) simulation section — untouched.

## Tests

- Toggle wiring: tapping each action calls the service with the right value
  (existing dev-options/service test patterns).
- Provider integration: override set → `isProtectedMinorProvider` reflects it
  in debug mode (existing provider tests as template).

## Acceptance (from #5721)

In a debug build, QA can flip a device into (and out of) protected-minor state
from Developer Options and observe #175's content lock respond, with no real
minor account involved.
