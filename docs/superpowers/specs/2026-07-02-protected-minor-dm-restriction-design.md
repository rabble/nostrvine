# Protected-minor DM restriction (mobile) — design

**Issue:** divinevideo/support-trust-safety#176 (part of the protected-minor epic #173; consumes the #174 seam, merged as #5708; shares #175's sticky fail-safe posture)
**Date:** 2026-07-02, filled in 2026-07-07 after the divine-mobile#4948 trust-model decision
**Status:** Design complete, pending Matt's approval; implementation follows on this branch. Security posture review by dcadenas on the PR before merge (per the #4948 handoff).

## Goal

Restrict a protected minor's direct messages to **official Divine accounts only**:
- **Send:** block sending a DM to any pubkey outside the approved-recipient set.
- **Inbound:** suppress display of DMs from senders outside the approved-recipient set.

Client-side by necessity: NIP-17 DMs are kind-1059 gift-wraps authored by a one-time key, so the relay cannot attribute a DM to a real sender and cannot filter by sender.

## Decisions (were open questions; resolved via divine-mobile#4948)

### The approved-recipient set: pinned ∩ live NIP-05 (Tier 2)

Per the #4948 decision, "may DM a protected minor" is a stricter trust tier than
labels/badges. An account is an approved minor-DM recipient iff **both**:

1. it is in `PINNED_OFFICIAL_ACCOUNTS` (hardcoded, ships with the app) with
   `minorContactable: true`, **and**
2. its pinned canonical NIP-05 identifier currently resolves to its pinned hex
   pubkey (the revocation lever: repointing/removing the name drops the account
   from the set within the cache TTL, no app release).

The pinned set (verified live 2026-07-07; full hex, never truncate):

| role | display | hex pubkey | canonical nip-05 | minorContactable |
|---|---|---|---|---|
| hq | Divine HQ | `c4a39f1291291d452405cd8ddd798c4a29a3858c52cd0d843f1f6852cf17682e` | `_@divinehq.divine.video` | true |
| moderation | Divine Moderation | `8fd5eb6d8f362163bc00a5ab6b4a3167dbf32d00ec4efdbcf43b3c9514433b7e` | `moderation@divine.video` | true |

Notes:
- The two accounts deliberately declare different canonical forms (subdomain vs
  classic); each entry pins its own identifier and the check verifies THAT
  identifier against THAT hex.
- The set is small and stable; team members act through these accounts via
  direct or bunkered keycast credentials, so it does not churn per-agent.
  Additions require an app release — accepted friction for this tier.
- `78a5c21b5166dc1474b64ddf7454bf79e6b5d6b4a77148593bf1e866b73c2738`
  ("support" in `bug_report_config.dart`, a personal key) is NOT in the set.
  Any minor-facing support affordance that points there migrates to HQ as part
  of this work (see Scope).

### NIP-05 leg semantics: fail open on network failure, fail closed on affirmative mismatch

Drop signals are graded by ambiguity (amended 2026-07-07 after pressure-testing):

- **Resolves to a DIFFERENT key** (unambiguous — either a deliberate revocation
  repoint or a name-server compromise, and under the intersection both mean
  "stop trusting this entry"): drop **immediately**, persist the dropped state.
- **Affirmative absence** (well-formed response without the name, or 404): weak
  signal — a name-server deploy hiccup or edge-cache misconfiguration looks
  identical and would otherwise mass-revoke support access for every protected
  minor at once. Require **confirmation on a ~5-minute recheck** before
  dropping; a single absent response alone never drops.
- **Network failure** (offline, timeout, 5xx, malformed response): the entry
  keeps its last-known state, defaulting to pin-trusted on cold start. A
  protected minor on a plane must still be able to DM support; the pin alone
  already prevents the attacker-ADDITION failure mode, so the NIP-05 leg exists
  only for revocation freshness and must not brick offline support access.
- **Cache TTL: 1 hour** for the background/inbound state (vs the 24h label
  cache), re-checked opportunistically on app foreground.
- **Send-time freshness:** the send path is async, so if the cached leg state
  is older than the TTL at the moment of send, `isApprovedMinorDmRecipient`
  awaits a fresh resolution before approving (falling back to the network-
  failure rule if the fetch fails). The action that matters most gets
  point-of-use freshness; the hot inbound-filter path stays on the sync cache.
- **Receive-time revalidation:** when an inbound message arrives from a tier-2
  counterparty whose cached leg state is stale, kick an async re-resolution in
  the background and re-apply the filter on result (the conversation streams
  already re-emit). Bounded to the two pinned names and TTL-gated, so there is
  no fetch-storm risk. With send- and receive-time freshness, revocation is
  near-instant at both points of use for reachable clients and the 1h TTL is a
  pure backstop, not the primary propagation mechanism.

