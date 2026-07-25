# Multi-account switching — architecture report and implementation plan

**Date:** 2026-07-24
**Status:** Draft for review
**Repo:** `divinevideo/divine-mobile`
**Author:** Claude (research + design), commissioned by Rabble
**Reviewer note:** this document is written to be adversarially reviewed. Every
claim about the current codebase carries a `file:line` citation so it can be
checked. Claims that are *not* verified are explicitly marked
**[UNVERIFIED]**. Please attack the unverified ones first.

---

## 1. Executive summary

Divine has a multi-account implementation today. It is feature-flagged off
(`FF_ACCOUNT_SWITCHING`), and when enabled it is slow, lands the user on a login
screen, and has produced real data-loss reports (epic #4623).

The root cause is not missing features. It is one structural decision:

> **`AuthService` is a mutable singleton whose identity changes underneath the
> 113 objects that hold it.**

Switching accounts is currently implemented as *sign out, then sign back in as
someone else* (`settings_account_cubit.dart:49`). Every teardown/rebuild race in
the app therefore becomes an account-switching bug, and destructive sign-out
cleanup runs on a path the user experiences as "switch", not "delete".

**Recommendation:** make the account boundary the Riverpod `ProviderContainer`.
An account switch builds a new container seeded with an immutable
`AccountSession`, swaps it into the existing `UncontrolledProviderScope`, and
disposes the old one. Identity becomes un-mutatable by construction; stale
cross-account state becomes unwritable rather than merely discouraged.

Critically, this design **deletes** more machinery than it adds. Several
subsystems currently maintain elaborate "react to the identity changing"
apparatus that exists only because identity *can* change
(`nostr_client_provider.dart:200-291`). Under this design that apparatus is
unnecessary.

**Estimated shape:** ~5 phases, each independently shippable and independently
revertable. Phase 1 and 2 have value even if the rest is abandoned.

---

## 2. What users report

From issue #4623 (epic, OPEN) and its three now-closed children:

- A user on iPhone 1.0.14+723 was publishing a clip. The app logged them out
  mid-publish, re-authenticated them into a **different account**, and their
  drafts and clips library appeared empty.
- Forensics in the epic: publish succeeded at 08:02:17 under pubkey
  `c4a39f1291291d452405cd8ddd798c4a29a3858c52cd0d843f1f6852cf17682e`; session
  recovery entered at 08:02:09; re-auth completed under
  `fc7031a810ce4b02b6195a7e477cfe3d08c0386038bd45b4431f82d9b3f5ffb0`;
  `_setupUserSession` then detected an identity change and ran **destructive
  cleanup for the old pubkey**.

Related closed issues showing the same bug class — state that should have died
with the old account but did not:

| Issue | Symptom |
|---|---|
| #4969 | block/mute sets persist across account switch (keepAlive repo never invalidated) |
| #5472 | DM unread-count cubit goes stale on account switch (no repository sync) |
| #5058 | stale background RPC refresh survives sign-out / account switch |
| #6174 | `VideoEventService` never disposed on `NostrService` client swap — orphaned timers leak |

Note the shape: four separate issues, four separate fixes, one underlying cause.
That is the signature of a missing structural boundary, not of four bugs.

---

## 3. Current architecture, as built

### 3.1 What exists and works

| Component | Location | Assessment |
|---|---|---|
| Known-accounts registry | `lib/services/auth/known_accounts_registry.dart` | **Good.** Stateless, reads `SharedPreferences` fresh, handles one-time legacy migration, sorts by `lastUsedAt`. Keep as-is. |
| `NostrIdentity` | `lib/services/auth/nostr_identity.dart:16` | **Good.** Already a `sealed class` implementing `NostrSigner`, with four subtypes (local, Keycast, bunker, Amber). An account is already representable as a value object. |
| Push session lifecycle | `lib/services/push_notification_session_coordinator.dart` | **Good.** Already pubkey-bound with explicit register/deregister. Works under the proposed design unchanged. |
| Owner-scoped upload queue | `packages/db_client/.../pending_uploads_dao.dart:107` | **Good.** Filters via `_ownedBy(t.nostrPubkey, ownerPubkey)`. |

### 3.2 What is broken

**(a) Switch is implemented as sign-out + sign-in.**

```dart
// lib/blocs/settings_account/settings_account_cubit.dart:49
Future<void> switchToAccount(String pubkeyHex) async {
  if (pubkeyHex == state.currentPubkey) return;
  _authService.pendingAccountSwitchPubkey = pubkeyHex;
  await _authService.signOut();
}
```

The user is signed out, routed to the welcome screen, and `WelcomeBloc`
pre-selects the target for re-authentication. Consequences:

- Full session teardown: relay disconnection, NIP-65 re-discovery, relay
  discovery cache clear (`auth_service.dart` signOut body), `configured_relays`
  removed, `current_user_pubkey_hex` removed.
- `clearUserSpecificData()` runs on the switch path
  (`auth_service.dart:3003`).
- There is a window during which the user is signed into **neither** account. If
  the process dies or the restore fails there, state is indeterminate. This is
  the #4623 failure mode.

**(b) Credentials are stored in mutable global slots and copied on every switch.**

`lib/services/auth/signer_secure_store.dart` keeps *one* active slot per
credential type — `bunker_info`, `amber_pubkey`, `amber_package`,
`keycast_session` — plus per-pubkey archived copies at `<key>_<pubkeyHex>`.
Switching calls `archive(leavingPubkey)` (`:192`) then
`restoreActiveKeys(arrivingPubkey, source)` (`:268`).

This is a **two-phase, non-atomic copy of secrets**. An interruption between the
phases can leave the active slot holding one account's credential while the
registry believes another is active. The code already documents a live instance
of this class of bug:

```dart
// signer_secure_store.dart:~225
// Archive OAuth session — only if it has a bound userPubkey
// matching this account. Null userPubkey means the session was
// created before pubkey binding (legacy) and cannot be verified
// as belonging to any specific account; archiving an unverifiable
// session risks cross-contamination (Bug 2).
```

Legacy sessions with `userPubkey == null` therefore **cannot be archived at
all** — a whole cohort of users whose credentials silently do not survive a
switch.

The same mutation pattern exists one layer down for local keys:
`packages/nostr_key_manager/lib/src/secure_key_storage.dart:697`
(`switchToIdentity`).

**(c) Identity is a mutable global, read in 130 places.**

`currentPublicKeyHex` is read at **130 call sites across 81 files**. But the
distribution matters, and it is better news than the raw number suggests:

```
 64  authService.currentPublicKeyHex          ← injected dependency
 21  _authService.currentPublicKeyHex         ← injected dependency (field)
 18  ref.watch(authServiceProvider).currentPublicKeyHex
  9  ref.read(authServiceProvider).currentPublicKeyHex   ← captures, never updates
  1  service.currentPublicKeyHex
```

**113 of 130 reads go through an injected dependency.** Those call sites are
*correct design* — an object declaring "I need to know who is signed in" as a
constructor dependency is right. The defect is that the dependency mutates
underneath them without their consent. You cannot audit 113 holders for a
mutation they never opted into.

The 9 `ref.read` sites are the genuinely defective ones: they capture a value
once and never observe a change.

**(d) Viewer-scoped preferences are unprefixed, so they are deleted rather than
switched.**

`UserDataCleanupService.userSpecificKeys` lists these keys with **no pubkey
prefix** — meaning there is nowhere per-account to put them, so switching
*deletes* them:

```
curated_lists, subscribed_list_ids, user_lists,
bookmark_sets, global_bookmarks, bookmark_published_hashes,
bookmark_pending_changes, muted_items, content_moderation_local_mutes,
content_moderation_subscribed_lists, content_reports_history,
content_deletions_history, seen_video_ids, seen_video_metrics,
subscribed_labelers, label_cache, trusted_reporters, report_cache,
age_verified_16_plus, terms_accepted_at, vine_drafts
```

A user switching A→B→A loses their bookmarks, mutes, and seen-video state for A.
This is a direct, reproducible data-loss path, independent of #4623.

(Four keys *are* correctly per-pubkey already: `following_list_`,
`relay_discovery_`, `dm.newestSyncedAt.`, `dm.oldestSyncedAt.`)

**(e) One database table is viewer-scoped but not owner-scoped.**

Audit of every table in `packages/db_client/lib/src/database/tables.dart`:

*Correctly unscoped (public content caches, shared across accounts by design):*
`NostrEvents`, `UserProfiles`, `VideoMetrics`, `ProfileStats`, `HashtagStats`,
`IdentityEvents`, `IdentityVerifications`. The last two are explicitly
documented as "viewer-independent public data… survive logout"
(`tables.dart:1489` doc comment). Correct.

*Correctly owner-scoped:* `Drafts`, `Clips`, `DirectMessages`,
`DmMessageReactions`, `Conversations`, `OutgoingDms`, `PendingGiftWraps`,
`ProcessedGiftWraps`, `PersonalReactions`, `PersonalReposts`, `PendingActions`,
`PendingProfileSaves`, `PendingViewEvents`, `PendingUploads` (via `nostrPubkey`).

*Incorrectly unscoped:*

- **`Notifications` (`tables.dart:228`)** — has `fromPubkey`, `targetPubkey`,
  but **no owner column**. Both accounts' notifications live in one bucket with
  `primaryKey => {id}`. This is a cross-account data leak in the current build.
- **`PendingProductEvents` (`tables.dart:1360`)** — analytics queue with no
  owner attribution. Events queued as A may be published as B. Severity depends
  on whether the publish path stamps identity at enqueue or at flush.
  **[UNVERIFIED — needs checking.]**

**(f) The feature flag is only half-enforced.**

`docs/superpowers/specs/2026-04-14-account-switching-feature-flag-design.md`
specified two gates: a UI gate in `SettingsScreen` **and** a logic gate in
`SettingsAccountCubit`, with this stated rationale:

> "If only the UI is gated, future callers could still trigger switching. The
> cubit guard closes that gap."

Only the UI gate shipped. Verified against clean `origin/main` @ `03c44c8cb`:

```bash
grep -n "FeatureFlag\|accountSwitching" mobile/lib/blocs/settings_account/settings_account_cubit.dart
# → no matches
```

`SettingsAccountCubit.switchToAccount` and `.addNewAccount` will sign the user
out regardless of the flag state. Any caller reaching the cubit directly —
another screen, a deep link, a future refactor — bypasses the gate entirely.
Low exploitability today (the only UI path is gated), but it means the flag does
not actually contain the buggy behaviour it was created to contain.

**(g) Dead code presenting a second, contradictory model.**

`lib/services/identity_manager_service.dart` (8.9K) implements `SavedIdentity` +
`IdentityManagerService.switchToIdentity`. It has **zero call sites** outside
itself. Its core method cannot function and says so:

```dart
// identity_manager_service.dart:~186
// Find the private key for this npub
// Note: This requires that we've previously saved the nsec securely
// For now, this is a limitation - we can only switch to identities
// that were imported during this app's lifetime
```

Two competing models of the same concept, one non-functional, is an active
source of confusion for anyone (human or agent) reading the codebase.

---

## 4. Root cause

All of §3.2 reduces to one sentence:

> **The account is ambient global state rather than a scope.**

Because it is ambient, every consumer must independently remember to react to it
changing. The codebase has responded by building per-subsystem reactive
apparatus — `nostr_client_provider.dart` alone maintains `_authSubscription`
listening to `authStateStream` (`:241`), a `_trackedClients` list,
`_invalidateClientGeneration()`, `_initializationRetryTimer`, and callback
re-registration, all in service of surviving an identity change. Each such
apparatus is a place to get it wrong, and #4969/#5472/#5058/#6174 are four
recorded instances of getting it wrong.

The fix is to make the account a scope, so that within that scope it cannot
change.

---

## 5. Requirements (decided)

Decisions taken with Rabble during design, 2026-07-24:

| # | Decision | Rationale |
|---|---|---|
| R1 | **Inactive accounts go fully dormant.** No background relay connections, DM sync, or notification subscriptions for non-active accounts. | X/Twitter model. Lowest battery/memory. Also means teardown-on-switch is *desired behavior*, not a hazard. |
| R2 | **All four auth sources switchable in v1**: local nsec, NIP-46 bunker, NIP-55 Amber, Divine/Keycast OAuth. | No second-class accounts. Implies switch-in can fail on network, so a failure UX is mandatory. |
| R3 | **Three entry points, one surface**: (a) tap/long-press own avatar, (b) Settings row, (d) profile-header name + chevron. | Discoverability was half the complaint ("not at all clear"). One shared component, three triggers. |
| R4 | **Atomic switch with rollback.** Prove the target signer live *before* committing. On failure, stay on the current account, untouched, with a retry affordance. | Directly eliminates the #4623 "signed into neither account" window. Costs a spinner for non-local sources. |
| R5 | **In-flight work survives the switch.** Uploads keep running under their originating account; unsaved recordings park as owner-scoped local rows and reappear on switch-back. Nothing is cancelled. | The "no data loss" requirement. Implies uploads carry an explicit owner pubkey rather than reading "current user" at completion. |

Not decided, needs input — see §12.

---

## 6. Prior art

### 6.0 Prior in-repo design work

`docs/superpowers/specs/2026-04-14-account-switching-feature-flag-design.md`
is the direct predecessor to this document. Its summary opens:

> "Account switching exists today but is still buggy and too advanced for
> general users. We will reuse the existing local feature-flag system to disable
> the account-switching entry point by default while keeping the implementation
> available for internal testing."

That work was a **containment measure, not a fix**. Its explicit non-goals were
"Rework multi-account flows outside Settings" and "Remove the underlying
account-switching implementation". This document is the follow-up it deferred,
and it should supersede that one once implemented. See §3.2f for a gate that
design specified but which never shipped.

Also relevant:
`docs/superpowers/specs/2026-07-10-foreground-resume-account-state-refetch-design.md`
(account-state refetch on foreground resume) — should be checked for
interaction with container swap during Phase 4. **[UNVERIFIED — not yet read.]**

### 6.1 Verified in-repo

The single most useful precedent is already in this codebase:
`mobile/lib/main.dart:1418` constructs a `ProviderContainer` explicitly and
`:1467` mounts it via `UncontrolledProviderScope`. Divine is *already* running
an externally-owned container. Swapping that container is a small delta on
existing plumbing, not a new architectural concept.

### 6.2 General industry patterns

**[PARTIALLY UNVERIFIED — these are architectural patterns from general
knowledge, not from reading these apps' source. Treat the *pattern* as sound and
the *attribution* as approximate.]**

- **Instagram / X (Twitter)** — account switching keeps only the active session
  live; switching tears down and rebuilds the session graph. Inactive accounts
  are dormant except for push. This matches R1.
- **Slack** — keeps all workspaces live simultaneously with per-workspace
  connections. Rejected here: contradicts R1, and N relay connection sets plus N
  gift-wrap decrypt loops is a serious battery cost on a video app.
- **Gmail (Android)** — accounts are a first-class scope; nearly every data
  access takes an account parameter. Closest to "Approach 1" in §7.

The general principle across all of them is the same one this document argues
for: **the account is a parameter or a scope, never an ambient global.**

### 6.3 Nostr-specific considerations

Nostr makes some of this *easier* than a typical SaaS app and some harder.

Easier: content is public and content-addressed, so the large caches
(`NostrEvents`, `UserProfiles`, `VideoMetrics`) are legitimately shareable
across accounts. No need to partition the bulk of the database. This is already
correct in the schema.

Harder: signing is pluggable and remote for three of the four sources. A
"session" is not a bearer token but a live capability that can fail
independently (bunker relay down, Amber uninstalled, Keycast refresh expired).
This is why R4 (prove-then-commit) is load-bearing rather than pedantic.

---

## 7. Options considered

### Option 1 — Per-account scoped providers (`.family(pubkey)`)

Make every viewer-scoped provider take the account pubkey as a family parameter.
`AccountSession` objects held in a registry; `currentPublicKeyHex` deprecated in
favor of explicit parameters everywhere.

- **Pro:** purest. Multi-account becomes a type-level property. Would permit
  R1 to be revisited later (background accounts) without re-architecting.
- **Con:** touches every consumer. All 97 `keepAlive: true` declarations across
  31 files need individual audit. **Any provider missed is a silent
  cross-account leak** — precisely the failure mode of the previous attempt.
  There is no single moment at which to assert correctness.
- **Verdict:** correct in the abstract, highest risk in practice, worst
  reviewability.

### Option 2 — Process restart on switch

Persist "next account", hard-relaunch the Flutter app tree.

- **Pro:** trivially correct, nothing stale can survive, smallest diff.
- **Con:** 1–3s relaunch with a splash screen. Kills in-flight uploads unless
  the uploader is a true OS-level background service. **Violates R5.**
- **Verdict:** rejected on R5, but worth keeping as the emergency fallback if
  Option 3 proves unworkable in Phase 3.

### Option 3 — Container swap ← **recommended**

Dispose the current `ProviderContainer`; construct a fresh one seeded with the
new account's immutable `AccountSession`; swap it into the existing
`UncontrolledProviderScope`. Device-scoped services are hoisted outside the
container and survive.

- **Pro:** same zero-stale-state guarantee as Option 2 with no relaunch. Natives
  stay warm. Uploads survive (R5 satisfied). Rollback is natural (R4).
- **Pro:** **zero call-site churn.** All 113 injected `authService` reads are
  reconstructed pointing at the new account. The "81 files" number evaporates.
- **Pro:** replaces N per-subsystem "react to identity change" mechanisms with
  one "identity never changes; the container does". Net deletion of code.
- **Pro:** correctness becomes *testable at one seam* (§10.1) rather than
  distributed across 97 providers.
- **Con:** requires an explicit device-scoped/account-scoped split. Mitigated by
  making it a declared object (§8.3) rather than a convention, and by the fact
  that the failure mode of forgetting to hoist is *conservative* (the thing
  restarts — slower, not wrong).
- **Con:** anything holding a `Ref` from the disposed container leaks. See §9.1
  for the measured extent of this risk — it is smaller than it sounds, and it
  already exists today unmitigated.

---

## 8. Recommended design

### 8.1 The account model

```dart
/// Immutable. One per signed-in account. Identity never mutates.
class AccountSession {
  const AccountSession({
    required this.pubkeyHex,
    required this.identity,
    required this.source,
    required this.relays,
  });

  final String pubkeyHex;
  final NostrIdentity identity;       // already exists, already sealed
  final AuthenticationSource source;
  final List<String> relays;
}

/// Device-scoped. Outlives every switch. Constructed once in main().
class AccountStore {
  Future<List<KnownAccount>> known();                 // -> KnownAccountsRegistry
  Future<AccountSession> activate(String pubkeyHex);  // may throw — see §8.2
  Future<void> forget(String pubkeyHex);
}

/// Seeded into each container by override. Read-only.
final activeAccountProvider = Provider<AccountScope>(
  (_) => throw UnimplementedError('overridden at container construction'),
);

/// A container is EITHER signed out or bound to exactly one account.
/// There is no "signing in" or "not ready yet" state — see §8.1.1.
sealed class AccountScope {}

class SignedOut extends AccountScope {}

class SignedIn extends AccountScope {
  SignedIn(this.session);
  final AccountSession session;
}
```

The load-bearing property: **`AccountScope` is immutable and supplied by
override**. A provider cannot observe its account changing, because within one
container it never does. Cross-account staleness stops being a bug you can write.

### 8.1.1 Signed-out is a scope, not a null

An earlier draft of this document modelled the active account as a non-nullable
`AccountSession`, which is wrong: signed-out is a real, reachable state
(first launch, onboarding, welcome screen, sign-out-to-nobody).

Modelling it as `AccountSession?` would reintroduce exactly the defect this
design exists to remove — every consumer independently handling "no account
yet", which is the shape of the #3503 cold-start race (a repository materialised
before `AuthService.initialize()` resolved, wrapping a `LocalKeySigner(null)`
placeholder, so every `sendLike` threw
`StateError("No public key available …")`).

