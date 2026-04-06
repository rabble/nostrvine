# Moderated Content Filtering — Fix Design

## Problem

When the relay serves moderated content (age-restricted or removed), the app shows video metadata — author, title, description, like/comment/share buttons — but the video player is broken. No content warning overlay appears, no NIP-98 auth is attempted, and there is no mechanism to skip the video.

## Root Causes

The content-filtering infrastructure already exists at the repository layer. `VideosRepository` accepts a `VideoContentFilter` and `VideoWarningLabelsResolver`, both of which are wired up via `createNsfwFilter` / `createNsfwWarnLabels` in `app_providers.dart`. The repository calls `_applyContentPreferences` on both the Funnelcake REST path (`_transformVideoStats`) and the Nostr relay path (`_transformAndFilter`). This pipeline works correctly for freshly fetched videos with *recognized* labels.

Investigation revealed three specific gaps that let moderated content reach the UI:

**1. `HomeFeedCache` bypasses the content-filter pipeline.**
`HomeFeedCache._parse()` in `lib/blocs/video_feed/home_feed_cache.dart:66` converts cached `VideoStats → VideoEvent` by calling `toVideoEvent()` directly. It never touches `VideosRepository._applyContentPreferences()`. On cold startup, `VideoFeedBloc._loadVideos()` (line 436) reads the cache and emits the result unfiltered. Cached NSFW videos show with no warn overlay and no hide filtering, until the fresh network response arrives and replaces them.

**2. Unrecognized moderation labels are silently dropped.**
`_normalizeModerationLabel()` in `packages/models/lib/src/video_stats.dart:511` compares against a hardcoded `_recognizedModerationLabels` set (19 entries). Any label outside that set — e.g. `"sexual content"` (with a space), `"adult"`, `"restricted"`, new labels added server-side — returns `null` and is discarded in `_parseModerationLabels`. A video whose only signal was an unknown label arrives at the UI with `moderationLabels: []` and passes through the filter as if unmoderated.

**3. No fallback when videos fail with 401/403 but weren't pre-filtered.**
When a video slips past the content filter (missing labels, unknown labels, race conditions) but the Blossom media server returns 401/403, `PooledVideoErrorOverlay` renders a small icon and a "Content restricted" or "Age-restricted content" message inside the player area. The metadata overlay (`FeedVideoOverlay`) continues to render author info, description, and action buttons on top of that broken player. The user sees a mostly-normal video card with an error icon where the video should be. There is no auto-advance, no blur overlay, and no NIP-98 auth prompt for age-restricted content.

## Goals

- Cached home feed entries are filtered the same way fresh ones are.
- Unknown server-side moderation labels default to a safe behavior rather than being silently dropped.
- Videos that fail to load due to 401/403 present a coherent UX — either skipped, or shown with a full-screen warning rather than a half-broken player card.
- Follow the BLoC architecture: filtering logic stays in the repository layer, BLoCs compose it, UI only renders state.

## Non-Goals

- Implementing NIP-42 relay authentication for protected subscriptions.
- Implementing relay CLOSED message handling with restriction codes.
- Reworking `ContentFilterService` / `ModerationLabelService` initialization.
- Adding a new content-warning taxonomy. The fix uses the existing `ContentFilterPreference` (show/warn/hide) and existing `ContentLabel` enum.

## Design

The fix has three parts, each addressing one gap. All work stays on the BLoC/repository side of the architecture — no new Riverpod surface.

### Part A — Filter cached videos through the repository

Add a public method on `VideosRepository` that re-applies the existing `_applyContentPreferences` pipeline to a list of already-parsed `VideoEvent`s:

