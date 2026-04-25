# Brainstorm: PR #3204 — asymmetric per-identity/primary-slot reader guard

Date: 2026-04-23

Source: review comment by @dcadenas on
https://github.com/divinevideo/divine-mobile/pull/3204#pullrequestreview-4159035376
(comment on `mobile/lib/services/auth_service.dart:2755`).

## Problem Statement

PR #3204 fixes the OAuth local-signing performance bug from #3066 (Phase 1) by
loading a local nsec in `signInWithDivineOAuth` so `_buildIdentity` can attach
a `LocalKeySigner` to the `KeycastNostrIdentity` instead of RPC-routing every
`signEvent` / `nip44Decrypt`. The new reader at `auth_service.dart:2755`,
however, is asymmetric:

- Per-identity branch (2755) trusts whatever
  `_keyStorage.getIdentityKeyContainer(npub)` returns.
- Primary-slot fallback (2758-2760) triple-checks `primary != null &&
  primary.hasPrivateKey && primary.publicKeyHex == publicKeyHex`.
- Final gate (2773) only re-checks `hasPrivateKey`, never pubkey equality with
  the OAuth session's `publicKeyHex`.

The underlying invariant — "a container stored under `npub = N` holds keys for
pubkey `N`" — is enforced nowhere. `storeIdentityKeyContainer`
(`mobile/packages/nostr_key_manager/lib/src/secure_key_storage.dart:598-628`)
does not validate `NostrKeyUtils.encodePubKey(container.publicKeyHex) == npub`.
Under any writer-side bug, partial multi-account migration, or future
regression returning a mismatched container, `_buildIdentity`
(`auth_service.dart:3685`) would build a `KeycastNostrIdentity` with
`pubkey = keyContainer.publicKeyHex` AND attach a
`LocalKeySigner(keyContainer)` over the same mismatched container — signing
for a different account than the UI shows.

The same asymmetry pre-exists in `signInForAccount:1694` — PR #3204 replicates
an existing shape, it does not introduce it.

## Constraints

- PR #3204 is a user-visible perf fix (DM sealing round-trips via RPC today).
  Don't block it on architectural debate.
- Reviewer explicitly says: not a blocker; if a near-term bridge is wanted,
  the right layer is a writer-side invariant in `storeIdentityKeyContainer`.
- Phase 2 of #3066 changes `_setupUserSession(pubkey, container?)` — passes
  pubkey as a typed parameter separate from the optional container. That
  dissolves the reader-side ambiguity entirely. Scope: ~20 files.
- Issue #3270 (atomic session restore — `NostrIdentity` owns its persistence)
  retires the npub-keyed slot entirely. Structural endgame; design unsettled.
- `SecureKeyContainer` auto-derives `_npub` from `publicKeyHex` in its
  factories (secure_key_container.dart:52, 80), so the container is internally
  self-consistent. The gap is only "what key is it filed under."
- `nostr_key_manager` is a shared package with its own CI/test suite — any
  change must include package-level tests.

## Prior Art

- **#3066** — parent issue; diagnoses `SecureKeyContainer.fromPublicKey` as
  the type-system failure producing the bug class. Phase 1 = PR #3204.
  Phase 2 = remove `fromPublicKey` + `hasPrivateKey`, change
  `_setupUserSession` signature (~20 files).
- **#3270** — atomic session restore via descriptor; no more five-way
  coordination; no npub-keyed slot to mismatch.
- **PR #2833 (#2355)** — non-null `NostrIdentity` sealed class; enables
  local-signing optimization that PR #3204 unblocks on the OAuth path.
- **PR #2997** — cleanup round for #2833; fixed NostrService identity desync
  regressions and OAuth account-recovery storage gaps.
- **`signInForAccount:1694`** — pre-existing asymmetric reader that mirrors
  the PR #3204 pattern.
- `storeIdentityKeyContainer` callers (6 total):
  - `auth_service.dart:390`, `auth_service.dart:3869`
  - `secure_key_storage.dart:270`, `secure_key_storage.dart:381`,
    `secure_key_storage.dart:659`

