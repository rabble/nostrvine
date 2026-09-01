# Plan: instrument the population #8439 can still lose a gift wrap from

**Type**: Task (instrumentation) · **Issue**: [#8439](https://github.com/divinevideo/divine-mobile/issues/8439) · **Complexity**: Medium

Built from `tasks/findings_8439.md` and
`mobile/docs/brainstorm/2026-09-01-issue8439-late-giftwrap-exposure-brainstorm.md`.

---

## Which hypothesis this addresses, and at what confidence

This plan does **not** fix H1. It measures the population H1 applies to, which is what #8439 asks
for before a remedy is chosen.

| Hypothesis | Confidence | Basis |
|---|---|---|
| **H1** — a wrap published before our newest processed wrap and delivered late is dropped by `since:` and never re-requested | **1.0** | Relay half measured against funnelcake (inclusive boundary pinned); app half mutation-proven in CI by `'a wrap the relay holds below the window is never served…'` (commit `b1a2d9e9f2`) |
| **H2** — the 2-day margin is not protocol-guaranteed | **1.0** | NIP-59 sets no bound (its `TWO_DAYS` is sample code); NIP-17's two days is SHOULD in a draft NIP; no relay-side enforcement mandated |
| **H3** — the loss is permanent | **1.0** | `recordWireSeen` advances only (`dm_sync_state.dart:151-159`); drain returns early when latched (`dm_repository.dart:1579-1587`) |
| **Population size** | **unknown** | ← what this plan produces |

## The predicate being measured

An install is **exposed** at a given `startListening` when all three hold:

1. `historyDrainComplete(pubkey)` is `true` — the only path that reaches below the live window is closed;
2. `newestWireSyncedAt(pubkey)` is non-null — a window exists and has a floor;
3. the set of relays the DM subscription **asks** has gained a member since the last time it was recorded.

Condition 3 carries the entire signal. Conditions 1 and 2 hold on essentially every established
install, which is why "derive from existing state only" was rejected in the brainstorm.

**Key simplification found during planning.** Exposure needs the relays that were *asked*, not the
relay that *delivered*. The asked set is `NostrClient.configuredRelays ∪ (ownInbox ?? [])`, both
already in hand inside `startListening`. So this measurement is **not** blocked by the fact that
`NostrClient.subscribe` merges pool and temp-relay responses into one stream — that blocker gates
the per-relay *remedy*, not this metric.

## Affected files

| File | Action | Description |
|---|---|---|
| `mobile/packages/dm_repository/lib/src/dm_sync_state.dart` | Modify | New `readRelayFingerprint` getter + `recordReadRelays`; add key to `clear` / `clearAll` |
| `mobile/packages/dm_repository/lib/src/dm_repository.dart` | Modify | New reporter-port typedef; compute the predicate in `startListening`; emit once per transition |
| `mobile/packages/dm_repository/lib/src/dm_repository_reportable_sites.dart` | Modify | One new site constant |
| `mobile/lib/providers/repository_providers.dart` | Modify | Wire the new port to `CrashReportingService` |
| `mobile/packages/dm_repository/test/src/dm_sync_state_test.dart` | Modify | Fingerprint storage, normalisation, per-pubkey scoping, clear/clearAll |
| `mobile/packages/dm_repository/test/src/dm_repository_test.dart` | Modify | Predicate, once-per-transition, no-fire cases |

No new package. No UI. No BLoC. No Riverpod.

## Implementation steps (bottom-up)

### 1. Repository layer — `DmSyncState`: persist the asked-relay fingerprint

- New prefix `dm.readRelays.` holding a `List<String>` of **normalised** relay identities.
- `List<String> readRelayFingerprint(String pubkey)` → `[]` when absent (a fresh install has no
  history to compare against, and must not report exposure on its first subscribe).
- `Future<Set<String>> recordReadRelays(String pubkey, Iterable<String> relays)` → normalises,
  unions with the stored set, persists, and returns **the members that were new**. Returning the
  delta keeps the "is this new" decision in one place rather than duplicated at the call site.
- **Normalisation uses `normalizeRelayUrl` from `package:nostr_client`** — already a `dm_repository`
  dependency and already exported. It strips the trailing slash and canonicalises the scheme, which
  is the same identity `RelayPool` keys on. Re-implementing it is how #8377 happened: `RelayPool`
  keyed on the stripped form while `handleAddrList` appended a slash, so a raw string compare matched
  nothing. A drifted copy here would report phantom novelty on every subscribe, forever.
- Entries that fail to normalise are dropped, not stored raw.
- **Bound the set.** Cap at a small constant (propose 32, well above any real pool + inbox list). At
  the cap, stop growing rather than evicting — an evicting set would re-report the same relay as new
  on the next rotation.
- Add the new key to both `clear` and `clearAll`, alongside the seven existing prefixes.

### 2. Repository layer — `DmRepository`: compute and emit

- New typedef beside `DmRepositoryErrorReporter`:
  ```
  typedef DmSyncExposureReporter = void Function({
    required int newRelayCount,
    required int knownRelayCount,
    required int bandSeconds,
  });
  ```
  Nullable constructor parameter, same shape as the existing error port. No pubkey, no relay URLs.
- In `startListening`, after `_ownInboxRelays()` resolves and the filter is built:
  - `asked = _nostrClient.configuredRelays ∪ (ownInbox ?? [])`
  - `newRelays = await syncState.recordReadRelays(pubkey, asked)`
  - fire only when `newRelays.isNotEmpty && historyDrainComplete && newestWireSyncedAt != null`
  - `bandSeconds = nowSec - since`, the width of the window below which nothing will be requested.
- **Placement matters.** It must sit *after* the existing `repairPoisonedBoundaries` call, so a
  healed boundary is measured rather than a poisoned one.
- **Once per transition, not per subscribe.** `recordReadRelays` persists the union before the emit
  decision, so the same relay can only ever be "new" once. A reconnect loop cannot re-fire — this is
  a property of the storage, not of a separate suppression flag, which is why it cannot drift.
- Do **not** let a reporter throw reach the subscription path: wrap the call, as the error port is.

### 3. App layer — wire the port

In `repository_providers.dart`, beside the existing `errorReporter`, wire to
`CrashReportingService.instance.recordError` with a distinct exception type so it groups on its own
and can be muted independently of real crashes.

## Payload (needs explicit approval before code — see Risks)

| Field | Example | Why |
|---|---|---|
| `newRelayCount` | `1` | How many relays entered the asked set |
| `knownRelayCount` | `5` | Denominator — distinguishes "first inbox relay" from "pool churn" |
| `bandSeconds` | `172800` | Width of the unreachable band; sizes the loss, not just its presence |

Deliberately absent: pubkey, npub, relay URLs (a relay URL identifies a user's chosen
infrastructure and can be identifying on its own), message counts, timestamps.

## Testing strategy

| Layer | File | Cases |
|---|---|---|
| `DmSyncState` | `dm_sync_state_test.dart` | fingerprint defaults to empty; union grows and is normalised; a trailing-slash variant is **not** reported new; delta is returned; cap holds; per-pubkey scoping; `clear`/`clearAll` remove it |
| `DmRepository` | `dm_repository_test.dart` | fires when all three conditions hold; **does not** fire on a fresh install; does not fire when the drain is not latched; does not fire when no watermark exists; does not fire on a second subscribe with the same relay set; `bandSeconds` equals `now - since`; a throwing reporter does not break the subscription |

Every one of those "does not fire" cases must be **mutation-proven** — drop the corresponding guard
and confirm the test goes red. The existing `#8439` boundary test was proven this way twice, and the
memory of this file is explicit that a green count is not evidence a guard is load-bearing.

**Ratchets to respect** (all verified against current baselines):
- `shared_setup_stubs.txt` for `dm_repository_test.dart` is **14** — new stubs go in the test body or
  a group-local `setUp`, never the file-level one.
- `dm_repository` coverage gate is **`min_coverage: 93`** (`.github/workflows/dm_repository.yaml`).
- `service_god_file_sizes.txt` and `post_close_emit.txt` do **not** apply (scope is `mobile/lib`).
- No entry in `ungrouped_tests.txt` or `skip_test_ceilings.txt` for either file — keep it that way.

## Risks and considerations

1. **This puts a routine metric in a crash dashboard.** `.claude/rules/error_handling.md` reserves
   Crashlytics for programming-invariant violations, and an exposure signal is not one. This was
   chosen deliberately, because `setCustomKey` only surfaces attached to a report that already
   happened and no other production-reaching channel yields an aggregate. Mitigation: distinct
   exception type, once per transition, no pubkey. **If the dashboard noise proves unacceptable, the
   fallback is the log-only route, not silence.**
2. **Relay-URL normalisation drift** would make every subscribe report phantom novelty. Mitigated by
   reusing `normalizeRelayUrl` rather than copying it, plus an explicit trailing-slash test.
3. **The metric counts exposure, not loss.** An exposed install has not necessarily lost anything —
   the newly-asked relay may hold nothing below the band. The number is an upper bound on affected
   installs, and must be reported as such rather than as "N users lost messages".
4. **Pool churn could inflate the count.** A relay added by ordinary discovery is "new" to the
   fingerprint even if it never held a DM. `knownRelayCount` is in the payload precisely so this can
   be separated during analysis; if it dominates, restrict the asked set to `ownInbox` only.
5. **A first subscribe after `clear` re-reports.** After an account switch the fingerprint is wiped,
   so the account can report exposure once more. That is correct — a re-added account genuinely has
   an unmeasured relay set — but it means the metric counts (install, account) pairs, not users.
6. **Open PR #8206 touches `dm_repository.dart`.** Coordinate before pushing; per repo memory,
   issue-scoped PRs have collided on this file before.

## What this plan deliberately does NOT do

- It does not fix #8439. No change to `since:`, the watermark, or the drain.
- It does not implement any of the four remedies the issue lists.
- It does not add relay attribution to `nostr_sdk`. That gates the per-relay remedy permanently and
  belongs in its own issue.

## Next step after the number exists

Choose among the four remedies against the measured band width and population. Note that
**"per-relay watermark" is not currently choosable** — `NostrClient.subscribe` merges pool and
temp-relay responses into a single stream, so nothing can attribute an event to a relay.
