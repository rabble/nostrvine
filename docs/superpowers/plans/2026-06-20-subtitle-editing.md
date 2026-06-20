# Creator Subtitle Editing & Republish-to-Blossom — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a creator fix the (often-wrong) auto-generated subtitles on
their own video, text-only, and republish the corrected captions to both
Blossom (durable content-addressed blob) and a Kind 39307 Nostr event,
with the video event referencing both for read-time redundancy.

**Architecture:** UI (`SubtitleEditorScreen`, Page/View) → Cubit
(`SubtitleEditorCubit`) → Repository (`SubtitleRepository`, owns
generate→upload→publish→republish orchestration) → Clients
(`BlossomUploadService.uploadSubtitleVtt`, `VideoEventPublisher`,
`NostrClient`). A shared `fetchSubtitleCues` function is extracted so the
display provider and the editor's load path share one fallback chain.

**Tech Stack:** Flutter, flutter_bloc (Cubit), Riverpod (DI bridge),
go_router, dio, nostr_sdk, Blossom BUD-01, WebVTT.

Spec: `docs/superpowers/specs/2026-06-20-subtitle-editing-design.md`.

---

## Pre-flight

- [ ] **Step 0: Create the worktree from `origin/main`** (run from repo root)

```bash
git fetch origin
git worktree add .worktrees/subtitle-editing -b feat/subtitle-editing origin/main
cd .worktrees/subtitle-editing/mobile
mise trust && mise exec -- flutter pub get
```

All `flutter`/`dart` commands below run from `mobile/` in this worktree,
prefixed with `mise exec --` per repo convention.

---

## File Structure

**Create:**
- `mobile/lib/services/subtitle_fetcher.dart` — shared `fetchSubtitleCues` + helpers (moved out of the provider).
- `mobile/lib/repositories/subtitle_repository.dart` — orchestration + `SubtitleEditException`.
- `mobile/lib/providers/subtitle_repository_provider.dart` — `subtitleRepositoryProvider`.
- `mobile/lib/blocs/subtitle_editor/subtitle_editor_cubit.dart`
- `mobile/lib/blocs/subtitle_editor/subtitle_editor_state.dart`
- `mobile/lib/screens/subtitle_editor/subtitle_editor_screen.dart` — Page + View + private widgets.
- Tests mirroring each of the above.

**Modify:**
- `mobile/packages/blossom_upload_service/lib/src/blossom_upload_service.dart` — add `uploadSubtitleVtt`.
- `mobile/packages/models/lib/src/video_event.dart` — add `textTrackRefs`, accumulate all `text-track` tags.
- `mobile/lib/providers/subtitle_providers.dart` — delegate to `fetchSubtitleCues`, accept `textTrackRefs`.
- `mobile/lib/widgets/video_feed_item/subtitle_overlay.dart` — pass `textTrackRefs`.
- `mobile/lib/services/video_event_publisher.dart` — add `publishSubtitleEvent`, extend `republishWithSubtitles`.
- `mobile/packages/models/lib/src/nip71_video_kinds.dart` — add subtitle kind constant.
- `mobile/lib/router/app_router.dart` — add `/subtitle-edit/:videoId` route.
- `mobile/lib/widgets/video_metadata/modes/edit/video_metadata_edit_bottom_bar.dart` — add "Edit subtitles" action.
- `mobile/lib/l10n/app_en.arb` + `test/l10n/arb_consistency_test.dart` allowlist.

---

## Task 1: Blossom — `uploadSubtitleVtt`

**Files:**
- Modify: `mobile/packages/blossom_upload_service/lib/src/blossom_upload_service.dart`
- Test: `mobile/packages/blossom_upload_service/test/src/blossom_upload_service_test.dart`

- [ ] **Step 1: Write the failing test**

Add inside the existing `group('BlossomUploadService', ...)` in the test
file. Mirrors the existing mock setup (`_MockAuthProvider`, `_MockDio`,
`_MockResponse`, `_signedEvent`). It asserts the VTT bytes are PUT with
`Content-Type: text/vtt` and that the sha256 is returned.

```dart
group('uploadSubtitleVtt', () {
  test('PUTs VTT bytes with text/vtt content type and returns sha256',
      () async {
    final mockDio = _MockDio();
    final mockResponse = _MockResponse();
    when(() => mockResponse.statusCode).thenReturn(200);
    when(() => mockResponse.data).thenReturn(<String, dynamic>{});
    when(() => mockAuthProvider.isAuthenticated).thenReturn(true);
    when(
      () => mockAuthProvider.createAndSignEvent(
        kind: any(named: 'kind'),
        content: any(named: 'content'),
        tags: any(named: 'tags'),
      ),
    ).thenAnswer(
      (_) async => _signedEvent(_testPublicKey, 24242, const [], ''),
    );
    when(
      () => mockDio.put<dynamic>(
        any(),
        data: any(named: 'data'),
        options: any(named: 'options'),
        onSendProgress: any(named: 'onSendProgress'),
      ),
    ).thenAnswer((_) async => mockResponse);

    final service = BlossomUploadService(
      authProvider: mockAuthProvider,
      dio: mockDio,
    );

    final vtt = utf8.encode('WEBVTT\n\n00:00:00.000 --> 00:00:01.000\nhi\n');
    final result = await service.uploadSubtitleVtt(
      bytes: Uint8List.fromList(vtt),
    );

    expect(result.success, isTrue);
    expect(result.videoId, isNotNull);
    expect(result.url, contains(result.videoId!));

    final captured = verify(
      () => mockDio.put<dynamic>(
        any(),
        data: any(named: 'data'),
        options: captureAny(named: 'options'),
        onSendProgress: any(named: 'onSendProgress'),
      ),
    ).captured.single as Options;
    expect(captured.headers!['Content-Type'], 'text/vtt');
  });

  test('returns auth failure when not authenticated', () async {
    when(() => mockAuthProvider.isAuthenticated).thenReturn(false);
    final service = BlossomUploadService(authProvider: mockAuthProvider);
    final result = await service.uploadSubtitleVtt(
      bytes: Uint8List.fromList(utf8.encode('WEBVTT\n')),
    );
    expect(result.success, isFalse);
    expect(result.failureReason, BlossomUploadFailureReason.auth);
  });
});
```

Add `import 'dart:convert';` to the test file if not already present
(`dart:typed_data` is already imported).

- [ ] **Step 2: Run test to verify it fails**

Run: `mise exec -- flutter test test/src/blossom_upload_service_test.dart --plain-name uploadSubtitleVtt` (from `mobile/packages/blossom_upload_service`)
Expected: FAIL — `uploadSubtitleVtt` not defined.

- [ ] **Step 3: Implement `uploadSubtitleVtt`**

Add this method to `class BlossomUploadService`, directly after the
existing `uploadAudio` method. It reuses `_BytesUploadSource`,
`HashUtil.sha256Hash`, `_getServerUrlsForUpload`, `_uploadToServer`,
`_classifyUploadException`, and `_defaultServerUrl` — all already in the
file.

```dart
/// Uploads a subtitle VTT blob (BUD-01) and returns its sha256 + canonical
/// URL. MIME defaults to `text/vtt`; Blossom is content-addressed so the
/// stored Content-Type does not affect the address.
Future<BlossomUploadResult> uploadSubtitleVtt({
  required Uint8List bytes,
  String mimeType = 'text/vtt',
  void Function(double)? onProgress,
}) async {
  if (!authProvider.isAuthenticated) {
    return const BlossomUploadResult(
      success: false,
      errorMessage: 'Not authenticated',
      failureReason: BlossomUploadFailureReason.auth,
    );
  }

  onProgress?.call(0.1);

  final fileHash = HashUtil.sha256Hash(bytes);
  final fileSize = bytes.length;

  final serverUrls = await _getServerUrlsForUpload();
  BlossomUploadResult? lastError;

  for (final serverUrl in serverUrls) {
    try {
      final result = await _uploadToServer(
        serverUrl: serverUrl,
        source: _BytesUploadSource(bytes: bytes, filename: 'subtitles.vtt'),
        fileHash: fileHash,
        fileSize: fileSize,
        contentType: mimeType,
        onProgress: onProgress,
      );

      if (result.success) {
        final canonicalUrl = '$_defaultServerUrl/$fileHash';
        return BlossomUploadResult(
          success: true,
          url: canonicalUrl,
          fallbackUrl: canonicalUrl,
          videoId: fileHash,
        );
      }
      lastError = result;
    } on Object catch (e) {
      final statusCode = e is DioException ? e.response?.statusCode : null;
      lastError = BlossomUploadResult(
        success: false,
        statusCode: statusCode,
        errorMessage: 'Upload to $serverUrl failed: $e',
        failureReason: _classifyUploadException(e),
      );
    }
  }

  return lastError ??
      const BlossomUploadResult(
        success: false,
        errorMessage: 'All servers failed',
        failureReason: BlossomUploadFailureReason.unknown,
      );
}
```