## Approaches Explored

### Approach A: Ship as-is, rely on Phase 2 of #3066

**Description:** Merge PR #3204 unchanged. Prioritize Phase 2 as the next work
item on #3066. Phase 2 eliminates the "container's pubkey might not match the
session pubkey" question structurally because the caller must pass the session
pubkey to `_buildIdentity` as a typed parameter.

**Layers affected:** None now; Phase 2 touches `auth_service.dart` + ~20
callers.

**Pros:**
- Matches reviewer's explicit "not a blocker" position.
- Zero scope creep on a perf-fix PR.
- No transient work — Phase 2 is already scoped.

**Cons:**
- Asymmetry lives on `main` until Phase 2 lands.
- `signInForAccount:1694` remains asymmetric regardless (pre-existing).
- Risk window depends on Phase 2 scheduling discipline.

**Risks / Unknowns:** All current writers appear disciplined; exploitation
requires a future regression, caller mistake, or partial migration. If Phase 2
slips for weeks, the window widens.

**Complexity:** Low (zero).

---

### Approach B: Defensive re-check in Phase-1 readers

**Description:** Add explicit pubkey verification after the per-identity
lookup in both `signInWithDivineOAuth:2755` and `signInForAccount:1694` —
reject `localKey` when `localKey.publicKeyHex != publicKeyHex`. Tighten the
final gate at 2773 to re-check pubkey equality.

**Layers affected:** `mobile/lib/services/auth_service.dart` only.

**Pros:**
- Symmetric guards across both reader paths.
- Small, localized diff. Easy to review and test.

**Cons:**
- **Hardens code Phase 2 is about to delete.** Explicitly flagged in the
  review as a downside.
- Doesn't protect future readers added elsewhere.
- Doesn't fix the class of bug — only two readers.

**Risks / Unknowns:** Pure transient work.

**Complexity:** Low.

---

### Approach C: Writer-side invariant in `storeIdentityKeyContainer` ⭐

**Description:** In `secure_key_storage.dart:598`, assert that
`NostrKeyUtils.encodePubKey(keyContainer.publicKeyHex) == npub` before
storing. Throw `SecureKeyStorageException` with a new `code:
'npub_pubkey_mismatch'` on violation. Add package-level tests covering
(a) correct file accepted, (b) mismatched container rejected, (c) existing
callers still pass.

**Layers affected:** `nostr_key_manager` package only. No changes to
`auth_service.dart`.

**Pros:**
- Fixes the **class of bug** for every current and future reader — the
  reviewer's recommended layer.
- Single enforcement point; package-level invariant.
- **Survives Phase 2.** Phase 2 refactors the reader side; the writer
  invariant is orthogonal and remains useful until #3270 retires the slot.
- Makes the storage API self-describing: contract becomes "container must
  match npub," not caller-discipline-only.
- Also "fixes" `signInForAccount:1694` for free by eliminating the risk it
  guards against.

**Cons:**
- Does not retroactively detect stale/bad data already on device (no known
  such data exists).
- Audit required on the 4 internal callers inside `secure_key_storage.dart`
  (lines 270, 381, 659) to confirm they pass consistent `npub`/container
  pairs. Expected clean; worth verifying.

**Risks / Unknowns:** Test fixtures that pre-seed storage with synthetic
containers could trip the invariant if any cross npub/pubkey boundaries.
Expected none; run package test suite under the new invariant.

**Complexity:** Low-Medium.

---

### Approach D: Writer invariant + reader tightening + tests

**Description:** Combine C + B. Writer blocks future bad writes; reader
re-checks catch any stale data already on device from hypothetical past bugs.

**Layers affected:** `nostr_key_manager` package + `auth_service.dart`.

**Pros:** Defense in depth.

**Cons:** Reader tightening deleted by Phase 2. Pays for a risk without
evidence (no known bad data on device).