Instead, **signed-out is its own container**. The app runs a `SignedOut`
container showing welcome/onboarding; signing in builds a `SignedIn` container
by the same mechanism as a switch (§8.2); signing out builds a `SignedOut` one.
Consequences:

- There is no "signing in" or "not ready" intermediate scope. A container is
  built only once its account is proven (§8.2 step 1), so a `SignedIn` container
  never contains a half-initialised signer. The #3503 race becomes
  unrepresentable rather than guarded against.
- Providers that are meaningless when signed out (relay subscriptions, DM sync,
  notification subscription) simply are not constructed in a `SignedOut`
  container. They do not need null checks.
- Sign-in, sign-out, and account-switch are **one code path** with three
  parameterisations, not three flows that can drift apart. Today they are
  separate, which is why switch inherited sign-out's destructive cleanup
  (§3.2a).
- `currentPublicKeyHex`'s deprecated forwarder returns `null` for `SignedOut`,
  preserving today's call-site semantics exactly.

`AuthService` keeps its ~152KB of sign-in flows (OAuth, bunker handshake, key
generation, session recovery) and becomes what its name says — the machinery
that *establishes* sessions. It stops being the identity holder.
`currentPublicKeyHex` becomes a deprecated forwarder reading
`activeAccountProvider`, so **none of the 113 injected call sites change**.

