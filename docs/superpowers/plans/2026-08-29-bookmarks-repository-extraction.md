# bookmarks_repository Extraction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move `BookmarkService` out of `mobile/lib/services/` into a new `mobile/packages/bookmarks_repository` package as `BookmarksRepository`, preserving production behaviour exactly.

**Architecture:** A single concrete class, modelled on `content_blocklist_repository` (the NIP-51 kind-10000 twin). The one app-layer dependency that cannot move — `AuthService.createAndSignEvent` — is replaced by a narrow `BookmarkSigner` interface declared in the package and implemented by `AuthService`, exactly as `AuthService` already implements `BlockListSigner`.

**Tech Stack:** Dart/Flutter 3.44.9 (via `mise exec --`), `flutter_bloc`, Riverpod (legacy glue), `mocktail`, `very_good_analysis`, VeryGood package CI.

**Spec:** `docs/superpowers/specs/2026-08-29-bookmarks-repository-extraction-design.md`

## Global Constraints

- **All Flutter commands run from `mobile/`**, prefixed `mise exec --` (a bare `dart`/`flutter` picks up the PATH SDK, not the pinned 3.44.9).
- **Branch:** `refactor/6969-bookmarks-repository`, worktree `.worktrees/6969-bookmarks-repo`, based on `origin/main` @ `f99d287eb`. One PR to `main`. Never stack.
- **Storage key values are frozen**: `'global_bookmarks'` and `'global_bookmarks_revision'` must remain byte-identical. `mobile/lib/services/user_data_cleanup_service.dart:50-51` mirrors them as bare string literals with no compile-time link.
- **Production behaviour must not change**, except the two deltas named in the spec §6: the type rename, and `NostrTimestamp` moving package. In particular the provider keeps `@riverpod` (autoDispose) and its `async` signature — this reproduces #7596 **on purpose**.
- **Never truncate Nostr identifiers** in logs; pubkeys reaching a log sink go through `pubkeyForLogs`. The moved code already complies — do not "improve" any log line.
- **No new `skip:`/`@Skip`, no TODOs, no commented-out code.** Every test must be able to fail.
- **Package `min_coverage: 100`** — must be stated explicitly in the workflow; omitting the key silently defaults to 100 anyway, but state it so the intent is readable.
- Never `git push --force` without `--lease`. Never `--no-verify`.

---

### Task 1: Move `NostrTimestamp` into `nostr_sdk`

Independent of the extraction; lands as its own commit. `mobile/lib/utils/nostr_timestamp.dart` is 117 lines with **zero imports** — pure Dart, no Flutter, no app types — so it moves without adaptation.

**Files:**
- Create: `mobile/packages/nostr_sdk/lib/utils/nostr_timestamp.dart` (moved)
- Create: `mobile/packages/nostr_sdk/test/utils/nostr_timestamp_test.dart` (moved)
- Delete: `mobile/lib/utils/nostr_timestamp.dart`, `mobile/test/services/timestamp_test.dart`
- Modify: `mobile/packages/nostr_sdk/lib/nostr_sdk.dart` (barrel, alphabetical in the `utils/` block at lines 73-77)
- Modify (import sites, 9 remaining): `mobile/lib/services/auth/signer_factory.dart:16`, `mobile/lib/services/bookmark_service.dart:11`, `mobile/lib/services/push_notification_service.dart:19`, `mobile/lib/utils/nostr_replacement_timestamp.dart:5`, `mobile/integration_test/helpers/test_nostr_service.dart:10`, `mobile/test/helpers/test_nostr_service.dart:10`, `mobile/test/services/auth_service_timestamp_test.dart:5`, `mobile/test/services/bookmark_service_test.dart:19`, `mobile/test/utils/nostr_replacement_timestamp_test.dart:7`

**Interfaces:**
- Consumes: nothing.
- Produces: `NostrTimestamp` importable as `package:nostr_sdk/nostr_sdk.dart`, with `static int getDriftToleranceForKind(int kind)` returning `defaultClockDriftTolerance` (30) for kind 10003.

- [ ] **Step 1: Move the file and its test with `git mv` so history follows**

```bash
cd /Users/meylisannagurbanov/512-SSD-data/divinevideo/divine-mobile/.worktrees/6969-bookmarks-repo
mkdir -p mobile/packages/nostr_sdk/test/utils
git mv mobile/lib/utils/nostr_timestamp.dart mobile/packages/nostr_sdk/lib/utils/nostr_timestamp.dart
git mv mobile/test/services/timestamp_test.dart mobile/packages/nostr_sdk/test/utils/nostr_timestamp_test.dart
```

- [ ] **Step 2: Export it from the `nostr_sdk` barrel**

In `mobile/packages/nostr_sdk/lib/nostr_sdk.dart`, insert into the existing alphabetical `utils/` block (currently `date_format_util`, `loopback_host`, `redact_http_headers_for_logs`, `relay_url_policy`, `string_util`), between `loopback_host` and `redact_http_headers_for_logs`:

```dart
export 'utils/nostr_timestamp.dart';
```

- [ ] **Step 3: Fix the moved test's imports**

Replace `import 'package:openvine/utils/nostr_timestamp.dart';` with `import 'package:nostr_sdk/nostr_sdk.dart';`.