```dart
// packages/videos_repository/lib/src/videos_repository.dart
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

In `VideoFeedBloc._loadVideos()`, run cached videos through this method before emitting:

```dart
// lib/blocs/video_feed/video_feed_bloc.dart (~line 438)
final cached = _homeFeedCache.read(_sharedPreferences);
if (cached != null) {
  final filtered = _videosRepository.applyContentPreferences(cached.videos);
  final cachedValid = filtered.where((v) => v.videoUrl != null).toList();
  // ...
}
```

**Why this location:** The BLoC already owns cache-read + emission logic. The repository owns filtering logic. Adding a pass-through method on the repository keeps the existing boundary intact. The alternative — moving `_parse` into the repository — would drag `HomeFeedCache` (which currently lives in `lib/blocs/video_feed/`) into the `videos_repository` package, creating a new cross-package dependency for no real gain.

**Testing:** `blocTest` with a mock `VideosRepository` verifying that cached videos pass through `applyContentPreferences` before being emitted. Existing `HomeFeedCache` tests stay as-is.

### Part B — Pass through unknown moderation labels conservatively

Change `_normalizeModerationLabel` to return the normalized string for any non-empty value rather than gating on a hardcoded recognized set. The alias mapping (`pornography → porn`, `nsfw → nudity`, etc.) stays; the final drop-unknown case goes away:

```dart
// packages/models/lib/src/video_stats.dart
String? _normalizeModerationLabel(String value) {
  if (value.isEmpty) return null;
  final normalized = value.toLowerCase().replaceAll('_', '-').replaceAll(' ', '-');
  switch (normalized) {
    case 'pornography':
    case 'explicit':
      return 'porn';
    // ...existing aliases...
  }
  return normalized; // was: _recognizedModerationLabels.contains(...) ? ... : null
}
```

Also normalize whitespace to hyphens so `"sexual content"` becomes `"sexual-content"` instead of being dropped.

Then, in `createNsfwFilter` / `createNsfwWarnLabels` (`lib/services/nsfw_content_filter.dart`), treat any moderation label that doesn't map to a known `ContentLabel` as a conservative hide signal when the user has default preferences, using the existing `ContentFilterService.getPreferenceForLabels` escape hatch:

```dart
// Unknown labels from the server are an implicit "something flagged this".
// Default behavior: hide. Users who want to see everything can change their
// filter preferences per-category.
final hasUnknownModerationSignal = modLabels
    .any((l) => ContentLabel.fromValue(l) == null);
if (hasUnknownModerationSignal) return true;
```

**Why conservative default:** The relay applies labels for a reason. Dropping unknown labels silently is the worst possible failure mode because it defeats the safety system without telling anyone. Hiding is recoverable (user can adjust), whereas showing unmoderated content is not.

**Testing:** Unit tests on `VideoStats._normalizeModerationLabel` for whitespace and unknown-value cases. Unit tests on `createNsfwFilter` verifying unknown labels trigger hide.

### Part C — Handle playback failure in the feed

When the pooled video player reports `VideoErrorType.forbidden` or `VideoErrorType.ageRestricted` for a video that reached the feed (i.e. wasn't caught by Parts A/B), the UI needs to present a coherent state instead of a broken player with full metadata overlay on top.

This is a BLoC concern, not a widget concern: the feed-level state should know which items have failed and react accordingly. Add a lightweight `VideoPlaybackStatusCubit` keyed by event ID that tracks `{playing, ageRestricted, forbidden, notFound, generic}` per video. The pooled player's error stream (already classified by `VideoFeedController._classifyError`) feeds into it.

The `FeedVideoOverlay` then uses `context.select` on the cubit for the current video ID:

```dart
final status = context.select(
  (VideoPlaybackStatusCubit cubit) => cubit.state.statusFor(video.id),
);

if (status == PlaybackStatus.forbidden ||
    status == PlaybackStatus.ageRestricted) {
  return _ModeratedContentOverlay(
    video: video,
    status: status,
    onDismiss: _advanceToNext,
  );
}
```

`_ModeratedContentOverlay` is a new full-screen overlay that:
- Shows a shield/lock icon and a clear explanation ("This video was restricted by the relay" / "This video requires age verification").
- Hides the author info, description, and interaction buttons (no likes/comments/shares on content the user cannot watch).
- For `ageRestricted`, shows a "Verify age" button that triggers the existing `MediaAuthInterceptor` flow.
- For `forbidden`, shows a "Skip" button that advances `PooledVideoFeedController` to the next video.

**Why not auto-skip:** Silent skipping breaks the user's mental model ("did I scroll?") and makes debugging impossible. A single tap to skip is low friction and preserves observability.

**Why a new cubit instead of extending `VideoFeedBloc`:** Per the state-management rules, BLoCs should have a single responsibility. `VideoFeedBloc` owns "which videos are in the feed and in what order." Playback status is a different axis — per-item, frequently changing, scoped to the active viewport. Mixing it into `VideoFeedBloc` state would cause feed-wide rebuilds on per-video status changes.

**Testing:** `blocTest` on `VideoPlaybackStatusCubit` for status transitions. Widget tests on `_ModeratedContentOverlay` for each status variant. Integration test in `integration_test/` covering: feed loads → video fails with 403 → overlay appears → skip button advances.

## Architecture Diagram

```
Funnelcake API / Nostr Relay
    │
    ▼
VideosRepository
    ├─ _transformVideoStats / _transformAndFilter
    ├─ _applyContentPreferences  ← filters + sets warnLabels
    └─ applyContentPreferences (NEW, Part A)  ← used for cached videos
         │
         ▼