### 8.2 Switch mechanics

```
User taps account B
  │
  ├─ 1. AccountStore.activate(B)         ← old container UNTOUCHED, fully live
  │       read B's credentials (per-account addressed; no mutation, no copy)
  │       build NostrIdentity for B
  │       prove the signer is live:
  │         local nsec → in-process, instant
  │         Keycast    → refresh token
  │         bunker     → connect + get_public_key
  │         Amber      → NIP-55 round-trip
  │       ── on failure ─→ return failure. A untouched. Toast + retry. DONE.
  │
  ├─ 2. Build new ProviderContainer
  │       overrides: activeAccountProvider = AccountSession(B)
  │                  + DeviceScope overrides (same instances)
  │
  ├─ 3. Swap into UncontrolledProviderScope    ← THE ATOMIC COMMIT (sync)
  │
  ├─ 4. oldContainer.dispose()
  │       every subscription, timer, relay connection for A stops (R1)
  │       DeviceScope survives → uploads keep running (R5)
  │
  └─ 5. Router resets to Home as B
```

Step 1 is the entire rollback story (R4): nothing observable happens until B is
proven good. Step 3 is a single synchronous assignment — **there is no
interruptible window in which the user is signed into neither account.** That
window is the current design's core defect.

**Timing.** Local nsec is instant (no network). Keycast/bunker/Amber are bounded
by step 1's round-trip, so the switcher shows a spinner **on the row being
switched to** while the current account stays fully interactive behind it.
Timeout proposed at 10s, then fail and stay put.