### Threat model and accepted risks (documented, not discovered-in-review)

- **The revocation guarantee is reachability-bounded:** "a revoked entry drops
  within TTL" holds only for clients that can successfully reach the name
  server. An attacker holding a compromised pinned key AND network position on
  a specific victim can suppress revocation for as long as they hold both. We
  accept this: the alternative (fail closed on network failure) cuts every
  offline minor off from support, a certain harm against a compound-condition
  one. Send- and receive-time freshness narrow both point-of-use windows;
  future hardening
  could try to distinguish general offline from selective unreachability of
  divine.video, but that is unreliable on mobile networks and deferred.
- **Storage-clear un-revokes until the next successful check:** persisted
  dropped state lives in SharedPreferences; clearing app storage returns the
  entry to the cold-start pin-trusted default. Chained with offline, a revoked
  entry can be transiently trusted again. Accepted for the same reason as
  above; noted so it is a decision, not a surprise.
- **Client-side filtering is the ONLY inbound enforcement layer.** NIP-17
  gift-wraps are authored by ephemeral keys, so the relay cannot block DMs
  from a banned sender, and a leaked raw nsec signs from anywhere regardless
  of keycast suspension. This is why the inbound filter and its fail-safe
  posture carry security-review weight disproportionate to their code size.

### Launch checklist (ops artifacts, required before the PR merges)

1. **Revocation runbook:** who repoints/removes a tier-2 nip-05 in the name
   server, how it is triggered out-of-hours, and the expected end-to-end
   propagation time (repoint + client TTL).
2. **Monitoring:** the team-side nostr.json monitor alerts specifically on the
   two tier-2 identifiers (resolution changed or absent), so a repoint or
   misconfiguration is seen on a dashboard before it is felt by minors.
