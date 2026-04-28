# Subtitle Edit (Author-Only) Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let an authenticated video author fix their own VTT captions in a focused editor; persist edits via a Kind 39307 publish + `PUT https://media.divine.video/v1/{sha256}/vtt` dual-write.

**Architecture:** UI (BlocProvider page → View) → BLoC (`SubtitleEditorCubit`) → Repository (`SubtitleEditRepository`, in new `mobile/packages/subtitle_repository/`) → Clients (`BlossomVttClient` + existing `NostrClient`). VTT generation lives in the cubit (uses existing `SubtitleService`); repository takes raw bytes and a pre-signed `Event` so the package stays free of `AuthService`/Flutter deps.

**Tech Stack:** Flutter, `flutter_bloc`, `equatable`, `http` (for Blossom PUT), existing `nostr_client` + `nostr_sdk`, `mocktail`, `bloc_test`, Patrol (E2E).

**Spec:** `docs/superpowers/specs/2026-04-26-subtitle-edit-design.md`

**Project rules to follow throughout:**
- `mobile/.claude/CLAUDE.md` (worktree-first, BLoC for new features, never truncate Nostr IDs)
- `mobile/.claude/rules/architecture.md` (UI → BLoC → Repository → Client; no BLoC↔BLoC)
- `mobile/.claude/rules/state_management.md` (no error strings in state — use `addError`; use `BlocSelector`)
- `mobile/.claude/rules/testing.md` (file structure mirrors lib/, descriptive names, single-purpose tests)
- `mobile/.claude/rules/code_style.md` (widgets-not-methods, no hardcoded values)
- `mobile/.claude/rules/ui_theming.md` (VineTheme, dark mode, DivineIcon)
- 100% coverage on new files (project CI policy)

---

## File Structure

**New package:**
```
mobile/packages/subtitle_repository/
├── pubspec.yaml
├── analysis_options.yaml
├── README.md
├── lib/
│   ├── subtitle_repository.dart                     # barrel
│   └── src/
│       ├── blossom_vtt_client.dart                  # HTTP PUT to Blossom
│       ├── blossom_vtt_exception.dart               # typed errors
│       ├── save_result.dart                         # enum: full | partial
│       └── subtitle_edit_repository.dart            # orchestrates dual-write
└── test/
    ├── blossom_vtt_client_test.dart
    └── subtitle_edit_repository_test.dart
```

**New screen:**
```
mobile/lib/screens/subtitle_editor/
├── subtitle_editor.dart                             # barrel
├── cubit/
│   ├── editable_cue.dart
│   ├── subtitle_editor_cubit.dart
│   └── subtitle_editor_state.dart
└── view/
    ├── subtitle_editor_page.dart                    # BlocProvider host
    ├── subtitle_editor_view.dart                    # main UI
    └── widgets/
        ├── cue_row.dart
        ├── single_cue_fallback.dart
        └── widgets.dart                             # barrel
```

**New tests:**
```
mobile/test/screens/subtitle_editor/
├── cubit/
│   └── subtitle_editor_cubit_test.dart
└── view/
    ├── subtitle_editor_view_test.dart
    └── widgets/
        ├── cue_row_test.dart
        └── single_cue_fallback_test.dart

mobile/test/services/subtitle_service_test.dart      # extend (or create)
mobile/integration_test/edit_captions_journey_test.dart
```

**Modify:**
- `mobile/pubspec.yaml` — add `subtitle_repository` path dep.
- `mobile/lib/widgets/video_feed_item/actions/cc_action_button.dart` — long-press for own videos.
- `mobile/lib/widgets/video_feed_item/metadata/metadata_expanded_sheet.dart` — add "Edit captions" row for own videos.
- `mobile/lib/router/app_router.dart` — add `/edit-captions/:videoDTag` typed route.
- `mobile/test/widgets/video_feed_item/actions/cc_action_button_test.dart` — add long-press tests.

---

## Chunk 1: Foundation — package skeleton + Blossom client (TDD)

### Task 1.1: Create the `subtitle_repository` package skeleton

**Files:**
- Create: `mobile/packages/subtitle_repository/pubspec.yaml`
- Create: `mobile/packages/subtitle_repository/analysis_options.yaml`
- Create: `mobile/packages/subtitle_repository/README.md`
- Create: `mobile/packages/subtitle_repository/lib/subtitle_repository.dart`

- [ ] **Step 1: Write `pubspec.yaml`**

```yaml
name: subtitle_repository
description: Repository for editing video subtitle (Kind 39307) tracks with dual-write to Nostr relay and Blossom media server.
version: 0.1.0+1
publish_to: none
resolution: workspace

environment:
  sdk: ^3.11.0

dependencies:
  equatable: ^2.0.5
  http: ^1.2.0
  meta: ^1.16.0
  nostr_sdk:
    path: ../nostr_sdk
  nostr_client:
    path: ../nostr_client

dev_dependencies:
  mocktail: ^1.0.4
  test: ^1.26.3
  very_good_analysis: ^10.0.0
```

- [ ] **Step 2: Write `analysis_options.yaml`**

```yaml
include: package:very_good_analysis/analysis_options.yaml
```

- [ ] **Step 3: Write `README.md`**

```markdown
# subtitle_repository

Repository for editing a video's subtitle track. Dual-writes a Kind 39307
Nostr event (signed source of truth) and a `PUT /v1/{sha256}/vtt` to the
Blossom media server (cache).

Author-only writes in v1.
```

- [ ] **Step 4: Write empty barrel `lib/subtitle_repository.dart`**

```dart
// ABOUTME: Public surface of the subtitle_repository package.
// ABOUTME: Re-exports the repository, client, result, and exception types.
```

- [ ] **Step 5: Run `flutter pub get` from `mobile/`**

Expected: package resolves, no errors. Run from `mobile/`:

```bash
cd mobile && flutter pub get
```

(If pubspec workspace listing fails, append `subtitle_repository:` `path: packages/subtitle_repository` under `dependencies:` in `mobile/pubspec.yaml` first — see Task 5.1.)

- [ ] **Step 6: Commit**

```bash
git add mobile/packages/subtitle_repository
git commit -m "feat(subtitle_repository): scaffold package"
```

---

### Task 1.2: Define `SaveResult` and `BlossomVttException`

**Files:**
- Create: `mobile/packages/subtitle_repository/lib/src/save_result.dart`
- Create: `mobile/packages/subtitle_repository/lib/src/blossom_vtt_exception.dart`
- Modify: `mobile/packages/subtitle_repository/lib/subtitle_repository.dart`

- [ ] **Step 1: Write `save_result.dart`**

```dart
// ABOUTME: Outcome of a dual-write subtitle save.
// ABOUTME: `full` = relay + Blossom both succeeded; `partial` = relay
// ABOUTME: succeeded but Blossom failed (cache will heal via reindex).

/// Outcome of [SubtitleEditRepository.save].
enum SaveResult {
  /// Kind 39307 was published AND the Blossom PUT returned 200.
  full,

  /// Kind 39307 was published, but the Blossom PUT failed.
  /// The cache will heal once funnelcake reindexes the new event.
  partial,
}
```

- [ ] **Step 2: Write `blossom_vtt_exception.dart`**

```dart
// ABOUTME: Typed errors thrown by [BlossomVttClient] for non-2xx responses.
// ABOUTME: Maps each documented status code to a recognisable subtype.

/// Base type for all Blossom VTT write failures.
sealed class BlossomVttException implements Exception {
  const BlossomVttException(this.statusCode, this.message);
  final int statusCode;
  final String message;

  @override
  String toString() => 'BlossomVttException($statusCode): $message';
}

class BlossomVttBadRequest extends BlossomVttException {
  const BlossomVttBadRequest(String message) : super(400, message);
}

class BlossomVttUnauthorized extends BlossomVttException {
  const BlossomVttUnauthorized(String message) : super(401, message);
}

class BlossomVttForbidden extends BlossomVttException {
  const BlossomVttForbidden(String message) : super(403, message);
}

class BlossomVttNotFound extends BlossomVttException {
  const BlossomVttNotFound(String message) : super(404, message);
}

class BlossomVttConflict extends BlossomVttException {
  const BlossomVttConflict(String message) : super(409, message);
}

class BlossomVttServerError extends BlossomVttException {
  const BlossomVttServerError(int statusCode, String message)
      : super(statusCode, message);
}
```

- [ ] **Step 3: Update barrel**

Replace `lib/subtitle_repository.dart` contents with:

```dart
// ABOUTME: Public surface of the subtitle_repository package.
// ABOUTME: Re-exports the repository, client, result, and exception types.

export 'src/blossom_vtt_exception.dart';
export 'src/save_result.dart';
```

- [ ] **Step 4: Commit**

```bash
git add mobile/packages/subtitle_repository
git commit -m "feat(subtitle_repository): add SaveResult + BlossomVttException"
```

---

### Task 1.3: TDD `BlossomVttClient` — happy path

**Files:**
- Create: `mobile/packages/subtitle_repository/test/blossom_vtt_client_test.dart`
- Create: `mobile/packages/subtitle_repository/lib/src/blossom_vtt_client.dart`

The client takes a pre-built NIP-98 `Authorization` header value (cubit owns NIP-98 construction), the sha256, and the VTT body. Keeps the package free of signing logic.

- [ ] **Step 1: Write the failing test (happy path)**

Create `test/blossom_vtt_client_test.dart`:

```dart
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:subtitle_repository/src/blossom_vtt_client.dart';
import 'package:subtitle_repository/subtitle_repository.dart';
import 'package:test/test.dart';

class _MockHttpClient extends Mock implements http.Client {}

class _FakeUri extends Fake implements Uri {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeUri());
  });

  group(BlossomVttClient, () {
    late http.Client httpClient;
    late BlossomVttClient client;

    const sha256 =
        '5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8';
    const vtt = 'WEBVTT\n\n00:00:00.000 --> 00:00:01.000\nhello\n';
    const auth = 'Nostr base64encodedevent==';

    setUp(() {
      httpClient = _MockHttpClient();
      client = BlossomVttClient(
        httpClient: httpClient,
        baseUri: Uri.parse('https://media.divine.video'),
      );
    });

    group('put', () {
      test('PUTs VTT to /v1/<sha256>/vtt with NIP-98 header on 200', () async {
        when(() => httpClient.put(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            )).thenAnswer(
          (_) async => http.Response('', 200),
        );

        await client.put(sha256: sha256, vtt: vtt, nip98Authorization: auth);

        final captured = verify(() => httpClient.put(
              captureAny(),
              headers: captureAny(named: 'headers'),
              body: captureAny(named: 'body'),
            )).captured;

        final uri = captured[0] as Uri;
        final headers = captured[1] as Map<String, String>;
        final body = captured[2] as String;

        expect(uri.toString(),
            equals('https://media.divine.video/v1/$sha256/vtt'));
        expect(headers['Authorization'], equals(auth));
        expect(headers['Content-Type'], equals('text/vtt'));
        expect(body, equals(vtt));
      });
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd mobile/packages/subtitle_repository && dart test test/blossom_vtt_client_test.dart
```

Expected: COMPILE FAIL — `BlossomVttClient` not defined.

- [ ] **Step 3: Write minimal implementation to pass**

Create `lib/src/blossom_vtt_client.dart`:

```dart
// ABOUTME: HTTP client for `PUT /v1/{sha256}/vtt` on the Blossom media server.
// ABOUTME: Caller supplies the NIP-98 Authorization header value.

import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';
import 'package:subtitle_repository/src/blossom_vtt_exception.dart';

/// Writes a corrected VTT file for the video identified by [sha256] to the
/// Blossom media server. The caller must build and pass the NIP-98
/// `Authorization` header value (the package stays free of signing deps).
class BlossomVttClient {
  BlossomVttClient({
    required http.Client httpClient,
    required Uri baseUri,
  })  : _httpClient = httpClient,
        _baseUri = baseUri;

  final http.Client _httpClient;
  final Uri _baseUri;

  /// PUT the [vtt] body to `<baseUri>/v1/<sha256>/vtt`.
  ///
  /// Throws a [BlossomVttException] subtype on non-2xx responses.
  @visibleForTesting
  static const contentType = 'text/vtt';

  Future<void> put({
    required String sha256,
    required String vtt,
    required String nip98Authorization,
  }) async {
    final uri = _baseUri.replace(path: '/v1/$sha256/vtt');
    final response = await _httpClient.put(
      uri,
      headers: {
        'Authorization': nip98Authorization,
        'Content-Type': contentType,
      },
      body: vtt,
    );

    if (response.statusCode == 200) return;

    throw switch (response.statusCode) {
      400 => BlossomVttBadRequest(response.body),
      401 => BlossomVttUnauthorized(response.body),
      403 => BlossomVttForbidden(response.body),
      404 => BlossomVttNotFound(response.body),
      409 => BlossomVttConflict(response.body),
      final code when code >= 500 =>
        BlossomVttServerError(code, response.body),
      final code => BlossomVttServerError(code, response.body),
    };
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
cd mobile/packages/subtitle_repository && dart test test/blossom_vtt_client_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add mobile/packages/subtitle_repository
git commit -m "feat(subtitle_repository): BlossomVttClient happy-path PUT"
```

---

### Task 1.4: TDD `BlossomVttClient` — error mapping

- [ ] **Step 1: Add failing tests for each documented status code**

Append to the `group('put', ...)` block in `blossom_vtt_client_test.dart`:

```dart
test('throws BlossomVttBadRequest on 400', () {
  when(() => httpClient.put(any(),
          headers: any(named: 'headers'), body: any(named: 'body')))
      .thenAnswer((_) async => http.Response('bad vtt', 400));

  expect(
    () => client.put(sha256: sha256, vtt: vtt, nip98Authorization: auth),
    throwsA(isA<BlossomVttBadRequest>()),
  );
});

test('throws BlossomVttUnauthorized on 401', () {
  when(() => httpClient.put(any(),
          headers: any(named: 'headers'), body: any(named: 'body')))
      .thenAnswer((_) async => http.Response('nope', 401));

  expect(
    () => client.put(sha256: sha256, vtt: vtt, nip98Authorization: auth),
    throwsA(isA<BlossomVttUnauthorized>()),
  );
});

test('throws BlossomVttForbidden on 403', () {
  when(() => httpClient.put(any(),
          headers: any(named: 'headers'), body: any(named: 'body')))
      .thenAnswer((_) async => http.Response('not author', 403));

  expect(
    () => client.put(sha256: sha256, vtt: vtt, nip98Authorization: auth),
    throwsA(isA<BlossomVttForbidden>()),
  );
});

test('throws BlossomVttNotFound on 404', () {
  when(() => httpClient.put(any(),
          headers: any(named: 'headers'), body: any(named: 'body')))
      .thenAnswer((_) async => http.Response('unknown sha', 404));

  expect(
    () => client.put(sha256: sha256, vtt: vtt, nip98Authorization: auth),
    throwsA(isA<BlossomVttNotFound>()),
  );
});

test('throws BlossomVttConflict on 409', () {
  when(() => httpClient.put(any(),
          headers: any(named: 'headers'), body: any(named: 'body')))
      .thenAnswer((_) async => http.Response('conflict', 409));

  expect(
    () => client.put(sha256: sha256, vtt: vtt, nip98Authorization: auth),
    throwsA(isA<BlossomVttConflict>()),
  );
});

test('throws BlossomVttServerError on 500', () {
  when(() => httpClient.put(any(),
          headers: any(named: 'headers'), body: any(named: 'body')))
      .thenAnswer((_) async => http.Response('boom', 500));

  expect(
    () => client.put(sha256: sha256, vtt: vtt, nip98Authorization: auth),
    throwsA(isA<BlossomVttServerError>()),
  );
});
```

- [ ] **Step 2: Run tests**

```bash
cd mobile/packages/subtitle_repository && dart test test/blossom_vtt_client_test.dart
```

Expected: ALL PASS (mapping was already implemented in Task 1.3).

- [ ] **Step 3: Update package barrel to export the client**

Replace `lib/subtitle_repository.dart`:

```dart
// ABOUTME: Public surface of the subtitle_repository package.
// ABOUTME: Re-exports the repository, client, result, and exception types.

export 'src/blossom_vtt_client.dart';
export 'src/blossom_vtt_exception.dart';
export 'src/save_result.dart';
```

- [ ] **Step 4: Commit**

```bash
git add mobile/packages/subtitle_repository
git commit -m "test(subtitle_repository): cover BlossomVttClient error mapping"
```

---

## Chunk 2: SubtitleEditRepository (orchestrator, TDD)

The repository takes:
- a pre-built **signed Kind 39307 `Event`** (cubit handles signing)
- the `sha256`, the raw `vtt` string, and the **NIP-98 Authorization header** for the Blossom PUT
- a `NostrClient` to publish the event
- a `BlossomVttClient` to PUT to Blossom

Returns `SaveResult.full` on full success, `SaveResult.partial` if Blossom fails after relay succeeded. **Throws** if the relay publish fails (Blossom is never attempted).

### Task 2.1: Write the contract test fixture

**Files:**
- Create: `mobile/packages/subtitle_repository/test/subtitle_edit_repository_test.dart`

- [ ] **Step 1: Write a placeholder failing test that establishes mocks**

```dart
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:subtitle_repository/src/blossom_vtt_client.dart';
import 'package:subtitle_repository/src/subtitle_edit_repository.dart';
import 'package:subtitle_repository/subtitle_repository.dart';
import 'package:test/test.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockBlossomVttClient extends Mock implements BlossomVttClient {}

class _FakeEvent extends Fake implements Event {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeEvent());
  });

  group(SubtitleEditRepository, () {
    late _MockNostrClient nostrClient;
    late _MockBlossomVttClient blossomClient;
    late SubtitleEditRepository repo;
    late Event signedEvent;

    const sha256 =
        '5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8';
    const vtt = 'WEBVTT\n\n00:00:00.000 --> 00:00:01.000\nhello\n';
    const auth = 'Nostr base64encodedevent==';

    setUp(() {
      nostrClient = _MockNostrClient();
      blossomClient = _MockBlossomVttClient();
      signedEvent = _FakeEvent();
      repo = SubtitleEditRepository(
        nostrClient: nostrClient,
        blossomClient: blossomClient,
      );
    });

    test('placeholder for contract', () {
      expect(repo, isNotNull);
    });
  });
}
```

- [ ] **Step 2: Run test to verify compile failure**

```bash
cd mobile/packages/subtitle_repository && dart test test/subtitle_edit_repository_test.dart
```

Expected: COMPILE FAIL — `SubtitleEditRepository` not defined.

- [ ] **Step 3: Write minimal `SubtitleEditRepository` skeleton**

