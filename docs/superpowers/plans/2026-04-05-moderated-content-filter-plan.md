# Moderated Content Filter Fix — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix moderated content leaking into the feed by filtering cached videos, handling unknown server labels conservatively, and presenting 401/403 playback failures coherently.

**Architecture:** Three isolated changes following the existing BLoC/repository layering. Part A reuses the repository's existing `_applyContentPreferences` pipeline for cached videos. Part B makes label parsing and the NSFW filter conservative by default. Part C adds a per-video playback-status cubit so the feed UI can replace the half-broken player card with a full-screen moderated-content overlay.

**Tech Stack:** Dart 3.11, flutter_bloc, flutter_test, mocktail, bloc_test, very_good_analysis. Package-level code lives under `packages/videos_repository/`, `packages/models/`. App code lives under `mobile/lib/`.

**Spec:** `docs/superpowers/specs/2026-04-05-moderated-content-filter-design.md`

**Working directory:** All `flutter`/`dart` commands run from `mobile/` unless otherwise stated.

**Branch:** `fix/moderated-content-filter` (already created in worktree `.worktrees/fix-moderation-filter`)

**Process rules:**
- TDD throughout. For every change: write a failing test, run it to confirm it fails for the right reason, implement the minimum, confirm it passes, commit.
- After every code change that touches a Dart file, run `dart format` and `flutter analyze` on the touched files. Do not commit if analyzer reports warnings or errors.
- 100% test coverage on new/modified lines (project rule).
- Never truncate Nostr IDs in tests, logs, or debug output (project rule).
- No emojis in code or commit messages unless explicitly requested.

---

## File Structure

### New files

| File | Responsibility |
|------|----------------|
| `mobile/lib/blocs/video_playback_status/video_playback_status_cubit.dart` | Per-video playback status tracking (ready / ageRestricted / forbidden / notFound / generic) |
| `mobile/lib/blocs/video_playback_status/video_playback_status_state.dart` | State with LRU-bounded map of event ID → status |
| `mobile/test/blocs/video_playback_status/video_playback_status_cubit_test.dart` | Cubit tests |
| `mobile/lib/widgets/video_feed_item/moderated_content_overlay.dart` | Full-screen overlay shown when the active video is forbidden/age-restricted |
| `mobile/test/widgets/video_feed_item/moderated_content_overlay_test.dart` | Widget tests for the overlay |

### Modified files

| File | Change |
|------|--------|
| `mobile/packages/videos_repository/lib/src/videos_repository.dart` | Add public `applyContentPreferences(List<VideoEvent>)` method |
| `mobile/packages/videos_repository/test/src/videos_repository_test.dart` | Tests for new method |
| `mobile/packages/models/lib/src/video_stats.dart` | Normalize whitespace to hyphens; stop dropping unknown labels in `_normalizeModerationLabel` |
| `mobile/packages/models/test/src/video_stats_test.dart` | Tests for whitespace normalization and unknown-label pass-through |
| `mobile/lib/services/nsfw_content_filter.dart` | Treat unknown moderation labels as conservative hide signal |
| `mobile/test/services/nsfw_content_filter_test.dart` | Tests for unknown-label hide behavior |
| `mobile/lib/blocs/video_feed/video_feed_bloc.dart` | Filter cached videos via new repository method before emitting |
| `mobile/test/blocs/video_feed/video_feed_bloc_test.dart` | Test that cached videos go through the filter |
| `mobile/lib/screens/feed/feed_video_overlay.dart` | Render `ModeratedContentOverlay` when playback status is restricted |
| `mobile/lib/screens/feed/pooled_fullscreen_video_feed_screen.dart` | Same, for fullscreen feed path |
| `mobile/lib/screens/feed/video_feed_page.dart` | Provide `VideoPlaybackStatusCubit` to the feed subtree and wire error callback |

---

## Chunk 1: Part A — Filter cached videos through the repository

### Task A1: Add `applyContentPreferences` to `VideosRepository`

**Files:**
- Modify: `mobile/packages/videos_repository/lib/src/videos_repository.dart`
- Test: `mobile/packages/videos_repository/test/src/videos_repository_test.dart`

**Context for the engineer:**
`VideosRepository` already has a private `_applyContentPreferences(VideoEvent)` method around line 873 that runs the injected `VideoContentFilter` (hide check) and `VideoWarningLabelsResolver` (warn labels). It is used inside `_transformVideoStats` and `_tryParseAndFilter`. We want to expose a list-level version so callers who already have `List<VideoEvent>` (e.g. `HomeFeedCache`) can run the same filter without re-parsing.

The method must also honor the `_blockFilter` (pubkey blocklist) to match the behavior of the parsing paths. Expired videos and URL-less videos are already filtered when the list is built, so we don't re-check those here.

- [ ] **Step 1: Write the failing test**

Append to `mobile/packages/videos_repository/test/src/videos_repository_test.dart`. If the file uses a top-level `main()` with a single `group`, add a new nested `group('applyContentPreferences', () { ... })`. First inspect the existing file to see the mock setup (`_MockNostrClient`, etc.) and the existing test pattern — reuse it exactly.

```dart
group('applyContentPreferences', () {
  test('returns videos unchanged when no filters are injected', () {
    final repo = VideosRepository(nostrClient: _MockNostrClient());
    final a = _videoEvent(id: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa');
    final b = _videoEvent(id: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb');

    final result = repo.applyContentPreferences([a, b]);

    expect(result, equals([a, b]));
  });

  test('removes videos whose pubkey is blocked', () {
    final blocked = 'blockedpubkey000000000000000000000000000000000000000000000000000';
    final repo = VideosRepository(
      nostrClient: _MockNostrClient(),
      blockFilter: (pubkey) => pubkey == blocked,
    );
    final good = _videoEvent(
      id: 'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
      pubkey: 'goodpubkey0000000000000000000000000000000000000000000000000000000',
    );
    final bad = _videoEvent(
      id: 'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
      pubkey: blocked,
    );

    final result = repo.applyContentPreferences([good, bad]);

    expect(result.map((v) => v.id), equals([good.id]));
  });

  test('removes videos whose content filter returns true', () {
    final repo = VideosRepository(
      nostrClient: _MockNostrClient(),
      contentFilter: (video) => video.moderationLabels.contains('nudity'),
    );
    final clean = _videoEvent(
      id: 'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
    );
    final nsfw = _videoEvent(
      id: 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
      moderationLabels: const ['nudity'],
    );

    final result = repo.applyContentPreferences([clean, nsfw]);

    expect(result.map((v) => v.id), equals([clean.id]));
  });

  test('applies warn labels from the resolver', () {
    final repo = VideosRepository(
      nostrClient: _MockNostrClient(),
      warningLabelsResolver: (video) =>
          video.contentWarningLabels.contains('violence')
              ? const ['violence']
              : const [],
    );
    final violent = _videoEvent(
      id: '1111111111111111111111111111111111111111111111111111111111111111',
      contentWarningLabels: const ['violence'],
    );

    final result = repo.applyContentPreferences([violent]);

    expect(result, hasLength(1));
    expect(result.single.warnLabels, equals(const ['violence']));
  });

  test('clears stale warnLabels when resolver returns empty', () {
    final repo = VideosRepository(
      nostrClient: _MockNostrClient(),
      warningLabelsResolver: (_) => const <String>[],
    );
    final stale = _videoEvent(
      id: '2222222222222222222222222222222222222222222222222222222222222222',
      warnLabels: const ['violence'],
    );

    final result = repo.applyContentPreferences([stale]);

    expect(result.single.warnLabels, isEmpty);
  });
});
```