### 8.3 `DeviceScope` — the hoisted set, declared not conventional

```dart
class DeviceScope {
  final AppDatabase db;               // all accounts' rows, one connection
  final SecureStorage secureStorage;
  final BackgroundUploader uploader;  // R5 — carries owner pubkey per job
  final VideoPlayerPool playerPool;
  final MediaCache mediaCache;
  final CrashReportingService crash;
}
```

Passed as overrides into every container. A service is device-scoped **because
it is in this list**, not because someone remembered to hoist it. Anything not
listed is account-scoped by default — the safe default, since the failure mode
is "restarts unnecessarily" rather than "leaks across accounts".

Existing static singletons audited (`lib/services/*`): `VideoFormatPreference`,
`StartupPerformanceService`, `CrashReportingService`, `BandwidthTrackerService`,
`BackgroundActivityManager` are device-scoped and belong here or already behave
correctly. `Nip07Service` and `WebAuthService` are web-only. **`NotificationService`
(`notification_service.dart:95`) is account-scoped and needs explicit
re-binding** — the one genuine item on the audit list.

### 8.4 Credential storage — write-once, addressed per account

Delete the archive/restore mutation (`signer_secure_store.dart:192-380`,
`secure_key_storage.dart:697`). Replace with addressed keys written once at
sign-in and never copied:

