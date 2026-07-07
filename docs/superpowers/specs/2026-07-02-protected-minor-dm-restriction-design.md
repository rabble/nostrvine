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

- **Affirmative mismatch** (the identifier resolves to a different key, or the
  name affirmatively 404s): the entry drops out of the approved set — this is
  the revocation path working as designed.
- **Network failure** (offline, timeout, 5xx): the entry keeps its last-known
  state, defaulting to pin-trusted on cold start. A protected minor on a plane
  must still be able to DM support; the pin alone already prevents the
  attacker-addition failure mode, so the NIP-05 leg only exists for revocation
  freshness and must not brick offline support access.
- **Cache TTL: 1 hour** (vs the 24h label cache). Rationale: this tier's whole
  point is fast revocation; hourly re-checks of exactly two names are cheap.
  Re-check opportunistically on app foreground.

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