Add a `_videoEvent(...)` test helper at the bottom of the file if one does not already exist. It should construct a minimal valid `VideoEvent` — mirror whatever pattern the existing tests in the file use. Do not invent new fields.

- [ ] **Step 2: Run test, expect failure**

```
cd mobile/packages/videos_repository && flutter test test/src/videos_repository_test.dart --name="applyContentPreferences"
```

Expected: compile error "The method 'applyContentPreferences' isn't defined for the type 'VideosRepository'".

- [ ] **Step 3: Implement**

In `mobile/packages/videos_repository/lib/src/videos_repository.dart`, immediately after the private `_applyContentPreferences(VideoEvent video)` method (around line 884), add:

```dart
/// Applies the injected block filter, content filter, and warning-labels
/// resolver to an already-parsed list of [VideoEvent]s.
///
/// Use this when you have videos that were not produced by this
/// repository's own parsing paths (e.g. entries restored from a local
/// cache). Videos that fail the block filter or content filter are
/// removed; surviving videos have their `warnLabels` rewritten to
/// reflect the current resolver output.
///
/// This is a pure, synchronous operation. It does not touch the network
/// or local storage.
List<VideoEvent> applyContentPreferences(List<VideoEvent> videos) {
  final out = <VideoEvent>[];
  for (final video in videos) {
    if (_blockFilter?.call(video.pubkey) ?? false) continue;
    final processed = _applyContentPreferences(video);
    if (processed != null) out.add(processed);
  }
  return out;
}
```

- [ ] **Step 4: Run test, expect pass**

```
cd mobile/packages/videos_repository && flutter test test/src/videos_repository_test.dart --name="applyContentPreferences"
```

Expected: all 5 tests pass.

- [ ] **Step 5: Format and analyze**

```
cd mobile/packages/videos_repository && dart format lib/src/videos_repository.dart test/src/videos_repository_test.dart && flutter analyze lib test
```

Expected: no issues.

- [ ] **Step 6: Commit**

```
cd mobile && git add packages/videos_repository/lib/src/videos_repository.dart packages/videos_repository/test/src/videos_repository_test.dart && git commit -m "feat(videos_repository): add applyContentPreferences for list-level filtering"
```

---

### Task A2: Filter cached home feed entries in `VideoFeedBloc`

**Files:**
- Modify: `mobile/lib/blocs/video_feed/video_feed_bloc.dart` (around line 436)
- Test: `mobile/test/blocs/video_feed/video_feed_bloc_test.dart`

**Context:** `VideoFeedBloc._loadVideos()` reads `HomeFeedCache` and emits cached videos with only a `videoUrl != null` filter. We want to route those videos through `VideosRepository.applyContentPreferences` first so cached NSFW content is hidden/warned the same way fresh videos are.

- [ ] **Step 1: Read the existing cache path**

Open `mobile/lib/blocs/video_feed/video_feed_bloc.dart` and read lines 425–470. Note the exact structure of the cache read block. You will modify only the block starting with `final cached = _homeFeedCache.read(...)`.

- [ ] **Step 2: Write the failing test**

In `mobile/test/blocs/video_feed/video_feed_bloc_test.dart`, find the existing group that tests cache loading (search for `_homeFeedCache` or `HomeFeedCache` in the file). Add a new test inside that group. If no such group exists yet, add one named `'cache filtering'`.

```dart
blocTest<VideoFeedBloc, VideoFeedState>(
  'filters cached videos through VideosRepository.applyContentPreferences '
  'before emitting them',
  setUp: () {
    // A cached video that should be hidden by the content filter.
    final hidden = _buildVideoEvent(
      id: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      moderationLabels: const ['nudity'],
    );
    final visible = _buildVideoEvent(
      id: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
    );
    when(() => homeFeedCache.read(any())).thenReturn(
      HomeFeedResult(videos: [hidden, visible]),
    );
    when(() => videosRepository.applyContentPreferences([hidden, visible]))
        .thenReturn([visible]);
    when(
      () => videosRepository.getHomeFeedVideos(
        authors: any(named: 'authors'),
        videoRefs: any(named: 'videoRefs'),
        userPubkey: any(named: 'userPubkey'),
        until: any(named: 'until'),
        skipCache: any(named: 'skipCache'),
      ),
    ).thenAnswer(
      (_) async => HomeFeedResult(videos: [visible]),
    );
  },
  build: () => _buildBloc(),
  act: (bloc) => bloc.add(const VideoFeedStarted(mode: FeedMode.forYou)),
  verify: (_) {
    verify(
      () => videosRepository.applyContentPreferences([hidden, visible]),
    ).called(1);
  },
);
```

Look at the top of the test file for existing mock names and helpers. Reuse `_buildBloc`, `_buildVideoEvent`, and `videosRepository` / `homeFeedCache` mocks exactly as they already exist — do not redefine them. If `_buildVideoEvent` doesn't accept `moderationLabels`, add the parameter to the helper rather than constructing `VideoEvent` inline.

- [ ] **Step 3: Run test, expect failure**

```
cd mobile && flutter test test/blocs/video_feed/video_feed_bloc_test.dart --name="applyContentPreferences"
```

