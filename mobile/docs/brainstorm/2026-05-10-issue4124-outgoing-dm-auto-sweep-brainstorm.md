# Brainstorm: Auto-sweep `outgoing_dms` self-wrap-failed rows (#4124)

Date: 2026-05-10

## Problem Statement

`outgoing_dms` rows where `recipient_wrap_status == sent` and
`self_wrap_status == failed` only progress today when the user manually
re-taps the Retry action on the partial-delivery SnackBar
(`ConversationView._onSendOutcome`). The SnackBar is ephemeral — once
dismissed (or if the app is killed before the user taps it), the row
sits durably broken. The self-wrap exists *specifically* for sender
cross-device sync, so a stuck self-wrap silently breaks the entire
purpose of NIP-17 self-wrapping. We need an automatic invocation path
for the `recoverSelfWrap` primitive landed in PR #4106.

## Constraints

- Layered architecture: UI → BLoC → Repository → Client. The auto-sweep
  is a **service**, not a BLoC — same shape as `PendingActionService`.
- BLoC-first for new state management. No new Riverpod surface beyond
  what's needed to wire the service into existing providers.
- `recoverSelfWrap` must remain the only path that publishes a self
  wrap. The sweep is a **scheduler**, not a publisher.
- Idempotency cooperation: a manual Retry tap mid-sweep must not
  republish. `recoverSelfWrap`'s `selfWrapStatus == sent` short-circuit
  already handles this; the sweep just has to not break the contract.
- Account-switch / sign-out: the service must rebuild on `userPubkey`
  identity change and not pick up the previous account's queue rows
  (mirror `pendingActionServiceProvider`'s null-on-no-userPubkey shape
  in `app_providers.dart:285`).
- No Flutter dependency leaks below the service layer.
  `dm_repository` stays Flutter-free; the foreground stream lives in
  the service / provider layer.

## Prior Art

**Already built (no new code needed):**
- `DmRepository.recoverSelfWrap(rumorId)` — idempotent, account-scoped,
  handles JSON-parse failures, has fallback bookkeeping. PR #4106.
- `OutgoingDmsDao` already exposes everything a retry service needs:
  - `getRetryableForOwner({ownerPubkey, maxRetries})` — filters to
    rows where either wrap is `failed` AND retry budget not exhausted.
  - `getStillPendingForOwner(ownerPubkey)` — rows still `pending` from
    an interrupted publish (e.g., app kill mid-`sendRumor`).
  - `incrementRetry(id)` — bumps `retry_count` and `last_attempt_at`
    atomically inside a transaction.
  - `markSelfWrapStatus`, `markRecipientWrapStatus` — both stamp
    `last_attempt_at = DateTime.now()` automatically.
  - `clearAllForUser(ownerPubkey)` — sign-out / account-switch sweep.
  PR #3911.
- `appForegroundProvider` — `StreamProvider<bool>` derived from
  `WidgetsBindingObserver`, seeds `true` on launch when
  `lifecycleState == null || resumed`. So the cold-start sweep fires
  for free without a separate trigger.
  `mobile/lib/providers/app_lifecycle_provider.dart`.
- `ConnectionStatusService` (keepAlive) is wired throughout but is
  **not** a chosen trigger for this service.

**Direct precedent for the sweep loop:**
`PendingActionService` (`mobile/lib/services/pending_action_service.dart`
+ `app_providers.dart:285`). Listens to connectivity, replays failed
rows with `PendingActionRetryConfig` defaults (`maxRetries: 5`,
`initialDelay: 2s`, `maxDelay: 5min`, `backoffMultiplier: 2.0`). Epic
#3912 / task #3909 explicitly cite this as the pattern to mirror.

**Schema confirmation:** `outgoing_dms` already has `retry_count`,
`recipient_wrap_last_error`, `self_wrap_last_error`, `last_attempt_at`
— no schema migration needed. The DAO doc literally references "the
retry service" in `getRetryableForOwner`'s doc comment.

