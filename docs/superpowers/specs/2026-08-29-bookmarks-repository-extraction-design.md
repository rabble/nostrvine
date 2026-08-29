# Extracting `bookmarks_repository` — design

Issue: [#6969](https://github.com/divinevideo/divine-mobile/issues/6969) ·
Epic: [#8294](https://github.com/divinevideo/divine-mobile/issues/8294) ·
Base: `origin/main` @ `f99d287eb` · Date: 2026-08-29

Every claim below was measured on `main` rather than inferred; the working
investigation log lives outside version control at `tasks/findings_6969.md`
(that directory is gitignored). Where a fact is load-bearing, the evidence is
restated inline here so this document stands alone.

---

## 1. What this changes, and what it deliberately does not

`BookmarkService` (`mobile/lib/services/bookmark_service.dart`, 1262 lines)
composes `NostrClient`, `AuthService` and `SharedPreferences`, owns the
relay/cache reconcile, and is consumed by two BLoCs. Under
`.claude/rules/architecture.md` that is repository work sitting in the app
layer. This moves it to `mobile/packages/bookmarks_repository`.

**This is a behaviour-preserving move of production code.** The only
intentional production-behaviour deltas are named in §6; everything else must
be observably identical.

### Two claims in the issue body are stale — recorded so nobody re-derives them

| Issue says | Measured on `main` |
|---|---|
| "~960 lines" | **1262** (+302 across 13 PRs since the issue was filed on 2026-08-09) |
| "entangles kind 10003 with kind 30003 bookmark *sets*" | **No 30003 anywhere in the service.** Deleted by PR #6966 (`d9a74255a`), the very prerequisite the deferral cited — the file went 992 → 506 lines, then grew back on kind-10003 correctness work |
| "#6966 added a first test file that the extraction can carry over" | Optimistic — the suite imports two app-layer symbols that cannot move (§4) |

The stated reason for deferring is therefore gone. The extraction is a
straighter move than the issue anticipates, over a larger and denser file.

---

## 2. Package shape

`mobile/packages/bookmarks_repository`, modelled on
`content_blocklist_repository` — the NIP-51 **kind 10000** repository, which is
this feature's structural twin (replaceable list, encrypted private section,
`SharedPreferences` snapshot, injected signer port) and is already package-pure.

```
mobile/packages/bookmarks_repository/
  lib/
    bookmarks_repository.dart          # barrel
    src/
      bookmarks_repository.dart        # the moved class
      bookmark_item.dart
      bookmark_toggle_result.dart      # + BookmarkToggleFailure
      bookmark_signer.dart             # the port (§3)
  test/
    src/bookmarks_repository_test.dart # the moved suite + 13 new tests
  pubspec.yaml
  analysis_options.yaml                # include: package:very_good_analysis/...
```

**Single concrete class, no interface.** `ContentBlocklistRepository` is
concrete; the two consuming BLoC tests already mock the concrete type with
mocktail. An interface would be indirection the move does not need.

Dependencies (all precedented; 9 packages already depend on
`shared_preferences`, including `nostr_client` itself):

```yaml
dependencies:
  meta: ^1.17.0
  nostr_client:
  nostr_sdk:
  shared_preferences: ^2.5.3
  unified_logger:
dev_dependencies:
  flutter_test: {sdk: flutter}
  mocktail: ^1.0.4
  very_good_analysis: ^10.2.0
```

### Storage keys must not change

`UserDataCleanupService` clears the snapshot by **hardcoded string literal**
(`mobile/lib/services/user_data_cleanup_service.dart:50-51`), with no
compile-time link to the constants:

```dart
'global_bookmarks',
'global_bookmarks_revision',
```

So `globalBookmarksStorageKey` and `globalBookmarksRevisionStorageKey` keep
**byte-identical values**. Renaming or namespacing either would silently break
identity-change cleanup with no test or analyzer failure. Tracked as
[#8314](https://github.com/divinevideo/divine-mobile/issues/8314); explicitly
out of scope here.

---

## 3. The signer port — the one genuine blocker

Of the four `AuthService` members the service uses, three have package-pure
equivalents already. Only one is a real blocker:

| Member | Blocker? | Why not |
|---|---|---|
| `currentPublicKeyHex` | No | `NostrClient.publicKey` / `resolvePublicKey()` |
| `isAuthenticated` | No | already on the existing `BlockListSigner` |
| `currentIdentity` → `nip44Encrypt` / `nip44Decrypt` / `decrypt` | No | `NostrIdentity` **is** a `NostrSigner` (`auth/nostr_identity.dart:16`), and all three are `NostrSigner` members |
| **`createAndSignEvent(…, createdAt:)`** | **Yes** | see below |

`SignerFactory.createAndSignEvent` does five things raw `NostrSigner.signEvent`
does not. Two are load-bearing guards:

- **`EventSignerAccountMismatchException`** when the signer returns an event for
  a different pubkey (#5450), reported via `Reportable`.
- **Background-isolate signature verification** for remote (Keycast/Amber)
  signers, plus an `isValid` structural check.

### Rejected: publish an unsigned `Event` and let `NostrClient` sign it

`Nostr.sendEvent` signs when `event.sig` is blank, and
`people_lists_repository` publishes this way — so it is tempting and it
compiles. **It silently drops both guards above.** That is a behaviour change,
not a move, and it is disqualified here. Recorded because it is the obvious
"simplest option" and would otherwise be re-proposed.

### Chosen: a narrow `BookmarkSigner` declared in the package

```dart
/// Minimal signer contract for publishing the NIP-51 kind-10003 bookmark list
/// without depending on the app's auth stack. Implemented at the app layer by
/// `AuthService`, which already implements the sibling `BlockListSigner`.
abstract class BookmarkSigner {
  bool get isAuthenticated;
  String? get currentPublicKeyHex;

  /// The active signer, for NIP-04/NIP-44 private-item crypto.
  NostrSigner? get currentIdentity;

  /// [createdAt] overrides the signer's clock. Kind 10003 is replaceable, so a
  /// publish must supersede the revision it replaces — see #7629 / #7635.
  Future<Event?> createAndSignEvent({
    required int kind,
    required String content,
    List<List<String>>? tags,
    int? createdAt,
  });
}
```

`AuthService` gains `BookmarkSigner` in its `implements` clause. Every member
already exists on it with a compatible signature (`createAndSignEvent` already
takes `createdAt`, `auth_service.dart:3640-3646`), so **no `AuthService` body
changes**.

Considered and ranked below this:

- **Widen the shared `BlockListSigner` with `createdAt`.** More DRY, and
  source-compatible everywhere (one production implementer, which already has
  the parameter; the only test double is a mocktail `Mock`). Ranked second
  because it edits a shared package's public contract to serve one caller —
  the coupling this issue exists to reduce — and hands
  `content_blocklist_repository` a parameter it does not use.
- **Package-local typedefs** (the `IdentityEventSigner` /
  `BadgeCurrentPubkeyReader` precedent). Ranked third: a fifth near-identical
  signer abstraction, and it splits one contract across two typedefs.

**Why not source the crypto from `NostrClient.signer`** (which is free, and
documented as "the same `NostrSigner` instance the client was created with"):
normally identical to `AuthService.currentIdentity`, but the two can diverge
during an identity transition. Keeping both halves on one port preserves
today's semantics exactly, which is the point of a pure move.

---

## 4. Tests

The existing suite is 1948 lines, **71 tests in 10 nested groups**, mocktail
(no generated mocks), all passing. It does **not** carry over untouched — it
imports two app-layer symbols:

- `AuthService` → becomes `_MockBookmarkSigner`.
- `LocalNostrIdentity` (`sealed class NostrIdentity implements NostrSigner`) —
  `setUp` deliberately builds a **real** one so NIP-44/NIP-04 are genuine
  crypto rather than stubs. It already implements `NostrSigner`, so the port's
  `currentIdentity` accepts it unchanged; only the import and the mock's return
  type move.

Helper seams to carry over verbatim: `stubRelay`,
`stubRelayForSettlementMode`, `seedCachedBookmarks`, `stubPublishRejected`,
`capturedSettlementDemands`, `encryptToSelf` / `encryptToSelfNip04` /
`decryptToSelf`, and the `createAndSignEvent` stub that captures `tags`,
`content` and `createdAt`.

### Reaching `min_coverage: 100`

Measured today: **90.75%** (265/292 lines). All 27 uncovered lines are
**unexercised error paths** — 13 of them:

| Site | Kind |
|---|---|
| `:305` `result.completeError` | the `_serialized` queue's error propagation — **real logic**, and the most valuable of the set |
| `:575, :781, :885, :1003, :1051, :1203, :1222, :1255` | `Log.error` in `catch` blocks never entered |
| `:747, :826, :866, :933, :1032, :1131` | `Log.warning` defensive branches |
| `:759` | `Log.debug` "already in global bookmarks" |
| `:1041` | encrypt round-trip verification failure |

These are **reachable but unexercised**, so `// coverage:ignore-line` would be
a misuse of an escape hatch `testing.md` reserves for genuinely unreachable
lines. The 13 tests are written by failure injection: throwing
`SharedPreferences`, a signer returning `null`, `nip44Encrypt` throwing, a
publish rejection, and an operation queued behind one that throws.

These tests add coverage, not production behaviour, so they do not compromise
the move's behaviour-preserving property.

---

## 5. CI and ratchets

New `.github/workflows/bookmarks_repository.yaml`, cloned from
`likes_repository.yaml`:

```yaml
    with:
      working_directory: "mobile/packages/bookmarks_repository"
      flutter_version: "3.44.9"
      min_coverage: 100
```

**`min_coverage` must be stated explicitly.** 28 existing package workflows
omit it and the VGV `flutter_package.yml` default is 100 — so an omitted key
gates at 100 silently rather than not gating.

Ratchet interactions, verified rather than assumed:

| Ratchet | Effect |
|---|---|
| `check_untested_services_floor.sh` | **Neutral — measured.** Ran the detector's own `comm -23` set-difference: 35 before, 35 after removing the service/test pair. `bookmark_service` leaves both sides at once, so neither NEW nor STALE |
| `check_service_god_file_ceiling.sh` | Not engaged (1262 < 1500 threshold; not baselined) |
| `check_ungrouped_tests.sh` / `check_skip_ceiling.sh` / `check_placeholder_tests.sh` | Absent from all three baselines; the suite is fully grouped with no skips |
| `check_layer_direction.sh` | **Neutral.** `bookmark_service` is absent from `layer_direction_imports.txt` and imports nothing under `screens/` / `widgets/` / `router/`, so the ratchet never saw it. The architectural gain is real but this guard does not measure it |

Also required: add `packages/bookmarks_repository` to the `workspace:` list in
`mobile/pubspec.yaml` (57 members today) and add the dependency.

---

## 6. What changes in production behaviour

**Two things, both deliberate and both flagged in the PR body.**

1. **The type is renamed** `BookmarkService` → `BookmarksRepository`, matching
   every sibling package. A "Service" exported from a repositories package is
   the layering confusion this issue is about.
2. **`NostrTimestamp` moves** from `mobile/lib/utils/nostr_timestamp.dart` into
   `nostr_sdk` (§7).

**What does *not* change — deliberately:**

`bookmarkServiceProvider` keeps `@riverpod` (autoDispose) and its `async`
signature, so both BLoCs keep `Future<BookmarksRepository…>` constructor
parameters. This **knowingly reproduces
[#7596](https://github.com/divinevideo/divine-mobile/issues/7596)**, so the
move stays provably behaviour-preserving and any later bookmark regression has
exactly one candidate cause. The PR body must say so explicitly, or a reviewer
will read it as an oversight.

The correct end state, settled during investigation and reproduced on device,
lands as the #7596 PR immediately after:

```dart
@Riverpod(keepAlive: true)
BookmarksRepository bookmarksRepository(Ref ref) => BookmarksRepository(
      nostrClient: ref.watch(nostrServiceProvider),
      signer: ref.watch(authServiceProvider),
      prefs: ref.watch(sharedPreferencesProvider),
    );
```

with consumers on `ref.watch`. Three supports: the `async` is **vestigial**
(`sharedPreferencesProvider` was already a synchronous `Provider` before #6342,
at which commit `bookmarkService` was already `async` with no awaits);
`keepAlive` is **required** for the class's own invariants (nine mutable fields
plus the `_serialized` queue whose entire purpose, #7598, is defeated by a
fresh instance per read); and `keepAlive` is **safe across account switches** —
`nostrServiceProvider` is a Notifier that reassigns `state` per identity and
`NostrClient` has no `==`, so the element is always torn down. That last point
was an earlier session's *retracted prediction*, re-tested against riverpod
3.3.2, and independently re-derived here.

---

## 7. `NostrTimestamp` → `nostr_sdk`

The service imports `openvine/utils/nostr_timestamp.dart` for one call,
`getDriftToleranceForKind(globalBookmarksKind)`, where kind 10003 falls through
to the default constant `30`.

The file is 117 lines with **zero imports** — pure Dart with no Flutter and no
app types — and has 10 importers (4 under `lib/`, 5 tests, 1 integration_test).
There is no equivalent in any package. Moving it to
`nostr_sdk/lib/utils/nostr_timestamp.dart` (which has an established
`lib/utils/` + barrel-export pattern and no name collision) fixes the root
cause rather than working around it.

Its test moves to `nostr_sdk/test/`. That test imports `unified_logger`, which
`nostr_sdk` does not depend on — resolve by dropping the import if it is only
log setup, or adding a dev-dependency.

This is **independent work**, so it is its own commit (§8).

---

## 8. Delivery — one PR, four commits

One PR to `main` (never stacked, per `agent_workflow.md` §3), on
`refactor/6969-bookmarks-repository` from `origin/main`:

1. `refactor(nostr): move NostrTimestamp into nostr_sdk` — the utility, its
   barrel export, its test, and the 10 import sites.
2. `refactor(bookmarks): extract a bookmarks_repository package` — the package,
   the `BookmarkSigner` port, `AuthService implements BookmarkSigner`, the
   moved suite, workspace + workflow wiring, deletion of the app-layer files.
3. `refactor(bookmarks): rename BookmarkService to BookmarksRepository`.
4. `test(bookmarks): cover the thirteen unexercised error paths`.

Each is revertable alone. Splitting 1 into its own PR was considered and
rejected in favour of commit separation.

Verification before push, from `mobile/`: `dart format` on changed files,
`flutter analyze lib test integration_test`, the moved suite, the two BLoC
suites, `share_video_menu_comprehensive_test`, `flutter test` in
`packages/bookmarks_repository` and `packages/nostr_sdk` with `--coverage`, and
every `check_*.sh` ratchet. Then `gh pr checks --watch` to completion before
any handback.

---

## 9. Risks

| Risk | Mitigation |
|---|---|
| Storage keys change and identity-change cleanup silently breaks | Keys stay byte-identical; assert their values in a test (#8314 tracks the real fix) |
| The move quietly drops a signing guard | `BookmarkSigner` routes through `AuthService.createAndSignEvent` unchanged; the unsigned-publish shortcut is rejected in §3 |
| `createdAt` stamping regresses (#7635) | The `publish timestamps` group (5 tests) moves with the suite and must stay green |
| Private-item crypto regresses (#7222 / #7589) | The `NIP-51 private items` group (18 tests, real crypto) moves intact |
| Reviewer reads the reproduced #7596 as an oversight | Stated explicitly in the PR body, with the follow-up named |
| `NostrTimestamp` move breaks an unrelated importer | 10 importers enumerated; `flutter analyze` over `lib test integration_test` covers all of them |
| Device evidence is narrow | The patrol account had **zero** bookmarks, so populated paths were not exercised on device — they remain covered only by the 71-test suite. Stated, not glossed |

---

## 10. Out of scope

Filed during this investigation, deliberately not fixed here:
[#8313](https://github.com/divinevideo/divine-mobile/issues/8313) (a repository
captured by a live bloc survives an account switch),
[#8314](https://github.com/divinevideo/divine-mobile/issues/8314) (hardcoded
cleanup-key literals),
[#8315](https://github.com/divinevideo/divine-mobile/issues/8315)
(`isInGlobalBookmarks` is public with no external caller). Already open and
untouched: #7134, #7137, #7135, #7586, #7596, #7634.