Expected: the `verify` call fails because `applyContentPreferences` was never invoked. Or mocktail throws "No stub was found" if the production code calls a different signature. Confirm the failure reason before moving on.

- [ ] **Step 4: Implement**

In `mobile/lib/blocs/video_feed/video_feed_bloc.dart`, locate the cache read block inside `_loadVideos` (around line 436). Replace:

```dart
if (cached != null) {
  final cachedValid = cached.videos
      .where((v) => v.videoUrl != null)
      .toList();
```

with:

```dart
if (cached != null) {
  final filtered = _videosRepository.applyContentPreferences(cached.videos);
  final cachedValid = filtered
      .where((v) => v.videoUrl != null)
      .toList();
```

The rest of the block (`if (cachedValid.isNotEmpty)` and everything after) stays unchanged.

- [ ] **Step 5: Run test, expect pass**

```
cd mobile && flutter test test/blocs/video_feed/video_feed_bloc_test.dart --name="applyContentPreferences"
```

Expected: pass.

- [ ] **Step 6: Run the full bloc test file to make sure nothing regressed**

```
cd mobile && flutter test test/blocs/video_feed/video_feed_bloc_test.dart
```

Expected: all tests pass. If a previously-passing test now fails because its mock `videosRepository` does not stub `applyContentPreferences`, add the stub `when(() => videosRepository.applyContentPreferences(any())).thenAnswer((invocation) => invocation.positionalArguments.first as List<VideoEvent>);` inside the shared `setUp` for the test group.

- [ ] **Step 7: Format and analyze**

```
cd mobile && dart format lib/blocs/video_feed/video_feed_bloc.dart test/blocs/video_feed/video_feed_bloc_test.dart && flutter analyze lib/blocs/video_feed test/blocs/video_feed
```

Expected: no issues.

- [ ] **Step 8: Commit**

```
cd mobile && git add lib/blocs/video_feed/video_feed_bloc.dart test/blocs/video_feed/video_feed_bloc_test.dart && git commit -m "fix(video_feed): filter cached home feed videos through content preferences"
```

---

## Chunk 2: Part B — Conservative handling of unknown moderation labels

### Task B1: Pass through unknown labels in `VideoStats._normalizeModerationLabel`

**Files:**
- Modify: `mobile/packages/models/lib/src/video_stats.dart` (around line 511)
- Test: `mobile/packages/models/test/src/video_stats_test.dart`

**Context:** Today `_normalizeModerationLabel` returns `null` for any value not in `_recognizedModerationLabels` (line 534). We want to keep the alias mapping but pass through everything else, and also normalize spaces to hyphens so labels like `"sexual content"` become `"sexual-content"` instead of being silently dropped.

- [ ] **Step 1: Read the existing function**

Open `mobile/packages/models/lib/src/video_stats.dart` and read lines 498–558. Confirm the exact structure of `_parseModerationLabels`, `_normalizeModerationLabel`, and `_recognizedModerationLabels`.

- [ ] **Step 2: Write the failing tests**

In `mobile/packages/models/test/src/video_stats_test.dart`, find the group (if any) that tests moderation-label parsing. If none, add a new `group('moderation labels', () { ... })` at the end of `main()`. Inside, add:

```dart
test('normalizes whitespace in labels to hyphens', () {
  final stats = VideoStats.fromJson(<String, dynamic>{
    'id': '3333333333333333333333333333333333333333333333333333333333333333',
    'pubkey': '4444444444444444444444444444444444444444444444444444444444444444',
    'video_url': 'https://example.com/v.mp4',
    'moderation_labels': ['sexual content', 'graphic media'],
  });

  expect(
    stats.moderationLabels,
    containsAll(<String>['sexual-content', 'graphic-media']),
  );
});

test('preserves unknown moderation labels instead of dropping them', () {
  final stats = VideoStats.fromJson(<String, dynamic>{
    'id': '5555555555555555555555555555555555555555555555555555555555555555',
    'pubkey': '6666666666666666666666666666666666666666666666666666666666666666',
    'video_url': 'https://example.com/v.mp4',
    'moderation_labels': ['some-new-server-label'],
  });

  expect(stats.moderationLabels, equals(const ['some-new-server-label']));
});

test('still applies known aliases', () {
  final stats = VideoStats.fromJson(<String, dynamic>{
    'id': '7777777777777777777777777777777777777777777777777777777777777777',
    'pubkey': '8888888888888888888888888888888888888888888888888888888888888888',
    'video_url': 'https://example.com/v.mp4',
    'moderation_labels': ['pornography', 'nsfw', 'gore'],
  });

  expect(
    stats.moderationLabels,
    containsAll(const <String>['porn', 'nudity', 'graphic-media']),
  );
});

test('drops empty strings', () {
  final stats = VideoStats.fromJson(<String, dynamic>{
    'id': '9999999999999999999999999999999999999999999999999999999999999999',
    'pubkey': 'aaaabbbbccccddddeeeeffff0000111122223333444455556666777788889999',
    'video_url': 'https://example.com/v.mp4',
    'moderation_labels': ['', '   ', 'nudity'],
  });

  expect(stats.moderationLabels, equals(const ['nudity']));
});
```

If the existing test file uses a different construction helper (e.g. `_buildJson`), use that helper instead of raw maps — copy the pattern from adjacent tests.

- [ ] **Step 3: Run tests, expect failure**

```
cd mobile/packages/models && flutter test test/src/video_stats_test.dart --name="moderation labels"
```

Expected: `preserves unknown moderation labels instead of dropping them` fails (returns empty list) and `normalizes whitespace in labels to hyphens` fails (dropped entirely). The alias test may pass already. Confirm the specific failure reasons before moving on.

- [ ] **Step 4: Implement**

In `mobile/packages/models/lib/src/video_stats.dart`, replace the `_normalizeModerationLabel` function (around line 511) with:

```dart
String? _normalizeModerationLabel(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;

  final normalized = trimmed
      .toLowerCase()
      .replaceAll('_', '-')
      .replaceAll(RegExp(r'\s+'), '-');

  switch (normalized) {
    case 'pornography':
    case 'explicit':
      return 'porn';
    case 'graphic-violence':
    case 'gore':
      return 'graphic-media';
    case 'nsfw':
      return 'nudity';
    case 'offensive':
    case 'hate-speech':
      return 'hate';
    case 'recreational-drug':
      return 'drugs';
    case 'weapon':
      return 'violence';
  }

  return normalized;
}
```

