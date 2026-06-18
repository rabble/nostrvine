// ABOUTME: Shared CacheSync payload for the offset-paginated profile Videos tab.
// ABOUTME: Captures the resolved scrolled-through window + REST offset cursor so
// ABOUTME: the main author feed renders instantly on reopen, then revalidates.

import 'dart:convert';

import 'package:models/models.dart';
import 'package:openvine/blocs/profile_shared/profile_snapshot_window.dart';

/// A point-in-time snapshot of the offset-paginated profile Videos tab.
///
/// Unlike [ProfileVideoListSnapshot] there is no client-side ID list — the
/// author feed is paginated by an **absolute REST offset** ([nextOffset], the
/// position into the author's newest-first feed for the next page). A `null`
/// offset means the feed is in Nostr-fallback pagination (REST unavailable);
/// load-more then resumes from the oldest restored video's timestamp.
///
/// Holds the resolved videos (unfiltered source — blocklist/content filters are
/// re-applied on every emit) so reopening restores the full scrolled window
/// without a relay round-trip.
class ProfileVideoOffsetSnapshot {
  const ProfileVideoOffsetSnapshot({
    required this.videos,
    required this.nextOffset,
    required this.totalVideoCount,
    required this.hasMoreContent,
  });

  /// Deserializes from a JSON string produced by [toJson].
  factory ProfileVideoOffsetSnapshot.fromJson(String json) {
    final data = jsonDecode(json) as Map<String, dynamic>;
    final videos = (data['videos'] as List<dynamic>? ?? const [])
        .map((e) => VideoEvent.fromJson(e as Map<String, dynamic>))
        .toList();
    return ProfileVideoOffsetSnapshot(
      videos: videos,
      nextOffset: data['nextOffset'] as int?,
      totalVideoCount: data['totalVideoCount'] as int?,
      hasMoreContent: data['hasMoreContent'] as bool? ?? false,
    );
  }

  /// Builds a snapshot capped to [ProfileSnapshotWindow.maxItems].
  ///
  /// Keeps the **head** of the feed (the newest videos the user sees first on
  /// reopen) and clamps [nextOffset] into the kept range so a load-more after
  /// reopen resumes REST pagination at the boundary of the persisted window
  /// rather than skipping the dropped tail. When videos are dropped,
  /// [hasMoreContent] is forced `true`.
  ///
  /// Because the kept window and the REST feed are both newest-first, resuming
  /// at the clamped offset re-fetches (and dedupes) at most the boundary page —
  /// it never leaves a gap. A `null` [nextOffset] (Nostr-fallback) is preserved
  /// and load-more resumes from the oldest restored video's timestamp.
  factory ProfileVideoOffsetSnapshot.capped({
    required List<VideoEvent> videos,
    required int? nextOffset,
    required int? totalVideoCount,
    required bool hasMoreContent,
  }) {
    const max = ProfileSnapshotWindow.maxItems;
    if (videos.length <= max) {
      return ProfileVideoOffsetSnapshot(
        videos: videos,
        nextOffset: nextOffset,
        totalVideoCount: totalVideoCount,
        hasMoreContent: hasMoreContent,
      );
    }
    final keptVideos = videos.sublist(0, max);
    return ProfileVideoOffsetSnapshot(
      videos: keptVideos,
      nextOffset: nextOffset?.clamp(0, keptVideos.length),
      totalVideoCount: totalVideoCount,
      hasMoreContent: true,
    );
  }

  /// The resolved videos, ordered newest-first (unfiltered source).
  final List<VideoEvent> videos;

  /// Absolute REST offset for the next page, or `null` in Nostr-fallback mode.
  final int? nextOffset;

  /// Total videos for this author (from the REST `X-Total-Count` header).
  final int? totalVideoCount;

  /// Whether more videos remain beyond the loaded window.
  final bool hasMoreContent;

  /// Serializes to a JSON string for cache storage.
  String toJson() => jsonEncode({
    'videos': videos.map((v) => v.toJson()).toList(),
    'nextOffset': nextOffset,
    'totalVideoCount': totalVideoCount,
    'hasMoreContent': hasMoreContent,
  });
}