Create `lib/src/subtitle_edit_repository.dart`:

```dart
// ABOUTME: Orchestrates a dual-write subtitle save:
// ABOUTME: Kind 39307 publish (must succeed) + Blossom PUT (best-effort).

import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:subtitle_repository/src/blossom_vtt_client.dart';
import 'package:subtitle_repository/src/save_result.dart';

class SubtitleEditRepository {
  SubtitleEditRepository({
    required NostrClient nostrClient,
    required BlossomVttClient blossomClient,
  })  : _nostrClient = nostrClient,
        _blossomClient = blossomClient;

  final NostrClient _nostrClient;
  final BlossomVttClient _blossomClient;

  Future<SaveResult> save({
    required Event signedKind39307Event,
    required String sha256,
    required String vtt,
    required String nip98Authorization,
  }) async {
    throw UnimplementedError();
  }
}
```

- [ ] **Step 4: Run test to verify it now compiles and passes the placeholder**

```bash
cd mobile/packages/subtitle_repository && dart test test/subtitle_edit_repository_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add mobile/packages/subtitle_repository
git commit -m "feat(subtitle_repository): SubtitleEditRepository skeleton"
```

---

### Task 2.2: TDD — relay-success + Blossom-success returns `full`

- [ ] **Step 1: Replace placeholder with happy-path test**

Replace the `test('placeholder for contract', ...)` block with:

```dart
test('publishes Kind 39307 then PUTs Blossom; returns full on success',
    () async {
  when(() => nostrClient.publishEvent(any())).thenAnswer((_) async {});
  when(() => blossomClient.put(
        sha256: any(named: 'sha256'),
        vtt: any(named: 'vtt'),
        nip98Authorization: any(named: 'nip98Authorization'),
      )).thenAnswer((_) async {});

  final result = await repo.save(
    signedKind39307Event: signedEvent,
    sha256: sha256,
    vtt: vtt,
    nip98Authorization: auth,
  );

  expect(result, equals(SaveResult.full));
  verifyInOrder([
    () => nostrClient.publishEvent(signedEvent),
    () => blossomClient.put(
          sha256: sha256,
          vtt: vtt,
          nip98Authorization: auth,
        ),
  ]);
});
```

(Adjust `publishEvent` name to match the real `NostrClient` API — verify with `grep -n 'publishEvent\|publish(' mobile/packages/nostr_client/lib/`. If the actual method is `publish(Event)`, use that name throughout.)

- [ ] **Step 2: Run, verify it fails**

```bash
cd mobile/packages/subtitle_repository && dart test test/subtitle_edit_repository_test.dart
```

Expected: FAIL — `UnimplementedError`.

- [ ] **Step 3: Implement happy path**

Replace `save` body:

```dart
Future<SaveResult> save({
  required Event signedKind39307Event,
  required String sha256,
  required String vtt,
  required String nip98Authorization,
}) async {
  await _nostrClient.publishEvent(signedKind39307Event);

  try {
    await _blossomClient.put(
      sha256: sha256,
      vtt: vtt,
      nip98Authorization: nip98Authorization,
    );
  } catch (_) {
    return SaveResult.partial;
  }

  return SaveResult.full;
}
```

- [ ] **Step 4: Run, verify it passes**

```bash
cd mobile/packages/subtitle_repository && dart test test/subtitle_edit_repository_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add mobile/packages/subtitle_repository
git commit -m "feat(subtitle_repository): happy-path dual-write returns full"
```

---

### Task 2.3: TDD — Blossom failure returns `partial`

- [ ] **Step 1: Add failing test**

Append to the group:

```dart
test('returns partial when Blossom PUT throws (relay still succeeded)',
    () async {
  when(() => nostrClient.publishEvent(any())).thenAnswer((_) async {});
  when(() => blossomClient.put(
        sha256: any(named: 'sha256'),
        vtt: any(named: 'vtt'),
        nip98Authorization: any(named: 'nip98Authorization'),
      )).thenThrow(const BlossomVttServerError(503, 'down'));

  final result = await repo.save(
    signedKind39307Event: signedEvent,
    sha256: sha256,
    vtt: vtt,
    nip98Authorization: auth,
  );

  expect(result, equals(SaveResult.partial));
  verify(() => nostrClient.publishEvent(signedEvent)).called(1);
});
```

- [ ] **Step 2: Run; should already pass (logic written in 2.2)**

```bash
cd mobile/packages/subtitle_repository && dart test test/subtitle_edit_repository_test.dart
```

Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add mobile/packages/subtitle_repository
git commit -m "test(subtitle_repository): Blossom failure → partial"
```

---

### Task 2.4: TDD — relay failure aborts, never calls Blossom

- [ ] **Step 1: Add failing test**

```dart
test('rethrows on relay failure and never calls Blossom', () async {
  when(() => nostrClient.publishEvent(any())).thenThrow(StateError('relay'));

  await expectLater(
    () => repo.save(
      signedKind39307Event: signedEvent,
      sha256: sha256,
      vtt: vtt,
      nip98Authorization: auth,
    ),
    throwsA(isA<StateError>()),
  );

  verifyNever(() => blossomClient.put(
        sha256: any(named: 'sha256'),
        vtt: any(named: 'vtt'),
        nip98Authorization: any(named: 'nip98Authorization'),
      ));
});
```

- [ ] **Step 2: Run, verify it passes** (already enforced by `await` order in 2.2)

```bash
cd mobile/packages/subtitle_repository && dart test test/subtitle_edit_repository_test.dart
```

Expected: PASS.

- [ ] **Step 3: Update package barrel to export the repository**

Add to `lib/subtitle_repository.dart`:

```dart
export 'src/subtitle_edit_repository.dart';
```

- [ ] **Step 4: Run analyzer**

```bash
cd mobile/packages/subtitle_repository && dart analyze
```

Expected: 0 issues.

- [ ] **Step 5: Commit**

```bash
git add mobile/packages/subtitle_repository
git commit -m "test(subtitle_repository): relay failure aborts before Blossom"
```

---

## Chunk 3: Cubit + state (TDD with `bloc_test`)

### Task 3.1: Define `EditableCue` value object

**Files:**
- Create: `mobile/lib/screens/subtitle_editor/cubit/editable_cue.dart`
- Create: `mobile/test/screens/subtitle_editor/cubit/editable_cue_test.dart`

- [ ] **Step 1: Write failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/screens/subtitle_editor/cubit/editable_cue.dart';

void main() {
  group(EditableCue, () {
    test('equates by value', () {
      const a = EditableCue(startMs: 0, endMs: 1000, text: 'hi');
      const b = EditableCue(startMs: 0, endMs: 1000, text: 'hi');
      expect(a, equals(b));
    });

    test('copyWith replaces only specified fields', () {
      const a = EditableCue(startMs: 0, endMs: 1000, text: 'hi');
      expect(
        a.copyWith(text: 'hey'),
        equals(const EditableCue(startMs: 0, endMs: 1000, text: 'hey')),
      );
    });
  });
}
```

- [ ] **Step 2: Run test, verify fail**

```bash
cd mobile && flutter test test/screens/subtitle_editor/cubit/editable_cue_test.dart
```

Expected: COMPILE FAIL.

- [ ] **Step 3: Implement**

```dart
// ABOUTME: Mutable-text view of a SubtitleCue used by the editor cubit.
// ABOUTME: Timing fields are immutable in v1; only `text` can change.

import 'package:equatable/equatable.dart';

class EditableCue extends Equatable {
  const EditableCue({
    required this.startMs,
    required this.endMs,
    required this.text,
  });

  final int startMs;
  final int endMs;
  final String text;

  EditableCue copyWith({String? text}) => EditableCue(
        startMs: startMs,
        endMs: endMs,
        text: text ?? this.text,
      );

  @override
  List<Object?> get props => [startMs, endMs, text];
}
```

- [ ] **Step 4: Run, pass, commit**

```bash
cd mobile && flutter test test/screens/subtitle_editor/cubit/editable_cue_test.dart
git add mobile/lib/screens/subtitle_editor mobile/test/screens/subtitle_editor
git commit -m "feat(subtitle_editor): EditableCue value object"
```

---

### Task 3.2: Define `SubtitleEditorState`

**Files:**
- Create: `mobile/lib/screens/subtitle_editor/cubit/subtitle_editor_state.dart`
- Create: `mobile/test/screens/subtitle_editor/cubit/subtitle_editor_state_test.dart`

- [ ] **Step 1: Failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/screens/subtitle_editor/cubit/editable_cue.dart';
import 'package:openvine/screens/subtitle_editor/cubit/subtitle_editor_state.dart';