Then delete the `_recognizedModerationLabels` constant (lines 537–557) — it is no longer referenced.

- [ ] **Step 5: Run tests, expect pass**

```
cd mobile/packages/models && flutter test test/src/video_stats_test.dart --name="moderation labels"
```

Expected: all 4 tests pass.

- [ ] **Step 6: Run the full `video_stats_test.dart` file**

```
cd mobile/packages/models && flutter test test/src/video_stats_test.dart
```

Expected: all tests pass. If an old test asserted that unknown labels were dropped, update it to match the new behavior — include a short comment explaining why.

- [ ] **Step 7: Format and analyze**

```
cd mobile/packages/models && dart format lib/src/video_stats.dart test/src/video_stats_test.dart && flutter analyze lib test
```

Expected: no issues. The `_recognizedModerationLabels` removal may leave an unused import — clean it up if the analyzer flags one.

- [ ] **Step 8: Commit**

```
cd mobile && git add packages/models/lib/src/video_stats.dart packages/models/test/src/video_stats_test.dart && git commit -m "fix(models): preserve unknown moderation labels and normalize whitespace"
```

---

### Task B2: Treat unknown labels as conservative hide in `createNsfwFilter`

**Files:**
- Modify: `mobile/lib/services/nsfw_content_filter.dart`
- Test: `mobile/test/services/nsfw_content_filter_test.dart`

**Context:** After Task B1, unknown labels now reach `createNsfwFilter`. `ContentFilterService.getPreferenceForLabels` only understands known `ContentLabel` values — it returns `show` for anything it doesn't recognize. We need the filter itself to treat "the server flagged this with a label we don't understand" as a hide signal.

Only `video.moderationLabels` (ML-generated, already normalized to string identifiers) gets this treatment. `contentWarningLabels` (creator self-labels) are noisier and stay on current behavior.

- [ ] **Step 1: Read the existing filter**

Open `mobile/lib/services/nsfw_content_filter.dart` and re-read `createNsfwFilter` (lines 22–48). Note the two branches: self-labels and `video.moderationLabels`.

- [ ] **Step 2: Write the failing tests**

In `mobile/test/services/nsfw_content_filter_test.dart`, find the group that tests `createNsfwFilter`. Add:

```dart
test('hides videos with unknown ML moderation labels', () {
  final contentFilterService = _StubContentFilterService();
  final filter = createNsfwFilter(contentFilterService);

  final video = _buildVideo(
    id: 'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
    moderationLabels: const ['some-new-server-label'],
  );

  expect(filter(video), isTrue);
});

test('still hides videos with known hide labels', () {
  final contentFilterService = _StubContentFilterService();
  final filter = createNsfwFilter(contentFilterService);

  final video = _buildVideo(
    id: 'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
    moderationLabels: const ['nudity'],
  );

  expect(filter(video), isTrue);
});

test('does not hide videos with no moderation labels', () {
  final contentFilterService = _StubContentFilterService();
  final filter = createNsfwFilter(contentFilterService);

  final video = _buildVideo(
    id: 'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
  );

  expect(filter(video), isFalse);
});

test('does not hide on self-labels the user chose to see', () {
  // Self-labels go through contentFilterService.getPreferenceForLabels,
  // not the unknown-label bypass. Unrecognized self-labels should still
  // use the existing behavior (show).
  final contentFilterService = _StubContentFilterService();
  final filter = createNsfwFilter(contentFilterService);

  final video = _buildVideo(
    id: 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
    contentWarningLabels: const ['some-unknown-self-label'],
  );

  // createNsfwFilter adds 'nudity' as a fallback when self-labels exist
  // but none are recognized (see _getContentLabels). So the existing
  // behavior is hide. This test locks that in.
  expect(filter(video), isTrue);
});
```

Check the existing file for the `_StubContentFilterService` and `_buildVideo` helpers — reuse them. If `_buildVideo` doesn't accept `moderationLabels` or `contentWarningLabels`, add those named parameters.

- [ ] **Step 3: Run tests, expect failure**

```
cd mobile && flutter test test/services/nsfw_content_filter_test.dart --name="unknown ML moderation labels"
```

Expected: `hides videos with unknown ML moderation labels` fails because `ContentFilterService.getPreferenceForLabels(['some-new-server-label'])` returns `show`.

- [ ] **Step 4: Implement**

In `mobile/lib/services/nsfw_content_filter.dart`, update the `video.moderationLabels` branch of `createNsfwFilter` (lines ~40–44) to:

```dart
// Also check ML-generated moderation labels from Funnelcake.
// These only trigger "hide" (never "warn") because ML classifiers
// are noisy and would otherwise block autoplay on ordinary videos.
final modLabels = video.moderationLabels;
if (modLabels.isNotEmpty) {
  // Conservative default: if the server tagged a video with a label
  // we don't recognize, treat it as a hide signal. The alternative —
  // silently showing the video — defeats the safety system whenever
  // the relay introduces a new label the client hasn't been updated
  // to understand.
  final hasUnknown =
      modLabels.any((l) => ContentLabel.fromValue(l) == null);
  if (hasUnknown) return true;

  final pref = contentFilterService.getPreferenceForLabels(modLabels);
  if (pref == ContentFilterPreference.hide) return true;
}
```

Add `import 'package:openvine/models/content_label.dart';` if it's not already imported.

- [ ] **Step 5: Run tests, expect pass**

```
cd mobile && flutter test test/services/nsfw_content_filter_test.dart
```

Expected: all tests pass, including the new ones.

- [ ] **Step 6: Format and analyze**

```
cd mobile && dart format lib/services/nsfw_content_filter.dart test/services/nsfw_content_filter_test.dart && flutter analyze lib/services test/services
```

Expected: no issues.

- [ ] **Step 7: Commit**

```
cd mobile && git add lib/services/nsfw_content_filter.dart test/services/nsfw_content_filter_test.dart && git commit -m "fix(nsfw_filter): treat unknown ML moderation labels as conservative hide"
```

---

## Chunk 3: Part C — Playback-status cubit and moderated-content overlay

### Task C1: Create `VideoPlaybackStatusState`

**Files:**
- Create: `mobile/lib/blocs/video_playback_status/video_playback_status_state.dart`

**Context:** The state tracks a bounded LRU map of event ID → status. New insertions bump the key to most-recent; when the map exceeds `maxEntries`, the oldest entry is evicted. This keeps memory bounded on long sessions.