The test also imports `package:unified_logger/unified_logger.dart`, which `nostr_sdk` does **not** depend on. Read the file: if the import is only log setup, delete it and any `Log.` calls. If it is load-bearing, add to `mobile/packages/nostr_sdk/pubspec.yaml` under `dev_dependencies:`:

```yaml
  unified_logger:
```

- [ ] **Step 4: Repoint the 9 remaining import sites**

Each currently reads `import 'package:openvine/utils/nostr_timestamp.dart';`. Replace with `import 'package:nostr_sdk/nostr_sdk.dart';` — **unless the file already imports that barrel**, in which case delete the line rather than duplicating the import.

```bash
cd mobile
grep -rln "package:openvine/utils/nostr_timestamp.dart" lib test integration_test
```

- [ ] **Step 5: Verify nothing still references the old path**

```bash
cd mobile && grep -rn "utils/nostr_timestamp" lib test integration_test || echo "clean"
```
Expected: `clean`.

- [ ] **Step 6: Run the moved test and the analyzer**

```bash
cd mobile/packages/nostr_sdk && mise exec -- flutter test test/utils/nostr_timestamp_test.dart
cd ../.. && mise exec -- flutter analyze lib test integration_test
```
Expected: tests pass; analyzer reports no issues.

- [ ] **Step 7: Confirm the `nostr_sdk` coverage gate still passes**

`nostr_sdk` gates at `min_coverage: 20`. Adding a well-covered file cannot lower it, but confirm:

```bash
cd mobile/packages/nostr_sdk && mise exec -- flutter test --coverage
```

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "refactor(nostr): move NostrTimestamp into nostr_sdk

