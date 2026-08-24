# Brainstorm: NIP-46 remote-signer response sender authentication (#7339 / #7344)

Date: 2026-08-24

## Problem Statement

The long-lived NIP-46 client signer (`NostrRemoteSigner.onMessage`) accepts kind-24133
"responses" from **any** pubkey: it never compares the inbound `event.pubkey` to the paired
`info.remoteSignerPubkey`, never checks the signature, and derives the NIP-44 conversation key
from the *inbound event's own* pubkey — so a payload any stranger encrypts to the client pubkey
decrypts cleanly. On the `auth_url` branch this hands an attacker-controlled URL straight to
`launchUrl(externalApplication)` (forced navigation / phishing, #7339); on the response branch
it lets a stranger complete a pending request via the `callbacks` map (identity poisoning / DM
plaintext substitution, #7344). Both are the **same missing invariant** — inbound responses are
not bound to a known author.

Proven at 1.0: executed offline (stranger `auth_url` fires the launcher; blanked sig still
fires; stranger completes a pending `get_public_key`) and on a physical iPhone (iOS 26.6.1):
the chain fires and Safari actually opens with the attacker URL. Full evidence in
`tasks/findings_7339.md`.

## Constraints

- Fix lives in a **pure vendored SDK package** (`mobile/packages/nostr_sdk`, extracted from
  `haorendashu/nostr_sdk` — still unfixed upstream). No Flutter-UI types; `log()` from
  `dart:developer` is the sink (`check_raw_logging.sh` exempts nostr_sdk).
- Two NIP-46 handlers with **different trust models**: the long-lived `NostrRemoteSigner`
  *knows* `remoteSignerPubkey` post-pairing → authenticate by author. The pairing-phase
  `NostrConnectSession` does *not* yet know it → authenticates by the shared secret and
  suppresses auth_url (#3760/#5683). The fix targets the long-lived signer only.
- Author check must compare against **`remoteSignerPubkey`**, never `userPubkey` — a bunker's
  signer key legitimately differs from the user key (nsec.app-style; Keycast derives a
  per-authorization bunker keypair). Confirmed safe for Keycast (cross-repo).
- Comparison must be **case-insensitive on hex** and must not misfire when `remoteSignerPubkey`
  is empty (empirically: `Uri` lowercases the bunker:// host on the persistence round-trip).
- `Event.isValid` is **id-integrity only**; the signature primitive is `Event.isSigned`. The
  repo-canonical pair is `isValid && isSigned` (`nip59/gift_wrap_util.dart:20`).
- Ratchets in scope: `check_pubkey_log_encoding.sh` (zero-tolerance; use `pubkeyForLogs`),
  `check_nostr_id_log_truncation.sh` (zero), `check_ungrouped_tests.sh` (packages/ in scope).
- Repo rule: interdependent work ships as **one PR**, never stacked.

## Prior Art

- **divine-web** already double-pins the author: `authors:[bp.pubkey]` filter term **and** a
  local `matchFilters` re-check before `onevent` (`nostr-tools/nip46.js:1183`,
  `abstract-pool.js:338`). Mobile is the outlier.
- **divine-connect** `nip46_client.rs:243`: `sender != Some(bunker_pubkey) => continue`, before
  decrypt — cleanest single precedent.
- **PR #3760 / #6151** fixed the identical threat on the *pairing* path (suppression, because
  the sender is unauthenticated there). #6151's PR body states the bunker path is "intentionally
  untouched (its sender is authenticated via the bunker:// URI)" — factually false about the
  code; #7339 is the discovery that the assumed invariant was never enforced.
- **#6153** already tracks a user-gated tap-to-open auth_url affordance (out of scope here).
- Free test infra: `test/support/test_relay_server.dart` (#7973). NIP-44 MAC enforced at
  `nip44_v2.dart:234-239`.

## Approaches Explored

### Approach A: Receive-layer author + signature pin only
**Description:** In `onMessage`, at the top of the `kind==24133` branch, drop the event unless
`event.pubkey == info.remoteSignerPubkey` (lowercased-hex, empty-guarded) **and**
`event.isValid && event.isSigned`, before decrypting. Mirrors divine-connect.
**Layers affected:** Client (nostr_sdk).
**Pros:** Smallest change that closes the whole class (both #7339 launcher and #7344 callbacks
hijack). Matches a shipped precedent. No behavior change for legitimate bunkers.
**Cons:** A malicious/compromised relay is still *asked* to deliver stranger events (it can't
succeed past the recheck, but the wire exposure remains). Leaves the auth_url ordering, CSPRNG
id, and log-redaction sub-items unaddressed.
**Complexity:** Low.

### Approach B: Defense-in-depth — subscription `authors:` filter + receive-layer recheck
**Description:** Approach A's recheck **plus** add `authors:[info.remoteSignerPubkey]` to the
subscription `Filter` in `genQueryMsg` (only when non-empty). Mirrors divine-web's double-pin:
the honest relay stops delivering stranger events at all; the recheck defends against a lying
relay that ignores the filter.
**Layers affected:** Client (nostr_sdk).
**Pros:** Strongest; matches divine-web exactly. Reduces wire noise and the unhandled-async
surface. Still one small package-local change.
**Cons:** Slightly more surface (filter + recheck) to test; must guard the empty-pubkey case in
two places.
**Complexity:** Low–Medium.

### Approach C: Suppress auth_url entirely (mirror the pairing sibling)
**Description:** Never surface/open the URL from the long-lived signer either; drop
`onAuthUrlReceived`.
**Layers affected:** Client + app (remove callback wiring).
**Cons:** Breaks third-party bunkers (e.g. nsec.app) that legitimately use auth_url to complete
login; heavier than needed since the long-lived signer *knows* the remote pubkey. **Rejected by
product decision (authenticate-and-keep).**
**Complexity:** Medium (user-visible).

### Approach D: Correlate-before-act only (require a pending request id)
**Description:** Require `callbacks.containsKey(response.id)` before acting on auth_url; leave
decryption trust as-is.
**Cons:** Does not fix the `callbacks` hijack (#7344) — a guessed/observed live id still
completes; does not bind the other response types; weaker than an author check. Insufficient
alone.
**Complexity:** Low.

## Recommendation

**Approach B (defense-in-depth author pin) as the core, packaged into the confirmed one-PR
scope closing #7339 + #7344**, with the auth_url branch kept (authenticate-and-keep):

1. **Author + signature pin** in `onMessage` before decrypt (`isValid && isSigned`,
   `event.pubkey == remoteSignerPubkey` lowercased-hex, empty-guarded) — the shared primary fix.
2. **`authors:` filter term** in `genQueryMsg` (defense in depth, divine-web parity).
3. **auth_url correctness:** move the branch below `callbacks.remove(response.id)` (or require a
   pending id), switch the inline predicate to the shared `NostrRemoteResponse.isAuthChallenge`,
   and redact the URL log at `:165` (`pubkeyForLogs`/no verbatim URL).
4. **CSPRNG `NostrRemoteRequest.id`** via `Random.secure()` (#7344 defense-in-depth).
5. **`pullPubkey` hex validation** (#7344).
6. Keep `onAuthUrlReceived` auto-open — now reachable only from the paired bunker (product
   decision; #6153 tracks any tap-to-open enhancement).

Why B over A: divine-web ships exactly this double layer against the same bunker ecosystem, at
near-zero extra cost, and it removes the honest-relay delivery of stranger events (also shrinking
the unhandled-async `Uri.parse` surface). Why not C/D: C is rejected by product decision and
breaks third-party bunkers; D leaves #7344 open.

**Scope out** to a follow-up issue: the six relay-subscription-id call sites in
`relay_pool.dart` / `nostr.dart` / `subscription.dart` (outside `nip46/`, different blast radius;
#7344 itself calls them a judgment call). Also note-as-separate: Keycast's `BUNKER_RELAYS`
leading with `relay.divine.video` (likely drops 24133).

## Open Questions for /plan

- [ ] Exact placement of the empty-`remoteSignerPubkey` guard (skip pin vs. hard-fail) — should
      be skip-pin-when-empty, since a constructed `NostrRemoteSigner` always has it, and the only
      empty case is the pairing-owned info object that never reaches this class.
- [ ] Whether a rejected forgery should `return` cleanly instead of letting `onMessage` rethrow
      (currently `:206-211` rethrows → unhandled async). Decide clean-drop.
- [ ] Fold `NostrConnectSession._handleResponse`'s `isValid`-only gate → `isValid && isSigned`?
      (adjacent, cheap, same file family) — decide in plan.
- [ ] Test file placement: `packages/nostr_sdk/test/unit/nostr_remote_signer_auth_test.dart`
      vs. extend existing `nostr_remote_signer_test.dart`.

## Prerequisites

- [ ] None blocking. No design mockups (no UI change under authenticate-and-keep). No new package.

## Next Step

`/plan https://github.com/divinevideo/divine-mobile/issues/7339` — build the implementation plan
from `tasks/findings_7339.md` + this brainstorm (one PR, Approach B, authenticate-and-keep).