**Complexity:** Medium.

---

### Approach E: Accelerate Phase 2 of #3066 instead of PR #3204

**Description:** Don't ship PR #3204 as Phase 1. Land Phase 2 directly — new
`_setupUserSession(pubkey, container?)` signature, remove
`SecureKeyContainer.fromPublicKey`, remove `hasPrivateKey`.

**Layers affected:** `auth_service.dart` + ~20 callers.

**Pros:** Most principled fix. No transient work.

**Cons:**
- Rolls the perf fix into a ~20-file refactor — violates the "ship perf fix
  alone" rationale in PR #3204's own description.
- Larger review surface delays users seeing fast DM signing.
- Expanding scope while review feedback on #3204 is still open compounds risk.

**Complexity:** High.

---

### Approach F: Accelerate #3270 (atomic session restore)

**Description:** Skip bridges. Do the structural endgame: each `NostrIdentity`
variant owns serialize/deserialize; retire the npub-keyed slot.

**Pros:** Removes the shape that produces the bug class.

**Cons:** Issue explicitly states the final shape needs design. Migration,
versioning, multi-account indexing all unresolved. Blocks perf fix for
weeks/months.

**Complexity:** Very High.

## Recommendation

**Ship PR #3204 as-is (Approach A). Follow immediately with Approach C as a
standalone ~30-line PR in `nostr_key_manager`.**

Rationale:

1. PR #3204 is a perf fix, not a security fix. Reviewer explicitly says
   non-blocking. Dragging extra changes in risks spiraling a clean perf PR
   into architectural debate.
2. Approach C is the right layer per the reviewer. Writer-side invariant
   fixes the class of bug for every reader. It's the only bridge whose value
   **survives Phase 2** — reader-side hardening (B) gets deleted; writer-side
   invariant persists until #3270 retires the slot.
3. Approach B is strictly worse than C — smaller target of protection,
   identical transience risk, and the reviewer flags it as "hardening code
   Phase 2 is about to delete."
4. Approaches E and F over-engineer the moment. PR #3204 is already in
   review; expanding scope costs more than it saves.
5. `signInForAccount:1694`'s pre-existing asymmetry is also covered by
   Approach C for free.

Recommended sequencing:

| Order | Action | Scope |
|-------|--------|-------|
| 1 | Merge PR #3204 unchanged | ship perf fix |
| 2 | Follow-up PR: writer invariant in `storeIdentityKeyContainer` | package-only, ~30 LoC + tests |
| 3 | Phase 2 of #3066 on usual schedule | ~20 files; removes `fromPublicKey` / `hasPrivateKey` |
| 4 | #3270 when design is settled | structural endgame |

## Open Questions for /plan (Approach C follow-up)

- [ ] Audit the 4 internal callers inside `secure_key_storage.dart`
      (lines 270, 381, 659) — confirm all pass consistent `npub`/container
      pairs.
- [ ] Exception class: reuse `SecureKeyStorageException` with a new
      `code: 'npub_pubkey_mismatch'` (consistent with existing patterns) or
      introduce a dedicated type?
- [ ] Should the check be a `kDebugMode` assert or always-on? Always-on is
      correct — this is a data-integrity invariant, not a dev aid.
- [ ] Any package test fixtures that pre-seed storage with synthetic
      containers crossing npub/pubkey boundaries? Expected none; run suite
      under the new invariant before shipping.
- [ ] Log level for rejections — `severe` so it surfaces in crash reporting,
      or `warning` to avoid spamming logs under a partial-migration recovery
      flow that might legitimately retry?

## Prerequisites

None. Phase 2 of #3066 can proceed in parallel once PR #3204 merges.

## Next Step

1. Merge PR #3204.
2. File a new issue titled *"enforce npub↔publicKeyHex invariant in
   `storeIdentityKeyContainer`"* referencing PR #3204's review and #3270.
3. `/plan <new-issue>` to produce the implementation spec for Approach C.