**Cross-checks:**
- No conflicting open PR — PR #4234 (open, fixes #4193) edits
  `ConversationBloc`'s optimistic-state shape, not the retry path.
- Sister issue #4127 (open) covers surfacing DAO bookkeeping failures;
  orthogonal — this brainstorm leaves its swallowed-error sites
  untouched.

## Approaches Explored

### Approach A: Full broad scope, includes new `recoverFullSend` primitive

Build `OutgoingDmRetryService` PLUS a new
`DmRepository.recoverFullSend(rumorId)` for `recipient: failed` rows
in one PR. Service dispatcher routes by row state to either
`recoverSelfWrap` or `recoverFullSend`.

- **Layers:** Service (new), Repository (new method), Provider (new
  wiring).
- **Pros:** Completes epic #3912's recovery vision in one PR.
- **Cons:** ~250–400 LOC. `recoverFullSend` needs careful idempotency
  thinking — what if the prior attempt's recipient publish landed but
  local `direct_messages` insert failed last time? Larger
  test-contract surface.
- **Risks:** Re-publishing a stale-feeling rumor for an old failed
  row; bounded by `maxRetries` + receiver-side dedup keys on rumor id.
- **Complexity:** Medium-High.

### Approach B: Broad shape, self-wrap-only recovery today (RECOMMENDED)

Same service skeleton as A. Strategy table maps row state to recovery
function — only one entry today (`recipient: sent / self: failed` →
`recoverSelfWrap`). Other retryable rows are **enumerated, counted,
and logged** so we get production telemetry on how often
`recipient: failed` and `pending: pending` rows actually appear before
committing to a primitive. No `DmRepository` changes; uses existing
`recoverSelfWrap` only.

- **Layers:** Service (new), Provider (new wiring).
- **Pros:** Smallest blast radius. Literal scope of #4124. Cleanly
  extends to A later by adding a second strategy entry + the new
  primitive. Defers `recoverFullSend` design until we have data.
- **Cons:** `recipient: failed` rows still sit queued forever in this
  PR. Splits the broad-scope work across two PRs.
- **Risks:** Logging-without-acting becomes a quiet liability if
  counts are non-zero and we don't follow up. Mitigation: open a
  tracking issue before merge.
- **Complexity:** Low-Medium. ~150–250 LOC.

### Approach C: Repository-internal sweep

Move the sweep loop inside `DmRepository`. `setCredentials` accepts an
optional `Stream<bool> appForegroundStream` and the repo subscribes
internally. No new service file.

- **Layers:** Repository (new method + new constructor param + sweep
  loop), Provider (wires the stream).
- **Pros:** No new service class.
- **Cons:** Violates separation — `architecture.md` says repos compose
  data sources, not lifecycle. The `PendingActionService` precedent
  the epic explicitly names lives in `lib/services/`. Mixes
  connection-state-aware orchestration into a 1500+ LOC repo, harder
  to test in isolation.
- **Risks:** Sets a precedent that any repo can grow a lifecycle
  observer; erodes layering.
- **Complexity:** Lower LOC, higher architectural cost.

## Recommendation

**Approach B.** Ship `OutgoingDmRetryService` with the broad-shaped
strategy table but only the self-wrap-only entry wired in today. Open
a tracking issue before merge for the `recipient: failed` recovery
primitive (`recoverFullSend`).

### Why B over A

The user's scope answer was "broad" — but the broad architecture
(service + dispatcher) is what unlocks future extension. The recovery
primitive `recoverFullSend` is meaningful new code with subtle
idempotency tradeoffs (recipient already landed, local persistence
failed, app killed before queue update — three distinct partial
states), and we currently have **zero production data** on whether
`recipient: failed` rows are common enough to justify the upfront
design. Logging the count gets us that data on day one and lets the
follow-up PR be targeted.

### Why B over C

`PendingActionService` is the in-repo precedent that epic #3912
explicitly cites. Mirroring it one-for-one means reviewers can compare
side-by-side; future maintainers find the same shape twice in
`lib/services/`. The repo-internal variant trades that clarity for
zero LOC saved (the foreground subscription has to live somewhere
either way).