```
signer/<pubkeyHex>/bunker
signer/<pubkeyHex>/amber_pubkey
signer/<pubkeyHex>/amber_package
signer/<pubkeyHex>/keycast_session
key/<pubkeyHex>/container
```

A switch becomes a **read**, not a read-modify-write of shared secret slots.
There is no interruptible window and no "active slot" to corrupt. This is where
the "no data loss" guarantee actually comes from — §8.2's atomicity depends on
it.

Migration: on first launch after upgrade, for each known account, copy from the
legacy layout (`<key>_<pubkey>` archives plus the global active slot) into
addressed keys, then verify before removing the legacy keys. The legacy
`userPubkey == null` OAuth cohort (§3.2b) needs an explicit decision — see §12.

### 8.5 Data-layer corrections

1. Add `owner_pubkey` to `Notifications` (`tables.dart:228`), backfill with the
   current account, add to the primary key or a unique index, filter all reads.
2. Decide and fix `PendingProductEvents` owner attribution **[pending
   verification]**.
3. Prefix the 21 unprefixed viewer-scoped `SharedPreferences` keys (§3.2d) with
   the account pubkey. Migrate existing values to the current account's prefix.
   Once prefixed, **delete-on-switch goes away entirely** — the keys simply
   aren't read by the other account.
4. Split `UserDataCleanupService` so that "switch away" (preserve everything)
   and "delete this account from this device" (destroy owner-scoped rows) are
   different code paths that cannot be confused. This is the direct fix for
   #4623's destructive-cleanup-on-switch.
5. Delete `lib/services/identity_manager_service.dart`.
6. Add the cubit-level feature-flag guard that §3.2f shows was specified but
   never shipped — or drop the flag entirely once Phase 5 ships.

### 8.6 Relationship to the Riverpod → BLoC migration

This design is built on `ProviderContainer`, a Riverpod construct, while the
repo is migrating UI state from Riverpod to BLoC
(`docs/BLOC_UI_MIGRATION_PRD.md`). That looks like a contradiction. It is not,
and the design in fact *retires* a chunk of migration debt.

**It operates in the layer Riverpod is sanctioned to keep.** The PRD's ownership
boundary is explicit:

> Riverpod **owns**: App-level dependency injection (repositories, services,
> clients); Long-lived infrastructure side-effects (relay sync, blocklist sync,
> push token sync); DI bridges: `ConsumerWidget` pages that read Riverpod deps
> and hand them into `BlocProvider`.
>
> BLoC/Cubit **owns**: All feature UI state; all UI side effects; all
> loading/error/success state managed by a screen or feature.

All 97 `keepAlive: true` declarations are DI and long-lived services. None are
feature UI state. The container swap never touches BLoC's half of the boundary,
and the 67 `ConsumerWidget` → `BlocProvider` bridges continue to work unchanged.
The PRD also states Riverpod "is not being removed everywhere immediately" and
remains "where non-UI/service-level usage is still stable" — which is precisely
this layer.

**It shrinks the migration's worst workaround.** `.claude/rules/state_management.md`
devotes ~200 lines to "Bridging Riverpod-provided dependencies into
BlocProvider" — the record-typed `ValueKey` guard. Its stated trigger:

> When a `BlocProvider.create:` consumes a Riverpod dependency whose identity
> can change at runtime (**auth flip, account switch, sign-out**, explicit
> `ref.invalidate`)

Nine such guards exist today:

```
lib/screens/profile_screen_router.dart:132
lib/screens/settings/nip05_settings_screen.dart:40
lib/screens/inbox/conversation/conversation_page.dart:91, 99
lib/screens/profile_setup/view/profile_setup_screen.dart:55
lib/notifications/view/inbox_notifications_page.dart:49
lib/notifications/view/notifications_page.dart:61
lib/widgets/video_feed_item/video_interactions_bloc_key.dart:5 (+ feed_videos.dart:854)
```

Under this design, auth flip / account switch / sign-out **are** container
swaps, which dispose every `BlocProvider` in the tree. The guard is unnecessary
for those three triggers. Two of the sites are especially telling — they put the
account pubkey directly into the key tuple:

```dart
// conversation_page.dart:91,99
key: ValueKey((dmRepository, currentPubkey)),
key: ValueKey((reactionsRepository, currentPubkey, 'reactions')),
```

That is an account boundary hand-rolled at the widget level, nine times over,
because the app has no real one. This design supplies it once.

**Honest limit:** the guard is still required for `ref.invalidate` calls *not*
tied to an account change. The rule shrinks; it does not disappear. Any decision
to weaken it should be a separate, evidenced change — not a side effect of this
work.

