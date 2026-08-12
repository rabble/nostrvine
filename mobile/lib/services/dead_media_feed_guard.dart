// ABOUTME: Confirms feed media is 404 plus a terminal moderation block before
// ABOUTME: the home feed skips past + persistently prunes it. See #6251.

import 'package:openvine/services/broken_video_tracker.dart';
import 'package:openvine/services/media_availability_checker.dart';
import 'package:openvine/services/video_moderation_status_service.dart';

typedef VideoEventMissingChecker = Future<bool> Function(String videoId);

/// Why a feed item is unavailable, and whether that reason may be persisted.
enum FeedUnavailability {
  none,
  sessionOnly,
  persistent,
}

extension FeedUnavailabilityX on FeedUnavailability {
  bool get shouldRemoveFromSession => this != FeedUnavailability.none;
  bool get shouldPersist => this == FeedUnavailability.persistent;
}

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
///
/// A 404 is only the first gate. Blossom answers 404 for quarantined blobs and
/// for blobs moderation classifies as age-restricted, so a HEAD-confirmed 404
/// is persisted only when the requester-independent moderation status says the
/// blob is `blocked` — the single terminal verdict. Quarantine maps to a
/// reversible RESTRICT (an approval-required uploader's SAFE clip is rewritten
/// to it), so quarantined, age-restricted and unknown states stay recoverable
/// and must not be marked broken. See #6251.
class DeadMediaFeedGuard {
  const DeadMediaFeedGuard({
    required BrokenVideoTracker brokenVideoTracker,
    required VideoModerationStatusService moderationStatusService,
    VideoEventMissingChecker? eventMissingChecker,
    MediaAvailabilityChecker availabilityChecker =
        const MediaAvailabilityChecker(),
  }) : _tracker = brokenVideoTracker,
       _checker = availabilityChecker,
       _eventMissingChecker = eventMissingChecker,
       _moderationStatusService = moderationStatusService;

  final BrokenVideoTracker _tracker;
  final MediaAvailabilityChecker _checker;
  final VideoEventMissingChecker? _eventMissingChecker;
  final VideoModerationStatusService _moderationStatusService;

  /// Classifies why [videoId] is unavailable.
  ///
  /// A canonical API 404 is [FeedUnavailability.sessionOnly]: funnelcake's
  /// by-id filter also 404s reversible states (quarantine, suspension,
  /// vanished, expiry), so it must not persist a tombstone. See #6251.
  ///
  /// [FeedUnavailability.persistent] is only a HEAD-confirmed 404 whose
  /// requester-independent moderation status is `blocked`.
  ///
  /// Returns [FeedUnavailability.none] when [videoUrl] is missing, reachable,
  /// returns any status other than 404, the HEAD request fails, the blob hash
  /// cannot be resolved, the moderation lookup fails, or moderation reports a
  /// reversible verdict (quarantined / age-restricted).
  Future<FeedUnavailability> isConfirmedUnavailable({
    required String videoId,
    required String? videoUrl,
    String? explicitSha256,
  }) async {
    final eventMissingChecker = _eventMissingChecker;
    if (eventMissingChecker != null && videoId.isNotEmpty) {
      try {
        if (await eventMissingChecker(videoId)) {
          return FeedUnavailability.sessionOnly;
        }
      } on Exception {
        // API confirmation is an optional prune signal. Fall through to the
        // media/moderation path and stay conservative if that cannot confirm.
      }
    }

    if (videoUrl == null || videoUrl.isEmpty) return FeedUnavailability.none;
    final missing = await _checker.isConfirmedMissing(videoUrl);
    if (!missing) return FeedUnavailability.none;

    final sha256 = VideoModerationStatusService.resolveSha256(
      explicitSha256: explicitSha256,
      videoUrl: videoUrl,
    );
    if (sha256 == null) return FeedUnavailability.none;

    final status = await _moderationStatusService.fetchStatus(sha256);
    // `blocked` (PERMANENT_BAN) is the only terminal verdict. QUARANTINE maps
    // to blossom RESTRICT: reversible and pending review, so a quarantined
    // blob 404s now but must stay recoverable. See #6251.
    return status?.blocked == true
        ? FeedUnavailability.persistent
        : FeedUnavailability.none;
  }

  /// Returns `true` when the item should leave this session's feed.
  /// Persists [videoId] as broken only for [FeedUnavailability.persistent].
  Future<bool> confirmAndMarkMissing({
    required String videoId,
    required String? videoUrl,
    String? explicitSha256,
  }) async {
    final unavailable = await isConfirmedUnavailable(
      videoId: videoId,
      videoUrl: videoUrl,
      explicitSha256: explicitSha256,
    );
    if (!unavailable.shouldRemoveFromSession) return false;
    if (unavailable.shouldPersist) {
      await _tracker.markVideoBroken(
        videoId,
        'Confirmed moderation-unavailable 404 in home feed',
      );
    }
    return true;
  }
}