### Trigger choice

Single trigger: `appForegroundProvider` transitions to `true`. Per the
user's choice, no service-init / no connectivity-restore / no periodic
timer. The `appForegroundProvider`'s seed-on-launch behavior gives us
the cold-start sweep for free; on connectivity blips, the user's next
foreground resume catches the work; on long-running foreground
sessions, the per-row backoff inside the sweep prevents tight loops.

### Backoff + per-row rate limit

Use `PendingActionRetryConfig` defaults verbatim (5 retries, 2s →
5min, 2× backoff). Per-row predicate: skip if
`now - lastAttemptAt < backoff(retryCount)`; otherwise dispatch.
`getRetryableForOwner` already drops rows past `maxRetries` server-
side. The `incrementRetry` DAO method makes the rate-limit state
durable across app kill.

## Open Questions for /plan

- [ ] **Cold-start coverage.** `appForegroundProvider`'s initial seed
      (line 17 of `app_lifecycle_provider.dart`) emits `true` when
      `lifecycleState == null || resumed`. Confirm this fires the
      first sweep on cold launch without a separate explicit-init
      path. If for some reason it does not (e.g., on web), decide
      whether to add an explicit init-time sweep.
- [ ] **Readiness gate vs. `dmRepository` provider.** The service must
      wait for `DmRepository.setCredentials` before calling
      `recoverSelfWrap` (which throws `StateError` on uninitialized
      repos). Decide between:
      (a) gate the provider on `isNostrReadyProvider` like
          `profileRepositoryProvider` already does;
      (b) gate the service's sweep loop on a try/catch around
          `StateError` and treat it as "not yet ready, will retry on
          next foreground transition."
      Option (a) is cleaner; option (b) is more resilient to provider
      ordering surprises.
- [ ] **Concurrency with manual SnackBar Retry.** The
      `recoverSelfWrap` `selfWrapStatus == sent` guard handles a
      concurrent manual tap mid-sweep. But the sweep should also avoid
      double-scheduling the same row twice in one foreground
      transition — use the same `_isSyncing` flag pattern from
      `PendingActionService:60`.
- [ ] **Telemetry shape for the broad-enumeration count.** Is a
      `Log.info('sweep observed N recipient-failed rows')` enough, or
      should this PR also wrap a `Reportable` (per
      `error_handling.md`) for "N consecutive sweeps observed
      `recipient: failed` rows for the same rumor"? Coordinate with
      issue #4127 — the right answer is probably the **counter /
      debug surface** option from #4127's matrix, not `Reportable`,
      because `recipient: failed` is an expected network failure
      class.
- [ ] **Group DM rows.** `sendGroupMessage` enqueues per-recipient
      rows with the same `ownerPubkey`. Confirm `getRetryableForOwner`
      naturally covers them (it should — same filter shape) and write
      an explicit test for a group-recipient self-wrap-failed row
      being recovered by the sweep.
- [ ] **Sign-out coordination.** Verify `clearAllForUser(prevPubkey)`
      already runs on sign-out (it should, given the DAO doc claims
      so). If not, decide whether the sweep service is the right
      place to add it, or whether the existing sign-out wiring should.
- [ ] **Test contract for "sweep never publishes a recipient wrap."**
      Pin via `verifyNever(messageService.sendRumor(...))` and
      `verifyNever(messageService.sendPrivateMessage(...))` after a
      sweep run, mirroring PR #4106's existing self-wrap-only
      contract tests.

## Prerequisites

- [ ] Open follow-up issue for `recoverFullSend` (recipient-failed
      recovery primitive) so the broad-scope work isn't lost.
      Reference this brainstorm and the enumeration counts the
      service will start logging.
- [ ] Confirm with the team that telemetry as `Log.info` counts (not
      `Reportable`) is acceptable for the recipient-failed
      enumeration in this PR. Coordinate with #4127.

## Next Step

Run `/plan 4124` with the recommendation above. Before kickoff, file
the `recoverFullSend` follow-up issue so /plan can reference it
explicitly in the PR description.