3. **Change control:** decide whether changes to the child-contactable set
   (pin changes in code, or name-server repoints of these two names) require a
   documented two-person rule, per the CSAM-adjacent change-control principles
   (raised as open item in the #4948 decision).

### Enforcement activation: same sticky posture as #175

Enforcement applies when the protected-minor state is `protected`
(`isProtectedMinorProvider`, last-known-preserving per #174's merged seam).
A never-resolved `unknown` does not enforce (matches the shipped #175
behavior); a `protected`-then-`unknown` sequence keeps enforcing until a
positive `not_protected` resolution lifts it.

## Architecture

### New: `OfficialAccountsService` (+ config)

- `lib/config/official_accounts.dart`: the `OfficialAccount` model
  (`pubkeyHex`, `nip05`, `role`, `minorContactable`) and the
  `PINNED_OFFICIAL_ACCOUNTS` const above.
- `lib/services/official_accounts_service.dart`:
  - `bool isPinnedMinorContactable(String pubkeyHex)` — sync, pin-only.
  - `Future<bool> isApprovedMinorDmRecipient(String pubkeyHex)` — pin ∩ NIP-05
    with the leg semantics above (uses `Nip05Validor` with a dedicated 1h
    cache + last-known store in SharedPreferences).
  - `bool isApprovedMinorDmRecipientSync(String pubkeyHex)` — pin ∩ last-known
    NIP-05 leg, for hot paths (inbound list filtering must not await network
    per conversation).
- Riverpod provider alongside `protected_minor_providers.dart`.

### Enforcement points (seams verified in code 2026-07-07)

1. **Repository send gate (authoritative):**
   `packages/dm_repository/lib/src/dm_repository.dart` `sendMessage()`
   (~:2471), before the `sendRumor()` call (~:2530): when the injected
   recipient policy is active and the recipient fails
   `isApprovedMinorDmRecipient`, return a typed failure (no silent drop).
   Group sends likewise require ALL recipients approved. dm_repository is a
   package and stays app-agnostic: it accepts an injected
   `Future<bool> Function(String recipientPubkey)?` recipient-policy callback,
   wired from the app layer only when the account is protected.
2. **UI affordances (UX, defense-in-depth):**
   - `lib/screens/other_profile_screen.dart` `_messageUser()` (~:160): hide the
     Message button for non-approved profiles when protected.
   - `ConversationPage` deep-link/route entry: guard `participantPubkeys`
     against the set when protected (redirect to inbox with a notice).
3. **Inbound filter:**
   `lib/blocs/dm/conversation_list/conversation_list_bloc.dart` (~:99-126):
   when protected, filter both `watchAcceptedConversations` and
   `watchPotentialRequests` streams to conversations whose counterparty passes
   `isApprovedMinorDmRecipientSync`. Applies to inbox AND the Requests tab —
   a protected minor sees no non-official requests at all.
   Sender identity is the **seal pubkey** (`dm_decryption_worker.dart` ~:172,
   authoritative per NIP-59; rumor sender claims are already rebuilt from the
   seal), so the filter keys on stored conversation counterparty pubkeys that
   derive from it.
4. **Blocked-send UX:** snackbar/inline copy (new l10n strings) explaining DMs
   are limited to Divine accounts for this account type. No dead-air failures.

### What this does NOT do

- No relay/server enforcement (impossible for NIP-17; documented in #176).
- No parent-approved allowlist (#178, later); the service API shape
  (`minorContactable` flag + injected policy callback) leaves room for it.
- No change to labels/badges resolution (Tier 1, `ModerationLabelService`,
  stays NIP-05-authoritative per #4948; advisory mismatch logging is separate
  small work there).

## Tests

- `official_accounts_service`: pin-miss rejected; pin-hit + NIP-05 match
  approved; affirmative mismatch drops entry (and persists dropped state);
  network failure preserves last-known/pin-trusted; TTL respected;
  non-minorContactable pinned entry rejected for DM purposes.
- send gate: protected minor → non-approved recipient returns typed failure and
  nothing publishes; approved recipient sends; non-minor unaffected; group send
  with any non-approved recipient fails.
- inbound: protected minor sees only official conversations in inbox and
  requests; non-minor sees everything; flip to protected mid-session filters on
  next emission.
- affordances: Message button hidden for non-approved when protected; deep link
  guarded.
- Follow existing bloc/service test harnesses; #5721's dev toggle enables
  manual QA end to end.

## Scope

Mobile this branch/PR. Web parity is divine-web#454 (mirrored design committed
there; web additionally migrates its hardcoded `DIVINE_SUPPORT_PUBKEY`
(personal key) surfaces to HQ). Mobile's `bug_report_config.supportPubkey`
migration to an official account rides along here only where it intersects
minor-facing DM affordances; the full support-identity cleanup is tracked via
support-trust-safety#115. Parent-approved allowlist is a later follow-on
(#178 / divine-web#455).

## Corrections after adversarial review (2026-07-07)

An independent adversarial review (verified against code) found three
correctness holes in the security boundary. These corrections supersede the
conflicting text above; the implementation follows the corrected design.

### C-H1 — the send gate moves to the lowest NIP-17 publish primitive (was: `sendMessage`)

`sendMessage()` is one of ~7 outbound kind-1059 publishers. Verified bypasses in
`dm_repository.dart`/`dm_reactions_repository.dart`: `sendGroupMessage` (:3367),
`sendSharedVideo` (:2657), `sendFileMessage` (:3695), the queue-replay paths
`recoverFullSend` (:3031) and `recoverSelfWrap` (:2861) — which re-publish from
`OutgoingDmsDao` JSON with no policy check and fire routinely on inbox open —
and `DmReactionsRepository._sendRumorWithTimeout` (:604), i.e. a DM *reaction* is
itself an outbound rumor. Correct chokepoint: enforce the injected recipient
policy inside `NIP17MessageService.sendRumor` / `sendPrivateMessage` /
`publishSelfWrap` (nip17_message_service.dart) so ALL NIP-17 paths are covered at
one seam; the legacy NIP-04 `_sendNip04Message` (:3791) gets its own guard.
**Queue replay must re-evaluate the policy at replay time**, not trust
enqueue-time state — a recipient revoked (or an account that became protected)
after enqueue must not be replayed to. Group send requires ALL recipients
approved at the primitive.

### C-H2 — new discriminated NIP-05 resolver (was: reuse `Nip05Validor`)

`Nip05Validor.getPubkey`/`valid` collapse different-key, absent, and network
failure into one `null`/`false`, so the graded model is unimplementable on it.
New resolver returning a discriminated result:
`{ matched | differentKey(hex) | absent | networkError }`, with explicit
connect/receive **timeouts** (so the network-failure branch actually triggers
and a slow/hostile server can't hang a send), a **redirect cap** and
**max-content-length**, and **lowercase+trim normalization** on both sides of
the hex compare (an uppercase/checksummed nostr.json must not be misread as
different-key and mass-revoke support). The graded drop / fail-open rules attach
to this discriminated result, not to a boolean.

### C-M1 — send-time freshness must not be defeated by in-flight dedup

The resolver's concurrency handling must **await the in-flight resolution** for a
name already being resolved (e.g. by a concurrent receive-time revalidation) and
return its real result, never a null-as-failure that the send path would treat as
network-failure → pin-trusted → approve. Point-of-use freshness cannot degrade to
fail-open just because the other point of use is mid-check on the same two names.

### C-L4 — receive-time first-render is accepted, bounded

Inbound filtering keys on the sync last-known leg, so a just-revoked-but-cached
counterparty's message can render for the moment before receive-time
revalidation completes and pulls it. Accepted (bounded to the revalidation
round-trip, and the pin still blocks attacker-addition); noted as a known small
window, not a silent one.
