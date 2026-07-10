// ABOUTME: Confirms a feed item's media is a hard 404 and marks it broken so
// ABOUTME: the home feed can skip past + persistently prune it. See #5953.

import 'package:openvine/services/broken_video_tracker.dart';
import 'package:openvine/services/media_availability_checker.dart';

/// Decides whether a feed item whose player failed should be treated as
/// permanently unavailable.
///
/// Imported classic-Vine clips can point at `media.divine.video/<sha256>` blobs
/// that were never stored and return a hard **HTTP 404**. Playback then fails
/// (iOS `COMPOSITION_ERROR` → `notFound`; Android `PLAYER_ERROR "Source error"`
/// → `generic`), but the home scrolling feed neither skips nor prunes them —
/// unlike the fullscreen feed, which HEAD-confirms the 404 and marks it broken.
///
/// This guard lifts that "confirm → mark" contract into a layer below the
/// widget so the home feed can reuse it. Detection is a deterministic HEAD 404
/// via [MediaAvailabilityChecker] — NOT the playback error string, which is
/// platform-divergent (see #5953 findings).
class DeadMediaFeedGuard {
  const DeadMediaFeedGuard({
    required BrokenVideoTracker brokenVideoTracker,
    MediaAvailabilityChecker availabilityChecker =
        const MediaAvailabilityChecker(),
  }) : _tracker = brokenVideoTracker,
       _checker = availabilityChecker;

  final BrokenVideoTracker _tracker;
  final MediaAvailabilityChecker _checker;

  /// Returns `true` iff [videoUrl] is a HEAD-confirmed hard 404, in which case
  /// [videoId] is persisted as broken so [BrokenVideoTracker.isVideoBroken]
  /// (and therefore `filterVideoList`) drops it from every list surface across
  /// restarts.
  ///
  /// Returns `false` when [videoUrl] is missing, reachable, returns any status
  /// other than 404, or the HEAD request fails with a network error — the
  /// caller must then treat the failure as transient and keep the item. This
  /// conservative gate is what prevents a one-off network flake from evicting a
  /// valid video.
  Future<bool> confirmAndMarkMissing({
    required String videoId,
    required String? videoUrl,
  }) async {
    if (videoUrl == null || videoUrl.isEmpty) return false;
    final missing = await _checker.isConfirmedMissing(videoUrl);
    if (!missing) return false;
    await _tracker.markVideoBroken(
      videoId,
      'Confirmed 404 in home feed',
    );
    return true;
  }
}
