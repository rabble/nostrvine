# Brainstorm: account-cleanup keys drift from the code that owns them

Date: 2026-09-06

Issues: [#8314](https://github.com/divinevideo/divine-mobile/issues/8314),
[#6985](https://github.com/divinevideo/divine-mobile/issues/6985) (same defect,
`priority:high`), under epic
[#4335](https://github.com/divinevideo/divine-mobile/issues/4335).

Investigation record: `tasks/findings_8314.md` (local, not committed).

## Problem Statement

`UserDataCleanupService.userSpecificKeys` is a `static const List<String>` of 22
SharedPreferences key literals wiped when a different account signs in, so
account A's data does not leak into account B's session. Nothing links those
literals to the constants they mirror, in either direction. Listed keys rot into
no-ops when their owner renames or deletes them, and newly-written keys are
never added — and neither failure is visible to the compiler, the tests, or CI.

#8314 filed this as a latent bookmark-specific risk. It is neither latent nor
bookmark-specific: 11 of the 22 listed keys are dead, 5 live user-scoped keys
are swept by nothing, and 2 of those 5 reproduce as a cross-account leak today.

## What we know

Established during investigation; every claim was verified against source or
git history rather than inferred.

- **11 of 22 listed keys are dead.** No production code writes them. Their only
  other references are tests that seed the key themselves and a design doc that
  copies the list.
- **The list has never been audited.** Created 2025-12-12 (`bda4b15be`, #624)
  with every key correct that day. Across 18 commits and nine months, its only
  removal was a functional relocation of `vine_drafts` (#5519). It is
  append-only by custom; the code it mirrors is not.
- **One dead key is a live leak.** `moderation_label_service.dart` was deleted
  in #661 *four days after* #624 listed its keys, then re-created in #1797 at the
  same path writing `subscribed_labeler_pubkeys`. The list still says
  `subscribed_labelers`.
- **Reproduced.** A unit probe on `origin/main` seeding a departing account and
  running an identity change leaves `subscribed_labeler_pubkeys` and
  `following_moderation_enabled` in place, while the service logs
  `cleared 3 entries` naming two keys nothing writes. Repro grade A.
- **Five live user-scoped keys are swept by nothing** — verified exhaustively
  against all six key sources in the cleanup service plus `auth_service`'s own
  direct removes:

  | Key | Owner | Holds |
  |---|---|---|
  | `subscribed_labeler_pubkeys` | `moderation_label_service.dart:95` | trusted labeler pubkeys |
  | `following_moderation_enabled` | `moderation_label_service.dart:98` | use-followed-as-labelers choice |
  | `account_content_label` | `account_label_service.dart:29` | the creator's own self-labels |
  | `content_filter_prefs` | `content_filter_service.dart:39` | `ContentLabel → show/warn/hide` |
  | `content_filter_migrated` | `content_filter_service.dart:40` | one-shot migration flag for the above |

- **Three tests pin the bug.** `user_data_cleanup_service_test.dart:724,734,738`
  assert the list *contains* three of the dead literals, so deleting them turns
  CI red. Two more tests seed a dead key and assert it was cleared — tautologies
  under `.claude/rules/testing.md`.
- **No prior attempt exists.** Searches across issues, PRs and `git log -S` over
  all refs including unmerged branches return no abandoned fix and no closed
  duplicate. #8314 and #6985 are the first and only filings, and both are scoped
  narrower than the defect.

## Constraints

- **No layering obstacle.** 7 of 11 live keys already expose public constants;
  `bookmarks_repository` is a workspace package and a direct app dependency; and
  `UserDataCleanupService` already composes three key sets from constants
  (`SavedSoundsService.accountStorageKey`, `PrefsSyncStateStore.appliedStorageKey`,
  `AgeVerificationService.accountKeys`). The literal list is the outlier.
- **The DB half of this same feature is already compile-checked.**
  `onDatabaseCleanup` (`social_providers.dart:744+`) has no string list at all —
  it is typed calls wrapped in `safeCleanup` / `requiredCleanup`.
- **`content_filter_prefs` and `content_filter_migrated` are a unit.** Clear the
  prefs without the flag and the next account gets an empty map instead of
  defaults; clear the flag without the prefs and A's preferences get re-migrated.
- **A second defect shares the list.** All these keys are unprefixed, so an
  A→B→A switch *deletes* A's data rather than restoring it
  (`docs/superpowers/specs/2026-07-24-multi-account-switching-design.md:164-186`).
  That is data loss rather than leakage, it has no issue of its own, and it
  belongs to epic #4623 — but no fix here should obstruct it.
- **Per-account scoping is live precedent.** #8538 (`34138c3f4`, 2026-09-04)
  added `_scopedKey(base, pubkey) => '${base}_$pubkey'` to
  `AgeVerificationService`, whose `accountKeys()` the cleanup service already
  consumes.
- Repo culture: ~45 `check_*.sh` guards, 11 Dart-AST detectors, two shared
  ratchet harnesses. The orphaned-ARB-key floor (#3630) is the direct analogue —
  declared names nothing references, frozen by a shrink-only ratchet with an
  AST detector because a grep mistakes comments and dartdoc for references.

## Prior art

- `mobile/scripts/lib/orphaned_arb_key_detector.dart` + `check_orphaned_arb_key_floor.sh` — the closest existing shape.
- `mobile/scripts/lib/numeric_ratchet.sh`, `list_ratchet.sh` — shared harnesses.
- `AgeVerificationService.accountKeys(pubkeyHex)` — a service already exporting its own key set for cleanup to consume. **This is the pattern to generalise.**
- `social_providers.dart:744+` — the compile-checked cleanup half.

## Approaches Explored

### Approach A: Reference the constants

**Description:** Replace the 22 literals with references to the owning
constants. Widen 4 private constants, create 2 that do not exist
(`age_verified_16_plus`, `terms_accepted_at`), delete the 11 dead entries, add
the 5 missing keys.

**Layers affected:** Service layer only.

**Pros:** Exactly what #8314 asks for. Low effort. A rename becomes a compile
error. No new infrastructure.

**Cons:** Catches only one failure direction. A service that adds a new
user-scoped key and does not list it stays silent — and that is the direction
that produced 5 of today's unswept keys, including both reproduced leaks. It
fixes the instances and leaves the mechanism.

**Complexity:** Low.

### Approach B: Invert ownership — services declare their own keys

**Description:** Each service that writes user-scoped preferences exposes
`static const List<String> userScopedPrefsKeys` alongside the constants
themselves. `UserDataCleanupService.userSpecificKeys` becomes a spread of those
lists and holds no literals.

**Layers affected:** Service layer, plus the one repository package.

**Pros:** Everything in A, plus the declaration now lives *next to the code that
writes the key* — so adding a key and declaring it are the same edit in the same
file, rather than an edit in a file the author may not know exists. Naturally
expresses the `content_filter_prefs` + `content_filter_migrated` unit, because
the service that knows they are coupled is the one declaring them. Generalises
`AgeVerificationService.accountKeys`, which already does this.

**Cons:** Still relies on an author remembering to add to their own list — much
likelier than remembering a distant file, but not enforced. Slightly widens
public API on five services.

**Complexity:** Medium.

### Approach C: CI ratchet over every prefs key

**Description:** A Dart-AST detector enumerates every SharedPreferences key
written under `mobile/lib` and `mobile/packages/*/lib`, and fails when a key
cannot be classified — see [Classification](#classification-six-categories-not-two)
below. Zero baseline.

**Layers affected:** None — tooling only.

**Pros:** The only option that catches **both** directions, including keys added
in future by someone who never reads this issue. Matches repo culture exactly.
Makes the device-scoped decision explicit and reviewed rather than implicit in
an omission.

**Cons:** Does nothing about the literals themselves — the list stays
uncheckable by the compiler. Highest build cost. Needs a classification for
every existing key up front, and "is this key user-scoped?" is a judgment call
for a handful of them.

**Complexity:** High.

### Approach D: Pubkey-namespace the keys

**Description:** Move user-scoped preferences to `${base}_$pubkey` following
#8538's `_scopedKey`, so cleanup becomes a prefix sweep and per-account state is
addressable rather than shared.

**Layers affected:** Every service writing user-scoped prefs, plus a migration.

**Pros:** Makes the leak impossible by construction rather than by
enumeration — there is no list to drift. Also fixes the A→B→A data-loss path,
which no other option touches. Follows a precedent introduced in this repo two
days ago.

**Cons:** Needs a one-time migration per key for every installed device, and a
migration bug here loses user data rather than leaking it. Touches many services
at once. Blast radius far exceeds either issue. Properly belongs to epic #4623,
where account-switching is already being hardened.

**Complexity:** High to very high.

## Recommendation

**B + C, shipped together** — services declare their own user-scoped keys, and a
zero-baseline CI guard fails on any prefs key that is neither swept nor
explicitly marked device-scoped.

Why this pairing rather than either alone:

- The defect has two directions and **B and C each cover one**. B makes a
  drifted or renamed key a compile error; C makes an undeclared key a CI
  failure. A alone covers neither of the two directions that caused the
  reproduced leaks.
- The nine-month history is the argument against relying on discipline. This
  list was correct the day it was written and was never revisited. Any fix whose
  durability depends on someone remembering to update a list will decay exactly
  as this one did — which is why the enforcement half is not optional.
- C alone would leave the literals in place. Given 7 of 11 constants are already
  public and the DB half of this very service is already compile-checked, that
  would be leaving the cheap half of the fix on the floor.

D is the better end state and is explicitly **not** recommended now: it carries a
data-migration risk for every installed device, and it belongs to #4623 where
account switching is already being reworked. B+C does not obstruct it — a
service that declares its own keys is strictly easier to namespace later, since
the declaration is the natural place to switch from a literal to a scoped
builder.

**Scope decision:** one PR closing both #8314 and #6985, with one commit per
finding so each is independently revertible. AGENTS.md forbids stacking and
directs combining dependent work; both issues are the same mechanism, and the
org member's comment on #8314 explicitly asked for the structural fix rather
than two string corrections.

## Classification: six categories, not two

The first sketch of this design used a binary — a key is user-scoped or
device-scoped. The full inventory (378 call sites, 187 named constants) turned
up real keys that **cannot be expressed in that binary**, and two of them are
ways a naive fix ships a worse bug than the one it closes.

| Category | Meaning | Examples |
|---|---|---|
| `userScoped` | cleared on identity change | `subscribed_labeler_pubkeys`, `muted_conversations` |
| `deviceScoped` | deliberately survives | `relay_url`, `analytics_enabled`, `deleted_curated_list_coordinates` |
| `pubkeyScoped` | key embeds the pubkey; safe by construction | `SavedSoundsService.accountStorageKey`, `AgeVerificationService.accountKeys` |
| `userScopedPrefix` | prefix-swept on identity change | `following_list_`, `relay_discovery_` |
| `deviceGateForUserData` | device flag whose effect is per-account — **must clear with the data it gates** | `content_filter_migrated`, `seen_videos_migrated_to_db`, `corrupted_video_repair_v1_completed` |
| `scopingKey` | the key other key names derive from — **must never be swept alone** | `blocklist_active_pubkey` |

The last two earn their place by failure mode, not tidiness:

- Without `deviceGateForUserData`, clearing `content_filter_prefs` while leaving
  `content_filter_migrated` set gives the next account an **empty** preference
  map instead of defaults.
- Without `scopingKey`, sweeping `blocklist_active_pubkey` unscopes every other
  key in `content_blocklist_repository` — the file resolves its on-disk names
  from it.

Only `userScoped` and `deviceScoped` need a new declaration; the other four
already have homes in existing code (`identityChangePrefixes`, the pubkey-scoped
builders, and — for the two new categories — the service that owns the gate or
the scope.)

## Storage layers: prefs is not the whole surface

The inventory's top-ranked leak is **not a SharedPreferences key**. `seen_videos`
migrated from prefs to Drift and left its cleanup behind: the Drift table has no
owner column (`db_client/…/tables.dart:1736-1751`, PK `{videoId}`),
`clearSeenVideos()` has zero production callers
(`seen_videos_service.dart:469`), and the DAO is absent from `onDatabaseCleanup`
against 15 that are present. The swept `seen_video_ids` / `seen_video_metrics`
are post-migration empty shells — the list clears the old home while nothing
clears the new one.

Account B inherits A's whole watch history as feed **dedup** state, so it is a
functional bug as well as a leak: B's feed skips content B has never seen.

Consequence for the guard: a prefs-only detector would not have caught this. The
plan must decide whether the detector's remit spans Drift and Hive stores, or
whether the storage-layer half becomes its own issue under #4335.

## Open Questions for /plan

- [x] ~~Does the inventory surface keys beyond the five?~~ **Yes — ~14 unswept
      keys plus one Drift table.** Two are write-path leaks (`content_language`
      tags published videos via NIP-32; `audio_sharing_enabled` governs whether
      the account's audio is reusable). Shape unchanged; ledger grew.
- [x] ~~Where does the device-scoped manifest live?~~ **In code, not a baseline
      file.** A ratchet baseline may only shrink, and legitimate new device
      settings must be able to grow — forcing them through a shrink-only
      baseline would fail CI on correct work and train people to regenerate it,
      the exact reflex the guard exists to prevent.
- [x] ~~Does the detector scan packages?~~ **Yes** — `bookmarks_repository` owns
      two keys and `content_blocklist_repository` owns the `scopingKey`.
      Scope: `mobile/lib` + `mobile/packages/*/lib`, matching
      `check_pubkey_log_encoding.sh`.
- [x] ~~How are pubkey-interpolated keys classified?~~ Via `pubkeyScoped` /
      `userScopedPrefix` above. Note the naive rule "interpolated ⇒ safe" is
      **wrong**: `'following_list_$pubkey'` cannot leak but `'draft_$draftId'`
      is equally interpolated and would.
- [ ] Does the guard's remit include Drift/Hive, or does the storage-layer half
      (`seen_videos` table, Hive `push_preferences`) become its own issue?
- [ ] Are `seen_video_ids` / `seen_video_metrics` live keys to convert, or dead
      post-migration shells to delete? If shells, widening their private
      constants is wasted work and the real fix is clearing the Drift table.
- [ ] Confirm the `show_verified_only` / `show_divine_hosted_only` product call.
      Planning default is `userScoped` — the risk is asymmetric (inheriting a
      *relaxed* safety filter is a regression; a strict one is harmless), so the
      conservative choice cannot cause the harm.
- [ ] Exact repair for the three tests that pin dead keys — delete outright, or
      rewrite to assert the composition instead of membership?
- [ ] Should `content_filter_prefs` / `content_filter_migrated` clear on plain
      logout or only on identity change? They are a unit, but the unit's
      lifetime is a product question.

## Prerequisites

- [ ] None blocking. No design mockups, no protocol decisions, no new packages.
- [ ] Confirm the device-scoped classification for any ambiguous key the
      inventory turns up before freezing the guard at zero.

## Next Step

`/plan 8314` — build the implementation plan for B+C as a single PR closing
#8314 and #6985, seeded from `tasks/findings_8314.md` and this document.