void main() {
  group(SubtitleEditorState, () {
    const cueA = EditableCue(startMs: 0, endMs: 500, text: 'hi');
    const cueB = EditableCue(startMs: 500, endMs: 1000, text: 'world');

    SubtitleEditorState base() => SubtitleEditorState(
          status: SubtitleEditorStatus.editing,
          cues: const [cueA, cueB],
          originalCues: const [cueA, cueB],
          videoId:
              '64a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f',
          videoDTag: 'my-vid',
          sha256:
              '5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8',
          videoDurationMs: 6000,
          language: 'en',
        );

    test('isDirty is false when cues match originalCues', () {
      expect(base().isDirty, isFalse);
    });

    test('isDirty is true when any cue text differs', () {
      final s = base().copyWith(cues: [cueA.copyWith(text: 'HI'), cueB]);
      expect(s.isDirty, isTrue);
    });

    test('isFallbackMode is true when originalCues has 1 empty cue', () {
      final s = base().copyWith(
        cues: const [EditableCue(startMs: 0, endMs: 6000, text: '')],
        originalCues: const [EditableCue(startMs: 0, endMs: 6000, text: '')],
      );
      expect(s.isFallbackMode, isTrue);
    });

    test('isFallbackMode is false for normal cue lists', () {
      expect(base().isFallbackMode, isFalse);
    });
  });
}
```

- [ ] **Step 2: Run, verify fail**

```bash
cd mobile && flutter test test/screens/subtitle_editor/cubit/subtitle_editor_state_test.dart
```

- [ ] **Step 3: Implement**

```dart
// ABOUTME: State for the subtitle editor screen.
// ABOUTME: status enum drives UI; cues vs originalCues drives the dirty flag.
// ABOUTME: No error fields — errors flow via cubit.addError per project rule.

import 'package:equatable/equatable.dart';
import 'package:openvine/screens/subtitle_editor/cubit/editable_cue.dart';

enum SubtitleEditorStatus {
  initial,
  loading,
  editing,
  saving,
  success,
  partialSuccess,
  failure,
}

class SubtitleEditorState extends Equatable {
  const SubtitleEditorState({
    this.status = SubtitleEditorStatus.initial,
    this.cues = const [],
    this.originalCues = const [],
    this.videoId = '',
    this.videoDTag = '',
    this.sha256,
    this.videoDurationMs = 0,
    this.language = 'en',
  });

  final SubtitleEditorStatus status;
  final List<EditableCue> cues;
  final List<EditableCue> originalCues;
  final String videoId;
  final String videoDTag;
  final String? sha256;
  final int videoDurationMs;
  final String language;

  bool get isDirty {
    if (cues.length != originalCues.length) return true;
    for (var i = 0; i < cues.length; i++) {
      if (cues[i] != originalCues[i]) return true;
    }
    return false;
  }

  bool get isFallbackMode =>
      originalCues.length <= 1 &&
      (originalCues.isEmpty || originalCues.first.text.isEmpty);

  SubtitleEditorState copyWith({
    SubtitleEditorStatus? status,
    List<EditableCue>? cues,
    List<EditableCue>? originalCues,
    String? videoId,
    String? videoDTag,
    String? sha256,
    int? videoDurationMs,
    String? language,
  }) =>
      SubtitleEditorState(
        status: status ?? this.status,
        cues: cues ?? this.cues,
        originalCues: originalCues ?? this.originalCues,
        videoId: videoId ?? this.videoId,
        videoDTag: videoDTag ?? this.videoDTag,
        sha256: sha256 ?? this.sha256,
        videoDurationMs: videoDurationMs ?? this.videoDurationMs,
        language: language ?? this.language,
      );

  @override
  List<Object?> get props => [
        status,
        cues,
        originalCues,
        videoId,
        videoDTag,
        sha256,
        videoDurationMs,
        language,
      ];
}
```

- [ ] **Step 4: Run, pass, commit**

```bash
cd mobile && flutter test test/screens/subtitle_editor/cubit/subtitle_editor_state_test.dart
git add mobile/lib/screens/subtitle_editor mobile/test/screens/subtitle_editor
git commit -m "feat(subtitle_editor): state object with isDirty/isFallbackMode"
```

---

### Task 3.3: TDD `SubtitleEditorCubit` — initialization

**Files:**
- Create: `mobile/lib/screens/subtitle_editor/cubit/subtitle_editor_cubit.dart`
- Create: `mobile/test/screens/subtitle_editor/cubit/subtitle_editor_cubit_test.dart`

The cubit takes a small set of injected collaborators and a one-shot `init(...)` call from the page that hydrates state from the existing cues fetched via `subtitleCuesProvider`.

The cubit's responsibilities:
1. **start**: seed `cues`/`originalCues` from existing parsed cues; if empty, synthesize a single empty cue spanning the video duration.
2. **updateCueText(index, text)**: replace cue at index.
3. **save()**: build VTT, sign Kind 39307 via injected signer, build NIP-98 via injected signer, call repository, emit success/partialSuccess/failure.
4. **discard()**: revert `cues` to `originalCues`.

Inject signing/auth as **function references** to keep the cubit free of `AuthService` directly:
```dart
typedef SignKind39307 = Future<Event?> Function({
  required String content,
  required List<List<String>> tags,
});

typedef BuildNip98Authorization = Future<String> Function({
  required String method,
  required Uri url,
  required String body,
});
```

- [ ] **Step 1: Failing test for init**

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/screens/subtitle_editor/cubit/editable_cue.dart';
import 'package:openvine/screens/subtitle_editor/cubit/subtitle_editor_cubit.dart';
import 'package:openvine/screens/subtitle_editor/cubit/subtitle_editor_state.dart';
import 'package:openvine/services/subtitle_service.dart';
import 'package:subtitle_repository/subtitle_repository.dart';

class _MockRepo extends Mock implements SubtitleEditRepository {}

void main() {
  group(SubtitleEditorCubit, () {
    late _MockRepo repo;

    setUp(() {
      repo = _MockRepo();
    });

    SubtitleEditorCubit makeCubit() => SubtitleEditorCubit(
          repository: repo,
          signKind39307: ({required content, required tags}) async => null,
          buildNip98Authorization:
              ({required method, required url, required body}) async => '',
        );

    blocTest<SubtitleEditorCubit, SubtitleEditorState>(
      'init seeds cues from non-empty list',
      build: makeCubit,
      act: (c) => c.init(
        videoId: 'vid-id-' + 'a' * 56,
        videoDTag: 'my-vid',
        sha256: 'b' * 64,
        videoDurationMs: 6000,
        language: 'en',
        existingCues: const [
          SubtitleCue(start: 0, end: 1000, text: 'hello'),
          SubtitleCue(start: 1000, end: 2000, text: 'world'),
        ],
      ),
      expect: () => [
        isA<SubtitleEditorState>()
            .having((s) => s.status, 'status', SubtitleEditorStatus.editing)
            .having((s) => s.cues.length, 'cues.length', 2)
            .having((s) => s.cues.first.text, 'cues[0].text', 'hello')
            .having((s) => s.isDirty, 'isDirty', false)
            .having((s) => s.isFallbackMode, 'isFallbackMode', false),
      ],
    );

    blocTest<SubtitleEditorCubit, SubtitleEditorState>(
      'init falls back to single empty cue when existing cues are empty',
      build: makeCubit,
      act: (c) => c.init(
        videoId: 'vid-id-' + 'a' * 56,
        videoDTag: 'my-vid',
        sha256: 'b' * 64,
        videoDurationMs: 6000,
        language: 'en',
        existingCues: const [],
      ),
      expect: () => [
        isA<SubtitleEditorState>()
            .having((s) => s.cues.length, 'cues.length', 1)
            .having((s) => s.cues.first.startMs, 'startMs', 0)
            .having((s) => s.cues.first.endMs, 'endMs', 6000)
            .having((s) => s.cues.first.text, 'text', '')
            .having((s) => s.isFallbackMode, 'isFallbackMode', true),
      ],
    );

    blocTest<SubtitleEditorCubit, SubtitleEditorState>(
      'init defaults videoDurationMs to 6000 when zero',
      build: makeCubit,
      act: (c) => c.init(
        videoId: 'vid-id-' + 'a' * 56,
        videoDTag: 'my-vid',
        sha256: null,
        videoDurationMs: 0,
        language: 'en',
        existingCues: const [],
      ),
      expect: () => [
        isA<SubtitleEditorState>()
            .having((s) => s.cues.first.endMs, 'endMs', 6000),
      ],
    );
  });
}
```

- [ ] **Step 2: Run, verify fail**

```bash
cd mobile && flutter test test/screens/subtitle_editor/cubit/subtitle_editor_cubit_test.dart
```

Expected: COMPILE FAIL.

- [ ] **Step 3: Implement cubit (init only for now)**

```dart
// ABOUTME: Cubit for the subtitle editor screen.
// ABOUTME: Hydrates cues, tracks dirty state, dual-writes via repository.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/screens/subtitle_editor/cubit/editable_cue.dart';
import 'package:openvine/screens/subtitle_editor/cubit/subtitle_editor_state.dart';
import 'package:openvine/services/subtitle_service.dart';
import 'package:subtitle_repository/subtitle_repository.dart';

typedef SignKind39307 = Future<Event?> Function({
  required String content,
  required List<List<String>> tags,
});

typedef BuildNip98Authorization = Future<String> Function({
  required String method,
  required Uri url,
  required String body,
});

class SubtitleEditorCubit extends Cubit<SubtitleEditorState> {
  SubtitleEditorCubit({
    required SubtitleEditRepository repository,
    required SignKind39307 signKind39307,
    required BuildNip98Authorization buildNip98Authorization,
  })  : _repository = repository,
        _signKind39307 = signKind39307,
        _buildNip98Authorization = buildNip98Authorization,
        super(const SubtitleEditorState());

  final SubtitleEditRepository _repository;
  final SignKind39307 _signKind39307;
  final BuildNip98Authorization _buildNip98Authorization;

  static const _defaultDurationMs = 6000;

  void init({
    required String videoId,
    required String videoDTag,
    required String? sha256,
    required int videoDurationMs,
    required String language,
    required List<SubtitleCue> existingCues,
  }) {
    final durationMs =
        videoDurationMs <= 0 ? _defaultDurationMs : videoDurationMs;

    final seed = existingCues.isEmpty
        ? <EditableCue>[
            EditableCue(startMs: 0, endMs: durationMs, text: ''),
          ]
        : existingCues
            .map((c) =>
                EditableCue(startMs: c.start, endMs: c.end, text: c.text))
            .toList(growable: false);

    emit(SubtitleEditorState(
      status: SubtitleEditorStatus.editing,
      cues: seed,
      originalCues: seed,
      videoId: videoId,
      videoDTag: videoDTag,
      sha256: sha256,
      videoDurationMs: durationMs,
      language: language,
    ));
  }
}
```

