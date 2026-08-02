// ABOUTME: Classifies a failed feed item's media so the feed can skip past it,
// ABOUTME: and prunes only genuinely unretrievable media. See #5953.

import 'package:openvine/services/broken_video_tracker.dart';
import 'package:openvine/services/media_availability_checker.dart';

/// What the feed should do with an item whose player failed.
enum DeadMediaVerdict {
  /// Media is retrievable, or the failure looks transient. Keep the item and
  /// leave today's retry behaviour alone.
  keep,

  /// Media is a HEAD-confirmed hard 404. Skip past it and prune it persistently.
  skipAndPrune,

  /// Media requires authentication (blossom's 401 age gate). Skip past it so the
  /// user is not parked on a dead player, but do **not** prune — an
  /// authenticated request can succeed, and pruning would hide a video the
  /// viewer is entitled to watch.
  skipOnly,
}

/// Decides how a feed item whose player failed should be treated.
///
/// Playback failures are platform-divergent (iOS `COMPOSITION_ERROR` →
/// `notFound`; Android `PLAYER_ERROR "Source error"` → `generic`), so detection
/// is a deterministic HEAD classification via [MediaAvailabilityChecker] rather
/// than the player's error string.
///
/// The 404/401 split is load-bearing. Divine's media host returns 404 for
/// banned, deleted and restricted blobs *and* for genuinely absent ones, but
/// **401** for age-restricted blobs, which play fine once the request is
/// authenticated. Treating those alike would prune viewable content for the
/// [BrokenVideoTracker]'s full TTL across every surface that consults it.
class DeadMediaFeedGuard {
  const DeadMediaFeedGuard({
    required BrokenVideoTracker brokenVideoTracker,
    MediaAvailabilityChecker availabilityChecker =
        const MediaAvailabilityChecker(),
  }) : _tracker = brokenVideoTracker,
       _checker = availabilityChecker;

  final BrokenVideoTracker _tracker;
  final MediaAvailabilityChecker _checker;

  /// Classifies [videoUrl], persisting [videoId] as broken only for a
  /// HEAD-confirmed hard 404.
  ///
  /// Returns [DeadMediaVerdict.keep] when the URL is missing, reachable, or the
  /// HEAD request fails with a network error — this conservative gate is what
  /// prevents a one-off flake from evicting a valid video.
  Future<DeadMediaVerdict> classify({
    required String videoId,
    required String? videoUrl,
  }) async {
    if (videoUrl == null || videoUrl.isEmpty) return DeadMediaVerdict.keep;

    switch (await _checker.check(videoUrl)) {
      case MediaAvailability.missing:
        await _tracker.markVideoBroken(videoId, 'Confirmed 404 in home feed');
        return DeadMediaVerdict.skipAndPrune;
      case MediaAvailability.authRequired:
        return DeadMediaVerdict.skipOnly;
      case MediaAvailability.available:
      case MediaAvailability.unknown:
        return DeadMediaVerdict.keep;
    }
  }

  /// Whether the feed should advance past this item.
  ///
  /// `true` for both a confirmed 404 and the 401 age gate — in either case the
  /// user cannot play the item anonymously, so parking on it helps no one. Only
  /// the 404 case also prunes.
  Future<bool> confirmAndMarkMissing({
    required String videoId,
    required String? videoUrl,
  }) async {
    final verdict = await classify(videoId: videoId, videoUrl: videoUrl);
    return verdict != DeadMediaVerdict.keep;
  }
}