**If Riverpod is eventually removed entirely**, the account boundary does not
have to move with it. `AccountScope` is a plain sealed class and `DeviceScope` a
plain object; only the *delivery mechanism* (container override) is
Riverpod-specific. Replacing it with an `InheritedWidget` keyed on account, or
whatever the endgame DI is, is a mechanical change confined to one seam. That is
a deliberate property of putting the boundary in a value object rather than in
Riverpod semantics.

---

## 9. Risk analysis

### 9.1 "Something holds a stale `Ref` across the swap" — measured

This was the stated top concern, so it was measured rather than argued.

Across the 31 files declaring `keepAlive: true`, 12 create disposable resources
(timers, subscriptions, stream controllers). Heuristic grep of resource-creation
count vs `onDispose` count:

```
social_providers.dart        resources=4   onDispose=12
social/video_providers.dart  resources=1   onDispose=10
relay_providers.dart         resources=7   onDispose=8
auth_providers.dart          resources=3   onDispose=8
repository_providers.dart    resources=1   onDispose=6
moderation_providers.dart    resources=1   onDispose=5
notifications_providers.dart resources=2   onDispose=4
nip05_verification.dart      resources=1   onDispose=3
popular_videos_feed.dart     resources=1   onDispose=1
video_events_providers.dart  resources=1   onDispose=1
nostr_client_provider.dart   resources=2   onDispose=1   ← inspected, clean
curation_providers.dart      resources=1   onDispose=0   ← inspected, false positive
```

Both apparent outliers were inspected manually and are fine:

- `nostr_client_provider.dart:280` has a thorough `onDispose` — cancels the
  retry timer, unregisters both auth callbacks, cancels `_authSubscription`,
  invalidates the client generation, and disposes every tracked client.
- `curation_providers.dart:119` is `ref.listen`, which Riverpod disposes
  automatically. Not a resource.

**Conclusion: no leaks found in the sample. This codebase already disposes
conscientiously.** #6174 was the outlier that got caught and fixed, not the
house style.

Three further points that reframe this risk:

1. **The swap does not create this risk; it already exists today, unmitigated.**
   #6174 happened with no container swapping anywhere. Every `ref.invalidate` on
   a keepAlive provider has the identical failure mode right now, spread across
   however many invalidation paths exist.
2. **Under R1, "teardown" is the feature, not the hazard.** The user decided
   inactive accounts go dormant. So closing A's subscriptions on switch is
   exactly what is supposed to happen. A "leak" is simply a failure to do the
   thing we already want done.
3. **The swap makes it testable at one seam.** See §10.1. You cannot write that
   test against the current design, because there is no single moment at which
   "the old account's runtime should now be gone."

### 9.2 Other risks

| Risk | Severity | Mitigation |
|---|---|---|
| GoRouter lifetime vs container | Medium | Determine whether the router is constructed inside the container. If so, rebuild it on swap and reset the stack to Home — which is desirable UX anyway. **[UNVERIFIED — needs checking.]** |
| Drift connection must not be torn down | High | It is in `DeviceScope`. A closed DB mid-switch would be severe; needs an explicit test. |
| Credential migration corrupts an account | High | Copy-verify-then-delete, never delete-then-copy. Keep legacy keys for one release. Ship behind the existing flag. |
| Legacy `userPubkey == null` OAuth cohort | Medium | Currently cannot be archived at all, so these users are *already* broken on switch. Needs a product decision (§12). |
| `AuthService` is 152KB and does two jobs | Medium | Not split in this work beyond removing identity-holding. Flagged as follow-up, not scope creep. |
| Perceived slowness on remote signers | Low | Spinner scoped to the target row; current account stays interactive. 10s timeout. |

---

## 10. Testing strategy

### 10.1 The gate test — run this against current code *before* building anything

```dart
test('container swap leaks nothing', () async {
  final before = liveResourceCount();
  for (var i = 0; i < 20; i++) {
    container = await swapAccount(container, i.isEven ? accountA : accountB);
  }
  expect(liveResourceCount(), before);  // growth => a named leak
});
```

If this is red on today's code, we learn that before building on top of it.

### 10.2 Required coverage

- **Rollback (R4):** switch to an account whose signer fails at each of the four
  sources; assert the original account is still fully live and unmodified, and
  that no credential was written.
- **Interrupt-safety:** kill the process between each step of §8.2; assert on
  restart the user is on a valid account with credentials intact.
- **No data loss (R5):** A creates a draft/clip/bookmark/mute → switch to B →
  switch back to A → assert all present. Explicitly assert on the 21 prefs keys
  from §3.2d.
- **Isolation:** as A, assert B's notifications, DMs, drafts, and mutes are
  invisible. This test fails on today's code for `Notifications`.
- **In-flight upload (R5):** start an upload as A, switch to B, assert it
  completes and is attributed to A.
- **Migration:** construct a fixture in the legacy archive layout for each auth
  source, run migration, assert all accounts still activate.
- **Per repo policy** (`.claude/rules/testing.md`): package-level changes to
  `db_client` carry that package's coverage gate. App-layer work is
  behavior-first. Every test must be able to fail — no coverage theatre.

---

## 11. Phased implementation plan

Each phase is independently shippable and revertable. Phases 1–2 carry value
even if 3–5 are abandoned.

### Phase 1 — Data-layer correctness (no architecture change)
*Fixes real bugs in today's build. Zero dependency on the rest.*

- [x] Add `owner_pubkey` to `Notifications`; migrate; filter all reads; claim
  legacy rows at session setup. **This was a live cross-account leak.**
  (commit `858619843`)
- [x] Delete `identity_manager_service.dart`. (commit `858619843`)
- [x] Close the half-enforced feature flag (§3.2f) — add the cubit guard the
  2026-04-14 design specified. (commit `d5f08774d`)