- [ ] **Step 4: Run, pass, commit**

```bash
cd mobile && flutter test test/screens/subtitle_editor/cubit/subtitle_editor_cubit_test.dart
git add mobile/lib/screens/subtitle_editor mobile/test/screens/subtitle_editor
git commit -m "feat(subtitle_editor): cubit init with single-cue fallback"
```

---

### Task 3.4: TDD `updateCueText` and `discard`

- [ ] **Step 1: Append tests**

```dart
blocTest<SubtitleEditorCubit, SubtitleEditorState>(
  'updateCueText replaces text at index and flips isDirty',
  build: makeCubit,
  seed: () => SubtitleEditorState(
    status: SubtitleEditorStatus.editing,
    cues: const [EditableCue(startMs: 0, endMs: 500, text: 'a')],
    originalCues: const [EditableCue(startMs: 0, endMs: 500, text: 'a')],
    videoDurationMs: 6000,
  ),
  act: (c) => c.updateCueText(0, 'b'),
  expect: () => [
    isA<SubtitleEditorState>()
        .having((s) => s.cues.first.text, 'text', 'b')
        .having((s) => s.isDirty, 'isDirty', true),
  ],
);

blocTest<SubtitleEditorCubit, SubtitleEditorState>(
  'discard reverts cues to originalCues',
  build: makeCubit,
  seed: () => SubtitleEditorState(
    status: SubtitleEditorStatus.editing,
    cues: const [EditableCue(startMs: 0, endMs: 500, text: 'EDITED')],
    originalCues: const [EditableCue(startMs: 0, endMs: 500, text: 'a')],
    videoDurationMs: 6000,
  ),
  act: (c) => c.discard(),
  expect: () => [
    isA<SubtitleEditorState>()
        .having((s) => s.cues.first.text, 'text', 'a')
        .having((s) => s.isDirty, 'isDirty', false),
  ],
);
```

- [ ] **Step 2: Run, verify fail**

- [ ] **Step 3: Implement**

Add to cubit:

```dart
void updateCueText(int index, String text) {
  final next = [...state.cues];
  next[index] = next[index].copyWith(text: text);
  emit(state.copyWith(cues: next));
}

void discard() {
  emit(state.copyWith(cues: state.originalCues));
}
```

- [ ] **Step 4: Run, pass, commit**

```bash
cd mobile && flutter test test/screens/subtitle_editor/cubit/subtitle_editor_cubit_test.dart
git add mobile/lib/screens/subtitle_editor mobile/test/screens/subtitle_editor
git commit -m "feat(subtitle_editor): updateCueText + discard"
```

---

### Task 3.5: TDD `save()` — happy path emits `success`

- [ ] **Step 1: Append test**

```dart
blocTest<SubtitleEditorCubit, SubtitleEditorState>(
  'save emits saving → success when repo returns SaveResult.full',
  build: () {
    when(() => repo.save(
          signedKind39307Event: any(named: 'signedKind39307Event'),
          sha256: any(named: 'sha256'),
          vtt: any(named: 'vtt'),
          nip98Authorization: any(named: 'nip98Authorization'),
        )).thenAnswer((_) async => SaveResult.full);
    return SubtitleEditorCubit(
      repository: repo,
      signKind39307: ({required content, required tags}) async =>
          _stubEvent(),
      buildNip98Authorization:
          ({required method, required url, required body}) async =>
              'Nostr stubbed',
    );
  },
  seed: () => SubtitleEditorState(
    status: SubtitleEditorStatus.editing,
    cues: const [EditableCue(startMs: 0, endMs: 500, text: 'edit')],
    originalCues: const [EditableCue(startMs: 0, endMs: 500, text: 'orig')],
    videoId: 'vid' + 'a' * 61,
    videoDTag: 'd-tag',
    sha256: 'b' * 64,
    videoDurationMs: 6000,
    language: 'en',
  ),
  act: (c) => c.save(),
  expect: () => [
    isA<SubtitleEditorState>()
        .having((s) => s.status, 'status', SubtitleEditorStatus.saving),
    isA<SubtitleEditorState>()
        .having((s) => s.status, 'status', SubtitleEditorStatus.success),
  ],
);
```

Add helper at top of file:

```dart
import 'package:nostr_sdk/nostr_sdk.dart';

Event _stubEvent() => Event(
      'a' * 64,
      39307,
      const [],
      'WEBVTT\n\n00:00:00.000 --> 00:00:00.500\nedit\n',
    );
```

- [ ] **Step 2: Run, verify fail (no save() yet)**

- [ ] **Step 3: Implement save()**

Add to cubit:

```dart
Future<void> save() async {
  final sha256 = state.sha256;
  if (sha256 == null || sha256.isEmpty) {
    emit(state.copyWith(status: SubtitleEditorStatus.failure));
    return;
  }

  emit(state.copyWith(status: SubtitleEditorStatus.saving));

  try {
    final vtt = SubtitleService.generateVtt(
      state.cues
          .map((c) => SubtitleCue(start: c.startMs, end: c.endMs, text: c.text))
          .toList(),
    );

    final tags = <List<String>>[
      ['d', 'subtitles:${state.videoDTag}'],
      ['e', state.videoId],
      ['language', state.language],
      ['alt', 'Subtitle track'],
    ];

    final signed = await _signKind39307(content: vtt, tags: tags);
    if (signed == null) {
      emit(state.copyWith(status: SubtitleEditorStatus.failure));
      return;
    }

    final url = Uri.parse('https://media.divine.video/v1/$sha256/vtt');
    final auth = await _buildNip98Authorization(
      method: 'PUT',
      url: url,
      body: vtt,
    );

    final result = await _repository.save(
      signedKind39307Event: signed,
      sha256: sha256,
      vtt: vtt,
      nip98Authorization: auth,
    );

    emit(state.copyWith(
      status: result == SaveResult.full
          ? SubtitleEditorStatus.success
          : SubtitleEditorStatus.partialSuccess,
      originalCues: state.cues,
    ));
  } catch (e, stack) {
    addError(e, stack);
    emit(state.copyWith(status: SubtitleEditorStatus.failure));
  }
}
```

- [ ] **Step 4: Run, pass, commit**

```bash
cd mobile && flutter test test/screens/subtitle_editor/cubit/subtitle_editor_cubit_test.dart
git add mobile/lib/screens/subtitle_editor mobile/test/screens/subtitle_editor
git commit -m "feat(subtitle_editor): save() happy path emits success"
```

---

### Task 3.6: TDD `save()` partial + failure paths

- [ ] **Step 1: Append tests**

```dart
blocTest<SubtitleEditorCubit, SubtitleEditorState>(
  'save emits partialSuccess when repo returns SaveResult.partial',
  build: () {
    when(() => repo.save(
          signedKind39307Event: any(named: 'signedKind39307Event'),
          sha256: any(named: 'sha256'),
          vtt: any(named: 'vtt'),
          nip98Authorization: any(named: 'nip98Authorization'),
        )).thenAnswer((_) async => SaveResult.partial);
    return SubtitleEditorCubit(
      repository: repo,
      signKind39307: ({required content, required tags}) async => _stubEvent(),
      buildNip98Authorization:
          ({required method, required url, required body}) async => 'auth',
    );
  },
  seed: () => /* same seed as 3.5 */ ,
  act: (c) => c.save(),
  expect: () => [
    isA<SubtitleEditorState>()
        .having((s) => s.status, 'status', SubtitleEditorStatus.saving),
    isA<SubtitleEditorState>()
        .having(
            (s) => s.status, 'status', SubtitleEditorStatus.partialSuccess),
  ],
);

blocTest<SubtitleEditorCubit, SubtitleEditorState>(
  'save emits failure and reports error when repo throws',
  build: () {
    when(() => repo.save(
          signedKind39307Event: any(named: 'signedKind39307Event'),
          sha256: any(named: 'sha256'),
          vtt: any(named: 'vtt'),
          nip98Authorization: any(named: 'nip98Authorization'),
        )).thenThrow(StateError('relay down'));
    return SubtitleEditorCubit(
      repository: repo,
      signKind39307: ({required content, required tags}) async => _stubEvent(),
      buildNip98Authorization:
          ({required method, required url, required body}) async => 'auth',
    );
  },
  seed: () => /* same seed */ ,
  act: (c) => c.save(),
  expect: () => [
    isA<SubtitleEditorState>()
        .having((s) => s.status, 'status', SubtitleEditorStatus.saving),
    isA<SubtitleEditorState>()
        .having((s) => s.status, 'status', SubtitleEditorStatus.failure),
  ],
  errors: () => [isA<StateError>()],
);

blocTest<SubtitleEditorCubit, SubtitleEditorState>(
  'save emits failure when sha256 is null',
  build: makeCubit,
  seed: () => SubtitleEditorState(
    status: SubtitleEditorStatus.editing,
    cues: const [EditableCue(startMs: 0, endMs: 500, text: 'edit')],
    originalCues: const [EditableCue(startMs: 0, endMs: 500, text: 'orig')],
    videoDurationMs: 6000,
  ),
  act: (c) => c.save(),
  expect: () => [
    isA<SubtitleEditorState>()
        .having((s) => s.status, 'status', SubtitleEditorStatus.failure),
  ],
);
```