- [ ] **Step 4: Run tests to verify pass + analyze**

Run: `mise exec -- flutter test test/src/blossom_upload_service_test.dart --plain-name uploadSubtitleVtt`
Expected: PASS.
Run: `mise exec -- flutter analyze lib test`
Expected: No issues.

- [ ] **Step 5: Commit**

```bash
git add packages/blossom_upload_service
git commit -m "feat(blossom): add uploadSubtitleVtt for text/vtt blobs"
```

---

## Task 2: Subtitle kind constant

**Files:**
- Modify: `mobile/packages/models/lib/src/nip71_video_kinds.dart`
- Test: `mobile/packages/models/test/src/nip71_video_kinds_test.dart` (create if absent)

- [ ] **Step 1: Write the failing test**

```dart
import 'package:models/models.dart';
import 'package:test/test.dart';

void main() {
  group(NIP71VideoKinds, () {
    test('subtitleEventKind is 39307', () {
      expect(NIP71VideoKinds.subtitleEventKind, 39307);
    });
  });
}
```

(If the package uses `flutter_test` instead of `test`, match the
neighbouring test files' import. Check an existing test in
`mobile/packages/models/test/`.)

- [ ] **Step 2: Run to verify it fails**

Run: `mise exec -- flutter test test/src/nip71_video_kinds_test.dart` (from `mobile/packages/models`)
Expected: FAIL — `subtitleEventKind` not defined.

- [ ] **Step 3: Add the constant**

In `class NIP71VideoKinds`, add:

```dart
/// Addressable subtitle/caption event kind referenced by a video's
/// `text-track` tag as `39307:<pubkey>:subtitles:<video-d-tag>`.
static const int subtitleEventKind = 39307;
```

- [ ] **Step 4: Run to verify pass**

Run: `mise exec -- flutter test test/src/nip71_video_kinds_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add packages/models/lib/src/nip71_video_kinds.dart packages/models/test
git commit -m "feat(models): add NIP71VideoKinds.subtitleEventKind constant"
```

---

## Task 3: `VideoEvent.textTrackRefs` — capture all text-track tags

**Files:**
- Modify: `mobile/packages/models/lib/src/video_event.dart`
- Test: `mobile/packages/models/test/src/video_event_text_track_test.dart`

- [ ] **Step 1: Write the failing test**

Append to the existing text-track test file:

```dart
test('captures multiple text-track tags into textTrackRefs in order', () {
  final event = Event(
    testPubkey,
    34236,
    [
      ['d', 'my-vine-id'],
      [
        'text-track',
        'https://media.divine.video/abc123',
        'wss://relay.divine.video',
        'captions',
        'en',
      ],
      [
        'text-track',
        '39307:$testPubkey:subtitles:my-vine-id',
        'wss://relay.divine.video',
        'captions',
        'en',
      ],
    ],
    'content',
  );

  final video = VideoEvent.fromNostrEvent(event);

  expect(video.textTrackRefs, [
    'https://media.divine.video/abc123',
    '39307:$testPubkey:subtitles:my-vine-id',
  ]);
  // Back-compat: single-value getter still returns the first.
  expect(video.textTrackRef, 'https://media.divine.video/abc123');
});
```

(Match how the existing tests in this file construct `Event` /
`testPubkey`; reuse the file's existing helpers.)

- [ ] **Step 2: Run to verify it fails**

Run: `mise exec -- flutter test test/src/video_event_text_track_test.dart --plain-name "captures multiple"` (from `mobile/packages/models`)
Expected: FAIL — `textTrackRefs` not defined (and only first tag captured).

- [ ] **Step 3: Implement the field + accumulation**

3a. Add the constructor parameter (in the `const VideoEvent({...})` list,
next to `this.textTrackRef`):

```dart
    this.textTrackRefs = const [],
```

3b. Add the field declaration (next to `final String? textTrackRef;`):

```dart
  /// All `text-track` references in tag order, for read-time fallback.
  /// `textTrackRef` mirrors the first entry for back-compat.
  final List<String> textTrackRefs;
```

3c. Replace the `case 'text-track':` parse handler. It currently does:

```dart
        case 'text-track':
          // Subtitle/caption track reference
          // Format: ['text-track', '<coords-or-url>', '<relay>', 'captions',
          //          '<lang>']
          if (tagValue.isNotEmpty) {
            textTrackRef ??= tagValue;
          }
```

Replace with (accumulate into a list local, mirroring the `hashtags`
pattern). First declare a local near the other tag-accumulator locals at
the top of the parse loop (where `hashtags`, `collaboratorPubkeys` are
declared):

```dart
    final textTrackRefs = <String>[];
```

Then the case body:

```dart
        case 'text-track':
          // Subtitle/caption track reference(s). Format:
          // ['text-track', '<coords-or-url>', '<relay>', 'captions', '<lang>']
          if (tagValue.isNotEmpty) {
            textTrackRefs.add(tagValue);
          }
```

3d. Where `VideoEvent.fromNostrEvent` constructs the `VideoEvent(...)`,
pass both the list and the first-element back-compat value. Find the
existing `textTrackRef: textTrackRef,` argument and replace it with:

```dart
      textTrackRef: textTrackRefs.isNotEmpty ? textTrackRefs.first : null,
      textTrackRefs: textTrackRefs,
```

Remove the now-unused `String? textTrackRef;` local that the old code
declared for the `??=` accumulation (if present).

3e. Add `textTrackRefs` to `copyWith` (find the `copyWith` method, add a
`List<String>? textTrackRefs` param and
`textTrackRefs: textTrackRefs ?? this.textTrackRefs,`).

- [ ] **Step 4: Run to verify pass + full models suite**

Run: `mise exec -- flutter test test/src/video_event_text_track_test.dart`
Expected: PASS.
Run: `mise exec -- flutter test` (from `mobile/packages/models`)
Expected: PASS (no regression in VideoEvent parsing/copyWith tests).

- [ ] **Step 5: Commit**

```bash
git add packages/models
git commit -m "feat(models): capture all text-track refs into VideoEvent.textTrackRefs"
```

---

## Task 4: Extract `fetchSubtitleCues` shared fallback chain

**Files:**
- Create: `mobile/lib/services/subtitle_fetcher.dart`
- Modify: `mobile/lib/providers/subtitle_providers.dart`
- Modify: `mobile/lib/widgets/video_feed_item/subtitle_overlay.dart`
- Test: `mobile/test/services/subtitle_fetcher_test.dart`

This moves the triple-fetch logic into a plain function reusable by both
the provider and the repository, and makes it iterate over an ordered
ref list (Blossom URL → 39307 coords) before the auto-generated
`{sha256}/vtt` path.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:openvine/services/subtitle_fetcher.dart';
import 'package:openvine/services/subtitle_service.dart';

class _FakeClient extends http.BaseClient {
  _FakeClient(this.handler);
  final Future<http.Response> Function(http.Request) handler;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final res = await handler(request as http.Request);
    return http.StreamedResponse(
      Stream.value(res.bodyBytes),
      res.statusCode,
      headers: res.headers,
    );
  }
}

const _vtt = 'WEBVTT\n\n00:00:00.000 --> 00:00:01.000\nhello\n';