VideoFeedBloc
    ├─ _loadVideos (filters cache via repo)  ← Part A
    └─ emits state.videos
         │
         ▼
UI (PooledVideoFeed)
    ├─ FeedVideoOverlay
    │   └─ watches ContentWarningBlurOverlay (warn labels)
    │   └─ watches VideoPlaybackStatusCubit  ← Part C
    │       └─ _ModeratedContentOverlay (403/401)
    └─ PooledVideoPlayer
         └─ error stream → VideoPlaybackStatusCubit  ← Part C
```

## Risks & Mitigations

**Risk:** Part B could cause false positives, hiding legitimate videos if the relay starts emitting noisy labels.
**Mitigation:** Log every unknown label at `Log.debug` level with the event ID so we can see what's showing up in the wild. If noise becomes a problem, we add explicit allowlist entries for labels that should *not* trigger hide (e.g. discovery tags like `topic:music`).

**Risk:** Part C's cubit tracks state per event ID indefinitely and could leak memory on long sessions.
**Mitigation:** The cubit keeps an LRU cache of the last N (e.g. 100) statuses — more than enough for any visible viewport, but bounded. Clear on feed-mode change.

**Risk:** Part A introduces a second pass over the video list on cold startup, adding CPU work.
**Mitigation:** The filter is O(n) over a small cached list (≤ one page). No network, no async. Negligible.

## Out of Scope (for this fix; may need follow-up)

- **Relay-level NIP-42 auth** for protected subscriptions. The relay currently returns public events with labels; when that changes, we need CLOSED message parsing and auth flow. Tracked separately.
- **Server-side content filter negotiation.** Ideally the client tells the server "hide this category" via `moderation_profile` and gets a pre-filtered response. That's a relay API change, not a mobile fix.
- **Moderation label taxonomy cleanup.** The hardcoded `_recognizedModerationLabels` set will still drift from whatever the relay emits. Long-term we want the relay docs to publish a canonical list and the client to consume it at build time.

## Files Touched

| File | Change |
|------|--------|
| `packages/videos_repository/lib/src/videos_repository.dart` | Add `applyContentPreferences(List<VideoEvent>)` method |
| `packages/videos_repository/test/videos_repository_test.dart` | Test new method |
| `packages/models/lib/src/video_stats.dart` | Pass through unknown moderation labels; normalize whitespace |
| `packages/models/test/src/video_stats_test.dart` | Test unknown-label pass-through |
| `lib/services/nsfw_content_filter.dart` | Treat unknown labels as conservative hide |
| `test/services/nsfw_content_filter_test.dart` | Test unknown-label hide |
| `lib/blocs/video_feed/video_feed_bloc.dart` | Filter cached videos via repository |
| `test/blocs/video_feed/video_feed_bloc_test.dart` | Test cache filtering |
| `lib/blocs/video_playback_status/video_playback_status_cubit.dart` | NEW: per-video playback status cubit |
| `lib/blocs/video_playback_status/video_playback_status_state.dart` | NEW: state |
| `test/blocs/video_playback_status/video_playback_status_cubit_test.dart` | NEW: tests |
| `lib/widgets/video_feed_item/moderated_content_overlay.dart` | NEW: full-screen overlay for 401/403 |
| `test/widgets/video_feed_item/moderated_content_overlay_test.dart` | NEW: widget tests |
| `lib/screens/feed/feed_video_overlay.dart` | Swap in `_ModeratedContentOverlay` when status is restricted |
| `lib/screens/feed/pooled_fullscreen_video_feed_screen.dart` | Same, for fullscreen feed |
| `lib/screens/feed/video_feed_page.dart` | Provide `VideoPlaybackStatusCubit` |
| `integration_test/moderated_content_test.dart` | NEW: end-to-end |

## Follow-ups (captured during implementation)

- **Namespacing for non-safety ML labels.** Task B2 makes every unknown
  `video.moderationLabels` entry a hide signal. This is correct for safety
  labels but will force-hide videos if the server ever emits
  discovery/taxonomy labels (e.g. `topic:music`, `lang:en`) in the same
  field. Before shipping any such label, coordinate with Funnelcake to
  either split the fields or adopt a namespace prefix convention the
  client can allowlist.

- **Label string sanity bounds.** `VideoStats._normalizeModerationLabel`
  (Task B1) now passes unknown label strings through verbatim. A misbehaving
  or compromised relay could inject pathological labels (very long, control
  characters, etc.). Current behavior is defense-by-conservative-hide,
  which is safe, but a length cap and printable-character filter would be
  good defense in depth.