- [ ] **Step 1: Write the state file**

```dart
// ABOUTME: State for VideoPlaybackStatusCubit — LRU-bounded map of event
// ABOUTME: IDs to per-video playback status (ready/forbidden/age-restricted).

import 'dart:collection';

import 'package:equatable/equatable.dart';

/// Per-video playback status reported by the pooled video player.
enum PlaybackStatus {
  /// Loading or ready for playback. The default.
  ready,

  /// Age-restricted — the media server returned 401 Unauthorized.
  ageRestricted,

  /// Moderation-restricted — the media server returned 403 Forbidden.
  forbidden,

  /// Content not found — 404 or unresolved blob hash.
  notFound,

  /// Any other playback failure.
  generic,
}

/// State for [VideoPlaybackStatusCubit].
///
/// Stores the playback status of recent videos keyed by event ID. The
/// internal map is LRU-bounded to [maxEntries] to keep memory use stable
/// during long feed sessions.
class VideoPlaybackStatusState extends Equatable {
  /// Creates an empty state. Use [withStatus] or [copyWith] to produce
  /// updated states.
  VideoPlaybackStatusState({
    this.maxEntries = _defaultMaxEntries,
    LinkedHashMap<String, PlaybackStatus>? statuses,
  }) : _statuses =
            statuses ?? LinkedHashMap<String, PlaybackStatus>();

  static const int _defaultMaxEntries = 100;

  /// Maximum number of per-video entries to retain.
  final int maxEntries;

  final LinkedHashMap<String, PlaybackStatus> _statuses;

  /// Returns the status for [eventId], or [PlaybackStatus.ready] when no
  /// status has been recorded.
  PlaybackStatus statusFor(String eventId) =>
      _statuses[eventId] ?? PlaybackStatus.ready;

  /// Returns a new state with [status] recorded for [eventId].
  ///
  /// If [eventId] already has an entry it is moved to most-recent. If the
  /// map exceeds [maxEntries] after insertion, the oldest entry is
  /// evicted.
  VideoPlaybackStatusState withStatus(String eventId, PlaybackStatus status) {
    final next = LinkedHashMap<String, PlaybackStatus>.from(_statuses)
      ..remove(eventId)
      ..[eventId] = status;
    while (next.length > maxEntries) {
      next.remove(next.keys.first);
    }
    return VideoPlaybackStatusState(
      maxEntries: maxEntries,
      statuses: next,
    );
  }

  /// Returns a cleared state (used when switching feed modes).
  VideoPlaybackStatusState cleared() =>
      VideoPlaybackStatusState(maxEntries: maxEntries);

  @override
  List<Object?> get props => [_statuses, maxEntries];
}
```

- [ ] **Step 2: Format and analyze**

```
cd mobile && dart format lib/blocs/video_playback_status/video_playback_status_state.dart && flutter analyze lib/blocs/video_playback_status
```

Expected: no issues.

- [ ] **Step 3: Commit**

```
cd mobile && git add lib/blocs/video_playback_status/video_playback_status_state.dart && git commit -m "feat(video_playback_status): add LRU-bounded playback status state"
```

---

### Task C2: Create `VideoPlaybackStatusCubit` with TDD

**Files:**
- Create: `mobile/lib/blocs/video_playback_status/video_playback_status_cubit.dart`
- Test: `mobile/test/blocs/video_playback_status/video_playback_status_cubit_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `mobile/test/blocs/video_playback_status/video_playback_status_cubit_test.dart`:

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/video_playback_status/video_playback_status_cubit.dart';
import 'package:openvine/blocs/video_playback_status/video_playback_status_state.dart';

void main() {
  group(VideoPlaybackStatusCubit, () {
    const id1 =
        '1111111111111111111111111111111111111111111111111111111111111111';
    const id2 =
        '2222222222222222222222222222222222222222222222222222222222222222';

    blocTest<VideoPlaybackStatusCubit, VideoPlaybackStatusState>(
      'records status for an event ID',
      build: VideoPlaybackStatusCubit.new,
      act: (cubit) => cubit.report(id1, PlaybackStatus.forbidden),
      verify: (cubit) {
        expect(cubit.state.statusFor(id1), PlaybackStatus.forbidden);
        expect(cubit.state.statusFor(id2), PlaybackStatus.ready);
      },
    );

    blocTest<VideoPlaybackStatusCubit, VideoPlaybackStatusState>(
      'emits a new state on each status change',
      build: VideoPlaybackStatusCubit.new,
      act: (cubit) {
        cubit.report(id1, PlaybackStatus.ageRestricted);
        cubit.report(id2, PlaybackStatus.forbidden);
      },
      expect: () => hasLength(2),
    );

    blocTest<VideoPlaybackStatusCubit, VideoPlaybackStatusState>(
      'clear() resets all statuses',
      build: VideoPlaybackStatusCubit.new,
      act: (cubit) {
        cubit.report(id1, PlaybackStatus.forbidden);
        cubit.clear();
      },
      verify: (cubit) {
        expect(cubit.state.statusFor(id1), PlaybackStatus.ready);
      },
    );

    test('evicts oldest entry when maxEntries is exceeded', () {
      final cubit = VideoPlaybackStatusCubit(maxEntries: 2);
      cubit.report(id1, PlaybackStatus.forbidden);
      cubit.report(id2, PlaybackStatus.ageRestricted);
      cubit.report(
        '3333333333333333333333333333333333333333333333333333333333333333',
        PlaybackStatus.notFound,
      );

      expect(cubit.state.statusFor(id1), PlaybackStatus.ready); // evicted
      expect(cubit.state.statusFor(id2), PlaybackStatus.ageRestricted);
    });

    test('reporting same id twice moves it to most-recent', () {
      final cubit = VideoPlaybackStatusCubit(maxEntries: 2);
      cubit.report(id1, PlaybackStatus.forbidden);
      cubit.report(id2, PlaybackStatus.ageRestricted);
      cubit.report(id1, PlaybackStatus.forbidden); // refresh id1
      cubit.report(
        '4444444444444444444444444444444444444444444444444444444444444444',
        PlaybackStatus.notFound,
      );

      // id2 should be evicted now, id1 survived.
      expect(cubit.state.statusFor(id2), PlaybackStatus.ready);
      expect(cubit.state.statusFor(id1), PlaybackStatus.forbidden);
    });
  });
}
```