- [x] Resolve `PendingProductEvents` attribution. **Verified it was a real,
  flag-independent bug:** the batch flush signs with the *current* account's
  NIP-98 token, rows carried no owner, and sign-out did not clear them, so a
  logout→login-as-different-account published the prior account's queued
  analytics under the new signature. Fixed by owner-scoping the queue (stamp
  at enqueue from the event's own `userPubkey`, filter flush to the current
  account). This one did *not* need the container — the queue already runs in
  a current-user context, so filtering `getRetryable` was enough.

**Reordered during implementation — prefs prefixing + cleanup split moved to
Phase 3.** The 18-key cleanup list turned out to be only **8 live keys across 5
services** (`seen_videos`, `bookmark`, `curated_list`, `content_reporting`,
`content_deletion`); the other 10 are dead (present only in the cleanup list).
Every one of those 5 services is constructed with **no account** and a static
global key. Prefixing them *before* the container boundary exists would require
bolting bespoke "react to account change" plumbing onto each — the exact
scattered per-subsystem reactive code Phase 3/4 deletes, and its own reliability
risk (the #4969/#5472/#6174 family). Post-container each service is constructed
inside an account-bound container and simply receives its pubkey; the migration
is identical, the plumbing is zero. The prefs bug is low-severity (local cache,
mostly relay-backed), so deferring it a few phases is safer than shipping
throwaway reactive code now. Moved to Phase 3 (see below).

The §10.1 leak gate test is also moved to Phase 4 — it exercises the container
swap, which does not exist until then.

**Shipped value alone:** closed the notification cross-account leak and the
half-open feature flag, independent of the rest.

### Phase 2 — Credential storage
*Removes the non-atomic secret copy.*

- Introduce addressed per-account credential keys (§8.4).
- Migration with copy-verify-then-delete; legacy keys retained one release.
- Decide and handle the legacy null-`userPubkey` OAuth cohort.
- Delete `archive` / `restoreActiveKeys` / `switchToIdentity` mutation paths.

**Correction — Phase 2 is NOT independently shippable before Phase 3/4.**
An attempt to land the write-once-at-sign-in piece in isolation was made and
reverted after two empirical findings falsified the plan's assumptions:

1. **There is no single finalization chokepoint at sign-in.** Fresh sign-in
   runs through `_setupUserSession`, but the reconnect/restore paths
   (`_reconnectAmber` `auth_service.dart:2199`, `_reconnectBunker`,
   `_reconnectNip07`) finalize *inline* and never call it. Worse, even on the
   fresh OAuth path the active credential slots are **not guaranteed populated**
   when `_setupUserSession` runs (verified: `persistForAccount` fired but read
   `oauth=false` on the local-signing sub-path). So "write the addressed key at
   sign-in" cannot be done with one hook — it needs the single
   `buildAndProveSession` chokepoint the Phase 4 `activate()` refactor creates.

2. **The null-`userPubkey` OAuth cohort cannot be safely auto-archived —
   not even at switch-away.** Attempting it (allow-null archive at the
   `_archiveSignerInfo` call) breaks the existing, intentional Bug-2 corruption
   guard (`auth_service_multi_account_test.dart`: "refuses to archive OAuth
   session with null userPubkey (legacy)"). Even at switch-away the active slot
   can hold a diverged/different session (the whole Bug-2 premise), so a null
   session is unverifiable there too. This confirms §12 Q2's recommendation:
   the null cohort's fix is **force re-auth (option a)**, a switcher-UX/restore
   flow change (Phase 4/5), NOT a storage rewrite.

**Consequence:** the write-once addressed-credential model (§8.4) lands *with*
the `buildAndProveSession` refactor (single finalize point) and the null-cohort
re-auth UX — i.e., folded into Phase 4, not before it. The value it delivers
(non-corrupting switch, no stranded credentials) is real but is not separable
from the finalization refactor. The current `archive`/`restoreActiveKeys`
mutation stays until then; it is dormant in production (`FF_ACCOUNT_SWITCHING`
off), so nothing regresses in the meantime.

### Phase 3 — `AccountSession` + `DeviceScope`
*Introduces the model without yet changing how switching works.*

- Define `AccountScope` (`SignedOut` | `SignedIn`), `AccountSession`,
  `AccountStore`, `activeAccountProvider` (§8.1, §8.1.1).
- Unify sign-in, sign-out, and switch onto the single container-construction
  path, so switch stops inheriting sign-out's destructive cleanup.
- Define `DeviceScope`; hoist its six members; re-bind `NotificationService`.
- Point `currentPublicKeyHex` at `activeAccountProvider` as a deprecated
  forwarder. **No call sites change.**
- Fix the 9 `ref.read(authServiceProvider).currentPublicKeyHex` capture sites.
- **Prefix the 8 live viewer-scoped prefs keys** across the 5 services
  (`seen_videos`, `bookmark`, `curated_list`, `content_reporting`,
  `content_deletion`), now that each receives its account pubkey at
  construction. Migration: copy the old global value into the account key once,
  then claim-on-first-signin like drafts/notifications. Per-key A→B→A regression
  test. Drop these keys from `UserDataCleanupService`'s always-clear list.
- **Split `UserDataCleanupService`** into `switchAway` (preserve owner-scoped
  data) and `deleteAccountFromDevice` (destroy). Removes the destructive path
  from switch — the direct #4623 fix. Coupled to the prefs prefixing above,
  which is why both land here rather than in Phase 1.

### Phase 4 — Container swap
*The actual switch.*

- Implement `swapAccount` per §8.2 with prove-then-commit and rollback.
- Router reset on swap.
- Delete the now-redundant reactive-rewiring apparatus in
  `nostr_client_provider.dart` and `auth_providers.dart`.
- Full §10.2 test matrix.

#### Implementation note — the `activate()` blocker (found during Phase 3)

`AccountStore.activate(pubkeyHex)` (§8.1) is specified as side-effect-free:
build and *prove* the target account's signer, and only commit by swapping the
container. The current codebase cannot do this yet, and the reason is specific:

- **`AuthService.signInForAccount(pubkeyHex, authSource)`
  (`auth_service.dart:1547`) fuses two responsibilities** that atomic switching
  needs separated: it (a) reconnects the source-specific signer
  (`_reconnectAmber` / `_reconnectBunker` / `_reconnectNip07` /
  `signInWithDivineOAuth`) **and** (b) mutates the global active session as it
  goes. There is no "return a proven session without becoming it" seam.
- **`AuthService` is a device-level singleton**, not per-container, so there is
  no prior active session to roll back *to* if the target fails mid-activation.
  The mutation is destructive the moment it starts.
- **`SignerFactory.buildIdentity(...)` (`signer_factory.dart:120`) is already
  side-effect-free** — it takes pre-connected signer objects and returns a
  `NostrIdentity`. So the pure half exists; what's missing is a side-effect-free
  *connect + prove* step feeding it.

**Required refactor before `swapAccount` can be atomic:** extract a
`Future<AccountSession> buildAndProveSession(KnownAccount)` that reads the
account's credentials (addressed, post-Phase-2), performs the source-specific
connect (reusing the `_reconnect*` bodies), proves liveness
(`get_public_key` == expected for remote signers; instant for local), and
returns an `AccountSession` **without** writing any global active state. Then
`signInForAccount` becomes `buildAndProveSession(...)` + a separate "make
active" commit, and `swapAccount` calls the former, commits by container swap,
and on failure simply drops the half-built session (§8.2 step 1).

This is the highest-risk edit in the project (a bug locks users out), touches
the signing path, and should be done as its own focused change with the §10.2
rollback/interrupt matrix written first. It is the reason Phase 4 is not a
"finish it in the same sitting" task.

### Phase 5 — UX and rollout
- Build the account-switcher surface; wire the three R3 entry points.
- Failure/retry UI; per-row spinner.
- Enable `FF_ACCOUNT_SWITCHING` progressively; keep the flag for one release.

**Sequencing note:** Phases 1 and 2 are pure de-risking and could be done by a
different person in parallel with design review of 3–5.

---

## 12. Open questions for the reviewer

1. **Is Option 3 right, or is the reviewer persuaded by Option 1's purity?** The
   argument for 3 is reviewability and a single testable seam. Counter-argument
   welcome.
2. **Legacy null-`userPubkey` OAuth cohort** (§3.2b): these users' credentials
   cannot currently be archived. Options: (a) force re-auth on first switch,
   (b) attempt to bind the session to the currently-active pubkey during
   migration and hope it is correct, (c) treat as un-switchable and hide from the
   picker. (a) is safest; (b) risks binding the wrong account. Recommend (a).
3. **Max accounts.** Not answered during design. Affects whether the picker
   needs search/scroll and whether `KnownAccountsRegistry`'s linear scan matters.
   Assumed 2–5, designed not to break at 20.
4. **Bottom sheet vs full-screen for the switcher.** `AGENTS.md` prefers
   full-screen flows, but `settings_account_cubit.dart`'s own doc comment says
   "account-switcher bottom sheet", so a sheet precedent already exists. Which
   wins?
5. **Is `PendingProductEvents` genuinely viewer-scoped?** Unverified. If
   analytics events are stamped with identity at enqueue time, no change needed.
6. **Where is GoRouter constructed relative to the container?** Unverified.
   Determines Phase 4 scope.
7. **Should Phase 2 also split `AuthService` (152KB, two responsibilities)?**
   Argument for: it is touched heavily anyway. Argument against: scope creep on
   an already-large change. Currently proposed as follow-up.
8. **Is "signed-out is its own container" (§8.1.1) right, or does it make cold
   start worse?** It means first launch builds a `SignedOut` container and then
   immediately replaces it on auto-restore — two containers during startup.
   Alternative: build the container *after* session restore resolves, at the
   cost of a longer pre-Flutter-tree gap. Startup time is already tracked
   (`StartupPerformanceService`), so this is measurable rather than arguable.
   **Recommend measuring before deciding.**
9. **Should the nine `BlocProvider` `ValueKey` identity guards (§8.6) be removed
   once Phase 4 lands?** They become redundant for auth flip / account switch /
   sign-out but remain load-bearing for unrelated `ref.invalidate`. Removing
   them is a separate evidenced change; leaving them is harmless but confusing
   to future readers. Recommend leaving them and adding a note to
   `.claude/rules/state_management.md` explaining which trigger still applies.

---

## 13. Appendix — verification commands

Every quantitative claim above is reproducible:

```bash
cd mobile

# 130 reads across 81 files
grep -rn "currentPublicKeyHex" lib --include="*.dart" | wc -l
grep -rl "currentPublicKeyHex" lib --include="*.dart" | wc -l

# read-pattern distribution (113 injected vs 27 provider-inline)
grep -rn "currentPublicKeyHex" lib --include="*.dart" | grep -v '\.g\.dart' \
  | grep -oE "(ref\.(read|watch)\([a-zA-Z]+\)[.?]*currentPublicKeyHex|_?authService\.currentPublicKeyHex)" \
  | sort | uniq -c | sort -rn

# 97 keepAlive declarations across 31 files
grep -rn "keepAlive: true" lib --include="*.dart" | wc -l
grep -rl "keepAlive: true" lib --include="*.dart" | wc -l

# tables lacking owner scoping
awk '/^class [A-Za-z]+ extends Table/{n=$2;b=""} {b=b"\n"$0} /^}/{if(n!=""){if(b !~ /ownerPubkey|userPubkey/) print n; n=""}}' \
  packages/db_client/lib/src/database/tables.dart

# identity_manager_service.dart has no external callers
grep -rn "IdentityManagerService" lib test --include="*.dart" | grep -v identity_manager_service.dart
```