It is 117 lines of pure Dart with zero imports, sitting in the app layer
while four lib files, five tests and one integration_test import it -- and
bookmarks_repository (#6969) needs it from a package, where package:openvine
is unreachable.

Refs #6969"
```

---

### Task 2: Scaffold the package and declare the `BookmarkSigner` port

**Files:**
- Create: `mobile/packages/bookmarks_repository/pubspec.yaml`
- Create: `mobile/packages/bookmarks_repository/analysis_options.yaml`
- Create: `mobile/packages/bookmarks_repository/lib/bookmarks_repository.dart` (barrel)
- Create: `mobile/packages/bookmarks_repository/lib/src/bookmark_signer.dart`
- Create: `mobile/packages/bookmarks_repository/test/src/bookmark_signer_test.dart`
- Modify: `mobile/pubspec.yaml` (`workspace:` list, alphabetically after `packages/blurhash_service`; and the dependency block)

**Interfaces:**
- Consumes: nothing.
- Produces: `abstract class BookmarkSigner` with `bool get isAuthenticated`, `String? get currentPublicKeyHex`, `NostrSigner? get currentIdentity`, and `Future<Event?> createAndSignEvent({required int kind, required String content, List<List<String>>? tags, int? createdAt})`.

- [ ] **Step 1: Create `pubspec.yaml`**

```yaml
name: bookmarks_repository
description: >
  Repository for the user's NIP-51 kind 10003 global bookmark list, including
  its encrypted private section.
version: 0.1.0+1
publish_to: none
resolution: workspace

environment:
  sdk: ^3.11.0

dependencies:
  meta: ^1.17.0
  nostr_client:
  nostr_sdk:
  shared_preferences: ^2.5.3
  unified_logger:

dev_dependencies:
  flutter_test:
    sdk: flutter
  mocktail: ^1.0.4
  very_good_analysis: ^10.2.0
```

- [ ] **Step 2: Create `analysis_options.yaml`**

```yaml
include: package:very_good_analysis/analysis_options.yaml
```

- [ ] **Step 3: Register the package in the workspace**

In `mobile/pubspec.yaml`, add to the `workspace:` list, alphabetically (after `  - packages/blurhash_service` on line 32):

```yaml
  - packages/bookmarks_repository
```

and add to `dependencies:` alphabetically (workspace members take no version constraint — match the bare form used by `content_blocklist_repository:` at line 219):

```yaml
  bookmarks_repository:
```

- [ ] **Step 4: Write the failing test for the port's contract**

Create `mobile/packages/bookmarks_repository/test/src/bookmark_signer_test.dart`. This test's job is to pin the **shape** — that a conforming implementation compiles and that `createdAt` is part of the contract. It fails today because the file does not exist.

```dart
// ABOUTME: Pins the BookmarkSigner contract the app layer must satisfy.
// ABOUTME: createdAt is load-bearing: kind 10003 is replaceable (#7635).

import 'package:bookmarks_repository/bookmarks_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

class _RecordingSigner implements BookmarkSigner {
  int? capturedCreatedAt;
  List<List<String>>? capturedTags;

  @override
  bool get isAuthenticated => true;

  @override
  String? get currentPublicKeyHex => 'a' * 64;

  @override
  NostrSigner? get currentIdentity => null;

  @override
  Future<Event?> createAndSignEvent({
    required int kind,
    required String content,
    List<List<String>>? tags,
    int? createdAt,
  }) async {
    capturedCreatedAt = createdAt;
    capturedTags = tags;
    return null;
  }
}

void main() {
  group(BookmarkSigner, () {
    test('carries createdAt through to the implementation', () async {
      final signer = _RecordingSigner();

      await signer.createAndSignEvent(
        kind: 10003,
        content: '',
        tags: const [
          ['e', 'abc'],
        ],
        createdAt: 1234567890,
      );

      expect(signer.capturedCreatedAt, equals(1234567890));
      expect(signer.capturedTags, equals(const [
        ['e', 'abc'],
      ]));
    });

    test('exposes the signer used for private-item crypto', () {
      expect(_RecordingSigner().currentIdentity, isNull);
      expect(_RecordingSigner().isAuthenticated, isTrue);
    });
  });
}
```

- [ ] **Step 5: Run it to confirm it fails**

```bash
cd mobile && mise exec -- flutter pub get
cd packages/bookmarks_repository && mise exec -- flutter test
```
Expected: FAIL — `Target of URI doesn't exist: 'package:bookmarks_repository/bookmarks_repository.dart'`.

- [ ] **Step 6: Write `lib/src/bookmark_signer.dart`**

```dart
// ABOUTME: Minimal signer contract for publishing the NIP-51 kind-10003 list.
// ABOUTME: Implemented at the app layer by AuthService.

import 'package:nostr_sdk/nostr_sdk.dart';

/// Minimal signer contract for publishing the NIP-51 kind-10003 bookmark list
/// without depending on the app's auth stack.
///
/// Implemented at the app layer by `AuthService`, which already implements the
/// sibling [BlockListSigner] for the kind-10000 mute list. Kept narrow on
/// purpose: it needs only [Event] and [NostrSigner] from `nostr_sdk`, so
/// neither this contract nor the repository depends on the app.
abstract class BookmarkSigner {
  /// Whether the current user is authenticated and can sign events.
  bool get isAuthenticated;

  /// The signed-in user's public key in hex, or `null` when signed out.
  String? get currentPublicKeyHex;

  /// The active signer, used for NIP-04/NIP-44 private-item crypto.
  ///
  /// `null` when signed out, or when the identity cannot sign.
  NostrSigner? get currentIdentity;

  /// Creates and signs an event, returning `null` if signing fails.
  ///
  /// [createdAt] overrides the signer's own clock. Kind 10003 is replaceable,
  /// so a publish must supersede the revision it replaces; two publishes
  /// inside the same second would otherwise sign a tie that NIP-01 can
  /// resolve against us (#7629, #7635).
  Future<Event?> createAndSignEvent({
    required int kind,
    required String content,
    List<List<String>>? tags,
    int? createdAt,
  });
}
```

- [ ] **Step 7: Write the barrel**

`mobile/packages/bookmarks_repository/lib/bookmarks_repository.dart`:

```dart
export 'src/bookmark_signer.dart';
```

- [ ] **Step 8: Run the test to confirm it passes**

```bash
cd mobile/packages/bookmarks_repository && mise exec -- flutter test
```
Expected: PASS, 2 tests.

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "refactor(bookmarks): scaffold bookmarks_repository and its signer port

BookmarkSigner names the four AuthService members the bookmark code uses, so
the code can move to a package where package:openvine is unreachable.

Refs #6969"
```

---

### Task 3: Move the repository code

The class moves **verbatim** apart from three mechanical substitutions. Do not reformat, reorder, reword a comment, or "improve" a log line — the diff must be reviewable as a move.

**Files:**
- Create: `mobile/packages/bookmarks_repository/lib/src/bookmark_item.dart`
- Create: `mobile/packages/bookmarks_repository/lib/src/bookmark_toggle_result.dart`
- Create: `mobile/packages/bookmarks_repository/lib/src/bookmarks_repository.dart`
- Modify: `mobile/packages/bookmarks_repository/lib/bookmarks_repository.dart` (barrel)
- Delete: `mobile/lib/services/bookmark_service.dart`

**Interfaces:**
- Consumes: `BookmarkSigner` (Task 2).
- Produces: `class BookmarkService` — **still under its old name at this point**; Task 7 renames it. Constructor `BookmarkService({required NostrClient nostrService, required BookmarkSigner authService, required SharedPreferences prefs, DateTime Function() now = DateTime.now})`. Public members: `globalBookmarks`, `hasUnreadablePrivateItems`, `syncGlobalBookmarks`, `toggleVideoInGlobalBookmarks`, `addToGlobalBookmarks`, `removeFromGlobalBookmarks`, `isInGlobalBookmarks`, `isVideoBookmarkedGlobally`, plus the six public constants. Also `BookmarkItem`, `BookmarkToggleResult`, `BookmarkToggleFailure`.

- [ ] **Step 1: Split the source into three files**

`git mv mobile/lib/services/bookmark_service.dart mobile/packages/bookmarks_repository/lib/src/bookmarks_repository.dart`, then lift two blocks out into their own files, cutting them **exactly** (comments included):

- `bookmark_item.dart` ← lines 15-67 of the original (`BookmarkItem`).
- `bookmark_toggle_result.dart` ← lines 69-124 (`BookmarkToggleResult` **and** `BookmarkToggleFailure`; they are a pair).
- `bookmarks_repository.dart` keeps the rest, including the private `_PrivateItemsState` and `_PrivateItemsRead` (lines 126-154), which are used only by the repository.

Each new file needs the two-line `// ABOUTME:` header the repo uses, plus its own imports (`package:meta/meta.dart` for `BookmarkItem`'s `@immutable`).

- [ ] **Step 2: Apply the three mechanical substitutions**

In `bookmarks_repository.dart` only:

| From | To |
|---|---|
| `import 'package:openvine/services/auth_service.dart';` | `import 'package:bookmarks_repository/src/bookmark_signer.dart';` |
| `import 'package:openvine/utils/nostr_timestamp.dart';` | delete — `NostrTimestamp` now arrives via the existing `package:nostr_sdk/nostr_sdk.dart` import (Task 1) |
| `required AuthService authService` / `final AuthService _authService;` | `required BookmarkSigner authService` / `final BookmarkSigner _authService;` |

Add `import 'package:bookmarks_repository/src/bookmark_item.dart';` and `.../bookmark_toggle_result.dart'`.

**Leave the parameter named `authService` and the field `_authService`** for now. Renaming them is Task 7's job; keeping them here makes this diff a pure move.

- [ ] **Step 3: Verify no app-layer import survives**

```bash
cd mobile && grep -rn "package:openvine" packages/bookmarks_repository/ || echo "clean"
```
Expected: `clean`. A `package:openvine` import inside a package is a hard error — the package cannot see the app.

- [ ] **Step 4: Export the public types from the barrel**

```dart
export 'src/bookmark_item.dart';
export 'src/bookmark_signer.dart';
export 'src/bookmark_toggle_result.dart';
export 'src/bookmarks_repository.dart';
```

- [ ] **Step 5: Confirm the package analyzes**

```bash
cd mobile/packages/bookmarks_repository && mise exec -- flutter analyze
```
Expected: no issues. The app will not analyze yet — Task 5 rewires it.

- [ ] **Step 6: Assert the frozen storage keys, so a future rename cannot pass silently**

Append to `test/src/bookmark_signer_test.dart`? No — create `test/src/storage_keys_test.dart`:

```dart
// ABOUTME: Freezes the SharedPreferences key values.
// ABOUTME: UserDataCleanupService mirrors them as bare literals (#8314).

import 'package:bookmarks_repository/bookmarks_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('storage keys', () {
    // These exact strings are duplicated as literals in
    // mobile/lib/services/user_data_cleanup_service.dart:50-51, which clears
    // them on identity change. There is no compile-time link between the two
    // (#8314), so changing either value here silently breaks that cleanup.
    test('are byte-identical to what UserDataCleanupService clears', () {
      expect(BookmarkService.globalBookmarksStorageKey, 'global_bookmarks');
      expect(
        BookmarkService.globalBookmarksRevisionStorageKey,
        'global_bookmarks_revision',
      );
    });
  });
}
```

- [ ] **Step 7: Run it**

```bash
cd mobile/packages/bookmarks_repository && mise exec -- flutter test test/src/storage_keys_test.dart
```
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "refactor(bookmarks): move the bookmark code into the package

Verbatim move apart from three substitutions: the AuthService import and
type become BookmarkSigner, and NostrTimestamp now arrives via nostr_sdk.
BookmarkItem and BookmarkToggleResult/Failure split into their own files.

The storage key values are frozen by a test because
UserDataCleanupService mirrors them as bare string literals (#8314).

Refs #6969"
```

---

### Task 4: Move the test suite

**Files:**
- Create: `mobile/packages/bookmarks_repository/test/src/bookmarks_repository_test.dart` (moved, 1948 lines, 71 tests)
- Delete: `mobile/test/services/bookmark_service_test.dart`

**Interfaces:**
- Consumes: everything Task 3 produced.
- Produces: `_MockBookmarkSigner`, and the helper seams `stubRelay`, `stubRelayForSettlementMode`, `seedCachedBookmarks`, `stubPublishRejected`, `capturedSettlementDemands`, `encryptToSelf`, `encryptToSelfNip04`, `decryptToSelf` — Task 8 reuses these.

- [ ] **Step 1: Move the file**

```bash
git mv mobile/test/services/bookmark_service_test.dart \
       mobile/packages/bookmarks_repository/test/src/bookmarks_repository_test.dart
```

- [ ] **Step 2: Repoint its four app-layer imports**

The suite imports exactly four `package:openvine/` symbols (original lines 16-19):

| Import | Action |
|---|---|
| `package:openvine/services/bookmark_service.dart` | → `package:bookmarks_repository/bookmarks_repository.dart` |
| `package:openvine/utils/nostr_timestamp.dart` | → delete; `NostrTimestamp` comes from the existing `package:nostr_sdk/nostr_sdk.dart` import |
| `package:openvine/services/auth_service.dart` | → delete (see Step 3) |
| `package:openvine/services/auth/nostr_identity.dart` | → **problem**; see Step 4 |

- [ ] **Step 3: Swap the AuthService mock for a signer mock**

Line 24 currently reads `class _MockAuthService extends Mock implements AuthService {}`. Replace with:

```dart
class _MockBookmarkSigner extends Mock implements BookmarkSigner {}
```

Rename every use of `_MockAuthService` to `_MockBookmarkSigner`. The suite stubs only `isAuthenticated`, `currentPublicKeyHex`, `currentIdentity` and `createAndSignEvent` — all four are on the port, so no stub changes are needed beyond the type name.

- [ ] **Step 4: Re-express the real identity against `NostrSigner`**

`setUp` (original line ~170) builds a **real** `LocalNostrIdentity` so NIP-44/NIP-04 are genuine crypto rather than stubs — the file explains why at lines 41-46 (`NostrIdentity` is `sealed` and cannot be mocked, and only a genuine payload exercises the decrypt branch instead of the failure path).

`LocalNostrIdentity` lives in the app layer and **cannot be imported here**. Its declaration is `class LocalNostrIdentity extends NostrIdentity implements IsolateDecryptSigner`, and `sealed class NostrIdentity implements NostrSigner` — so the *capability* the test needs is `NostrSigner`.

Replace it with `nostr_sdk`'s own local-key signer. Find the concrete `NostrSigner` implementation in `nostr_sdk` that wraps a private key:

```bash
cd mobile && grep -rn "implements NostrSigner\|extends NostrSigner" packages/nostr_sdk/lib
```

Use that class, constructed from the same `generatePrivateKey()` the suite already imports. The stub becomes:

```dart
when(() => mockSigner.currentIdentity).thenReturn(localSigner);
```

**If and only if `nostr_sdk` has no such concrete signer**, write a small `_LocalKeySigner implements NostrSigner` test double in the suite that performs real NIP-04/NIP-44 using `nostr_sdk`'s crypto helpers. Do **not** stub the crypto out — the 18 private-item tests exist to exercise it, and stubbing would make them unable to fail.

- [ ] **Step 5: Run the whole moved suite**

```bash
cd mobile/packages/bookmarks_repository && mise exec -- flutter test
```
Expected: **71 tests pass** (plus the 3 from Tasks 2-3 = 74 total). Any failure here is a move defect, not a flake — compare against `git show HEAD~1:mobile/test/services/bookmark_service_test.dart`.

- [ ] **Step 6: Confirm coverage matches the pre-move measurement**

```bash
cd mobile/packages/bookmarks_repository && mise exec -- flutter test --coverage
mise exec -- dart pub global run coverage:format_coverage --lcov --in=coverage --out=coverage/lcov.info --report-on=lib 2>/dev/null || true
```
Expected: `src/bookmarks_repository.dart` around **90.75%** (265/292 lines), matching the app-layer measurement. A materially lower number means a test stopped exercising something.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "test(bookmarks): move the suite into the package

71 tests, unchanged in substance. _MockAuthService becomes
_MockBookmarkSigner, and the real LocalNostrIdentity -- app-layer and sealed
-- is re-expressed against NostrSigner so the private-item tests keep doing
genuine NIP-44/NIP-04 crypto rather than stubbing it.

Refs #6969"
```

---

### Task 5: Rewire the app layer and delete the old files

**Files:**
- Modify: `mobile/lib/services/auth_service.dart:13` (show clause), `:111` (implements clause)
- Modify: `mobile/lib/providers/repository_providers.dart:41` (import), `:570-582` (provider)
- Modify: `mobile/lib/blocs/profile_saved_videos/profile_saved_videos_bloc.dart:18`, and `profile_saved_videos_event.dart`, `profile_saved_videos_state.dart` (imports only)
- Modify: `mobile/lib/blocs/share_sheet/share_sheet_bloc.dart:17`
- Modify: `mobile/lib/widgets/video_feed_item/actions/share_action_button.dart:28`
- Modify: `mobile/test/blocs/profile_saved_videos/profile_saved_videos_bloc_test.dart:15`, `mobile/test/blocs/share_sheet/share_sheet_bloc_test.dart:17`, `mobile/test/widgets/share_video_menu_comprehensive_test.dart:22`
- Regenerate: `mobile/lib/providers/repository_providers.g.dart`

**Interfaces:**
- Consumes: the package barrel from Tasks 2-4.
- Produces: `bookmarkServiceProvider` unchanged in shape — still `@riverpod`, still `Future<BookmarkService>`.

- [ ] **Step 1: Make `AuthService` implement the port**

At `mobile/lib/services/auth_service.dart:111`:

```dart
class AuthService implements BackgroundAwareService, BlockListSigner, BookmarkSigner {
```

Add `import 'package:bookmarks_repository/bookmarks_repository.dart' show BookmarkSigner;`.

**No `AuthService` body changes are needed.** Every member already exists with a compatible signature: `isAuthenticated`, `currentPublicKeyHex`, `createAndSignEvent(… , int? createdAt)` at `:3640-3646`, and `NostrIdentity? get currentIdentity` at `:293` — which satisfies `NostrSigner? get currentIdentity` by return-type covariance, since `sealed class NostrIdentity implements NostrSigner`.

- [ ] **Step 2: Repoint the eight remaining import sites**

Every `import 'package:openvine/services/bookmark_service.dart';` becomes `import 'package:bookmarks_repository/bookmarks_repository.dart';`.

```bash
cd mobile && grep -rln "services/bookmark_service.dart" lib test integration_test
```

- [ ] **Step 3: Leave the provider's shape alone**

`mobile/lib/providers/repository_providers.dart:570-582` keeps `@riverpod`, keeps `async`, keeps `Future<BookmarkService>`. Only the import changes.

Add this comment directly above the annotation so the next reader knows it is deliberate:

```dart
/// Bookmark service for NIP-51 bookmarks.
///
/// Deliberately left as an autoDispose `Future` provider by the #6969
/// extraction so that move stayed behaviour-preserving. Both consumers use
/// `ref.read(...future)`, so every read builds a fresh instance and drops its
/// in-memory cache and serialization queue — tracked as #7596, fixed next.
@riverpod
```

- [ ] **Step 4: Regenerate the Riverpod output**

```bash
cd mobile && mise exec -- dart run build_runner build --delete-conflicting-outputs
git status --short   # expect repository_providers.g.dart
```

Confirm the generated flag is unchanged — `isAutoDispose: true` for `bookmarkServiceProvider`. If it flipped, the annotation was edited by mistake.

- [ ] **Step 5: Confirm the old file is gone and nothing references it**

```bash
cd mobile && test ! -f lib/services/bookmark_service.dart && echo "deleted"
grep -rn "BookmarkService" lib | grep -v "bookmarks_repository" | head
```

- [ ] **Step 6: Analyze and run every affected suite**

```bash
cd mobile
mise exec -- flutter analyze lib test integration_test
mise exec -- flutter test \
  test/blocs/profile_saved_videos/profile_saved_videos_bloc_test.dart \
  test/blocs/share_sheet/share_sheet_bloc_test.dart \
  test/widgets/share_video_menu_comprehensive_test.dart \
  test/services/user_data_cleanup_service_test.dart
```
Expected: analyzer clean; all suites pass.

- [ ] **Step 7: Run the ratchets that this task can move**

```bash
cd /Users/meylisannagurbanov/512-SSD-data/divinevideo/divine-mobile/.worktrees/6969-bookmarks-repo
bash mobile/scripts/check_untested_services_floor.sh
bash mobile/scripts/check_test_unit_structure.sh
bash mobile/scripts/check_ungrouped_tests.sh
bash mobile/scripts/check_skip_ceiling.sh
bash mobile/scripts/check_placeholder_tests.sh
bash mobile/scripts/check_layer_direction.sh
bash mobile/scripts/check_dependency_provenance.sh
```
Expected: all pass. The untested-services floor is neutral — `bookmark_service` leaves both the service set and the test set at once (measured: 35 before, 35 after). **If a ratchet reports a stale baseline because the branch is behind `origin/main`, rebase before regenerating anything** — a shrink-only ratchet run on a stale branch produces a false red.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "refactor(bookmarks): point the app at bookmarks_repository

AuthService implements BookmarkSigner the same way it already implements
BlockListSigner; no AuthService body changes were needed.

The provider keeps its autoDispose Future shape on purpose so this stays a
behaviour-preserving move. That reproduces #7596, which lands next.

Closes #6969"
```

---

### Task 6: Add the package CI workflow

**Files:**
- Create: `.github/workflows/bookmarks_repository.yaml`

**Interfaces:**
- Consumes: the package from Tasks 2-5.
- Produces: a `Bookmarks Repository CI` check on PRs touching the package.

- [ ] **Step 1: Create the workflow, cloned from `likes_repository.yaml`**

```yaml
# ABOUTME: CI workflow for the bookmarks_repository package.
# ABOUTME: Runs tests, formatting, and analysis only when its files change.

name: Bookmarks Repository CI

on:
  push:
    branches: [main]
    paths:
      - "mobile/packages/bookmarks_repository/**"
      - ".github/workflows/bookmarks_repository.yaml"
  pull_request:
    branches: [main]
    paths:
      - "mobile/packages/bookmarks_repository/**"
      - ".github/workflows/bookmarks_repository.yaml"

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  build:
    uses: VeryGoodOpenSource/very_good_workflows/.github/workflows/flutter_package.yml@v1
    with:
      working_directory: "mobile/packages/bookmarks_repository"
      flutter_version: "3.44.9"
      min_coverage: 100
```

`min_coverage` is stated explicitly rather than omitted: 28 existing package workflows omit the key, and the VeryGood default is 100, so an omitted key gates at 100 without saying so.

- [ ] **Step 2: Commit**

```bash
git add .github/workflows/bookmarks_repository.yaml
git commit -m "ci(bookmarks): add the bookmarks_repository package workflow

Refs #6969"
```

---

### Task 7: Rename `BookmarkService` → `BookmarksRepository`

Its own commit so it can be reverted alone, and so Tasks 3-5 read as a pure move.

**Files:**
- Modify: every file touched in Tasks 3-6 that names the type, plus `mobile/packages/bookmarks_repository/lib/src/bookmarks_repository.dart`

**Interfaces:**
- Consumes: everything above.
- Produces: `BookmarksRepository` as the exported type name; `bookmarksRepositoryProvider` as the provider name.

- [ ] **Step 1: Rename the type and its constructor parameter**

`BookmarkService` → `BookmarksRepository` throughout. While here, rename the now-misleading constructor parameter and field, since the type they hold changed in Task 3:

- `required BookmarkSigner authService` → `required BookmarkSigner signer`
- `final BookmarkSigner _authService;` → `final BookmarkSigner _signer;`
- every `_authService.` → `_signer.`

Also rename `nostrService` → `nostrClient` to match every sibling package's constructor, and `_nostrService` → `_nostrClient`.

- [ ] **Step 2: Rename the provider**

In `mobile/lib/providers/repository_providers.dart`, `bookmarkService` → `bookmarksRepository` (the generated provider becomes `bookmarksRepositoryProvider`). Update the two `ref.read(...)` call sites at `mobile/lib/screens/saved_videos_screen.dart:45` and `mobile/lib/widgets/video_feed_item/actions/share_action_button.dart:164`, plus the bloc constructor parameter names (`bookmarkServiceFuture` → `bookmarksRepositoryFuture`, `bookmarkService` → `bookmarksRepository`).

- [ ] **Step 3: Regenerate and verify nothing is left behind**

```bash
cd mobile && mise exec -- dart run build_runner build --delete-conflicting-outputs
grep -rn "BookmarkService\|bookmarkServiceProvider" lib test integration_test packages || echo "clean"
```
Expected: `clean`.

- [ ] **Step 4: Analyze, format, and run every affected suite**

```bash
cd mobile
mise exec -- dart format lib test packages/bookmarks_repository
mise exec -- flutter analyze lib test integration_test
mise exec -- flutter test \
  test/blocs/profile_saved_videos/profile_saved_videos_bloc_test.dart \
  test/blocs/share_sheet/share_sheet_bloc_test.dart \
  test/widgets/share_video_menu_comprehensive_test.dart
cd packages/bookmarks_repository && mise exec -- flutter test
```
Expected: all green.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor(bookmarks): rename BookmarkService to BookmarksRepository

Every sibling package names its type after the package. A 'Service'
exported from a repositories package is the layering confusion #6969 is
about. Also renames the constructor parameters the move made misleading:
authService -> signer, nostrService -> nostrClient.

Refs #6969"
```

---

### Task 8: Cover the thirteen unexercised error paths

Measured before the move: **90.75%** (265/292). All 27 uncovered lines are error paths that no test enters. `min_coverage: 100` needs them exercised. These are reachable-but-unexercised, so `// coverage:ignore-line` is **not** available — `testing.md` reserves it for genuinely unreachable lines.

**Files:**
- Modify: `mobile/packages/bookmarks_repository/test/src/bookmarks_repository_test.dart`

**Interfaces:**
- Consumes: the helper seams from Task 4.
- Produces: nothing; tests only.

- [ ] **Step 1: List the exact uncovered lines against the moved file**

```bash
cd mobile/packages/bookmarks_repository && mise exec -- flutter test --coverage
python3 - <<'PY'
cur=None
for line in open('coverage/lcov.info'):
    line=line.strip()
    if line.startswith('SF:'): cur=line[3:]
    elif line.startswith('DA:') and cur and 'bookmarks_repository.dart' in cur:
        ln,cnt=line[3:].split(',')[:2]
        if int(cnt) == 0: print(ln)
    elif line=='end_of_record': cur=None
PY
```

Pre-move these were, in the app-layer file: 305, 575-576, 747, 759-760, 781-782, 826, 866-867, 885-886, 933, 1003-1004, 1032, 1041, 1051-1052, 1131, 1203-1204, 1222-1223, 1255-1256. Line numbers shift after the Task 3 split — trust the fresh lcov output, not this list.

- [ ] **Step 2: Add one test per error path, in the group that owns it**

Thirteen tests. Each must fail if its `catch` is removed. Group placement follows the existing structure:

| Target | Group | How to trigger |
|---|---|---|
| `_serialized` `completeError` | `concurrent syncs and publishes` | queue an op whose body throws; assert the returned future rejects **and** a later queued op still runs |
| sync failure log | `syncGlobalBookmarks` | `stubRelay` throws |
| add failure log | `addToGlobalBookmarks` | signer's `createAndSignEvent` throws |
| "already in bookmarks" debug | `addToGlobalBookmarks` | add the same item twice; assert one publish |
| add warning branch | `addToGlobalBookmarks` | `isAuthenticated` false |
| remove failure log | `removeFromGlobalBookmarks` | signer throws |
| "not found" warning | `removeFromGlobalBookmarks` | remove an absent item; assert no publish |
| remove warning branch | `removeFromGlobalBookmarks` | not authenticated |
| publish failure log | `toggleVideoInGlobalBookmarks` | `stubPublishRejected` |
| publish warning branch | `toggleVideoInGlobalBookmarks` | not authenticated |
| encrypt failure | `NIP-51 private items` | `currentIdentity.nip44Encrypt` throws |
| encrypt round-trip mismatch | `NIP-51 private items` | `nip44Decrypt` returns text ≠ plaintext |
| decrypt warning | `NIP-51 private items` → `unreadable content` | `nip44Decrypt` throws |
| prefs load failure | new group `SharedPreferences failures` | seed a malformed JSON value under `global_bookmarks`; assert construction still yields an empty list |
| prefs revision load failure | same | malformed value under `global_bookmarks_revision` |
| prefs save failure | same | a `SharedPreferences` double whose `setString` throws |

Assert observable behaviour, not that a log ran — e.g. "a malformed cached snapshot yields an empty list rather than throwing", "a failed publish leaves `isVideoBookmarkedGlobally` unchanged". A test asserting only that a `Log.` call happened cannot fail for a good reason.

- [ ] **Step 3: Confirm 100%**

```bash
cd mobile/packages/bookmarks_repository && mise exec -- flutter test --coverage
```
Then recompute the percentage with the Step 1 script. Expected: **100.00%**, zero uncovered lines.

- [ ] **Step 4: Prove the new tests can fail**

For three of them, temporarily delete the `catch` block they target, re-run, confirm red, restore. A test that stays green with its target removed is not testing anything.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "test(bookmarks): cover the thirteen unexercised error paths

Coverage was 90.75% (265/292) and every uncovered line was an error path no
test entered -- reachable, so coverage:ignore was not available. Each test
asserts observable behaviour rather than that a log line ran.

Refs #6969"
```

---

### Task 9: Rebase, verify, and open the PR

- [ ] **Step 1: Rebase onto fresh `origin/main`**

```bash
cd /Users/meylisannagurbanov/512-SSD-data/divinevideo/divine-mobile/.worktrees/6969-bookmarks-repo
git fetch origin && git rebase origin/main
```
Resolve any conflict, then re-run the full verification below. Never merge `main` in.

- [ ] **Step 2: Full local verification**

```bash
cd mobile
mise exec -- flutter analyze lib test integration_test
cd packages/bookmarks_repository && mise exec -- flutter test --coverage
cd ../nostr_sdk && mise exec -- flutter test
cd ../.. && mise exec -- flutter test test/blocs test/widgets/share_video_menu_comprehensive_test.dart
cd .. && for s in mobile/scripts/check_*.sh; do echo "== $s"; bash "$s" || echo "FAILED $s"; done
```

- [ ] **Step 3: Push and open the PR**

```bash
git push --force-with-lease -u origin refactor/6969-bookmarks-repository
```

Title (Conventional Commit, set at creation — editing later does not retrigger `semantic_pr`):

```
refactor(bookmarks): extract a bookmarks_repository package
```

The body must state, in its own section:

- The two stale claims in #6969's body (line count; the kind-30003 entanglement deleted by #6966), so a reviewer is not confused by the mismatch.
- That the provider **deliberately** reproduces #7596, and that the fix lands next.
- The rename and the `NostrTimestamp` move as **unrequested changes**, called out separately from the extraction.
- The three issues filed during investigation: #8313, #8314, #8315.

- [ ] **Step 4: Request review**

```bash
gh pr edit <n> --add-reviewer divinevideo/reviewers
```

- [ ] **Step 5: Watch checks to completion before any handback**

```bash
gh pr checks <n> --watch
```

Confirm the watched run is for the current head — `gh pr checks --watch` can settle on the previous head:

```bash
gh pr view <n> --json headRefOid --jq .headRefOid
```

Do not report the task complete while checks are red or still running.

---

## Self-Review

**Spec coverage.** §2 package shape → Tasks 2, 3. §2 frozen storage keys → Task 3 Step 6. §3 signer port → Task 2. §3 rejected unsigned-publish → encoded as "leave `createAndSignEvent` routed through the port" in Task 3 Step 2. §4 test move → Task 4; the `LocalNostrIdentity` problem → Task 4 Step 4. §4 coverage to 100 → Task 8. §5 CI → Task 6; ratchets → Task 5 Step 7; workspace → Task 2 Step 3. §6 rename → Task 7; deliberate #7596 reproduction → Task 5 Step 3. §7 `NostrTimestamp` → Task 1. §8 four commits → Tasks 1, 3-5, 7, 8 (Tasks 2 and 6 add two more commits than the spec's four; that is a deliberate refinement — scaffolding and CI are separately revertable). §9 risks → each has a verification step. No spec requirement is unimplemented.

**Placeholder scan.** No TBD/TODO. Two steps are conditional rather than fixed, and both name the condition and the decision rule explicitly: Task 1 Step 3 (`unified_logger` — read the file, drop or add) and Task 4 Step 4 (find `nostr_sdk`'s concrete `NostrSigner`, else write a real-crypto double). These are genuinely discoverable only at the file, and the fallback is specified.

**Type consistency.** `BookmarkSigner`'s four members are identical in Task 2 (declaration), Task 3 Step 2 (consumption), Task 4 Step 3 (mock), Task 5 Step 1 (`AuthService implements`). The type is `BookmarkService` through Tasks 3-6 and becomes `BookmarksRepository` only in Task 7 — intentional, and stated in each affected task's **Interfaces** block. Task 3's storage-keys test uses `BookmarkService`, which is correct at that point; Task 7 Step 3's `grep` sweep catches it.

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-08-29-bookmarks-repository-extraction.md`. Two execution options:

1. **Subagent-Driven (recommended)** — a fresh subagent per task, review between tasks, fast iteration.
2. **Inline Execution** — execute tasks in this session with checkpoints for review.