- [ ] **Step 2: Run tests, expect failure**

```
cd mobile && flutter test test/blocs/video_playback_status/video_playback_status_cubit_test.dart
```

Expected: compile error — `VideoPlaybackStatusCubit` does not exist.

- [ ] **Step 3: Implement the cubit**

Create `mobile/lib/blocs/video_playback_status/video_playback_status_cubit.dart`:

```dart
// ABOUTME: Tracks per-video playback status reported by the pooled video
// ABOUTME: player. Feed UIs read this to swap in moderated-content overlays.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/video_playback_status/video_playback_status_state.dart';

/// A lightweight cubit that tracks per-video playback status.
///
/// Widgets in the feed listen for the active video's entry and swap in
/// specialized overlays (moderated content, not found, retry) when the
/// pooled video player reports an error.
class VideoPlaybackStatusCubit extends Cubit<VideoPlaybackStatusState> {
  /// Creates a cubit with an optional [maxEntries] cap for the internal
  /// LRU map. Defaults come from [VideoPlaybackStatusState].
  VideoPlaybackStatusCubit({int? maxEntries})
      : super(
          maxEntries == null
              ? VideoPlaybackStatusState()
              : VideoPlaybackStatusState(maxEntries: maxEntries),
        );

  /// Reports [status] for the video with [eventId].
  void report(String eventId, PlaybackStatus status) {
    emit(state.withStatus(eventId, status));
  }

  /// Clears all tracked statuses (call on feed-mode change).
  void clear() {
    emit(state.cleared());
  }
}
```

- [ ] **Step 4: Run tests, expect pass**

```
cd mobile && flutter test test/blocs/video_playback_status/video_playback_status_cubit_test.dart
```

Expected: all 5 tests pass.

- [ ] **Step 5: Format and analyze**

```
cd mobile && dart format lib/blocs/video_playback_status test/blocs/video_playback_status && flutter analyze lib/blocs/video_playback_status test/blocs/video_playback_status
```

Expected: no issues.

- [ ] **Step 6: Commit**

```
cd mobile && git add lib/blocs/video_playback_status/video_playback_status_cubit.dart test/blocs/video_playback_status/video_playback_status_cubit_test.dart && git commit -m "feat(video_playback_status): add cubit for per-video playback status tracking"
```

---

### Task C3: Build `ModeratedContentOverlay` widget with TDD

**Files:**
- Create: `mobile/lib/widgets/video_feed_item/moderated_content_overlay.dart`
- Test: `mobile/test/widgets/video_feed_item/moderated_content_overlay_test.dart`

**Context:** Full-screen overlay that replaces the `FeedVideoOverlay` entirely (no author info, no like/comment/share) when the current video's status is `forbidden` or `ageRestricted`. Two callbacks: `onSkip` (advances to next video) and `onVerifyAge` (only shown for `ageRestricted`).

- [ ] **Step 1: Write the failing widget tests**

```dart
// mobile/test/widgets/video_feed_item/moderated_content_overlay_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/video_playback_status/video_playback_status_state.dart';
import 'package:openvine/widgets/video_feed_item/moderated_content_overlay.dart';

void main() {
  group(ModeratedContentOverlay, () {
    Future<void> pumpOverlay(
      WidgetTester tester, {
      required PlaybackStatus status,
      VoidCallback? onSkip,
      VoidCallback? onVerifyAge,
    }) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModeratedContentOverlay(
              status: status,
              onSkip: onSkip ?? () {},
              onVerifyAge: onVerifyAge,
            ),
          ),
        ),
      );
    }

    testWidgets('renders content-restricted message for forbidden', (tester) async {
      await pumpOverlay(tester, status: PlaybackStatus.forbidden);

      expect(find.text('Content restricted'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('Verify age'), findsNothing);
    });

    testWidgets('renders age-restricted message and Verify age button', (tester) async {
      await pumpOverlay(
        tester,
        status: PlaybackStatus.ageRestricted,
        onVerifyAge: () {},
      );

      expect(find.text('Age-restricted content'), findsOneWidget);
      expect(find.text('Verify age'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
    });

    testWidgets('calls onSkip when Skip is tapped', (tester) async {
      var skipped = 0;
      await pumpOverlay(
        tester,
        status: PlaybackStatus.forbidden,
        onSkip: () => skipped++,
      );
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(skipped, equals(1));
    });

    testWidgets('calls onVerifyAge when Verify age is tapped', (tester) async {
      var verified = 0;
      await pumpOverlay(
        tester,
        status: PlaybackStatus.ageRestricted,
        onVerifyAge: () => verified++,
      );
      await tester.tap(find.text('Verify age'));
      await tester.pumpAndSettle();

      expect(verified, equals(1));
    });

    testWidgets('does not render author info or action buttons', (tester) async {
      await pumpOverlay(tester, status: PlaybackStatus.forbidden);

      // The overlay must NOT show any of the usual FeedVideoOverlay chrome.
      // We assert by Semantics identifiers used by the main overlay.
      expect(find.bySemanticsLabel(RegExp('Video author: .*')), findsNothing);
      expect(find.bySemanticsLabel(RegExp('Video description: .*')), findsNothing);
    });
  });
}
```

- [ ] **Step 2: Run tests, expect failure**

```
cd mobile && flutter test test/widgets/video_feed_item/moderated_content_overlay_test.dart
```

Expected: compile error — `ModeratedContentOverlay` does not exist.

- [ ] **Step 3: Implement the widget**

Create `mobile/lib/widgets/video_feed_item/moderated_content_overlay.dart`:

```dart
// ABOUTME: Full-screen overlay shown when the active video has a 401/403
// ABOUTME: playback failure. Replaces the normal FeedVideoOverlay entirely.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/blocs/video_playback_status/video_playback_status_state.dart';

/// Displayed in place of the normal feed overlay when the active video's
/// [PlaybackStatus] is [PlaybackStatus.forbidden] or
/// [PlaybackStatus.ageRestricted].
///
/// Shows a coherent restriction message with a Skip button and, for
/// age-restricted content, a Verify age button that triggers the caller-
/// provided auth flow.
class ModeratedContentOverlay extends StatelessWidget {
  const ModeratedContentOverlay({
    required this.status,
    required this.onSkip,
    this.onVerifyAge,
    super.key,
  });

  /// The reason the video cannot be played.
  final PlaybackStatus status;

  /// Called when the user taps Skip.
  final VoidCallback onSkip;

  /// Called when the user taps Verify age. Must be non-null when [status]
  /// is [PlaybackStatus.ageRestricted].
  final VoidCallback? onVerifyAge;

  bool get _isAgeRestricted => status == PlaybackStatus.ageRestricted;

  @override
  Widget build(BuildContext context) {
    final icon = _isAgeRestricted
        ? DivineIconName.lockSimple
        : DivineIconName.shieldCheck;
    final title = _isAgeRestricted
        ? 'Age-restricted content'
        : 'Content restricted';
    final body = _isAgeRestricted
        ? 'Verify your age to view this video.'
        : 'This video was restricted by the relay.';

    return ColoredBox(
      color: VineTheme.backgroundColor,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 16,
              children: [
                DivineIcon(
                  icon: icon,
                  color: VineTheme.whiteText,
                  size: 64,
                ),
                Text(
                  title,
                  style: VineTheme.titleMediumFont(),
                  textAlign: TextAlign.center,
                ),
                Text(
                  body,
                  style: VineTheme.bodyMediumFont(),
                  textAlign: TextAlign.center,
                ),
                if (_isAgeRestricted && onVerifyAge != null)
                  DivineButton(
                    label: 'Verify age',
                    type: DivineButtonType.primary,
                    onPressed: onVerifyAge!,
                  ),
                DivineButton(
                  label: 'Skip',
                  type: DivineButtonType.tertiary,
                  onPressed: onSkip,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

Check `divine_ui` for the exact `DivineButton`/`DivineIcon`/typography API names. If `VineTheme.titleMediumFont()` does not exist, use the nearest equivalent (look at `feed_video_overlay.dart` for references already in use). If `spacing:` is not supported on the target `Column` variant, replace with `SizedBox(height: 16)` separators — but only after grepping the codebase to confirm.

- [ ] **Step 4: Run tests, expect pass**

```
cd mobile && flutter test test/widgets/video_feed_item/moderated_content_overlay_test.dart
```

Expected: all 5 tests pass.

- [ ] **Step 5: Format and analyze**

```
cd mobile && dart format lib/widgets/video_feed_item/moderated_content_overlay.dart test/widgets/video_feed_item/moderated_content_overlay_test.dart && flutter analyze lib/widgets/video_feed_item test/widgets/video_feed_item
```

Expected: no issues.

- [ ] **Step 6: Commit**

```
cd mobile && git add lib/widgets/video_feed_item/moderated_content_overlay.dart test/widgets/video_feed_item/moderated_content_overlay_test.dart && git commit -m "feat(video_feed_item): add ModeratedContentOverlay widget"
```

---

### Task C4: Wire the cubit into the feed page and swap in the overlay

**Files:**
- Modify: `mobile/lib/screens/feed/video_feed_page.dart`
- Modify: `mobile/lib/screens/feed/feed_video_overlay.dart`
- Modify: `mobile/lib/screens/feed/pooled_fullscreen_video_feed_screen.dart`

**Context:** The last step connects the pieces. The `_PooledVideoFeedItemContent` state already owns `PooledVideoPlayer` and its `errorBuilder`. We want to:
1. Provide a single `VideoPlaybackStatusCubit` at the top of each feed subtree.
2. When the pooled player reports an error, call `cubit.report(video.id, status)` from a callback on the error overlay.
3. In `FeedVideoOverlay`, watch the cubit for the current video's status and short-circuit to `ModeratedContentOverlay` when restricted.

This task does not have its own unit tests beyond what we already built — the existing feed widget tests remain the safety net for layout. We add one BLoC-level integration test to confirm the wiring.

- [ ] **Step 1: Provide the cubit in `video_feed_page.dart`**

Find the `BlocProvider` for `VideoFeedBloc` (around line 62). Wrap it in a `MultiBlocProvider` adding the new cubit:

```dart
return MultiBlocProvider(
  providers: [
    BlocProvider(
      key: ValueKey('video-feed-$showDivineHostedOnly'),
      create: (_) => VideoFeedBloc(
        // ...existing args...
      )..add(VideoFeedStarted(mode: initialMode)),
    ),
    BlocProvider(
      create: (_) => VideoPlaybackStatusCubit(),
    ),
  ],
  child: const VideoFeedView(),
);
```

Add the imports:
```dart
import 'package:openvine/blocs/video_playback_status/video_playback_status_cubit.dart';
import 'package:openvine/blocs/video_playback_status/video_playback_status_state.dart';
```

Do the same in `pooled_fullscreen_video_feed_screen.dart` if it owns its own `VideoFeedBloc` provider. If the fullscreen screen reuses the same provider from the parent route, skip it.

- [ ] **Step 2: Report status from the error builder**

In `video_feed_page.dart`, find the `errorBuilder` on `PooledVideoPlayer` (around line 742). The existing code passes `errorType` into `PooledVideoErrorOverlay`. Wrap it in a `Builder` that also reports into the cubit:

```dart
errorBuilder: (context, onRetry, errorType) {
  // Fire-and-forget notify the cubit so FeedVideoOverlay can react.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final status = switch (errorType) {
      VideoErrorType.ageRestricted => PlaybackStatus.ageRestricted,
      VideoErrorType.forbidden => PlaybackStatus.forbidden,
      VideoErrorType.notFound => PlaybackStatus.notFound,
      VideoErrorType.generic || null => PlaybackStatus.generic,
    };
    context.read<VideoPlaybackStatusCubit>().report(video.id, status);
  });
  return PooledVideoErrorOverlay(
    video: video,
    onRetry: onRetry,
    errorType: errorType,
  );
},
```

Apply the same change to `pooled_fullscreen_video_feed_screen.dart` around line 724. Import `package:flutter/scheduler.dart` if `WidgetsBinding` isn't already available via an existing import.

- [ ] **Step 3: Swap in `ModeratedContentOverlay` from `FeedVideoOverlay`**

In `mobile/lib/screens/feed/feed_video_overlay.dart`, at the top of `_FeedVideoOverlayState.build` (around line 82), after reading `video`, add:

```dart
final playbackStatus = context.select(
  (VideoPlaybackStatusCubit cubit) => cubit.state.statusFor(video.id),
);

