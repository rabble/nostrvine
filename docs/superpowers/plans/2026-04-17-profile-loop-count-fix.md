# Profile Loop Count Display Fix Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop the fullscreen video player from showing "0 loops" on profile-feed videos by (a) preserving the REST-supplied `views` count through Nostr enrichment and (b) collapsing duplicated `archivedLoops + liveViews` math behind a `VideoEvent` getter.

**Architecture:** Two narrow surgical changes — one to `enrichVideosWithNostrTags` (merge, don't replace, `rawTags`), one to `VideoEvent` (expose `hasLoopMetadata` getter and reuse the existing `totalLoops` getter from the two widgets that currently inline the formula). No new layers, no provider rewiring. Bigger architectural consolidation (a shared REST→Nostr `VideoFeedRepository`) is intentionally deferred to a follow-up plan.

**Tech Stack:** Dart, Flutter, `flutter_test`, `mocktail`, the existing `models` package, Riverpod-based feed providers (untouched).

---

## Background

### The bug (root cause)

Both `PopularNowFeed` (home) and `ProfileFeed` (profile) hydrate videos from Funnelcake REST and then call `enrichVideosInBackground` to fetch full Nostr tags. The REST endpoint returns `loops` and `views` (engagement metrics from ClickHouse) which `VideoStats.toVideoEvent()` writes to `originalLoops` and `rawTags['views']`. The display widget at `mobile/lib/widgets/video_feed_item/video_feed_item.dart:1492-1497` reads both:

```dart
final archivedLoops = video.originalLoops ?? 0;
final liveViews = int.tryParse(video.rawTags['views'] ?? '') ?? 0;
final loopCount = archivedLoops + liveViews;
final hasLoopMetadata = video.originalLoops != null
    || video.rawTags.containsKey('loops')
    || video.rawTags.containsKey('views');
```

`enrichVideosWithNostrTags` (`mobile/lib/utils/video_nostr_enrichment.dart:60-67`) **replaces** `rawTags` wholesale with the Nostr-parsed tags whenever the REST response had `<4` raw tags. Nostr events do not carry a `'views'` tag (it is a server-side metric), so REST-supplied `rawTags['views']` is wiped on enrichment. `originalLoops` is conservatively preserved (`?? parsed.originalLoops`). For a fresh diVine upload whose `originalLoops` is `0` (a non-null int), `hasLoopMetadata` stays `true` but the count collapses to `0 + 0 = 0`. The user sees literal `"0 loops"`.

This same code path runs for the home feed too, so why doesn't home show "0 loops"? In practice `getRecentVideos` rows almost always carry rich `rawTags` (`d`, `imeta`, `title`, `t`, …) from the Funnelcake response, so the `<4` enrichment trigger never fires and `views` survives. Profile videos hit the same trigger less often, but the path that does fire reliably destroys `views`. Curl-verified live data: the `goddess is allergic` video returns `loops: 6, views: 34` from both endpoints — the fact that the UI still shows `0` confirms the destruction happens client-side, after the REST fetch.

### The duplication (architectural smell)

The exact same `(originalLoops ?? 0) + int.tryParse(rawTags['views'] ?? '')` formula already exists as `VideoEvent.totalLoops` (`mobile/packages/models/lib/src/video_event.dart:814-816`) but is reimplemented inline in two display widgets:

- `mobile/lib/widgets/video_feed_item/video_feed_item.dart:1492-1497` (the symptom in the screenshot)
- `mobile/lib/widgets/video_feed_item/actions/video_description_overlay.dart:74`

`hasLoopMetadata` has no shared getter; widgets recompute the predicate inline.

### Out of scope

A larger consolidation — pulling the REST → Nostr fallback + metadata-cache orchestration out of `PopularNowFeed`, `ProfileFeed`, `PopularVideosFeed`, and `VideoFeed` into a single `VideoFeedRepository` — is the right long-term answer to "shouldn't most of the video player things be the same regardless of source?". That is intentionally deferred to a separate plan because it touches generated Riverpod code across four providers and warrants its own review. This plan is the surgical bug fix.

---

## File Structure

### Files modified

- `mobile/packages/models/lib/src/video_event.dart` — add `hasLoopMetadata` getter; update doc on `totalLoops`. Single responsibility: domain model derivations.
- `mobile/lib/utils/video_nostr_enrichment.dart` — change one line in the `copyWith` to merge `rawTags` instead of replace. Single responsibility: REST→Nostr enrichment merge policy.
- `mobile/lib/widgets/video_feed_item/video_feed_item.dart` — replace inline math at `:1492-1501` with `video.totalLoops` + `video.hasLoopMetadata`. Single responsibility: presentation only.
- `mobile/lib/widgets/video_feed_item/actions/video_description_overlay.dart` — replace inline math at `:74` with `video.totalLoops`.

### Files created

- `mobile/packages/models/test/src/video_event_loop_metadata_test.dart` — covers the new `hasLoopMetadata` getter and the existing `totalLoops` getter for the cases that today reach the bad UI state. Single responsibility: derived getter behavior.
- `mobile/test/utils/video_nostr_enrichment_views_test.dart` — covers the merge-don't-replace behavior of `enrichVideosWithNostrTags` for `rawTags['views']`. Single responsibility: enrichment merge contract.

No barrel files change; getters are exported via the existing `VideoEvent` class.

---

## Chunk 1: Domain getter (`hasLoopMetadata`)

### Task 1: Failing test for `hasLoopMetadata`

**Files:**
- Create: `mobile/packages/models/test/src/video_event_loop_metadata_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// ABOUTME: Tests for VideoEvent.totalLoops and hasLoopMetadata derivations
// ABOUTME: that drive the "N loops" label on the fullscreen video player.

import 'package:models/models.dart';
import 'package:test/test.dart';

VideoEvent _video({
  int? originalLoops,
  Map<String, String> rawTags = const {},
}) {
  return VideoEvent(
    id: 'a' * 64,
    pubkey: 'b' * 64,
    createdAt: 1704067200,
    content: '',
    timestamp: DateTime.fromMillisecondsSinceEpoch(
      1704067200 * 1000,
      isUtc: true,
    ),
    originalLoops: originalLoops,
    rawTags: rawTags,
  );
}

void main() {
  group(VideoEvent, () {
    group('totalLoops', () {
      test('returns 0 when neither originalLoops nor rawTags[views] set', () {
        expect(_video().totalLoops, equals(0));
      });

      test('sums originalLoops and rawTags[views]', () {
        final video = _video(
          originalLoops: 6,
          rawTags: const {'views': '34'},
        );
        expect(video.totalLoops, equals(40));
      });

      test('treats unparseable rawTags[views] as 0', () {
        final video = _video(
          originalLoops: 6,
          rawTags: const {'views': 'not-a-number'},
        );
        expect(video.totalLoops, equals(6));
      });
    });

    group('hasLoopMetadata', () {
      test('is false when no loop fields present', () {
        expect(_video().hasLoopMetadata, isFalse);
      });

      test('is true when originalLoops is non-null (even if 0)', () {
        expect(_video(originalLoops: 0).hasLoopMetadata, isTrue);
      });

      test('is true when rawTags contains views', () {
        final video = _video(rawTags: const {'views': '34'});
        expect(video.hasLoopMetadata, isTrue);
      });

      test('is true when rawTags contains loops (vine archive)', () {
        final video = _video(rawTags: const {'loops': '13565'});
        expect(video.hasLoopMetadata, isTrue);
      });
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run from repo root:
```bash
cd mobile/packages/models && dart test test/src/video_event_loop_metadata_test.dart
```
Expected: `hasLoopMetadata` tests FAIL with "The getter 'hasLoopMetadata' isn't defined for the type 'VideoEvent'." `totalLoops` tests should PASS (getter already exists).

- [ ] **Step 3: Add the getter**

Edit `mobile/packages/models/lib/src/video_event.dart`. Find the existing `totalLoops` getter (`:814-816`):

```dart
  /// Total loops combining archived Vine loops and live diVine views.
  int get totalLoops =>
      (originalLoops ?? 0) + (int.tryParse(rawTags['views'] ?? '') ?? 0);
```

Insert immediately after it:

```dart
  /// Whether this video carries any loop-count metadata.
  ///
  /// Used by the fullscreen player to decide whether to render
  /// `"$totalLoops loops"` or fall back to relative time. Returns true when
  /// any of the three loop-related fields is present, even when the
  /// derived `totalLoops` is zero (a deliberate `0` count is still
  /// metadata).
  bool get hasLoopMetadata =>
      originalLoops != null ||
      rawTags.containsKey('loops') ||
      rawTags.containsKey('views');
```

- [ ] **Step 4: Run test to verify it passes**

```bash
cd mobile/packages/models && dart test test/src/video_event_loop_metadata_test.dart
```
Expected: All 7 tests PASS.

- [ ] **Step 5: Run wider model package tests to confirm no regression**

```bash
cd mobile/packages/models && dart test
```
Expected: All previously-passing tests still pass.

- [ ] **Step 6: Commit**

```bash
git add mobile/packages/models/lib/src/video_event.dart \
        mobile/packages/models/test/src/video_event_loop_metadata_test.dart
git commit -m "feat(models): add VideoEvent.hasLoopMetadata getter

Mirrors the predicate currently inlined in two display widgets.
Returns true whenever originalLoops, rawTags['loops'], or
rawTags['views'] is present — even if the derived count is 0."
```

---

## Chunk 2: Enrichment merges, doesn't replace, `rawTags`

### Task 2: Failing test that `views` survives enrichment

**Files:**
- Create: `mobile/test/utils/video_nostr_enrichment_views_test.dart`
- Modify: `mobile/lib/utils/video_nostr_enrichment.dart`

- [ ] **Step 1: Write the failing test**

```dart
// ABOUTME: Regression tests for views/loops engagement metrics surviving
// ABOUTME: Nostr enrichment in enrichVideosWithNostrTags.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/utils/video_nostr_enrichment.dart';

class _MockNostrClient extends Mock implements NostrClient {}

VideoEvent _restVideo({
  required String id,
  int? originalLoops,
  String? views,
}) {
  return VideoEvent(
    id: id,
    pubkey: 'a' * 64,
    createdAt: 1704067200,
    content: 'rest video',
    timestamp: DateTime.fromMillisecondsSinceEpoch(
      1704067200 * 1000,
      isUtc: true,
    ),
    videoUrl: 'https://example.com/$id.mp4',
    originalLoops: originalLoops,
    // Three tags + views — under the < 4 enrichment trigger.
    rawTags: {
      'd': id,
      'title': 'Test',
      'thumb': 'https://example.com/$id.jpg',
      if (views != null) 'views': views,
    },
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(<Filter>[]);
  });

  group('enrichVideosWithNostrTags', () {
    late _MockNostrClient mockNostrClient;

    setUp(() {
      mockNostrClient = _MockNostrClient();
    });

    test(
      'preserves rawTags[views] from REST when Nostr enrichment fires',
      () async {
        const pubkey =
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
        final nostrEvent = Event(
          pubkey,
          34236,
          [
            ['d', 'video-1'],
            ['url', 'https://example.com/video-1.mp4'],
            ['title', 'Enriched Title'],
            ['m', 'video/mp4'],
          ],
          'Enriched content',
          createdAt: 1704067200,
        );
        final restVideo = _restVideo(
          id: nostrEvent.id,
          originalLoops: 0,
          views: '34',
        );

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [nostrEvent]);

        final enriched = await enrichVideosWithNostrTags(
          [restVideo],
          nostrService: mockNostrClient,
        );

        expect(enriched, hasLength(1));
        expect(enriched.single.rawTags['views'], equals('34'));
        expect(enriched.single.totalLoops, equals(34));
        expect(enriched.single.hasLoopMetadata, isTrue);
      },
    );

    test(
      'Nostr-supplied tags override REST tags on key collision',
      () async {
        const pubkey =
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
        final nostrEvent = Event(
          pubkey,
          34236,
          [
            ['d', 'video-2'],
            ['url', 'https://example.com/video-2.mp4'],
            ['title', 'Nostr Title Wins'],
            ['m', 'video/mp4'],
          ],
          'Nostr content',
          createdAt: 1704067200,
        );
        final restVideo = _restVideo(
          id: nostrEvent.id,
          views: '7',
        )..rawTags['title'] = 'REST Title (stale)';

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [nostrEvent]);

        final enriched = await enrichVideosWithNostrTags(
          [restVideo],
          nostrService: mockNostrClient,
        );

        expect(enriched.single.rawTags['title'], equals('Nostr Title Wins'));
        expect(enriched.single.rawTags['views'], equals('7'));
      },
    );
  });
}
```

> **Note on `Map<String, String>` mutation:** `_restVideo` returns a `VideoEvent` whose `rawTags` is mutable in the test scope because we built it from a non-`const` map literal (the `if (views != null)` collection-if forces a new `Map`). The cascade `..rawTags['title'] = ...` is therefore safe.

- [ ] **Step 2: Run test to verify it fails**

```bash
cd mobile && flutter test test/utils/video_nostr_enrichment_views_test.dart
```
Expected: First test FAILS — `enriched.single.rawTags['views']` is `null` (clobbered by Nostr-only tags) and `totalLoops` is `0`. Second test PASSES (Nostr title already wins under current "replace" behavior).

- [ ] **Step 3: Implement the merge fix**

Edit `mobile/lib/utils/video_nostr_enrichment.dart`. Find the `copyWith` block at `:60-67`:

```dart
    return videos.map((video) {
      final parsed = nostrEventsMap[video.id];
      if (parsed != null) {
        // Check if Nostr event has original Vine metric tags

        return video.copyWith(
          rawTags: parsed.rawTags,
```

Replace the single line `rawTags: parsed.rawTags,` with:

```dart
          // Merge: keep REST-only keys (e.g. `views` engagement metric that
          // Nostr events never carry), but let Nostr win on key collisions.
          rawTags: {...video.rawTags, ...parsed.rawTags},
```

Leave every other field assignment in the `copyWith` unchanged.

- [ ] **Step 4: Run test to verify both pass**

```bash
cd mobile && flutter test test/utils/video_nostr_enrichment_views_test.dart
```
Expected: Both tests PASS.

- [ ] **Step 5: Run the existing enrichment streaming test to confirm no regression**

```bash
cd mobile && flutter test test/utils/video_nostr_enrichment_streaming_test.dart
```
Expected: All previously-passing tests still pass. (The streaming test populates `proof: c2pa-hash` on the Nostr side and starts from an empty REST `rawTags`, so the merge is a strict superset — no behavior change.)

- [ ] **Step 6: Commit**

```bash
git add mobile/lib/utils/video_nostr_enrichment.dart \
        mobile/test/utils/video_nostr_enrichment_views_test.dart
git commit -m "fix(enrichment): merge rawTags during Nostr enrichment

Previously rawTags was replaced wholesale with the Nostr-parsed
tags, wiping REST-only engagement keys like 'views'. That made
the fullscreen player report '0 loops' on profile videos whose
originalLoops happened to be 0. Merge instead, with Nostr winning
on key collisions."
```

---

## Chunk 3: Widgets reuse `totalLoops` / `hasLoopMetadata`

### Task 3: Replace inline math in `video_feed_item.dart`

**Files:**
- Modify: `mobile/lib/widgets/video_feed_item/video_feed_item.dart:1492-1501`

This is a pure refactor. The behavior is already verified by Chunk 1's getter tests. We do not need a new test — running the existing widget test suite is sufficient.

- [ ] **Step 1: Apply the refactor**

In `mobile/lib/widgets/video_feed_item/video_feed_item.dart`, replace lines 1492-1501:

```dart
                        final archivedLoops = video.originalLoops ?? 0;
                        final liveViews =
                            int.tryParse(video.rawTags['views'] ?? '') ?? 0;
                        // Always sum archived (original Vine) and live (new diVine)
                        // loops so migrated videos show their full combined count.
                        final loopCount = archivedLoops + liveViews;
                        final hasLoopMetadata =
                            video.originalLoops != null ||
                            video.rawTags.containsKey('loops') ||
                            video.rawTags.containsKey('views');
```

with:

```dart
                        final loopCount = video.totalLoops;
                        final hasLoopMetadata = video.hasLoopMetadata;
```

Leave the surrounding `Text(hasLoopMetadata ? ... : video.relativeTime, ...)` block unchanged.

- [ ] **Step 2: Verify the symbol is no longer referenced anywhere unexpected**

```bash
grep -n "originalLoops ?? 0" mobile/lib/widgets/video_feed_item/video_feed_item.dart
grep -n "rawTags\['views'\]"  mobile/lib/widgets/video_feed_item/video_feed_item.dart
```
Expected: No matches in `video_feed_item.dart`.

- [ ] **Step 3: Run widget tests for this file**

```bash
cd mobile && flutter test test/widgets/video_feed_item/
```
Expected: All previously-passing tests still pass. (Tests that did not assert on the loop label remain green; if any test happens to assert the rendered "N loops" string, it should also still pass because `totalLoops`/`hasLoopMetadata` reproduce the prior formula.)

- [ ] **Step 4: Commit**

```bash
git add mobile/lib/widgets/video_feed_item/video_feed_item.dart
git commit -m "refactor(video_feed_item): use VideoEvent.totalLoops getter

Drops the inlined loop-count math in favor of the existing
VideoEvent.totalLoops + new VideoEvent.hasLoopMetadata getters."
```

### Task 4: Replace inline math in `video_description_overlay.dart`

**Files:**
- Modify: `mobile/lib/widgets/video_feed_item/actions/video_description_overlay.dart:74`

- [ ] **Step 1: Read the current expression in context**

```bash
sed -n '60,90p' mobile/lib/widgets/video_feed_item/actions/video_description_overlay.dart
```
Expected: shows the `'🔁 ${StringUtils.formatCompactNumber(...)} loops'` interpolation.

- [ ] **Step 2: Apply the refactor**

Replace the substring inside the `formatCompactNumber(...)` call:

```dart
StringUtils.formatCompactNumber((video.originalLoops ?? 0) + (int.tryParse(video.rawTags['views'] ?? '') ?? 0))
```

with:

```dart
StringUtils.formatCompactNumber(video.totalLoops)
```

- [ ] **Step 3: Verify no remaining inline duplication in this file**

```bash
grep -n "originalLoops ?? 0\|rawTags\['views'\]" mobile/lib/widgets/video_feed_item/actions/video_description_overlay.dart
```
Expected: no matches.

- [ ] **Step 4: Run widget tests for the overlay (and any tests that import it)**

```bash
cd mobile && flutter test test/widgets/video_feed_item/
```
Expected: green.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/widgets/video_feed_item/actions/video_description_overlay.dart
git commit -m "refactor(video_description_overlay): use VideoEvent.totalLoops"
```

---

## Chunk 4: Final verification

### Task 5: Full local verification

- [ ] **Step 1: Format**

```bash
cd mobile && mise exec -- dart format lib test
```
Expected: no diffs (or only the files we touched).

- [ ] **Step 2: Analyzer**

```bash
cd mobile && mise exec -- flutter analyze lib test
```
Expected: no new analyzer issues.

- [ ] **Step 3: Targeted test run for the changed surface**

```bash
cd mobile && flutter test \
  test/utils/video_nostr_enrichment_views_test.dart \
  test/utils/video_nostr_enrichment_streaming_test.dart \
  test/widgets/video_feed_item/
cd mobile/packages/models && dart test test/src/video_event_loop_metadata_test.dart \
  test/src/video_event_parsing_test.dart
```
Expected: green.

- [ ] **Step 4: Spot-check the wider feed test suite**

```bash
cd mobile && flutter test test/providers/profile_feed_pagination_contract_test.dart \
  test/providers/explore_feed_refresh_retention_test.dart
```
Expected: green. These exercise the providers that consume `enrichVideosWithNostrTags`; they should be unaffected because the merge only adds keys, never removes any that were present before.

- [ ] **Step 5: Manual sanity check (devices optional)**

Apply @superpowers:verification-before-completion before claiming done. If a device or emulator is available:

```bash
cd mobile && flutter run --dart-define=DEFAULT_ENV=PRODUCTION
```

Then:
1. Open a profile (own or someone else's) that has at least one video.
2. Tap a thumbnail to enter the fullscreen player.
3. Confirm the `"N loops"` label under the author name shows a non-zero count for videos whose REST API row has `views > 0`.
4. Confirm the same video opened from the home/explore feed shows the same count.

If no device is available, document that explicitly in the PR description and rely on the unit + widget tests.

- [ ] **Step 6: Push and open PR**

```bash
git push -u origin fix/profile-loop-count
gh pr create --title "fix: profile-feed videos showed '0 loops' due to enrichment wiping rawTags['views']" \
  --body "$(cat <<'EOF'
## Summary
- `enrichVideosWithNostrTags` now merges `rawTags` instead of replacing them, so REST-only engagement keys like `views` survive enrichment.
- `VideoEvent` exposes a new `hasLoopMetadata` getter; the existing `totalLoops` getter is now used by the two display widgets that previously inlined the same formula.

## Why
Profile-feed playback was showing literal "0 loops" for videos whose Funnelcake `loops` field happened to be 0 even though `views > 0`, because the background Nostr enrichment was overwriting `rawTags['views']` with the Nostr event's tags (which never include a `views` key).

## Test plan
- [x] New unit tests for `VideoEvent.hasLoopMetadata` and merge contract of `enrichVideosWithNostrTags`.
- [x] Existing enrichment streaming + widget tests still pass.
- [x] Targeted feed-provider tests (profile pagination, explore refresh retention) still pass.
- [ ] Manual: open a profile video and verify the loop count is non-zero and matches the home feed for the same video.

## Out of scope
A bigger consolidation that pulls the REST → Nostr fallback (and metadata cache) out of the four feed providers into a shared `VideoFeedRepository` is the right long-term answer to "shouldn't profile and home share the player data path?". That refactor is intentionally deferred to a follow-up plan.
EOF
)"
```

- [ ] **Step 7: Worktree cleanup (after PR merges)**

Defer to @superpowers:finishing-a-development-branch — do **not** prune the worktree until the PR is merged.

---

## Follow-ups (intentionally not in this plan)

- Consolidate REST → Nostr fallback + metadata cache into `mobile/packages/videos_repository`. Owners: `PopularNowFeed`, `ProfileFeed`, `PopularVideosFeed`, `VideoFeed`. Touches generated Riverpod code; deserves its own plan.
- Consider deleting the `<4 rawTags` enrichment trigger entirely now that the merge is non-destructive — enrichment could become unconditional (with a budget) and the predicate becomes obsolete. Investigate after this lands.
