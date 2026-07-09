# Protected-minor DM restriction (mobile) — design

**Issue:** divinevideo/support-trust-safety#176 (protected-minor epic #173; consumes the #174 seam merged as #5708).
**Trust model:** decided in divine-mobile#4948 (tiered).
**Status:** Design complete; implementation held pending @dcadenas design-level review (child-safety control). Two independent adversarial reviews (2026-07-07) are folded into this document.
**Note:** this is the clean consolidated spec; it supersedes the earlier draft + correction rounds in git history.

## Goal

Restrict a **protected minor** (13-15, keycast `verified_minor`) to DMs with **official Divine accounts only**:
- **Send:** block sending a DM to any pubkey outside the approved set.
- **Inbound:** suppress display of, and metadata about, DMs from senders outside the approved set.

Enforcement is **client-side by necessity and is the only inbound layer**: NIP-17 DMs are kind-1059 gift-wraps authored by ephemeral keys, so the relay cannot attribute a DM to a sender or filter by one, and a leaked raw nsec signs regardless of keycast suspension. This is why the fail-safe posture below carries security weight out of proportion to its code size.

## The approved set — pinned ∩ live NIP-05 (Tier 2 of #4948)

"May DM a protected minor" is a stricter tier than labels/badges. An account is an approved recipient iff **both**:

1. it is in `PINNED_OFFICIAL_ACCOUNTS` (hardcoded, ships with the app) with `minorContactable: true`, **and**
2. its pinned canonical NIP-05 identifier currently resolves to its pinned hex pubkey.

The pin blocks attacker *addition* (an attacker can't inject a key the app didn't ship); the NIP-05 leg is the *revocation* lever (repointing/removing a name drops that account without an app release).

The set (verified live 2026-07-07; full hex, never truncate):

| role | display | hex pubkey | canonical nip-05 | minorContactable |
|---|---|---|---|---|
| hq | Divine HQ | `c4a39f1291291d452405cd8ddd798c4a29a3858c52cd0d843f1f6852cf17682e` | `_@divinehq.divine.video` | true |
| moderation | Divine Moderation | `8fd5eb6d8f362163bc00a5ab6b4a3167dbf32d00ec4efdbcf43b3c9514433b7e` | `moderation@divine.video` | true |

- Each entry pins its **own** canonical form (HQ uses a subdomain origin, moderation the classic form); the check verifies THAT identifier against THAT hex.
- Small and stable: team members act *through* these accounts via direct/bunkered keycast credentials, so per-agent attribution lives in keycast's audit layer and the set does not churn. Additions require an app release — accepted friction for a child-contact list.
- The personal key `78a5c21b5166dc1474b64ddf7454bf79e6b5d6b4a77148593bf1e866b73c2738` ("support" in `bug_report_config.dart`) is **not** in the set; minor-facing affordances pointing there migrate to HQ (see Scope).
- **Design validation:** `report_content_dialog.dart:443` DMs the moderation pubkey, which is in the set — so a minor's abuse-report still sends. An approved-*set* gate preserves safety-reporting where a blanket minor-DM block would break it. This is why moderation must be in the set.

## Fail-safe posture — FAIL CLOSED and PERSISTENT (the load-bearing decision)

A deliberate divergence from #175's adult-content lock, because **the restricted party can trivially suppress the input that produces `unknown`** (airplane mode, clear storage, block the keycast domain, let the token expire). If `unknown` failed open, the control would be opt-out by its own target. So:

- **Persist last-known `protected` to disk.** The "sticky from Riverpod `.value`" assumption was false — `.value` is in-memory and dies with the process. **DONE on mobile:** #5744 (#175) shipped `ProtectedMinorStickyStore` (per-account SharedPreferences, valid at cold start) behind `isProtectedMinorProvider`, which trusts only a freshly-resolved status on an authenticated session and otherwise returns the persisted last-known. #176 **consumes** this seam; it does not rebuild it. (The remaining persistence gap is WEB — tracked in support-trust-safety#180, re-scoped web-only.)
- **Enforce on `unknown` and during cold-start-before-resolution** whenever this account was ever seen `protected`.
- **A null/empty token maps to `unknown`, not `notProtected`.** Today `protected_minor_repository.dart:24-35` returns a *positive* `notProtected()` on a missing token, which affirmatively *lifts* protection on a transient blip. It must become `unknown`.
- **The persistent store's role is to RELAX, not to protect:** it lets accounts positively seen as `not_protected` skip the fail-closed default so adults don't eat a lockout on every network blip. Safety does not depend on it; adult UX does. Accepted cost: a brand-new adult install during a keycast outage can DM only official accounts until the check clears (rare, self-heals). The same brief restriction applies once per account at first launch after this ships (no persisted verdict yet, resolves in seconds).
- **The DM gates consume a dedicated fail-closed seam (`isDmRestrictedProvider`), not `isProtectedMinorProvider`.** The shared #175 seam collapses "confirmed not-protected" and "no verdict yet" into `false` (fail-open, correct for the content lock's posture); the DM seam reads the sticky store tri-state (`lastKnownFor`) and restricts unless a positive not-protected verdict exists — trusted live or persisted. Surfaced in dcadenas's review of the first implementation round.
- **Wire the gate unconditionally** and have the callback read live state at call time — never install it conditionally on a value that starts `false`.
- **Re-resolve on mid-session approval:** the provider recomputes only on auth-state change, so a minor approved mid-session stays ungated until invalidated. Invalidate on the approval signal.

## NIP-05 leg — graded drop, fail open only on network failure

Drop signals are graded by ambiguity (a name-server hiccup must not mass-revoke support):

- **Resolves to a DIFFERENT key** → drop **immediately**, persist. (Revocation or compromise; both mean stop trusting.)
- **Affirmative absence** (well-formed response without the name, or 404) → drop only after a **confirming ~5-minute recheck**; a single absent response never drops.
- **Network failure** (offline, timeout, 5xx, malformed) → keep last-known, pin-trusted on cold start. The pin already blocks attacker-addition, so the leg exists only for revocation freshness and must not brick offline support access.
- **1h background/inbound TTL**, plus point-of-use freshness so the TTL is a backstop, not the propagation mechanism:
  - **Send-time:** if the cached leg is stale at send, await a fresh resolution before approving.
  - **Receive-time:** an inbound message from a stale-cached tier-2 counterparty kicks a background re-resolution and re-applies the filter on result (streams re-emit; bounded to two names, no fetch-storm).

## Architecture

### `OfficialAccountsService` + a new discriminated resolver

