// ABOUTME: Flutter-free seen-video lookup port used by feed freshness policy.
// ABOUTME: Lets app-layer persistence influence repository ordering.

import 'package:models/models.dart';

/// Default window used to move recently watched For You candidates later.
const Duration defaultRecentlySeenVideoWindow = Duration(hours: 24);

/// Function signature for checking whether a video was seen recently.
typedef WasVideoSeenRecently = bool Function(String videoId, {Duration within});

/// Function signature for waiting until the lookup has loaded persisted state.
typedef InitializeSeenVideoLookup = Future<void> Function();

/// Port for app-layer seen-video persistence.
///
/// The repository package stays Flutter-free; the app injects this with its
/// persisted seen-video service implementation.
class SeenVideoLookup {
  /// Creates a lookup from a recently-seen predicate.
  const SeenVideoLookup({required this.wasSeenRecently, this.initialize});

  /// Returns whether a video ID was seen within the supplied recency window.
  final WasVideoSeenRecently wasSeenRecently;

  /// Loads any persisted seen-video state needed by [wasSeenRecently].
  final InitializeSeenVideoLookup? initialize;

  /// Waits for [initialize] when the app layer provides one.
  Future<void> ensureInitialized() => initialize?.call() ?? Future.value();
}

/// Returns candidates with not-recently-seen videos first.
///
/// Recently seen videos are appended instead of dropped so small candidate
/// pools still produce a feed.
List<VideoEvent> prioritizeNotRecentlySeenVideos(
  Iterable<VideoEvent> videos, {
  SeenVideoLookup? seenVideoLookup,
  Duration recencyWindow = defaultRecentlySeenVideoWindow,
}) {
  final candidates = videos is List<VideoEvent> ? videos : videos.toList();
  if (seenVideoLookup == null || candidates.length < 2) return candidates;

  final notRecentlySeen = <VideoEvent>[];
  final recentlySeen = <VideoEvent>[];

  for (final video in candidates) {
    if (video.id.isNotEmpty &&
        seenVideoLookup.wasSeenRecently(video.id, within: recencyWindow)) {
      recentlySeen.add(video);
    } else {
      notRecentlySeen.add(video);
    }
  }

  if (notRecentlySeen.isEmpty || recentlySeen.isEmpty) return candidates;
  return [...notRecentlySeen, ...recentlySeen];
}
