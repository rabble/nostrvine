# Blocked DM send is terminal in the queue drain (mobile)

Design for divinevideo/support-trust-safety#186, part of the protected-minor
(13-15) safeguards epic #173. Surfaced during the #176 DM-restriction review.
Low priority, **no safety impact**.

## Problem (verified against code)

The durable outbound-DM queue drain treats a policy-blocked send the same as a
transient failure. In `DmRepository.recoverFullSend` (dm_repository package),
`sendRumor` returns a `NIP17SendResult`; `result.success` is `false` for a
`NIP17SendResult.blocked(...)` (blocked is a `NIP17SendFailure` subtype), so it
falls into the `else` branch → `_finalizeAfterRecipientFailure` → both wraps
marked `failed`. The retry sweep (`OutgoingDmRetryService`, State B) then
re-attempts the row on every pass until `retryCount` reaches `maxRetries`,
after which the row lingers permanently as a dead `failed` bubble.

### Why it is not a safety issue

Both `sendMessage` and `sendGroupMessage` pre-gate at `canSendTo` and return
`.blocked` **before enqueuing**, so a blocked row never originates at initial
send. A blocked row only arises when a row was enqueued while sending was
allowed, then the policy flipped before the drain replayed it (sender became a
protected minor, or an official recipient's approval was revoked). On replay,
`sendRumor`'s choke point re-evaluates the policy and re-blocks — nothing is
ever delivered to a non-approved recipient. This is purely a reliability /
efficiency wart: wasted retry round-trips plus a permanently-`failed` row that
never resolves.

`recoverFullSend` is the single drain entry for both 1:1 and group rows (the
retry sweep funnels every `recipientWrapStatus == failed` row through it), so
there is one fix site.

## Decision

**Delete the row** on a blocked result, rather than adding a distinct
non-retriable `OutgoingWrapStatus.blocked` state. Deleting reuses the existing
`deleteById` (already the terminal path the user's "Cancel send" uses), needs
no Drift schema migration (the `_parseStatus` fail-loud downgrade contract
makes a new enum value a heavier, higher-blast-radius change), and the failed
bubble simply disappears, cancel-like. A policy block is a permanent decision,
not a transient error, and this is a no-safety-impact wart, so the proportionate
fix is to drop the doomed row.

## Design

Two files, one logical fix ("blocked is terminal" end-to-end):

**1. `dm_repository.dart` — `recoverFullSend` else branch.** Branch on
`result.blocked` before the transient-failure path:

```dart
} else if (result.blocked) {
  await _finalizeAfterRecipientBlocked(outgoingDao: dao, rumorId: rumorId);
} else {
  await _finalizeAfterRecipientFailure(
    outgoingDao: dao,
    rumorId: rumorId,
    errorMessage: result.error ?? 'Unknown publish failure',
  );
}
```

`_finalizeAfterRecipientBlocked` deletes via `deleteById`, logs, and swallows /
reports on error without rethrowing — matching `_finalizeAfterRecipientFailure`'s
non-rethrow posture (the caller still returns the blocked result). If the delete
somehow fails, the row stays `failed` and self-heals on a later sweep.

**2. `outgoing_dm_retry_service.dart` — State B dispatch.** After
`recoverFullSend`, the current `else` calls `incrementRetry` and counts
`failedFullSend++`. A deleted row makes `incrementRetry` a harmless no-op
(returns `false` on a missing row), but it is a wasted DB call and mis-counts a
terminal block as a failure. Add an `else if (result.blocked)` that treats the
row as terminal: skip `incrementRetry`, and count it as terminal rather than
failed. This keeps "blocked is terminal" true end-to-end.

## Test plan

- **dm_repository:** a queued row (`recipientWrapStatus == failed`) whose
  recipient is now non-approved, with `sendRumor` stubbed to return
  `NIP17SendResult.blocked(...)` → `recoverFullSend` deletes the row
  (`getById` returns `null`), does not mark it `failed`, and returns a blocked
  result. Confirm the row is absent from `getRetryableForOwner` afterward (no
  loop).
- **Regression guard:** a transient `NIP17SendResult.failure(...)` still marks
  both wraps `failed` and leaves the row retryable (unchanged path).
- **outgoing_dm_retry_service:** a sweep over a row that drains to blocked
  drops the row and does not call `incrementRetry` / count it as a retry
  failure.

## Out of scope

- The initial-send race where a policy flip mid-`sendGroupMessage` loop yields a
  per-recipient blocked result that gets marked retryable: vanishingly narrow,
  and it self-heals through the drain fix above on the next sweep.
- #185 (foreground-resume account-state refetch) — its own PR.