- [ ] **Step 2: Run, expect all pass** (logic already in 3.5).

- [ ] **Step 3: Add barrel `mobile/lib/screens/subtitle_editor/subtitle_editor.dart`**

```dart
// ABOUTME: Public surface of the subtitle_editor feature.
export 'cubit/editable_cue.dart';
export 'cubit/subtitle_editor_cubit.dart';
export 'cubit/subtitle_editor_state.dart';
```

- [ ] **Step 4: Commit**

```bash
git add mobile/lib/screens/subtitle_editor mobile/test/screens/subtitle_editor
git commit -m "test(subtitle_editor): partial-success + failure + missing-sha"
```

---

## Chunk 4: View + widgets

### Task 4.1: `CueRow` widget (TDD)

**Files:**
- Create: `mobile/lib/screens/subtitle_editor/view/widgets/cue_row.dart`
- Create: `mobile/test/screens/subtitle_editor/view/widgets/cue_row_test.dart`

A row that renders timestamp range + a `TextField` bound to a cue's text. Pure widget — takes the text + `onChanged` callback.

- [ ] **Step 1: Failing widget test**

```dart
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/screens/subtitle_editor/view/widgets/cue_row.dart';

void main() {
  group(CueRow, () {
    testWidgets('renders formatted timestamp range', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: CueRow(
            startMs: 1500,
            endMs: 2750,
            text: 'hello',
            onChanged: (_) {},
          ),
        ),
      ));

      expect(find.text('00:01.500 – 00:02.750'), findsOneWidget);
      expect(find.text('hello'), findsOneWidget);
    });

    testWidgets('calls onChanged when text edited', (tester) async {
      var captured = '';
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: CueRow(
            startMs: 0,
            endMs: 500,
            text: 'hi',
            onChanged: (v) => captured = v,
          ),
        ),
      ));

      await tester.enterText(find.byType(TextField), 'hey');
      expect(captured, equals('hey'));
    });
  });
}
```

- [ ] **Step 2: Run, fail.**

- [ ] **Step 3: Implement**

```dart
// ABOUTME: Renders one cue's timestamp + editable text field.
// ABOUTME: Pure widget — parent cubit owns the data and handles changes.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';

class CueRow extends StatelessWidget {
  const CueRow({
    required this.startMs,
    required this.endMs,
    required this.text,
    required this.onChanged,
    super.key,
  });

  final int startMs;
  final int endMs;
  final String text;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 6,
        children: [
          Text(
            '${_format(startMs)} – ${_format(endMs)}',
            style: VineTheme.labelSmallFont(color: VineTheme.secondaryText),
          ),
          TextFormField(
            initialValue: text,
            onChanged: onChanged,
            maxLength: 2000,
            maxLines: null,
            style: VineTheme.bodyMediumFont(),
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
        ],
      ),
    );
  }

  static String _format(int ms) {
    final m = (ms ~/ 60000).toString().padLeft(2, '0');
    final s = ((ms % 60000) ~/ 1000).toString().padLeft(2, '0');
    final mmm = (ms % 1000).toString().padLeft(3, '0');
    return '$m:$s.$mmm';
  }
}
```

(`TextFormField` with `initialValue` rebuilds correctly when the parent state's text matches; if the test fails because controller state desyncs, switch to a `StatefulWidget` with a `TextEditingController` keyed on `(startMs,endMs)`.)

- [ ] **Step 4: Run, pass, commit**

```bash
cd mobile && flutter test test/screens/subtitle_editor/view/widgets/cue_row_test.dart
git add mobile/lib/screens/subtitle_editor mobile/test/screens/subtitle_editor
git commit -m "feat(subtitle_editor): CueRow widget"
```

---

### Task 4.2: `SingleCueFallback` widget (TDD)

**Files:**
- Create: `mobile/lib/screens/subtitle_editor/view/widgets/single_cue_fallback.dart`
- Create: `mobile/test/screens/subtitle_editor/view/widgets/single_cue_fallback_test.dart`

- [ ] **Step 1: Failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/screens/subtitle_editor/view/widgets/single_cue_fallback.dart';

void main() {
  group(SingleCueFallback, () {
    testWidgets('shows duration in label and routes onChanged',
        (tester) async {
      var captured = '';
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: SingleCueFallback(
            durationMs: 6000,
            text: '',
            onChanged: (v) => captured = v,
          ),
        ),
      ));

      expect(find.text('Captions for full video (0:00 – 0:06)'),
          findsOneWidget);
      await tester.enterText(find.byType(TextField), 'all of it');
      expect(captured, equals('all of it'));
    });
  });
}
```

- [ ] **Step 2: Implement**

```dart
// ABOUTME: Single-textarea fallback when the parsed VTT had zero cues.
// ABOUTME: One cue spans 0..durationMs; user types the whole transcript.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';

class SingleCueFallback extends StatelessWidget {
  const SingleCueFallback({
    required this.durationMs,
    required this.text,
    required this.onChanged,
    super.key,
  });

  final int durationMs;
  final String text;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Text(
            'Captions for full video (0:00 – ${_durationLabel(durationMs)})',
            style: VineTheme.labelSmallFont(color: VineTheme.secondaryText),
          ),
          TextFormField(
            initialValue: text,
            onChanged: onChanged,
            maxLines: 6,
            maxLength: 2000,
            style: VineTheme.bodyMediumFont(),
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
        ],
      ),
    );
  }

  static String _durationLabel(int ms) {
    final s = (ms / 1000).round();
    return '0:${s.toString().padLeft(2, '0')}';
  }
}
```

- [ ] **Step 3: Run, pass, commit**

```bash
cd mobile && flutter test test/screens/subtitle_editor/view/widgets/single_cue_fallback_test.dart
git add mobile/lib/screens/subtitle_editor mobile/test/screens/subtitle_editor
git commit -m "feat(subtitle_editor): SingleCueFallback widget"
```

---

### Task 4.3: `SubtitleEditorView` (TDD)

**Files:**
- Create: `mobile/lib/screens/subtitle_editor/view/subtitle_editor_view.dart`
- Create: `mobile/test/screens/subtitle_editor/view/subtitle_editor_view_test.dart`

The view assumes a `SubtitleEditorCubit` is provided above it. Renders:
- AppBar with X (close) and Save (disabled when not dirty).
- Body: cue list OR `SingleCueFallback`.
- Listens for `success`/`partialSuccess`/`failure` to fire snackbars and pop on success.

- [ ] **Step 1: Failing test — renders cue list, save disabled**

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/screens/subtitle_editor/cubit/editable_cue.dart';
import 'package:openvine/screens/subtitle_editor/cubit/subtitle_editor_cubit.dart';
import 'package:openvine/screens/subtitle_editor/cubit/subtitle_editor_state.dart';
import 'package:openvine/screens/subtitle_editor/view/subtitle_editor_view.dart';

class _MockCubit extends MockCubit<SubtitleEditorState>
    implements SubtitleEditorCubit {}

void main() {
  group(SubtitleEditorView, () {
    late _MockCubit cubit;

    setUp(() {
      cubit = _MockCubit();
    });

    testWidgets('renders cues and disables Save when not dirty',
        (tester) async {
      whenListen(
        cubit,
        const Stream<SubtitleEditorState>.empty(),
        initialState: const SubtitleEditorState(
          status: SubtitleEditorStatus.editing,
          cues: [EditableCue(startMs: 0, endMs: 500, text: 'a')],
          originalCues: [EditableCue(startMs: 0, endMs: 500, text: 'a')],
          videoDurationMs: 6000,
        ),
      );

      await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark(),
        home: BlocProvider<SubtitleEditorCubit>.value(
          value: cubit,
          child: const SubtitleEditorView(),
        ),
      ));

      expect(find.text('Edit captions'), findsOneWidget);
      expect(find.text('a'), findsOneWidget);
      final save = tester.widget<TextButton>(find.widgetWithText(TextButton, 'Save'));
      expect(save.onPressed, isNull);
    });

    testWidgets('renders single-cue fallback when isFallbackMode',
        (tester) async {
      whenListen(
        cubit,
        const Stream<SubtitleEditorState>.empty(),
        initialState: const SubtitleEditorState(
          status: SubtitleEditorStatus.editing,
          cues: [EditableCue(startMs: 0, endMs: 6000, text: '')],
          originalCues: [EditableCue(startMs: 0, endMs: 6000, text: '')],
          videoDurationMs: 6000,
        ),
      );

      await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark(),
        home: BlocProvider<SubtitleEditorCubit>.value(
          value: cubit,
          child: const SubtitleEditorView(),
        ),
      ));

      expect(find.text('Captions for full video (0:00 – 0:06)'),
          findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Implement view**

```dart
// ABOUTME: Stateless view for the subtitle editor.
// ABOUTME: Reacts to status via BlocListener; rebuilds list via BlocSelector.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:openvine/screens/subtitle_editor/cubit/subtitle_editor_cubit.dart';
import 'package:openvine/screens/subtitle_editor/cubit/subtitle_editor_state.dart';
import 'package:openvine/screens/subtitle_editor/view/widgets/cue_row.dart';
import 'package:openvine/screens/subtitle_editor/view/widgets/single_cue_fallback.dart';