void main() {
  group('fetchSubtitleCues', () {
    test('parses embedded textTrackContent first (no network)', () async {
      final cues = await fetchSubtitleCues(
        httpClient: _FakeClient((_) async => throw StateError('no network')),
        nostrClient: null,
        delay: (_) async {},
        textTrackContent: _vtt,
      );
      expect(cues, hasLength(1));
      expect(cues.first.text, 'hello');
    });

    test('falls back to second ref when first http ref is unavailable',
        () async {
      final cues = await fetchSubtitleCues(
        httpClient: _FakeClient((req) async {
          if (req.url.toString() == 'https://media.divine.video/dead') {
            return http.Response('', 404);
          }
          if (req.url.toString() == 'https://media.divine.video/live') {
            return http.Response(_vtt, 200);
          }
          return http.Response('', 500);
        }),
        nostrClient: null,
        delay: (_) async {},
        textTrackRefs: const [
          'https://media.divine.video/dead',
          'https://media.divine.video/live',
        ],
      );
      expect(cues, hasLength(1));
      expect(cues.first.text, 'hello');
    });
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `mise exec -- flutter test test/services/subtitle_fetcher_test.dart` (from `mobile/`)
Expected: FAIL — `subtitle_fetcher.dart` does not exist.

- [ ] **Step 3: Create `subtitle_fetcher.dart`**

Move the helper functions out of `subtitle_providers.dart` and add the
ref-iteration. `NostrClient` is nullable so the repository/tests can pass
`null` when no relay is needed.

```dart
// ABOUTME: Shared subtitle fetch chain used by the display provider and the
// ABOUTME: editor's load path. Ordered fallback: embedded content → each
// ABOUTME: text-track ref (http or 39307 relay) → Blossom {sha256}/vtt.

import 'package:http/http.dart' as http;
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/services/subtitle_service.dart';
import 'package:unified_logger/unified_logger.dart';

typedef SubtitlePollDelay = Future<void> Function(Duration duration);

const _maxBlossomPollAttempts = 4;
const _maxBlossomPollWait = Duration(seconds: 15);
const _defaultBlossomRetryAfter = Duration(seconds: 3);

Duration _parseRetryAfter(Map<String, String> headers) {
  final rawValue = headers['retry-after'];
  if (rawValue == null) return _defaultBlossomRetryAfter;
  final seconds = int.tryParse(rawValue.trim());
  if (seconds == null || seconds <= 0) return _defaultBlossomRetryAfter;
  return Duration(seconds: seconds);
}

Uri? _parseHttpSubtitleUrl(String ref) {
  if (ref.isEmpty) return null;
  final uri = Uri.tryParse(ref);
  if (uri == null) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;
  return uri;
}

Future<List<SubtitleCue>?> _fetchHttp(http.Client client, Uri url) async {
  try {
    final response = await client.get(url);
    if (response.statusCode == 200 && response.body.trim().isNotEmpty) {
      return SubtitleService.parseVtt(response.body);
    }
  } catch (e) {
    Log.warning(
      'Direct VTT fetch failed for $url: $e',
      name: 'fetchSubtitleCues',
      category: LogCategory.video,
    );
  }
  return null;
}

Future<List<SubtitleCue>?> _fetchRelay(
  NostrClient nostrClient,
  String ref,
) async {
  final parts = ref.split(':');
  if (parts.length < 3) return null;
  final kind = int.tryParse(parts[0]);
  if (kind == null) return null;
  final pubkey = parts[1];
  final dTag = parts.sublist(2).join(':');
  final events = await nostrClient.queryEvents(
    [
      Filter(kinds: [kind], authors: [pubkey], d: [dTag], limit: 1),
    ],
    tempRelays: ['wss://relay.divine.video'],
  );
  if (events.isEmpty) return null;
  return SubtitleService.parseVtt(events.first.content);
}

Future<List<SubtitleCue>?> _fetchBlossom({
  required http.Client client,
  required SubtitlePollDelay delay,
  required Uri vttUrl,
}) async {
  var waited = Duration.zero;
  for (var attempt = 0; attempt < _maxBlossomPollAttempts; attempt++) {
    final response = await client.get(vttUrl);
    if (response.statusCode == 200 && response.body.trim().isNotEmpty) {
      return SubtitleService.parseVtt(response.body);
    }
    if (response.statusCode == 202) {
      if (attempt == _maxBlossomPollAttempts - 1) return null;
      final retryAfter = _parseRetryAfter(response.headers);
      if (waited + retryAfter > _maxBlossomPollWait) return null;
      waited += retryAfter;
      await delay(retryAfter);
      continue;
    }
    return null;
  }
  return null;
}

/// Resolves subtitle cues with ordered fallback. Returns `[]` when no
/// source yields cues (e.g. auto-transcription not ready yet).
Future<List<SubtitleCue>> fetchSubtitleCues({
  required http.Client httpClient,
  required NostrClient? nostrClient,
  required SubtitlePollDelay delay,
  String? textTrackContent,
  List<String> textTrackRefs = const [],
  String? sha256,
}) async {
  if (textTrackContent != null && textTrackContent.isNotEmpty) {
    return SubtitleService.parseVtt(textTrackContent);
  }

  for (final ref in textTrackRefs) {
    final httpUrl = _parseHttpSubtitleUrl(ref);
    if (httpUrl != null) {
      final cues = await _fetchHttp(httpClient, httpUrl);
      if (cues != null) return cues;
      continue;
    }
    if (nostrClient != null) {
      try {
        final cues = await _fetchRelay(nostrClient, ref);
        if (cues != null) return cues;
      } catch (e) {
        Log.warning(
          'Relay VTT fetch failed for $ref: $e',
          name: 'fetchSubtitleCues',
          category: LogCategory.video,
        );
      }
    }
  }

  if (sha256 != null && sha256.isNotEmpty) {
    final vttUrl = Uri.parse('https://media.divine.video/$sha256/vtt');
    try {
      final cues = await _fetchBlossom(
        client: httpClient,
        delay: delay,
        vttUrl: vttUrl,
      );
      if (cues != null) return cues;
    } catch (e) {
      Log.warning(
        'Blossom VTT fetch failed for $sha256: $e',
        name: 'fetchSubtitleCues',
        category: LogCategory.video,
      );
    }
  }

  return [];
}
```

(Confirm the `nostr_client` import path matches the one used elsewhere in
`lib/` — see `subtitle_providers.dart`'s existing imports. If `NostrClient`
is surfaced via a different package name, use that.)

- [ ] **Step 4: Run the new test to verify pass**

Run: `mise exec -- flutter test test/services/subtitle_fetcher_test.dart`
Expected: PASS.

- [ ] **Step 5: Rewire the provider to delegate**

In `mobile/lib/providers/subtitle_providers.dart`:

5a. Keep `subtitleHttpClientProvider`, `subtitlePollDelayProvider`, and
`SubtitleVisibility`. Remove the now-moved helpers (`_parseRetryAfter`,
`_parseHttpSubtitleUrl`, `_fetchBlossomSubtitles`) and the
`SubtitlePollDelay` typedef — import them from the fetcher instead. Add:

```dart
import 'package:openvine/services/subtitle_fetcher.dart';
```

(Keep `subtitlePollDelayProvider` using the imported `SubtitlePollDelay`.)

5b. Replace the `subtitleCues` provider body, adding an optional
`textTrackRefs` param (existing `textTrackRef` retained for back-compat):

```dart
@riverpod
Future<List<SubtitleCue>> subtitleCues(
  Ref ref, {
  required String videoId,
  String? textTrackRef,
  List<String> textTrackRefs = const [],
  String? textTrackContent,
  String? sha256,
}) async {
  final refs = textTrackRefs.isNotEmpty
      ? textTrackRefs
      : [
          if (textTrackRef != null && textTrackRef.isNotEmpty) textTrackRef,
        ];
  return fetchSubtitleCues(
    httpClient: ref.read(subtitleHttpClientProvider),
    nostrClient: ref.read(nostrServiceProvider),
    delay: ref.read(subtitlePollDelayProvider),
    textTrackContent: textTrackContent,
    textTrackRefs: refs,
    sha256: sha256,
  );
}
```

5c. Regenerate Riverpod:

Run: `mise exec -- dart run build_runner build --delete-conflicting-outputs`

- [ ] **Step 6: Update the overlay caller**

In `mobile/lib/widgets/video_feed_item/subtitle_overlay.dart` (~line 75),
change:

```dart
    final cuesAsync = ref.watch(
      subtitleCuesProvider(
        videoId: widget.video.id,
        textTrackRef: widget.video.textTrackRef,
        textTrackContent: widget.video.textTrackContent,
        sha256: widget.video.sha256,
      ),
    );
```

to:

```dart
    final cuesAsync = ref.watch(
      subtitleCuesProvider(
        videoId: widget.video.id,
        textTrackRefs: widget.video.textTrackRefs,
        textTrackContent: widget.video.textTrackContent,
        sha256: widget.video.sha256,
      ),
    );
```

- [ ] **Step 7: Run the existing provider suite + analyze**

Run: `mise exec -- flutter test test/providers/subtitle_providers_test.dart`
Expected: PASS (the existing single-`textTrackRef` and `sha256` tests still
hold; behavior preserved, with relay refs now tried before the auto-gen
`sha256` path).
Run: `mise exec -- flutter analyze lib test`
Expected: No issues.

- [ ] **Step 8: Commit**

```bash
git add lib/services/subtitle_fetcher.dart \
        lib/providers/subtitle_providers.dart \
        lib/providers/subtitle_providers.g.dart \
        lib/widgets/video_feed_item/subtitle_overlay.dart \
        test/services/subtitle_fetcher_test.dart
git commit -m "refactor(subtitles): extract shared fetchSubtitleCues with ordered ref fallback"
```

---

## Task 5: `VideoEventPublisher` — publish 39307 + dual text-track refs

**Files:**
- Modify: `mobile/lib/services/video_event_publisher.dart`
- Test: `mobile/test/services/video_event_publisher_subtitle_test.dart`

- [ ] **Step 1: Write the failing tests**

Append to the existing subtitle publisher test file (reuse its mocks for
`AuthService`, `NostrClient`, etc.; mirror how `republishWithSubtitles`
is already tested there).

```dart
test('publishSubtitleEvent signs a 39307 with d=subtitles:<vineId>',
    () async {
  // Arrange: video with vineId, authed pubkey, signer returns an Event,
  // publish succeeds. (Match the file's existing arrange helpers.)
  final ref = await publisher.publishSubtitleEvent(
    video: existingEvent, // has vineId 'my-vine-id'
    vttContent: 'WEBVTT\n\n00:00:00.000 --> 00:00:01.000\nhi\n',
    blossomUrl: 'https://media.divine.video/abc123',
  );

  expect(ref, '39307:$testPubkey:subtitles:my-vine-id');

  final captured = verify(
    () => mockAuthService.createAndSignEvent(
      kind: captureAny(named: 'kind'),
      content: captureAny(named: 'content'),
      tags: captureAny(named: 'tags'),
    ),
  ).captured;
  expect(captured[0], 39307);
  final tags = (captured[2] as List).cast<List<String>>();
  expect(tags, contains(['d', 'subtitles:my-vine-id']));
  expect(tags, contains(['url', 'https://media.divine.video/abc123']));
  expect(tags, contains(['m', 'text/vtt']));
});

test('republishWithSubtitles emits one text-track tag per ref', () async {
  await publisher.republishWithSubtitles(
    existingEvent: existingEvent,
    textTrackRef: 'https://media.divine.video/abc123',
    extraTextTrackRefs: const ['39307:$testPubkey:subtitles:my-vine-id'],
  );

  final captured = verify(
    () => mockAuthService.createAndSignEvent(
      kind: any(named: 'kind'),
      content: any(named: 'content'),
      tags: captureAny(named: 'tags'),
    ),
  ).captured.single as List;
  final tags = captured.cast<List<String>>();
  final trackTags = tags.where((t) => t.first == 'text-track').toList();
  expect(trackTags, hasLength(2));
  expect(trackTags[0][1], 'https://media.divine.video/abc123');
  expect(trackTags[1][1], '39307:$testPubkey:subtitles:my-vine-id');
});
```

- [ ] **Step 2: Run to verify they fail**

Run: `mise exec -- flutter test test/services/video_event_publisher_subtitle_test.dart` (from `mobile/`)
Expected: FAIL — `publishSubtitleEvent` undefined, `extraTextTrackRefs` undefined.

- [ ] **Step 3: Implement**

3a. Add `import 'package:models/models.dart';` if `NIP71VideoKinds`
isn't already imported (it is used elsewhere in this file via
`NIP71VideoKinds.getPreferredAddressableKind()`, so it is).

3b. Extend `republishWithSubtitles`. Change its signature to add
`extraTextTrackRefs` and emit one tag per ref. Replace the single
`tags.add([...])` block:

```dart
  Future<bool> republishWithSubtitles({
    required VideoEvent existingEvent,
    required String textTrackRef,
    List<String> extraTextTrackRefs = const [],
    String textTrackLang = 'en',
  }) async {
    final tags = existingEvent.nostrEventTags
        .where((t) => t.isNotEmpty && t.first != 'text-track')
        .map(List<String>.from)
        .toList();

    for (final ref in [textTrackRef, ...extraTextTrackRefs]) {
      tags.add([
        'text-track',
        ref,
        'wss://relay.divine.video',
        'captions',
        textTrackLang,
      ]);
    }

    final event = await _authService?.createAndSignEvent(
      kind: NIP71VideoKinds.getPreferredAddressableKind(),
      content: existingEvent.content,
      tags: tags,
    );
    // ... rest of the method (null check, optimistic cache, publish)
    // stays exactly as-is ...
```

3c. Add `publishSubtitleEvent` directly after `republishWithSubtitles`:

```dart
  /// Publishes a Kind 39307 subtitle event for [video] and returns its
  /// addressable ref `39307:<pubkey>:subtitles:<vineId>`, or `null` on
  /// failure (not authenticated, no addressable id, sign/publish failed).
  Future<String?> publishSubtitleEvent({
    required VideoEvent video,
    required String vttContent,
    required String blossomUrl,
    String lang = 'en',
  }) async {
    final pubkey = _authService?.currentPublicKeyHex;
    final vineId = video.vineId;
    if (pubkey == null || vineId == null || vineId.isEmpty) return null;

    final dTag = 'subtitles:$vineId';
    final videoKind = NIP71VideoKinds.getPreferredAddressableKind();

    final event = await _authService?.createAndSignEvent(
      kind: NIP71VideoKinds.subtitleEventKind,
      content: vttContent,
      tags: [
        ['d', dTag],
        ['a', '$videoKind:$pubkey:$vineId'],
        ['url', blossomUrl],
        ['m', 'text/vtt'],
        ['l', lang],
      ],
    );
    if (event == null) {
      Log.error(
        'Failed to sign subtitle event',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
      return null;
    }

    final ok = await _publishEventToNostr(event);
    if (!ok) return null;
    return '${NIP71VideoKinds.subtitleEventKind}:$pubkey:$dTag';
  }
```

- [ ] **Step 4: Run to verify pass + existing republish tests**

Run: `mise exec -- flutter test test/services/video_event_publisher_subtitle_test.dart`
Expected: PASS (existing `republishWithSubtitles` tests still green —
`extraTextTrackRefs` defaults to empty → one tag).
Run: `mise exec -- flutter analyze lib test`
Expected: No issues.

- [ ] **Step 5: Commit**

```bash
git add lib/services/video_event_publisher.dart test/services/video_event_publisher_subtitle_test.dart
git commit -m "feat(publisher): publish 39307 subtitle events + dual text-track refs"
```

---

## Task 6: `SubtitleRepository` — orchestration

**Files:**
- Create: `mobile/lib/repositories/subtitle_repository.dart`
- Create: `mobile/lib/providers/subtitle_repository_provider.dart`
- Test: `mobile/test/repositories/subtitle_repository_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/repositories/subtitle_repository.dart';
import 'package:openvine/services/subtitle_service.dart';

class _MockBlossom extends Mock implements BlossomUploadService {}
class _MockPublisher extends Mock implements _PublisherLike {}

// If VideoEventPublisher is hard to mock directly, mock it as its concrete
// type instead (import the real class). Keep a thin abstraction only if the
// real type is final/sealed — otherwise mock VideoEventPublisher directly.

abstract class _PublisherLike {} // placeholder; see note in Step 3

void main() {
  group(SubtitleRepository, () {
    test('publishEditedSubtitles uploads VTT, publishes 39307, republishes',
        () async {
      // Arrange mocks per Step 3's final constructor shape, then:
      // - blossom.uploadSubtitleVtt returns success url .../hash
      // - publisher.publishSubtitleEvent returns coords ref
      // - publisher.republishWithSubtitles returns true
      // Act + assert order of calls and that republish receives both refs.
    });

    test('throws SubtitleEditException when vineId is null', () async {
      // video with vineId == null → expect throwsA(isA<SubtitleEditException>())
    });
  });
}
```

> Note: this test is fully fleshed out in Step 3 once the constructor
> shape is fixed (mock `VideoEventPublisher` and `BlossomUploadService`
> directly with mocktail — both are plain classes). Replace the
> `_PublisherLike` placeholder with `_MockPublisher extends Mock
> implements VideoEventPublisher`.

- [ ] **Step 2: Run to verify it fails**

Run: `mise exec -- flutter test test/repositories/subtitle_repository_test.dart` (from `mobile/`)
Expected: FAIL — `subtitle_repository.dart` does not exist.

- [ ] **Step 3: Implement the repository + finalize the test**

Create `mobile/lib/repositories/subtitle_repository.dart`:

```dart
// ABOUTME: Owns the edit-subtitles orchestration: load current cues, then
// ABOUTME: generate VTT → upload to Blossom → publish 39307 → republish the
// ABOUTME: video with both refs.

import 'dart:convert';
import 'dart:typed_data';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:http/http.dart' as http;
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/subtitle_fetcher.dart';
import 'package:openvine/services/subtitle_service.dart';
import 'package:openvine/services/video_event_publisher.dart';

/// Thrown when an edited-subtitle publish cannot complete. Carries no PII.
class SubtitleEditException implements Exception {
  SubtitleEditException(this.message);
  final String message;
  @override
  String toString() => 'SubtitleEditException: $message';
}

class SubtitleRepository {
  SubtitleRepository({
    required BlossomUploadService blossomUploadService,
    required VideoEventPublisher videoEventPublisher,
    required AuthService authService,
    required NostrClient nostrClient,
    required http.Client httpClient,
    required SubtitlePollDelay pollDelay,
  })  : _blossom = blossomUploadService,
        _publisher = videoEventPublisher,
        _authService = authService,
        _nostrClient = nostrClient,
        _httpClient = httpClient,
        _pollDelay = pollDelay;

  final BlossomUploadService _blossom;
  final VideoEventPublisher _publisher;
  final AuthService _authService;
  final NostrClient _nostrClient;
  final http.Client _httpClient;
  final SubtitlePollDelay _pollDelay;

  /// Loads the current cues for [video] using the shared fallback chain.
  /// Returns `[]` when auto-transcription is not yet available.
  Future<List<SubtitleCue>> loadCues(VideoEvent video) {
    return fetchSubtitleCues(
      httpClient: _httpClient,
      nostrClient: _nostrClient,
      delay: _pollDelay,
      textTrackContent: video.textTrackContent,
      textTrackRefs: video.textTrackRefs,
      sha256: video.sha256,
    );
  }

  /// Generates VTT from [cues], uploads it to Blossom, publishes a 39307
  /// subtitle event, then republishes the video referencing both.
  ///
  /// Throws [SubtitleEditException] on any failed step.
  Future<void> publishEditedSubtitles({
    required VideoEvent video,
    required List<SubtitleCue> cues,
    String lang = 'en',
  }) async {
    if (_authService.currentPublicKeyHex == null) {
      throw SubtitleEditException('Not authenticated');
    }
    final vineId = video.vineId;
    if (vineId == null || vineId.isEmpty) {
      throw SubtitleEditException('Video has no addressable identifier');
    }

    final vtt = SubtitleService.generateVtt(cues);
    final bytes = Uint8List.fromList(utf8.encode(vtt));

    final upload = await _blossom.uploadSubtitleVtt(bytes: bytes);
    final blossomUrl = upload.url;
    if (!upload.success || blossomUrl == null) {
      throw SubtitleEditException('Subtitle upload to Blossom failed');
    }

    final coordsRef = await _publisher.publishSubtitleEvent(
      video: video,
      vttContent: vtt,
      blossomUrl: blossomUrl,
      lang: lang,
    );
    if (coordsRef == null) {
      throw SubtitleEditException('Subtitle event publish failed');
    }

    final ok = await _publisher.republishWithSubtitles(
      existingEvent: video,
      textTrackRef: blossomUrl,
      extraTextTrackRefs: [coordsRef],
      textTrackLang: lang,
    );
    if (!ok) {
      throw SubtitleEditException('Video republish failed');
    }
  }
}
```

Now finalize the test (replace the Step-1 skeleton body):

```dart
class _MockBlossom extends Mock implements BlossomUploadService {}
class _MockPublisher extends Mock implements VideoEventPublisher {}
class _MockAuth extends Mock implements AuthService {}
class _MockNostr extends Mock implements NostrClient {}
class _MockHttp extends Mock implements http.Client {}

final _video = VideoEvent(
  id: 'vid1',
  pubkey: 'pk1',
  createdAt: 1,
  content: '',
  timestamp: DateTime.fromMillisecondsSinceEpoch(0),
  vineId: 'my-vine-id',
);

final _cues = const [SubtitleCue(start: 0, end: 1000, text: 'hi')];

void main() {
  group(SubtitleRepository, () {
    late _MockBlossom blossom;
    late _MockPublisher publisher;
    late _MockAuth auth;
    late SubtitleRepository repo;

    setUp(() {
      blossom = _MockBlossom();
      publisher = _MockPublisher();
      auth = _MockAuth();
      repo = SubtitleRepository(
        blossomUploadService: blossom,
        videoEventPublisher: publisher,
        authService: auth,
        nostrClient: _MockNostr(),
        httpClient: _MockHttp(),
        pollDelay: (_) async {},
      );
      when(() => auth.currentPublicKeyHex).thenReturn('pk1');
    });

    test('uploads VTT, publishes 39307, republishes with both refs',
        () async {
      when(() => blossom.uploadSubtitleVtt(bytes: any(named: 'bytes')))
          .thenAnswer((_) async => const BlossomUploadResult(
                success: true,
                url: 'https://media.divine.video/hash',
                videoId: 'hash',
              ));
      when(() => publisher.publishSubtitleEvent(
            video: any(named: 'video'),
            vttContent: any(named: 'vttContent'),
            blossomUrl: any(named: 'blossomUrl'),
            lang: any(named: 'lang'),
          )).thenAnswer((_) async => '39307:pk1:subtitles:my-vine-id');
      when(() => publisher.republishWithSubtitles(
            existingEvent: any(named: 'existingEvent'),
            textTrackRef: any(named: 'textTrackRef'),
            extraTextTrackRefs: any(named: 'extraTextTrackRefs'),
            textTrackLang: any(named: 'textTrackLang'),
          )).thenAnswer((_) async => true);

      await repo.publishEditedSubtitles(video: _video, cues: _cues);

      verify(() => publisher.republishWithSubtitles(
            existingEvent: _video,
            textTrackRef: 'https://media.divine.video/hash',
            extraTextTrackRefs: const ['39307:pk1:subtitles:my-vine-id'],
            textTrackLang: 'en',
          )).called(1);
    });

    test('throws when vineId is null', () async {
      final noId = VideoEvent(
        id: 'v',
        pubkey: 'pk1',
        createdAt: 1,
        content: '',
        timestamp: DateTime.fromMillisecondsSinceEpoch(0),
      );
      expect(
        () => repo.publishEditedSubtitles(video: noId, cues: _cues),
        throwsA(isA<SubtitleEditException>()),
      );
    });
  });
}
```

Add `registerFallbackValue(_video);` in a `setUpAll` if mocktail requires
it for the `existingEvent`/`video` matchers.

- [ ] **Step 4: Create the provider**

`mobile/lib/providers/subtitle_repository_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/subtitle_providers.dart';
import 'package:openvine/providers/video_providers.dart';
import 'package:openvine/repositories/subtitle_repository.dart';

final subtitleRepositoryProvider = Provider<SubtitleRepository>((ref) {
  return SubtitleRepository(
    blossomUploadService: ref.watch(blossomUploadServiceProvider),
    videoEventPublisher: ref.watch(videoEventPublisherProvider),
    authService: ref.watch(authServiceProvider),
    nostrClient: ref.watch(nostrServiceProvider),
    httpClient: ref.watch(subtitleHttpClientProvider),
    pollDelay: ref.watch(subtitlePollDelayProvider),
  );
});
```

(Confirm import paths: `authServiceProvider`, `blossomUploadServiceProvider`,
`videoEventPublisherProvider`, `nostrServiceProvider` — grep for each to
confirm its defining file, e.g. `rg "blossomUploadServiceProvider ="
lib/providers`.)

- [ ] **Step 5: Run tests + analyze**

Run: `mise exec -- flutter test test/repositories/subtitle_repository_test.dart`
Expected: PASS.
Run: `mise exec -- flutter analyze lib test`
Expected: No issues.

- [ ] **Step 6: Commit**

```bash
git add lib/repositories/subtitle_repository.dart \
        lib/providers/subtitle_repository_provider.dart \
        test/repositories/subtitle_repository_test.dart
git commit -m "feat(subtitles): add SubtitleRepository orchestration"
```

---

## Task 7: `SubtitleEditorCubit` + state

**Files:**
- Create: `mobile/lib/blocs/subtitle_editor/subtitle_editor_state.dart`
- Create: `mobile/lib/blocs/subtitle_editor/subtitle_editor_cubit.dart`
- Test: `mobile/test/blocs/subtitle_editor/subtitle_editor_cubit_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/subtitle_editor/subtitle_editor_cubit.dart';
import 'package:openvine/repositories/subtitle_repository.dart';
import 'package:openvine/services/subtitle_service.dart';

class _MockRepo extends Mock implements SubtitleRepository {}

final _video = VideoEvent(
  id: 'v',
  pubkey: 'pk',
  createdAt: 1,
  content: '',
  timestamp: DateTime.fromMillisecondsSinceEpoch(0),
  vineId: 'd1',
);

void main() {
  setUpAll(() => registerFallbackValue(_video));

  group(SubtitleEditorCubit, () {
    late _MockRepo repo;
    setUp(() => repo = _MockRepo());

    blocTest<SubtitleEditorCubit, SubtitleEditorState>(
      'load → ready with cues',
      setUp: () => when(() => repo.loadCues(any())).thenAnswer(
        (_) async => const [SubtitleCue(start: 0, end: 1000, text: 'a')],
      ),
      build: () => SubtitleEditorCubit(repository: repo, video: _video),
      act: (c) => c.load(),
      expect: () => [
        isA<SubtitleEditorState>()
            .having((s) => s.status, 'status', SubtitleEditorStatus.loading),
        isA<SubtitleEditorState>()
            .having((s) => s.status, 'status', SubtitleEditorStatus.ready)
            .having((s) => s.cues.length, 'cues', 1),
      ],
    );

    blocTest<SubtitleEditorCubit, SubtitleEditorState>(
      'load with no cues → processing',
      setUp: () =>
          when(() => repo.loadCues(any())).thenAnswer((_) async => const []),
      build: () => SubtitleEditorCubit(repository: repo, video: _video),
      act: (c) => c.load(),
      expect: () => [
        isA<SubtitleEditorState>()
            .having((s) => s.status, 'status', SubtitleEditorStatus.loading),
        isA<SubtitleEditorState>().having(
            (s) => s.status, 'status', SubtitleEditorStatus.processing),
      ],
    );

    blocTest<SubtitleEditorCubit, SubtitleEditorState>(
      'updateCueText marks dirty',
      setUp: () => when(() => repo.loadCues(any())).thenAnswer(
        (_) async => const [SubtitleCue(start: 0, end: 1000, text: 'a')],
      ),
      build: () => SubtitleEditorCubit(repository: repo, video: _video),
      act: (c) async {
        await c.load();
        c.updateCueText(0, 'fixed');
      },
      verify: (c) {
        expect(c.state.isDirty, isTrue);
        expect(c.state.cues.first.text, 'fixed');
      },
    );

    blocTest<SubtitleEditorCubit, SubtitleEditorState>(
      'save success emits saving then success',
      setUp: () {
        when(() => repo.loadCues(any())).thenAnswer(
          (_) async => const [SubtitleCue(start: 0, end: 1000, text: 'a')],
        );
        when(() => repo.publishEditedSubtitles(
              video: any(named: 'video'),
              cues: any(named: 'cues'),
            )).thenAnswer((_) async {});
      },
      build: () => SubtitleEditorCubit(repository: repo, video: _video),
      act: (c) async {
        await c.load();
        await c.save();
      },
      skip: 2,
      expect: () => [
        isA<SubtitleEditorState>()
            .having((s) => s.status, 'status', SubtitleEditorStatus.saving),
        isA<SubtitleEditorState>()
            .having((s) => s.status, 'status', SubtitleEditorStatus.success),
      ],
    );

    blocTest<SubtitleEditorCubit, SubtitleEditorState>(
      'save failure emits failure and reports error',
      setUp: () {
        when(() => repo.loadCues(any())).thenAnswer(
          (_) async => const [SubtitleCue(start: 0, end: 1000, text: 'a')],
        );
        when(() => repo.publishEditedSubtitles(
              video: any(named: 'video'),
              cues: any(named: 'cues'),
            )).thenThrow(SubtitleEditException('boom'));
      },
      build: () => SubtitleEditorCubit(repository: repo, video: _video),
      act: (c) async {
        await c.load();
        await c.save();
      },
      skip: 2,
      expect: () => [
        isA<SubtitleEditorState>()
            .having((s) => s.status, 'status', SubtitleEditorStatus.saving),
        isA<SubtitleEditorState>()
            .having((s) => s.status, 'status', SubtitleEditorStatus.failure),
      ],
      errors: () => [isA<SubtitleEditException>()],
    );
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `mise exec -- flutter test test/blocs/subtitle_editor/subtitle_editor_cubit_test.dart`
Expected: FAIL — cubit/state not defined.

- [ ] **Step 3: Implement state**

`subtitle_editor_state.dart`:

```dart
part of 'subtitle_editor_cubit.dart';

enum SubtitleEditorStatus { loading, processing, ready, saving, success, failure }

/// One editable subtitle cue. Timing is fixed (text-only editing).
class EditableCue extends Equatable {
  const EditableCue({
    required this.start,
    required this.end,
    required this.text,
  });

  factory EditableCue.fromCue(SubtitleCue cue) =>
      EditableCue(start: cue.start, end: cue.end, text: cue.text);

  final int start;
  final int end;
  final String text;

  SubtitleCue toCue() => SubtitleCue(start: start, end: end, text: text);

  EditableCue copyWith({String? text}) =>
      EditableCue(start: start, end: end, text: text ?? this.text);

  /// `M:SS` label for display (timing is read-only).
  String get timestampLabel {
    final totalSeconds = start ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  List<Object?> get props => [start, end, text];
}

class SubtitleEditorState extends Equatable {
  const SubtitleEditorState({
    this.status = SubtitleEditorStatus.loading,
    this.cues = const [],
    this.isDirty = false,
  });

  final SubtitleEditorStatus status;
  final List<EditableCue> cues;
  final bool isDirty;

  SubtitleEditorState copyWith({
    SubtitleEditorStatus? status,
    List<EditableCue>? cues,
    bool? isDirty,
  }) {
    return SubtitleEditorState(
      status: status ?? this.status,
      cues: cues ?? this.cues,
      isDirty: isDirty ?? this.isDirty,
    );
  }

  @override
  List<Object?> get props => [status, cues, isDirty];
}
```

- [ ] **Step 4: Implement cubit**

`subtitle_editor_cubit.dart`:

```dart
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart';
import 'package:openvine/repositories/subtitle_repository.dart';
import 'package:openvine/services/subtitle_service.dart';

part 'subtitle_editor_state.dart';

class SubtitleEditorCubit extends Cubit<SubtitleEditorState> {
  SubtitleEditorCubit({
    required SubtitleRepository repository,
    required VideoEvent video,
  })  : _repository = repository,
        _video = video,
        super(const SubtitleEditorState());

  final SubtitleRepository _repository;
  final VideoEvent _video;

  Future<void> load() async {
    emit(state.copyWith(status: SubtitleEditorStatus.loading));
    try {
      final cues = await _repository.loadCues(_video);
      if (cues.isEmpty) {
        emit(state.copyWith(status: SubtitleEditorStatus.processing));
        return;
      }
      emit(state.copyWith(
        status: SubtitleEditorStatus.ready,
        cues: cues.map(EditableCue.fromCue).toList(),
        isDirty: false,
      ));
    } catch (e, st) {
      addError(e, st);
      emit(state.copyWith(status: SubtitleEditorStatus.failure));
    }
  }

  void updateCueText(int index, String text) {
    if (index < 0 || index >= state.cues.length) return;
    final updated = List<EditableCue>.from(state.cues);
    updated[index] = updated[index].copyWith(text: text);
    emit(state.copyWith(cues: updated, isDirty: true));
  }

  Future<void> save() async {
    emit(state.copyWith(status: SubtitleEditorStatus.saving));
    try {
      await _repository.publishEditedSubtitles(
        video: _video,
        cues: state.cues.map((c) => c.toCue()).toList(),
      );
      emit(state.copyWith(status: SubtitleEditorStatus.success, isDirty: false));
    } catch (e, st) {
      addError(e, st);
      emit(state.copyWith(status: SubtitleEditorStatus.failure));
    }
  }
}
```

- [ ] **Step 5: Run to verify pass + analyze**

Run: `mise exec -- flutter test test/blocs/subtitle_editor/subtitle_editor_cubit_test.dart`
Expected: PASS.
Run: `mise exec -- flutter analyze lib test`
Expected: No issues.

- [ ] **Step 6: Commit**

```bash
git add lib/blocs/subtitle_editor test/blocs/subtitle_editor
git commit -m "feat(subtitles): add SubtitleEditorCubit and state"
```

---

## Task 8: l10n keys

**Files:**
- Modify: `mobile/lib/l10n/app_en.arb`
- Modify: `mobile/test/l10n/arb_consistency_test.dart` (allowlist) — see memory note `project_arb_consistency_test`.

- [ ] **Step 1: Add keys to `app_en.arb`**

Insert these keys (alphabetical placement not required, but keep valid
JSON — comma discipline):

```json
  "subtitleEditorTitle": "Edit subtitles",
  "subtitleEditorSave": "Save",
  "subtitleEditorProcessing": "Subtitles are still being generated. Check back in a moment.",
  "subtitleEditorLoadError": "Couldn't load subtitles. Try again.",
  "subtitleEditorSaveSuccess": "Subtitles updated",
  "subtitleEditorSaveError": "Couldn't save subtitles. Try again.",
  "subtitleEditorRetry": "Retry",
  "subtitleEditorCueHint": "Caption text",
  "videoEditEditSubtitles": "Edit subtitles",
```

- [ ] **Step 2: Allowlist or translate (ARB consistency gate)**

Add the nine keys above to the allowlist set in
`mobile/test/l10n/arb_consistency_test.dart` (find the existing allowlist
collection and append the keys), per the repo's ARB-consistency gate.

- [ ] **Step 3: Regenerate l10n**

Run: `mise exec -- flutter gen-l10n`
Expected: regenerated files under `lib/l10n/generated/`.

- [ ] **Step 4: Verify the ARB consistency test passes**

Run: `mise exec -- flutter test test/l10n/arb_consistency_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/l10n/app_en.arb lib/l10n/generated test/l10n/arb_consistency_test.dart
git commit -m "feat(l10n): add subtitle editor strings"
```

---

## Task 9: `SubtitleEditorScreen` (Page/View)

**Files:**
- Create: `mobile/lib/screens/subtitle_editor/subtitle_editor_screen.dart`
- Test: `mobile/test/screens/subtitle_editor/subtitle_editor_screen_test.dart`

- [ ] **Step 1: Write the failing widget test**

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/subtitle_editor/subtitle_editor_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/subtitle_editor/subtitle_editor_screen.dart';

class _MockCubit extends MockCubit<SubtitleEditorState>
    implements SubtitleEditorCubit {}

void main() {
  late _MockCubit cubit;
  setUp(() => cubit = _MockCubit());

  Widget pump() => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<SubtitleEditorCubit>.value(
          value: cubit,
          child: const SubtitleEditorView(),
        ),
      );

  testWidgets('renders a text field per cue when ready', (tester) async {
    when(() => cubit.state).thenReturn(const SubtitleEditorState(
      status: SubtitleEditorStatus.ready,
      cues: [
        EditableCue(start: 0, end: 1000, text: 'one'),
        EditableCue(start: 1000, end: 2000, text: 'two'),
      ],
    ));
    await tester.pumpWidget(pump());
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('one'), findsOneWidget);
  });

  testWidgets('shows processing message when status is processing',
      (tester) async {
    when(() => cubit.state).thenReturn(
      const SubtitleEditorState(status: SubtitleEditorStatus.processing),
    );
    await tester.pumpWidget(pump());
    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(find.text(l10n.subtitleEditorProcessing), findsOneWidget);
  });

  testWidgets('editing a field dispatches updateCueText', (tester) async {
    when(() => cubit.state).thenReturn(const SubtitleEditorState(
      status: SubtitleEditorStatus.ready,
      cues: [EditableCue(start: 0, end: 1000, text: 'one')],
    ));
    await tester.pumpWidget(pump());
    await tester.enterText(find.byType(TextField).first, 'edited');
    verify(() => cubit.updateCueText(0, 'edited')).called(1);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `mise exec -- flutter test test/screens/subtitle_editor/subtitle_editor_screen_test.dart`
Expected: FAIL — screen not defined.

- [ ] **Step 3: Implement the screen**

```dart
// ABOUTME: Full-screen editor for correcting a video's subtitle text.
// ABOUTME: Page builds the cubit from Riverpod; View renders cue text fields.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/subtitle_editor/subtitle_editor_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/subtitle_repository_provider.dart';

class SubtitleEditorScreen extends ConsumerWidget {
  const SubtitleEditorScreen({required this.video, super.key});

  static const path = '/subtitle-edit';
  static const routeName = 'subtitle-edit';

  static String pathFor(String videoId) =>
      '$path/${Uri.encodeComponent(videoId)}';

  final VideoEvent video;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(subtitleRepositoryProvider);
    return BlocProvider<SubtitleEditorCubit>(
      key: ObjectKey(repository),
      create: (_) =>
          SubtitleEditorCubit(repository: repository, video: video)..load(),
      child: const SubtitleEditorView(),
    );
  }
}

@visibleForTesting
class SubtitleEditorView extends StatelessWidget {
  const SubtitleEditorView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: VineTheme.surfaceBackground,
      appBar: DiVineAppBar(
        title: l10n.subtitleEditorTitle,
        backgroundColor: VineTheme.surfaceBackground,
        showBackButton: true,
        onBackPressed: context.pop,
      ),
      body: BlocConsumer<SubtitleEditorCubit, SubtitleEditorState>(
        listenWhen: (p, c) => p.status != c.status,
        listener: (context, state) {
          if (state.status == SubtitleEditorStatus.success) {
            SemanticsService.sendAnnouncement(
              View.of(context),
              l10n.subtitleEditorSaveSuccess,
              Directionality.of(context),
            );
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.subtitleEditorSaveSuccess)),
            );
            context.pop();
          } else if (state.status == SubtitleEditorStatus.failure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.subtitleEditorSaveError)),
            );
          }
        },
        builder: (context, state) {
          return switch (state.status) {
            SubtitleEditorStatus.loading => const _Loading(),
            SubtitleEditorStatus.processing => const _Processing(),
            _ => _CueList(state: state),
          };
        },
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}

