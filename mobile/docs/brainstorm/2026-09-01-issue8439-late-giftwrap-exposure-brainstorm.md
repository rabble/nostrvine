# Brainstorm: sizing the population #8439 can still lose a gift wrap from

Date: 2026-09-01
Issue: [#8439](https://github.com/divinevideo/divine-mobile/issues/8439)
Evidence: `tasks/findings_8439.md` (worktree `.worktrees/8439-late-wrap`)

## Problem Statement

A gift wrap published *before* our newest processed wrap and delivered late falls below
`since: (newestWireSyncedAt - 2d)` and is never requested again — the window only rises,
and the history drain returns before issuing a query once it has latched. #8439 asks for a
number before a remedy is chosen. This brainstorm is about what to measure, not whether the
mechanism is real: that is settled (see below).

## What is already settled (do not re-derive)

| Claim | State |
|---|---|
| The relay silently drops a kind-1059 whose outer stamp is below `since:` | Measured against funnelcake; NIP-01 inclusive boundary pinned to the second |
| The app asks with `since = wire - 2d` and the older wrap is never served | Proven in CI by a mutation-verified test (`dm_repository_test.dart`, `_SinceEnforcingRelay`) |
| The loss is permanent | `recordWireSeen` advances only; `_runHistoryDrain` returns early on the latched flag |
| Two days is **not** protocol-guaranteed | NIP-59 sets no bound at all (its `TWO_DAYS` is sample code); NIP-17's two days is SHOULD in a draft NIP; no relay-side enforcement is mandated |

## Constraints

Established by measurement during the investigation, not assumed:

- **No relay probe.** Client-local signals only (user decision). This is load-bearing: without
  a probe the client *cannot* observe a wrap it never received, so nothing local can count the
  loss. It can count only **exposure** and **recovery**.
- **Product analytics does not reach production.** `analytics_service.dart:53-58` enables it only
  when `DEFAULT_ENV == 'STAGING'`; `PRODUCT_ANALYTICS_ENABLED` is defined nowhere in the repo.
- **A new analytics event is a cross-repo change.** The contract lives in `divine-context`
  (`analytics/event-contract.yaml`), is codegen'd, vendored, hash-locked, and CI-verified.
- **`dm_repository` is a pure-Dart package** with no analytics dependency. The sanctioned route to
  observability is a reporter-port typedef, as `DmRepositoryErrorReporter` already does.
- **Layering.** UI -> BLoC -> Repository -> Client. The signal originates in the repository; the
  app layer owns the Crashlytics wiring.
- **Privacy.** Absolute gap + local count, no pubkey (user decision). The analytics contract's own
  `prohibited_fields` already bans `pubkey`/`npub`/`email`/`ip`, and the same bar applies here.

## Prior Art

- 12 brainstorms in `mobile/docs/brainstorm/`; **none** on DM sync boundaries.
- `DmRepositoryErrorReporter` (`dm_repository.dart:77-78`), wired at
  `repository_providers.dart:706-731` — the shape any new port should copy.
- `CrashReportingService.updateCacheMetricsKeys()` — the existing precedent for *routine metrics*
  on the Crashlytics surface, via `setCustomKey` (`cache_hit_rate`, `cache_total_lookups`).
- `#8362` / PR #8442 — the forced re-drain, and the reason a one-shot recovery pass is already spent.

## Approaches Explored

### Approach A: session-local exposure flag

**Description.** At each `startListening`, derive drain-latched + watermark-present + band width,
plus whether `tempRelays` changed against the previous subscribe **in this session**. Report once.

**Layers affected:** Repository (derivation), app layer (sink wiring).

**Pros:** No new persistence. Small diff. Catches the `_resolveOwnDmInbox` memo-self-clear path,
where a `failed` resolve is retried on the next reconnect and widens the relay set with no restart.

**Cons:** Blind across sessions — which is the case #8439 actually describes ("reachable only
through the recipient's kind-10050 inbox that a later session dials"). Likely under-counts.

**Complexity:** Low

### Approach B: persisted relay-set fingerprint — **RECOMMENDED**

**Description.** Persist, per account, the union of relay identities the DM subscription has ever
read from. At each `startListening`, compare the current set against it. Exposure fires when a
relay is **new** *and* `historyDrainComplete` is true *and* a wire watermark exists — i.e. a relay
that was never asked about the band below `since:`, on an install whose only path below that band
is already closed. Report the band width alongside.

**Layers affected:** `DmSyncState` (one new key), `DmRepository` (comparison + emit), app layer (sink).

**Pros:** Captures the across-session case, which is the one the issue describes and the one relay
asymmetry actually produces. The predicate is exactly the defect's precondition, so the number means
what it says. Doubles as groundwork for the per-relay remedy.

**Cons:** One new SharedPreferences key (must default safely on installs that have none, and be
cleared in `clear`/`clearAll` alongside the existing keys). Set-union grows unboundedly in principle
— needs a cap or normalisation.

**Risks:** Relay URL normalisation is subtle here — `RelayPool` keys on `normalizeRelayUrl` while
`handleAddrList` appends a trailing slash, and that exact mismatch caused #8377. The fingerprint must
use the same identity function or it will report phantom "new" relays forever.

**Complexity:** Medium

### Approach C: per-relay watermark shadow — **BLOCKED**

**Description.** Track the wire boundary per relay, measure-only, and report any relay whose own
boundary sits far below the account boundary.

**Why it is blocked.** `NostrClient.subscribe` merges pool and temp-relay responses into a single
stream with one shared `onEvent` callback (`nostr_client.dart:1349`); `RelayPool.subscribe` fans out
to both arms into the same sink. **A caller cannot tell which relay delivered an event.** Per-relay
watermarks are unobtainable without adding relay attribution to `nostr_sdk`.

**This blocks more than the measurement.** "Treat the watermark as per-relay rather than
per-account" is one of the four remedies #8439 itself lists — and it cannot be chosen at all until
that attribution exists, whatever the number turns out to be.

**Complexity:** High (and gated on other work)

### Approach D: derive from existing persisted state only

**Description.** Emit `historyDrainComplete`, `newestWireSyncedAt`, and the band width from state
already persisted. Nothing new stored.

**Why it fails.** Conditions 1 and 2 hold on essentially every established install, so "exposed"
would read as ~100% and the number would not discriminate. The entire signal lives in condition 3
(the readable relay set widened), which this approach cannot see.

**Complexity:** Trivial — and not worth doing.

## Recommendation

**Approach B**, with the exposure signal emitted as a **countable Crashlytics non-fatal** through a
new reporter port on `DmRepository`.

Why B over A: the defect #8439 describes is an across-session one, and A cannot see it. A's slice is
a strict subset of B's logic, so shipping A first buys a smaller diff at the cost of a number that
may be inconclusive for the wrong reason.

Why B over D: D's predicate does not discriminate.

Why not C: blocked, and its blocker is worth its own issue regardless.

### The tension to hold, not resolve silently

`.claude/rules/error_handling.md` is explicit that expected conditions stay out of Crashlytics — its
decision matrix reserves reporting for programming-invariant violations. A routine exposure metric is
not that. The user chose the countable non-fatal deliberately, because `setCustomKey` only surfaces
attached to a report that already happened ("installs that crashed" is a worse sample than bug
reports), and no other production-reaching channel yields an aggregate.

The design must therefore earn its place in that dashboard:

- fire **at most once per (install, account, exposure transition)** — never per `startListening`;
- carry a distinct, clearly-named exception type so it groups on its own and can be muted;
- carry no pubkey, per the privacy bound.

## Open Questions for /plan

- [ ] Which identity function for the relay fingerprint — must match `RelayPool`'s `_relayIdentity`
      normalisation or it reports phantom novelty (#8377's exact failure).
- [ ] Where the union is bounded. A cap, or normalise-and-store only relays that actually answered?
- [ ] Should the fingerprint record relays from the **drain** path too, or the live subscription only?
      The drain shares `_ownInboxRelays()` but queries a different window.
- [ ] Exact once-per-transition key: what marks an exposure as already-reported so a reconnect loop
      cannot re-fire it?
- [ ] Does the signal belong on `DmSyncState.clear` (account switch) — i.e. does a re-added account
      get to re-report?
- [ ] Payload fields, for explicit approval before any code: band width, relay-count delta, drain
      state. No pubkey, no relay URLs (a relay URL can identify a user's chosen infrastructure).

## Prerequisites

- [ ] None blocking. The reporter-port pattern, the Crashlytics wiring, and the `DmSyncState` key
      shape all have existing precedent in-tree.
- [ ] File the `nostr_sdk` relay-attribution gap separately — it gates remedy option 2 permanently.

## Next Step

`/plan 8439` — implementation plan for Approach B.