class SubtitleEditorView extends StatelessWidget {
  @visibleForTesting
  const SubtitleEditorView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<SubtitleEditorCubit, SubtitleEditorState>(
      listenWhen: (p, c) => p.status != c.status,
      listener: _onStatusChange,
      child: Scaffold(
        backgroundColor: VineTheme.backgroundColor,
        appBar: AppBar(
          backgroundColor: VineTheme.backgroundColor,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => _onClose(context),
          ),
          title: const Text('Edit captions'),
          actions: [
            BlocBuilder<SubtitleEditorCubit, SubtitleEditorState>(
              buildWhen: (p, c) =>
                  p.isDirty != c.isDirty || p.status != c.status,
              builder: (context, state) {
                final canSave = state.isDirty &&
                    state.status != SubtitleEditorStatus.saving;
                return TextButton(
                  onPressed: canSave
                      ? () => context.read<SubtitleEditorCubit>().save()
                      : null,
                  child: const Text('Save'),
                );
              },
            ),
          ],
        ),
        body: const _Body(),
      ),
    );
  }

  void _onStatusChange(BuildContext context, SubtitleEditorState state) {
    final messenger = ScaffoldMessenger.of(context);
    switch (state.status) {
      case SubtitleEditorStatus.success:
        messenger.showSnackBar(
            const SnackBar(content: Text('Captions updated')));
        Navigator.of(context).maybePop();
      case SubtitleEditorStatus.partialSuccess:
        messenger.showSnackBar(const SnackBar(
            content:
                Text('Saved — may take a moment to appear everywhere.')));
        Navigator.of(context).maybePop();
      case SubtitleEditorStatus.failure:
        messenger.showSnackBar(const SnackBar(
            content: Text("Couldn't save captions. Try again.")));
      case _:
        break;
    }
  }

  Future<void> _onClose(BuildContext context) async {
    final cubit = context.read<SubtitleEditorCubit>();
    if (!cubit.state.isDirty) {
      Navigator.of(context).maybePop();
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('Your edits will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      cubit.discard();
      if (context.mounted) Navigator.of(context).maybePop();
    }
  }
}

class _Body extends StatelessWidget {
  const _Body();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SubtitleEditorCubit, SubtitleEditorState>(
      builder: (context, state) {
        if (state.isFallbackMode) {
          return SingleCueFallback(
            durationMs: state.videoDurationMs,
            text: state.cues.first.text,
            onChanged: (v) =>
                context.read<SubtitleEditorCubit>().updateCueText(0, v),
          );
        }
        return ListView.builder(
          itemCount: state.cues.length,
          itemBuilder: (context, i) {
            final cue = state.cues[i];
            return CueRow(
              key: ValueKey('cue_${cue.startMs}_${cue.endMs}'),
              startMs: cue.startMs,
              endMs: cue.endMs,
              text: cue.text,
              onChanged: (v) =>
                  context.read<SubtitleEditorCubit>().updateCueText(i, v),
            );
          },
        );
      },
    );
  }
}
```

- [ ] **Step 3: Run, pass, commit**

```bash
cd mobile && flutter test test/screens/subtitle_editor/view/subtitle_editor_view_test.dart
git add mobile/lib/screens/subtitle_editor mobile/test/screens/subtitle_editor
git commit -m "feat(subtitle_editor): SubtitleEditorView (cue list + fallback)"
```

---

### Task 4.4: `SubtitleEditorPage` (host that wires deps)

**Files:**
- Create: `mobile/lib/screens/subtitle_editor/view/subtitle_editor_page.dart`

The page reads dependencies from `context` (Riverpod providers + BlocProvider/MultiRepositoryProvider, depending on how the app injects `AuthService` / `NostrClient`), constructs the cubit, and calls `init`. It also fetches existing cues using the existing `subtitleCuesProvider`.

- [ ] **Step 1: Implement page**

```dart
// ABOUTME: BlocProvider host for SubtitleEditorView.
// ABOUTME: Fetches existing cues, wires AuthService for signing + NIP-98.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/subtitle_providers.dart';
import 'package:openvine/screens/subtitle_editor/cubit/subtitle_editor_cubit.dart';
import 'package:openvine/screens/subtitle_editor/view/subtitle_editor_view.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/utils/nip98.dart'; // create if missing — see note
import 'package:subtitle_repository/subtitle_repository.dart';

class SubtitleEditorPage extends ConsumerWidget {
  const SubtitleEditorPage({required this.video, super.key});

  final VideoEvent video;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cuesAsync = ref.watch(subtitleCuesProvider(
      videoId: video.id,
      textTrackRef: video.textTrackRef,
      textTrackContent: video.textTrackContent,
      sha256: video.sha256,
    ));

    return cuesAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(child: Text('Could not load captions: $e')),
      ),
      data: (existing) {
        final repo = context.read<SubtitleEditRepository>();
        final auth = context.read<AuthService>();

        return BlocProvider(
          create: (_) => SubtitleEditorCubit(
            repository: repo,
            signKind39307: ({required content, required tags}) =>
                auth.createAndSignEvent(
              kind: 39307,
              content: content,
              tags: tags,
            ),
            buildNip98Authorization: ({
              required method,
              required url,
              required body,
            }) =>
                buildNip98Authorization(
              authService: auth,
              method: method,
              url: url,
              payload: body,
            ),
          )..init(
              videoId: video.id,
              videoDTag: video.dTag ?? video.id,
              sha256: video.sha256,
              videoDurationMs: (video.duration ?? 6) * 1000,
              language: 'en',
              existingCues: existing,
            ),
          child: const SubtitleEditorView(),
        );
      },
    );
  }
}
```

**Note on `nip98.dart`:** if the project already has a NIP-98 builder (search `grep -rn "Nip98\|nip-98\|nip98" mobile/lib mobile/packages`), reuse it. Otherwise create `mobile/lib/utils/nip98.dart` with a small helper that builds a Kind 27235 event signed via `AuthService.createAndSignEvent` with tags `[["u", url], ["method", method], ["payload", sha256(body)]]`, base64-encodes the JSON, returns `'Nostr <base64>'`. Add tests for the helper before using it.

- [ ] **Step 2: If `Nip98` builder is missing, create + test it as its own task**

(Branch off here for a Task 4.4a if needed; same TDD discipline. Skip if existing infrastructure is reused.)

- [ ] **Step 3: Wire `SubtitleEditRepository` provider**

The repo needs to be available via `context.read<SubtitleEditRepository>()`. Add a `RepositoryProvider` near the top of `mobile/lib/main.dart` (or wherever app-level providers live):

```dart
RepositoryProvider<SubtitleEditRepository>(
  create: (context) => SubtitleEditRepository(
    nostrClient: context.read<NostrClient>(),
    blossomClient: BlossomVttClient(
      httpClient: http.Client(),
      baseUri: Uri.parse('https://media.divine.video'),
    ),
  ),
),
```

(Match this to the existing app-startup wiring style — likely already a `MultiRepositoryProvider` somewhere.)

- [ ] **Step 4: Commit**

```bash
git add mobile/lib mobile/test
git commit -m "feat(subtitle_editor): SubtitleEditorPage + DI wiring"
```

---

## Chunk 5: Entry points + routing

### Task 5.1: Add the package to `mobile/pubspec.yaml`

- [ ] **Step 1: Open `mobile/pubspec.yaml`** and add under `dependencies:`:

```yaml
  subtitle_repository:
    path: packages/subtitle_repository
```

- [ ] **Step 2: Run `flutter pub get`**

```bash
cd mobile && flutter pub get
```

- [ ] **Step 3: Commit**

```bash
git add mobile/pubspec.yaml mobile/pubspec.lock
git commit -m "chore(mobile): add subtitle_repository path dep"
```

---

### Task 5.2: Add typed route in `app_router.dart`

- [ ] **Step 1: Open `mobile/lib/router/app_router.dart`**, find a sibling typed route as a template (e.g. an existing video screen route).

- [ ] **Step 2: Add typed route**

```dart
@TypedGoRoute<EditCaptionsRoute>(
  name: 'editCaptions',
  path: '/edit-captions/:videoId',
)
@immutable
class EditCaptionsRoute extends GoRouteData {
  const EditCaptionsRoute({required this.videoId, this.$extra});

  final String videoId;
  final VideoEvent? $extra;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    final video = $extra;
    if (video == null) {
      // Defense in depth — direct deep link without VideoEvent shouldn't happen
      // because the entry points always have one in hand. Bounce back.
      return const SizedBox.shrink();
    }
    return SubtitleEditorPage(video: video);
  }
}
```

(Follow the project's existing `extra` patterns. If they avoid `extra` per `routing.md`, refactor to fetch the `VideoEvent` from a provider keyed by `videoId`.)

- [ ] **Step 3: Re-run codegen**

```bash
cd mobile && dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 4: Commit (incl. generated files)**

```bash
git add mobile/lib/router
git commit -m "feat(router): add /edit-captions/:videoId route"
```

---

### Task 5.3: Long-press on `CcActionButton` opens the editor for the author

