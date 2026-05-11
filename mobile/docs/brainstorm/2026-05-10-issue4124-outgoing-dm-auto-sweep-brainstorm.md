# Brainstorm: Auto-sweep `outgoing_dms` self-wrap-failed rows (#4124)

Date: 2026-05-10

## Problem Statement

`outgoing_dms` rows where `recipient_wrap_status == sent` and
`self_wrap_status == failed` only progressed through the ephemeral
manual Retry action in the DM failure SnackBar. If the SnackBar was
dismissed, or the app was killed before the user tapped it, the durable
queue row stayed broken and sender cross-device sync silently failed.

## Implemented Design

The shipped solution adds `OutgoingDmRetryService`, a scheduler-layer
service that:

- listens to app-foreground transitions
- queries `OutgoingDmsDao.getRetryableForOwner(...)` for the current
  account
- dispatches only `recipient: sent / self: failed` rows to
  `DmRepository.recoverSelfWrap(...)`
- applies per-row exponential backoff using the same defaults as
  `PendingActionRetryConfig`
- logs and counts `recipient: failed` rows without attempting recovery
- short-circuits overlapping sweeps with an `_isSweeping` guard
- contains top-level sweep failures so foreground-triggered retries do
  not surface as unhandled async errors

This keeps the layering aligned with the existing
`PendingActionService` precedent: lifecycle trigger in a service,
publish logic in the repository.

## Provider Wiring

`outgoingDmRetryServiceProvider` is `keepAlive` and returns `null`
unless:

- the user is authenticated
- `isNostrReadyProvider` is `true`

That gate ensures `DmRepository.setCredentials(...)` has already run
before the first sweep can call `recoverSelfWrap(...)`.

The provider bridges the synchronous
`mobile/lib/providers/app_foreground_provider.dart` notifier into a
plain `Stream<bool>` so the service stays Riverpod-free and easy to
unit test. `main.dart` eagerly reads the provider because the service
has no UI consumer and would otherwise never initialize.

## Recovery Scope

The current implementation intentionally handles only one recovery
state:

- `recipient: sent / self: failed` -> `recoverSelfWrap(...)`

Other queue states are explicitly out of scope for this PR:

- `recipient: failed` rows are counted in logs only. A future recovery
  primitive can extend the dispatcher when that behavior is designed.
- `pending: pending` rows are not part of
  `getRetryableForOwner(...)`; they remain the concern of a separate
  interrupted-send recovery path.

## Decisions Captured

- Trigger on foreground transitions only. No periodic timer and no
  connectivity-triggered sweep.
- Rebuild the service on sign-in, sign-out, and account switch by
  watching `currentAuthStateProvider`.
- Keep `recoverSelfWrap(...)` as the only self-wrap publishing path.
- Treat `StateError` as pass-level "repo not ready" and abort without
  burning retry budget.
- Treat `ArgumentError` as row-local terminal state and continue.
- Bump retry count only on actual publish failure or unexpected throw
  from the recovery path.

## Follow-up Scope

Future work can extend the dispatcher with a second recovery strategy
for `recipient: failed` rows once the repository contract is designed
and production occurrence data warrants it.