- `lib/config/official_accounts.dart`: `OfficialAccount` (`pubkeyHex`, `nip05`, `role`, `minorContactable`) + `PINNED_OFFICIAL_ACCOUNTS`.
- A **new NIP-05 resolver** (NOT `Nip05Validor`, which collapses different-key/absent/network into one `null`): returns `{ matched | differentKey(hex) | absent | networkError }`, with connect/receive **timeouts** (so the network branch actually fires and a hostile server can't hang a send), **redirect cap**, **max-content-length**, and **lowercase+trim** hex normalization (an uppercase/checksummed nostr.json must not read as different-key and mass-revoke). Concurrency: a request for a name already in flight **awaits that resolution** and returns its real result — never null-as-failure that would degrade send-time freshness to fail-open.
- `lib/services/official_accounts_service.dart`: `bool isPinnedMinorContactable(hex)` (pin-only, sync); `Future<bool> isApprovedMinorDmRecipient(hex)` (pin ∩ NIP-05, graded rules, dedicated 1h cache + persistent last-known); `bool isApprovedMinorDmRecipientSync(hex)` (pin ∩ last-known, for hot list paths). Riverpod provider alongside `protected_minor_providers.dart`.

### Enforcement points (seams verified in code 2026-07-07)

1. **Send gate at the lowest primitive, before enqueue, re-checked on drain.** `sendMessage` is one of ~7 publishers and it **enqueues (`dm_repository.dart:2505`) before publishing (`:2530`)**, so a point-of-send check is a stored-intent bypass. Enforce inside `NIP17MessageService.sendRumor`/`sendPrivateMessage`/`publishSelfWrap` so all NIP-17 paths are covered at one seam (covers `sendGroupMessage`, `sendSharedVideo`, `sendFileMessage`, reactions via `DmReactionsRepository._sendRumorWithTimeout:604`); the legacy NIP-04 `_sendNip04Message:3791` gets its own guard. Gate **before** `outgoingDao.enqueue`, AND **re-evaluate the policy in the queue drain** (`recoverFullSend:3031`, `recoverSelfWrap:2861`) before every republish — a recipient revoked (or an account that became protected) after enqueue must not be replayed to. Group send requires **ALL** recipients approved. Failure returns a typed error, never a silent drop; surfaced as blocked-send UX (new l10n copy), no dead air.
2. **Inbound filter** in `conversation_list_bloc.dart:99-126`: when protected, filter both `watchAcceptedConversations` and `watchPotentialRequests` to counterparties passing `isApprovedMinorDmRecipientSync` — inbox AND Requests tab. Counterparty identity is the **seal pubkey** (`dm_decryption_worker.dart:172`, authoritative per NIP-59; spoofed rumor senders already rebuilt from the seal). **Group inbound requires EVERY non-self participant approved** (else an attacker p-tags the minor + a pinned decoy to slip content through). Receive-time revalidation (above) pulls a just-revoked-but-cached counterparty; the brief first-render before it completes is an accepted, bounded window.
3. **Unread badge:** `DmUnreadCountCubit` composes counts independently ("count cannot drift from list"), so it must apply the same predicate (or route through one filtered source) or it leaks the existence + count of hidden contact attempts.
4. **Affordance guards (UX / defense-in-depth):** hide the Message button in `other_profile_screen.dart:160` for non-approved profiles when protected; guard the `ConversationPage` deep-link/route (redirect to inbox with a notice); guard the **message-request preview route** (`/inbox/message-requests/:id`) inside `RequestPreviewCubit.load()` — the same non-empty ∩ all-approved predicate (`allParticipantsApprovedForMinor`, shared with the route guard) runs against the route-provided pubkeys before ANY repository read, else the view bounces to the inbox. Resolving counterparties from the DB is itself a read of hidden request data, so a restricted preview with no route extras (direct or stale URL) fails closed via the predicate's empty-list branch rather than being looked up; in-app navigation always passes extras, so nothing legitimate is lost. Surfaced in dcadenas's review, twice: first the ungated preview, then the DB lookup that ran before the gate.
5. **Mid-session flip recompute:** a settled inbox list and the unread badge re-filter when the restriction itself flips (approval/revocation via the account-review refresh, dev toggle) — `DmRestrictionGateSync`, always mounted at the app shell, pumps the flip into the inbox gate's `changes` stream. Without it the filters re-ran only on the next DM event.

### What this does NOT do

- No relay/server enforcement (impossible for NIP-17).
- No parent-approved allowlist (#178, later); the `minorContactable` flag + injected-policy shape leaves room for it.
- No change to Tier 1 labels/badges (`ModerationLabelService` stays NIP-05-authoritative per #4948; advisory mismatch logging is separate small work).

## Threat model and accepted risks

- **The name server and the moderation key share one Cloudflare account (confirmed).** So the NIP-05 revocation lever is NOT custody-independent of the moderation nsec — a single CF-account compromise yields both the key and the ability to repoint the name meant to revoke it. This is exactly why Tier 2 pins, and the intersection makes that worst case fail-safe: an attacker who fully controls the CF account can repoint `moderation@` to their own key, but their key is not in `PINNED_OFFICIAL_ACCOUNTS`, so the intersection **drops the real account** (fail closed — a recoverable support-access DoS) and **cannot add the attacker** as minor-contactable. A total CF-account compromise therefore cannot open a channel to a protected minor; it can only temporarily deny support access. Rotating a compromised key to a new legitimate one requires an app release (the new key must join the pin) — accepted friction for a child-contact list, and the reason additions are release-gated by design.
- **Revocation is reachability-bounded:** a revoked entry drops within TTL only for clients that can reach the name server. An attacker holding a compromised pinned key AND network position on a victim can suppress revocation while they hold both. Accepted vs the alternative (fail-closed-on-network cuts every offline minor off from support). Send/receive freshness narrow both point-of-use windows.
- **Storage-clear un-revokes** an entry to the pin-trusted default until the next successful check; chained with offline, transiently trusts a revoked entry. Accepted, noted.
- **Client-side ceiling (self-custody):** for a user holding their own nsec, app-side fail-closed defeats the trivial no-tools bypass (airplane mode) but not a sideloaded/patched client or raw-protocol use — nothing client-side can. It raises the bar from "toggle a switch" to "sideload a modified app." Liz has accepted this ceiling.
- **Custodial ceiling (Keycast-held key) — LOWER than the above; app-side #176 does NOT close it (surfaced 2026-07-07):** Keycast's headless API is open (public CORS) and authenticates with the minor's own Keycast email/password, then signs/encrypts via `/api/nostr` for that account — no nsec, no sideloaded app. A custodial minor (or anyone with their credentials) can have Keycast mint a NIP-17 DM to any recipient, bypassing every app-side gate. For custodial accounts #176 is therefore **friction + defense-in-depth, not containment.** Real custodial DM containment requires Keycast to restrict `verified_minor` signing/encryption server-side (support-trust-safety#183); the export/change-key gate (support-trust-safety#182) removes the raw-key-escape path but not this headless-signer path. This ceiling is distinct from the self-custody one and needs explicit product sign-off.

## Launch checklist (ops artifacts, required before merge)

1. **Revocation runbook — mandate REPOINT-to-burner, not removal.** Removal is an "affirmative absence" and eats the 5-min recheck delay (and an attacker who can force absence-not-key-swap holds trust across rechecks); repoint is immediate. Include who executes it out-of-hours and expected propagation (repoint + TTL).
2. **Monitoring** on the two tier-2 identifiers (resolution changed OR absent) — and specifically the **`divinehq` subdomain origin** as its own dependency, since the support migration makes HQ load-bearing and its well-known is a separate origin from `divine.video`. A dashboard should see a repoint/misconfig before minors feel it.
3. **Change control:** decide whether changes to the child-contactable set (code pins or name-server repoints of these two names) require a two-person rule, per the CSAM-adjacent change-control principles.

## Tests

- **resolver:** matched/differentKey/absent/networkError discrimination; timeout fires network branch; case-normalized compare; concurrency awaits in-flight (never null-as-failure).
- **official-accounts service:** pin-miss rejected; pin+match approved; different-key drops+persists; absence needs the confirming recheck; network failure retains last-known; non-minorContactable pinned entry rejected; TTL respected.
- **protected-state:** fails closed on `unknown`/cold-start when ever-seen-protected; persists across restart; null token → `unknown` not `notProtected`; relax only on positive `not_protected`; re-resolves on mid-session approval.
- **send gate:** covered at the primitive for every publisher incl. reactions/group/file; blocked before enqueue; drain re-checks and refuses a revoked recipient; group requires all approved; typed failure, nothing published.
- **inbound:** protected minor sees only official conversations in inbox + requests; group requires all participants approved; unread badge matches the list; non-minor unaffected; receive-time revalidation pulls a revoked counterparty.
- Use existing bloc/service harnesses; #5721's dev toggle drives manual end-to-end QA.

## Scope

Mobile this branch/PR. Web parity is divine-web#454 (mirror spec on that branch; web additionally guards the thread view, persists last-known to localStorage, and sweeps the personal-support-key migration across all four sites). Mobile's `bug_report_config.supportPubkey` migration rides along only where it touches minor-facing DM affordances; full support-identity cleanup is support-trust-safety#115. Parent-approved allowlist is #178.
