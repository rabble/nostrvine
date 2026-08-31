# Brainstorm: bounding the DM send segments outside the publish backstop

Date: 2026-08-31
Issue: [#7091](https://github.com/divinevideo/divine-mobile/issues/7091)
Findings: `tasks/findings_7091.md` (17 hypotheses, all at 1.0, device-reproduced)

## Problem Statement

`dm_repository`'s 130s publish backstop wraps only
`NIP17MessageService.sendRumor`. Substantial awaited work runs on both sides of
it with no bound of its own, so the backstop bounds **one segment of a send**
rather than the send. `OutgoingDmRetryService.interruptedMinAge` (160s) is
derived as that backstop plus a named 30s `_inboxResolutionMargin` for the
outside work — but nothing enforces the 30s, so the guard is a heuristic. Its
own doc comment concedes this and says bounding those segments is "tracked
separately"; that is this issue.

## The measurement that defines the target

A/B on the real `sendMessage` path, same build, same device, same conversation,
one variable changed (relay reachability):

| | resolve | publish (inside the 130s cap) | inFlight |
|---|---|---|---|
| control — relay healthy | **36 ms** | 13 ms | 49 ms |
| treatment — relays unreachable | **51 052 ms** | 10 ms | 51 062 ms |

The cap governed **0.02%** of the elapsed send. Resolution exceeded its
budgeted 30s margin by **21 s**.

Segment breakdown from the same run, for a kind-10050 query declaring a 5s
timeout: `cacheRead=36ms retryRelays=48028ms poolAcquire=0ms innerQuery=53ms`
— and on other queries in the same run, `poolAcquire=8521ms`. **The declared 5s
governed 53 ms of a 48 119 ms call.**

## Constraints

- **NIP-17 "Publishing":** clients MUST only publish to relays in the
  recipient's kind-10050; if absent, "clients shouldn't try". Today
  `resolveDmInboxRelays` collapses absent / unreadable to `null` and every
  caller falls back to the default pool — open issue **#7317**. A timeout must
  **not** become another `null`, or this fix makes #7317 strictly more
  reachable. `_queryOwnDmInbox` already returns `{found, absent, failed}`; only
  the public wrapper flattens it.
- `dm_repository` cannot import `keycast_flutter`; budget guard tests therefore
  live in `mobile/test/`.
- `dm_repository_test.dart` is frozen at **14** shared-setUp stubs
  (`shared_setup_stubs.txt:10`). A stalling stub must go in a leaf `setUp` or
  inline.
- `retryDisconnectedRelays` lives in the shared `nostr_client` package, reached
  by ~91 query call sites.
- No new tech debt: no TODOs, no skipped tests, no half-migrated code paths.

## Prior Art

- **`nostr_sdk/lib/nostr.dart:356-387`** already implements the correct
  discipline one layer down: a single `deadline`, with `remainingTimeout()`
  re-applied at each awaited step, `TimeoutException` caught and the
  subscription unsubscribed. **The wrapper above it does not.** This is the
  pattern to lift, not invent.
- **`relay_manager.dart:621-628`** already parallelizes the *startup* connect
  path — `Future.wait`, commented "reduces startup from O(n * timeout) to
  O(max timeout)". Git history shows the sequential retry loop is original code
  from #380 and the parallel form arrived later in #1217 incidentally, so
  **nothing kept retry sequential deliberately.**
- `#6586` / `#7075` established that a backstop whose derivation goes stale is
  a recurring failure mode here; `#7092` re-derived the transport bound.

## Trap ruled out during exploration

**`Pool(timeout:)` does not bound acquisition.** `pool-1.5.2:75-81` — "if that
much time passes **without any activity** all pending request futures will
throw... intended to avoid deadlocks" — and `_resetTimer()` fires on every
acquire and release. It is an inactivity/deadlock timer; under the exact
contention the wrapper's own comment describes, it would never fire while one
waiter starves. The bound must be on the acquisition itself, or above it.

## Approaches Explored

### Approach A: thread an explicit deadline through the send
Mint one `DateTime deadline` per send; pass it down through
`resolveDmInboxRelays` → `_queryOwnDmInbox` → `queryEventsDetailed`, each step
spending from it.
**Layers:** Repository, Client. **Complexity: High.**
**Pros:** most precise; the send owns its budget explicitly.
**Cons:** signature changes down the chain; duplicates, at a higher layer, the
deadline machinery the SDK already has.

### Approach B: compose wrappers at each boundary
`.timeout()` around resolution at the three call sites; widen the backstop over
the in-cap unbounded work; aggregate cap inside `retryDisconnectedRelays`;
`.timeout()` on pool acquisition.
**Layers:** Repository, Client. **Complexity: Low-Medium.**
**Pros:** smallest review surface; no signature churn.
**Cons:** leaves `queryEventsDetailed(timeout:)` still meaning "bounds one of
four awaits" — the defect stays, merely papered over for one caller.

### Approach C: make `queryEventsDetailed(timeout:)` mean what its name says
Apply the SDK's own shared-deadline pattern inside
`NostrClient.queryEventsDetailed` so the parameter becomes end-to-end.
Resolution is then bounded automatically, as are the ~90 other callers that
already assume this.
**Layers:** Client. **Complexity: Medium.**
**Pros:** fixes the actual defect at the one place every caller passes through;
uses a proven in-repo pattern; every other query path benefits.
**Cons:** real blast radius — queries that silently ran 48s now return at their
declared bound.

### Approach D: take resolution off the critical path
Serve the send from a cached inbox, refresh in background.
**Layers:** Repository. **Complexity: Medium.**
**Pros:** removes the unbounded segment rather than bounding it.
**Cons:** ships a user-visible behavior change and pushes **against** #7317 — a
send would route on a stale or absent list more often. Rejected.

## Recommendation

**C + B, in one PR.**

C repairs the contract at the boundary all callers share, using the pattern
`nostr.dart` already proves. B adds the send-level cap that AC1 and AC4 need
and bounds the in-cap segments (connectivity probe, send policy,
`refreshPublicKey`). A's threading buys precision that a deadline *inside* the
wrapper already delivers. D is the only approach that changes what users see.

The `retryDisconnectedRelays` half follows #1217's own precedent: parallelize
**and** add the aggregate cap the startup path still lacks.

**Blast radius is treated as a fix, not hidden.** Every one of those ~90
callers passed a `timeout` and got something else; honoring it is the
correction. It gets its own PR section with the measured numbers and a
regression test asserting the declared bound is now end-to-end.

**The timeout outcome stays distinguishable from `absent`.** `resolveDmInboxRelays`
keeps returning `null` so #7091 ships no product behavior change, but
`_queryOwnDmInbox`'s existing `failed` state carries the timeout — leaving
#7317 a clean seam rather than a worse defect.

## Open Questions for /plan

- [ ] What value should the send-level inbox-resolution bound take, and does
      `_inboxResolutionMargin` become derived from it or disappear?
- [ ] Does the aggregate cap on `retryDisconnectedRelays` belong in the loop or
      at `nostr_client.dart:944`'s call site?
- [ ] Should the in-flight dedup for `retryDisconnectedRelays` (7 overlapping
      sweeps observed) land here or as its own issue?
- [ ] Which of the three in-cap awaits get folded into `chainWorstCase` vs
      documented as excluded (AC3)?
- [ ] Exact wording of the `interruptedMinAge` restatement (AC4) and which of
      the two existing budget tests it lands in.

## Prerequisites

None. No design input, no new package, no protocol decision — NIP-17 and NIP-59
impose no timing constraints, so the bound values are a client engineering call.

## Next Step

`/plan 7091`