if (playbackStatus == PlaybackStatus.forbidden ||
    playbackStatus == PlaybackStatus.ageRestricted) {
  return ModeratedContentOverlay(
    status: playbackStatus,
    onSkip: () {
      // Advance to the next page. The controller is owned by VideoFeedView
      // and exposed via context. Use the same mechanism the existing code
      // uses for navigation (e.g. PooledVideoFeedController.goToNext() if
      // available; otherwise post a VideoFeedSkipRequested event).
      _skipCurrentVideo(context);
    },
    onVerifyAge: playbackStatus == PlaybackStatus.ageRestricted
        ? () => _verifyAge(context, video)
        : null,
  );
}
```

`_skipCurrentVideo` and `_verifyAge` are new helper methods on `_FeedVideoOverlayState`. Implementation:

```dart
void _skipCurrentVideo(BuildContext context) {
  // Look up the enclosing PooledVideoFeedState to advance by one page.
  final feedState = context
      .findAncestorStateOfType<PooledVideoFeedState>();
  feedState?.goToNext();
}

Future<void> _verifyAge(BuildContext context, VideoEvent video) async {
  final interceptor = ref.read(mediaAuthInterceptorProvider);
  await interceptor.handleAgeVerification(context, video);
}
```

Before writing this block, grep for the exact API of `PooledVideoFeedState` and `MediaAuthInterceptor` — they may not have the methods named above. If `goToNext()` is not public, raise a question comment in the plan and reuse whichever page-advance API already exists in `video_feed_page.dart` for the "Next" button (search for `nextPage`, `jumpToPage`, or `PageController`). Do not invent APIs.

Add imports:
```dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/video_playback_status/video_playback_status_cubit.dart';
import 'package:openvine/blocs/video_playback_status/video_playback_status_state.dart';
import 'package:openvine/widgets/video_feed_item/moderated_content_overlay.dart';
```

- [ ] **Step 4: Do the same swap in `pooled_fullscreen_video_feed_screen.dart`**

The fullscreen screen has its own `overlayBuilder` that mirrors `FeedVideoOverlay`'s content-warning check (around line 730). Apply the same `PlaybackStatus` short-circuit immediately before the existing `showContentWarningOverlay` check. Reuse `ModeratedContentOverlay` and the same helpers.

- [ ] **Step 5: Format and analyze**

```
cd mobile && dart format lib/screens/feed/video_feed_page.dart lib/screens/feed/feed_video_overlay.dart lib/screens/feed/pooled_fullscreen_video_feed_screen.dart && flutter analyze lib/screens/feed
```

Expected: no issues. The analyzer may complain about unused imports or missing switch cases — resolve them before proceeding.

- [ ] **Step 6: Run the broader feed test suite to catch regressions**

```
cd mobile && flutter test test/screens/feed test/blocs/video_feed test/widgets/video_feed_item
```

Expected: all tests pass. If an existing widget test for `FeedVideoOverlay` now fails because the widget requires a `VideoPlaybackStatusCubit`, wrap the pumped widget in a `BlocProvider<VideoPlaybackStatusCubit>` that supplies a fresh cubit.

- [ ] **Step 7: Commit**

```
cd mobile && git add lib/screens/feed/video_feed_page.dart lib/screens/feed/feed_video_overlay.dart lib/screens/feed/pooled_fullscreen_video_feed_screen.dart && git commit -m "feat(feed): swap in ModeratedContentOverlay for 401/403 playback failures"
```

---

## Chunk 4: End-to-end verification

### Task V1: Run the full test suite

- [ ] **Step 1: Run all Dart tests**

```
cd mobile && flutter test
cd mobile/packages/videos_repository && flutter test
cd mobile/packages/models && flutter test
```

Expected: every test passes. If anything fails, fix it before moving on — do not skip or mark as xfail.

- [ ] **Step 2: Run analyzer on the whole app**

```
cd mobile && flutter analyze lib test integration_test
```

Expected: no issues.

- [ ] **Step 3: Confirm coverage on new and modified lines**

```
cd mobile && flutter test --coverage
```

Inspect `mobile/coverage/lcov.info` and confirm the following files have 100% line coverage:
- `lib/blocs/video_playback_status/video_playback_status_cubit.dart`
- `lib/blocs/video_playback_status/video_playback_status_state.dart`
- `lib/widgets/video_feed_item/moderated_content_overlay.dart`
- `lib/services/nsfw_content_filter.dart`

For modified files (`video_feed_bloc.dart`, `videos_repository.dart`, `video_stats.dart`), verify the newly added lines are covered. Add tests if any branch is uncovered.

- [ ] **Step 4: Manual smoke check**

Launch the local stack and run the app against it:

```
cd mobile && mise run local_up
cd mobile && flutter run -d <device> --dart-define=DEFAULT_ENV=LOCAL
```

Reproduction: open the home feed, confirm that normal videos still play. Then publish a kind 34236 event pointing at a media URL that returns 403 (or use an existing moderated test fixture on the local relay if available) and confirm the moderated-content overlay appears in place of the broken player card. This step is manual and not automated.

### Task V2: Update CHANGELOG and open PR

- [ ] **Step 1: Update `CHANGELOG.md`**

Add an entry under the Unreleased / Fixed section:

```markdown
- Moderated videos from the relay are now filtered from the home feed cache,
  unknown server-side moderation labels are preserved and treated as hide
  signals, and 401/403 playback failures display a full-screen overlay with
  skip and age-verification actions instead of a half-broken player card.
```

- [ ] **Step 2: Commit the changelog**

```
cd mobile && git add ../CHANGELOG.md && git commit -m "docs: note moderated content filtering fix in changelog"
```

(Note: `CHANGELOG.md` is at the repo root, not under `mobile/`.)

- [ ] **Step 3: Push and open PR**

```
cd mobile && git push -u origin fix/moderated-content-filter
```

Then open the PR using the project's `pr-summary` skill / template. Title: `fix(feed): handle moderated content in cache, unknown labels, and 401/403 playback`. Body should link back to the design spec at `docs/superpowers/specs/2026-04-05-moderated-content-filter-design.md` and list the three parts (A/B/C).

---

## Done

When every checkbox above is checked and the PR is open, the three gaps from the design spec are closed:
- Part A: cached videos pass through the filter (Tasks A1–A2)
- Part B: unknown labels are preserved and treated conservatively (Tasks B1–B2)
- Part C: playback failures render a coherent overlay (Tasks C1–C4)
- End-to-end: full suite green + manual smoke check (Tasks V1–V2)