class _Processing extends StatelessWidget {
  const _Processing();
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 16,
        children: [
          Text(
            l10n.subtitleEditorProcessing,
            textAlign: TextAlign.center,
            style: VineTheme.bodyMediumFont(color: VineTheme.secondaryText),
          ),
          TextButton(
            onPressed: () => context.read<SubtitleEditorCubit>().load(),
            child: Text(l10n.subtitleEditorRetry),
          ),
        ],
      ),
    );
  }
}

class _CueList extends StatelessWidget {
  const _CueList({required this.state});
  final SubtitleEditorState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: state.cues.length,
            itemBuilder: (context, index) =>
                _CueRow(index: index, cue: state.cues[index]),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _SaveButton(
              enabled: state.isDirty &&
                  state.status != SubtitleEditorStatus.saving,
              busy: state.status == SubtitleEditorStatus.saving,
            ),
          ),
        ),
      ],
    );
  }
}

class _CueRow extends StatelessWidget {
  const _CueRow({required this.index, required this.cue});
  final int index;
  final EditableCue cue;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text(
              cue.timestampLabel,
              style: VineTheme.bodySmallFont(color: VineTheme.secondaryText),
            ),
          ),
          Expanded(
            child: TextFormField(
              initialValue: cue.text,
              minLines: 1,
              maxLines: null,
              style: VineTheme.bodyMediumFont(),
              decoration: InputDecoration(
                hintText: context.l10n.subtitleEditorCueHint,
              ),
              onChanged: (value) =>
                  context.read<SubtitleEditorCubit>().updateCueText(index, value),
            ),
          ),
        ],
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.enabled, required this.busy});
  final bool enabled;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: enabled
            ? () => context.read<SubtitleEditorCubit>().save()
            : null,
        child: busy
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(context.l10n.subtitleEditorSave),
      ),
    );
  }
}
```

> The widget test uses a `TextField` finder; `TextFormField` builds a
> `TextField` internally so `find.byType(TextField)` matches. If the test's
> `enterText` does not trigger `onChanged` for `TextFormField` in your
> Flutter version, switch `_CueRow` to a `TextField` with a controller —
> but prefer `TextFormField`'s `initialValue` to avoid controller lifecycle
> management. Re-run the test to confirm.

- [ ] **Step 4: Run to verify pass + analyze**

Run: `mise exec -- flutter test test/screens/subtitle_editor/subtitle_editor_screen_test.dart`
Expected: PASS.
Run: `mise exec -- flutter analyze lib test`
Expected: No issues.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/subtitle_editor test/screens/subtitle_editor
git commit -m "feat(subtitles): add SubtitleEditorScreen (Page/View)"
```