**Files:**
- Modify: `mobile/lib/widgets/video_feed_item/actions/cc_action_button.dart`
- Modify: `mobile/test/widgets/video_feed_item/actions/cc_action_button_test.dart`

- [ ] **Step 1: Failing test**

Add to `cc_action_button_test.dart`:

```dart
testWidgets('long-press navigates to /edit-captions when current user is author',
    (tester) async {
  // Stub current user pubkey == video.pubkey, then long-press the CC button
  // and verify GoRouter received the EditCaptionsRoute.
  // (Use a captured router that records the last go() call.)
});

testWidgets('long-press is a no-op for non-authors', (tester) async {
  // Stub current user pubkey != video.pubkey, long-press, expect no nav.
});
```

(Implement using the project's existing test helpers for routing — search `mobile/test` for `GoRouter` mocks already in use.)

- [ ] **Step 2: Implement long-press wiring**

```dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  final isActive = ref.watch(subtitleVisibilityProvider);
  final currentPubkey = ref.watch(currentUserPubkeyProvider); // existing
  final isAuthor =
      currentPubkey != null && currentPubkey == video.pubkey;

  if (!video.hasSubtitles && !isAuthor) return const SizedBox.shrink();

  return Semantics(
    identifier: 'cc_button',
    container: true,
    explicitChildNodes: true,
    button: true,
    label: isActive ? 'Hide subtitles' : 'Show subtitles',
    child: GestureDetector(
      onLongPress: isAuthor
          ? () => EditCaptionsRoute(videoId: video.id, $extra: video)
              .push(context)
          : null,
      child: IconButton(
        // ... existing IconButton unchanged ...
      ),
    ),
  );
}
```

(Wrap with `GestureDetector` rather than adding to `IconButton` because IconButton doesn't expose `onLongPress`.)

- [ ] **Step 3: Run, pass, commit**

```bash
cd mobile && flutter test test/widgets/video_feed_item/actions/cc_action_button_test.dart
git add mobile/lib/widgets mobile/test/widgets
git commit -m "feat(cc_button): long-press opens editor for video author"
```

---

### Task 5.4: Add "Edit captions" item to the metadata expanded sheet

**Files:**
- Modify: `mobile/lib/widgets/video_feed_item/metadata/metadata_expanded_sheet.dart`
- Modify (or create): tests for that sheet

- [ ] **Step 1: Find an existing list-item pattern in the sheet** and add a new tile shown only when `currentPubkey == video.pubkey`. Tile copy: "Edit captions". On tap: close the sheet, then `EditCaptionsRoute(videoId: video.id, $extra: video).push(context)`.

- [ ] **Step 2: Add a widget test that asserts:**
  1. Tile is hidden for non-author.
  2. Tile is visible for author.
  3. Tapping tile triggers navigation (capture via mock router).

- [ ] **Step 3: Run, pass, commit**

```bash
git add mobile/lib/widgets mobile/test/widgets
git commit -m "feat(metadata_sheet): Edit captions item for video author"
```

---

## Chunk 6: E2E + ship checks

### Task 6.1: Round-trip tests for `SubtitleService`

**Files:**
- Create or extend: `mobile/test/services/subtitle_service_test.dart`

- [ ] **Step 1: Add tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/subtitle_service.dart';

void main() {
  group(SubtitleService, () {
    test('generate→parse round-trip preserves cues', () {
      const input = [
        SubtitleCue(start: 0, end: 1000, text: 'hello'),
        SubtitleCue(start: 1000, end: 2500, text: 'world\nline 2'),
      ];
      final vtt = SubtitleService.generateVtt(input);
      final parsed = SubtitleService.parseVtt(vtt);
      expect(parsed.length, equals(2));
      expect(parsed[0].start, equals(0));
      expect(parsed[0].end, equals(1000));
      expect(parsed[0].text, equals('hello'));
      expect(parsed[1].text, equals('world\nline 2'));
    });

    test('parse returns empty list on garbage / JSON', () {
      expect(SubtitleService.parseVtt(''), isEmpty);
      expect(SubtitleService.parseVtt('[]'), isEmpty);
      expect(SubtitleService.parseVtt('{"text":"x"}'), isEmpty);
    });

    test('generate single full-duration cue produces valid VTT', () {
      const input = [SubtitleCue(start: 0, end: 6000, text: 'whole video')];
      final vtt = SubtitleService.generateVtt(input);
      expect(vtt, startsWith('WEBVTT'));
      expect(vtt, contains('00:00:00.000 --> 00:00:06.000'));
      expect(vtt, contains('whole video'));
    });
  });
}
```

- [ ] **Step 2: Run, commit**

```bash
cd mobile && flutter test test/services/subtitle_service_test.dart
git add mobile/test/services/subtitle_service_test.dart
git commit -m "test(subtitle_service): round-trip + garbage parse + full-duration"
```

---

### Task 6.2: E2E — author edits their own captions

**Files:**
- Create: `mobile/integration_test/edit_captions_journey_test.dart`

Follow `mobile/.claude/rules/e2e_testing.md` (uses Patrol + local Docker stack). Requires `mise run local_up` to be running.

- [ ] **Step 1: Implement the journey**

```dart
// ABOUTME: E2E — register, publish a video, edit its captions, verify
// ABOUTME: Kind 39307 lands on the local relay with the new content.

import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'helpers/db_helpers.dart';
import 'helpers/http_helpers.dart';
import 'helpers/navigation_helpers.dart';
import 'helpers/relay_helpers.dart';
import 'helpers/test_setup.dart';

void main() {
  patrolTest('author can edit captions on their own video', ($) async {
    final tester = $.tester;

    final originalOnError = suppressSetStateErrors();
    final originalErrorBuilder = saveErrorWidgetBuilder();

    launchAppGuarded(/* main entrypoint */);
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // 1. register a fresh user, verify, log in
    // 2. publish a short video so we own a Kind 34236 + Kind 39307 stub
    // 3. open the video, long-press CC button (or open 3-dot → Edit captions)
    // 4. type into the first cue's textfield: "corrected words"
    // 5. tap Save
    // 6. await snackbar "Captions updated"
    // 7. assert relay has Kind 39307 from our pubkey containing "corrected words"

    restoreErrorWidgetBuilder(originalErrorBuilder);
    restoreErrorHandler(originalOnError);
    drainAsyncErrors(tester);
  });
}
```

(Fill in the journey using existing helpers. Pattern-match against `auth_journey_test.dart` for register-and-publish flow; use `relay_helpers.dart` to query Kind 39307 after save.)

- [ ] **Step 2: Run E2E**

```bash
cd mobile && mise run local_up && mise run e2e_test integration_test/edit_captions_journey_test.dart
```

Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add mobile/integration_test/edit_captions_journey_test.dart
git commit -m "test(e2e): author edits own captions, verifies Kind 39307 on relay"
```

---

### Task 6.3: Final ship verification

- [ ] **Step 1: `flutter analyze` clean**

```bash
cd mobile && flutter analyze lib test integration_test
```

Expected: 0 issues.

- [ ] **Step 2: All tests pass**

```bash
cd mobile && flutter test --test-randomize-ordering-seed random
```

Expected: ALL PASS, randomized order.

- [ ] **Step 3: Coverage on new files ≥ 100%**

```bash
cd mobile && flutter test --coverage
# inspect coverage/lcov.info — focus on lib/screens/subtitle_editor/**
# and packages/subtitle_repository/**
```

If gaps, add targeted tests; do not lower the threshold.

- [ ] **Step 4: Manual smoke**

```bash
cd mobile && mise run local_up
flutter run --dart-define=DEFAULT_ENV=LOCAL
```

- Sign in
- Publish a short video
- Open the video, 3-dot → Edit captions (and try long-press CC)
- Edit a cue, Save
- Verify the new text appears on next play of the same video
- Verify a non-author CANNOT see "Edit captions" on someone else's video

- [ ] **Step 5: Cross-check the Backend Contract section in the spec against the deployed Blossom endpoint**

Coordinate with the parallel Blossom-side work. If the live response codes differ from the spec, update both the spec and `BlossomVttClient` mapping.

- [ ] **Step 6: PR**

```bash
git push -u origin <branch>
gh pr create \
  --title "feat(captions): author-only caption editing" \
  --body "$(cat <<'EOF'
## Summary
- New "Edit captions" entry point (3-dot + long-press CC) shown only on the author's own videos
- Full-screen editor with cue-list + single-cue fallback for empty/garbage VTT
- Dual-write: Kind 39307 (signed source of truth) + `PUT /v1/{sha256}/vtt` (cache, best-effort)
- New `subtitle_repository` package with TDD-built BlossomVttClient + repository

Spec: `docs/superpowers/specs/2026-04-26-subtitle-edit-design.md`
Plan: `docs/superpowers/plans/2026-04-26-subtitle-edit.md`

## Test plan
- [ ] `flutter analyze lib test integration_test` clean
- [ ] `flutter test --test-randomize-ordering-seed random` passes
- [ ] Coverage 100% on new files
- [ ] E2E `edit_captions_journey_test.dart` passes against local stack
- [ ] Manual smoke: edit captions on own video, see new text on next play
- [ ] Manual: non-author cannot see "Edit captions" entry

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

---

## v2 / Future Work (NOT in this plan — captured in spec)

- Collaborator editing (NIP-26 vs allowlist resolution)
- Re-transcribe action
- Timing edits / split / merge / add / delete cues
- Multi-language tracks
- Viewer "report bad captions" affordance