---

## Task 10: Route + entry-point wiring

**Files:**
- Modify: `mobile/lib/router/app_router.dart`
- Modify: `mobile/lib/widgets/video_metadata/modes/edit/video_metadata_edit_bottom_bar.dart`
- Test: `mobile/test/widgets/video_metadata/modes/edit/video_metadata_edit_bottom_bar_test.dart` (extend if present; else create a focused test)

- [ ] **Step 1: Add the route**

In `app_router.dart`, near the existing `VideoMetadataEditScreen` route,
add (mirror that route's structure):

```dart
GoRoute(
  path: '${SubtitleEditorScreen.path}/:videoId',
  name: SubtitleEditorScreen.routeName,
  builder: (ctx, st) {
    final videoId = st.pathParameters['videoId'];
    if (videoId == null || videoId.isEmpty) {
      return RouteErrorScreen(message: ctx.l10n.routeInvalidVideoId);
    }
    final prefetched = st.extra as VideoEvent?;
    if (prefetched == null) {
      return RouteErrorScreen(message: ctx.l10n.routeInvalidVideoId);
    }
    return SubtitleEditorScreen(video: prefetched);
  },
),
```

Add the import for `SubtitleEditorScreen` at the top of `app_router.dart`.

> The editor requires a `VideoEvent` (it edits an already-resolved own
> video). The entry point always passes `extra: video`, so a missing
> `extra` is a programming error → show the existing error screen. (A
> future deep-link entry could resolve by id; out of scope for v1.)

- [ ] **Step 2: Write the failing entry-point test**

Add a test asserting the bottom bar shows an "Edit subtitles" control and
navigates. Use the existing test's `MockGoRouter` pattern (see
`badges_screen_test.dart`'s `MockGoRouterProvider`). Assert that tapping
the control calls `push` with `SubtitleEditorScreen.pathFor(video.id)`.

```dart
testWidgets('tapping Edit subtitles pushes the subtitle editor route',
    (tester) async {
  final goRouter = MockGoRouter();
  // pump the bottom bar (or the edit stack) wrapped in
  // MockGoRouterProvider with localization delegates, with a test video.
  await tester.tap(find.text(
    lookupAppLocalizations(const Locale('en')).videoEditEditSubtitles,
  ));
  await tester.pump();
  verify(() => goRouter.push(
        SubtitleEditorScreen.pathFor(testVideo.id),
        extra: testVideo,
      )).called(1);
});
```

(Match the bottom bar's existing test harness for how the video is
injected. If the bottom bar doesn't currently receive the `VideoEvent`,
thread it through from its parent — the edit stack already has the
resolved video.)

- [ ] **Step 3: Run to verify it fails**

Run: `mise exec -- flutter test test/widgets/video_metadata/modes/edit/video_metadata_edit_bottom_bar_test.dart`
Expected: FAIL — no "Edit subtitles" control.

- [ ] **Step 4: Add the action to the bottom bar**

Restructure the bottom bar's `build` `Row` into a `Column` so the new
full-width action sits above the existing Delete/Update row. Replace the
`child: Row(...)` (the Delete/Update row) with:

```dart
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 10,
          children: [
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isBusy ? null : _editSubtitles,
                icon: const DivineIcon(icon: .closedCaption),
                label: Text(context.l10n.videoEditEditSubtitles),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              spacing: 10,
              children: [
                Expanded(
                  child: _DeleteButton(
                    onTap: _confirmDelete,
                    isBusy: _isBusy,
                    isDeleting: _isDeleting,
                  ),
                ),
                Expanded(
                  child: _UpdateButton(
                    onTap: _updateVideo,
                    isBusy: _isBusy,
                    isUpdating: _isUpdating,
                  ),
                ),
              ],
            ),
          ],
        ),
```

Add the handler method (the bottom bar already has access to the video it
edits — use that field; confirm its name, e.g. `widget.video`):

```dart
  void _editSubtitles() {
    context.push(
      SubtitleEditorScreen.pathFor(widget.video.id),
      extra: widget.video,
    );
  }
```

Add imports for `SubtitleEditorScreen`, `context.l10n`, and `DivineIcon`
if not present. Confirm the `closedCaption` icon exists in
`DivineIconName`; if not, use the closest existing caption/subtitle icon
or a generic edit icon — grep `rg "enum DivineIconName" -A60` in
`divine_ui`.

> Ownership: `VideoMetadataEditScreen` already resolves the video with
> `allowOwnContentBypass: true`, so the edit surface (and therefore this
> button) is only reachable for the creator's own video. No additional
> pubkey gate is needed here.

- [ ] **Step 5: Run to verify pass + analyze**

Run: `mise exec -- flutter test test/widgets/video_metadata/modes/edit/video_metadata_edit_bottom_bar_test.dart`
Expected: PASS.
Run: `mise exec -- flutter analyze lib test`
Expected: No issues.

- [ ] **Step 6: Commit**

```bash
git add lib/router/app_router.dart \
        lib/widgets/video_metadata/modes/edit/video_metadata_edit_bottom_bar.dart \
        test/widgets/video_metadata/modes/edit
git commit -m "feat(subtitles): wire Edit subtitles entry point and route"
```

---

## Task 11: Full verification

- [ ] **Step 1: Analyze the whole touched surface**

Run: `mise exec -- flutter analyze lib test integration_test`
Expected: No issues.

- [ ] **Step 2: Format**

Run: `mise exec -- dart format lib test`
Expected: formats only changed files; commit if anything changed.

- [ ] **Step 3: Run all affected suites**

Run (from `mobile/`):
```bash
mise exec -- flutter test \
  test/services/subtitle_fetcher_test.dart \
  test/providers/subtitle_providers_test.dart \
  test/repositories/subtitle_repository_test.dart \
  test/blocs/subtitle_editor/subtitle_editor_cubit_test.dart \
  test/screens/subtitle_editor/subtitle_editor_screen_test.dart \
  test/services/video_event_publisher_subtitle_test.dart \
  test/l10n/arb_consistency_test.dart \
  test/widgets/video_metadata/modes/edit
```
Run (from `mobile/packages/models`): `mise exec -- flutter test`
Run (from `mobile/packages/blossom_upload_service`): `mise exec -- flutter test`
Expected: all PASS.

- [ ] **Step 4: Rebase + push**

```bash
git fetch origin
git rebase origin/main
# re-run analyze + affected tests if the rebase pulled changes
git push --force-with-lease -u origin feat/subtitle-editing
```

- [ ] **Step 5: Open the PR** (targets `main`)

Use `/pr-summary` to generate the body. Attach a screen recording of the
edit→save→updated-captions flow. Manual test plan: own freshly-uploaded
video (processing state), own video with ready auto-subs (edit a wrong
word → save → confirm corrected caption appears), and a non-owner cannot
reach the editor.

---

## Self-Review (completed during authoring)

- **Spec coverage:** Blossom upload (T1), 39307 publish (T5), dual-ref
  redundancy + reader fallback (T3/T4/T5), repository orchestration (T6),
  Cubit with status enum + addError (T7), full-screen Page/View editor +
  l10n + a11y announcement (T8/T9), both entry points via one screen — the
  post-publish "Edit subtitles" action (T10), and the "publish now, edit
  when ready" processing state (T7/T9). Author-only via existing
  `allowOwnContentBypass` resolver (T10). Single language `en` throughout.
- **Risk #1 resolved:** the HTTP text-track branch already exists; T3+T4
  make the reader actually iterate refs so the Blossom fallback is real.
- **Type consistency:** `textTrackRefs` (List<String>), `EditableCue`
  (start/end/text + `toCue`/`fromCue`), `SubtitleEditorStatus` enum,
  `publishSubtitleEvent` returns `String?`, `republishWithSubtitles` gains
  `extraTextTrackRefs` — names match across tasks.
- **At-publish entry:** v1 ships the activatable own-video affordance; the
  "subtitles ready" badge is the same action becoming usable once
  `loadCues` returns non-empty. No separate editor — matches the spec.
