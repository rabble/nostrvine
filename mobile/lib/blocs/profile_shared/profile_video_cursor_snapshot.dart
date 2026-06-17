// ABOUTME: Shared CacheSync payload for cursor-paginated profile video tabs.
// ABOUTME: Captures the loaded videos + relay cursor so a server-feed tab
// ABOUTME: (Collabs, …) renders instantly on reopen.

import 'dart:convert';

import 'package:models/models.dart';
import 'package:openvine/blocs/profile_shared/profile_snapshot_window.dart';

/// A point-in-time snapshot of a cursor-paginated profile video tab.
///
/// Unlike [ProfileVideoListSnapshot] there is no client-side ID list — the
/// feed is ordered and paginated by the server via [paginationCursor] (a Unix
/// timestamp used as the relay `until` bound).
class ProfileVideoCursorSnapshot {
  const ProfileVideoCursorSnapshot({
    required this.videos,
    required this.paginationCursor,
    required this.hasMoreContent,
  });

  /// Deserializes from a JSON string produced by [toJson].
  factory ProfileVideoCursorSnapshot.fromJson(String json) {
    final data = jsonDecode(json) as Map<String, dynamic>;
    final videos = (data['videos'] as List<dynamic>? ?? const [])
        .map((e) => VideoEvent.fromJson(e as Map<String, dynamic>))
        .toList();
    return ProfileVideoCursorSnapshot(
      videos: videos,
      paginationCursor: data['paginationCursor'] as int?,
      hasMoreContent: data['hasMoreContent'] as bool? ?? false,
    );
  }

  /// Builds a snapshot capped to [ProfileSnapshotWindow.maxItems].
  ///
  /// Keeps the head of the feed and re-anchors [paginationCursor] to the last
  /// kept video's timestamp so a load-more after reopen continues right after
  /// the persisted window rather than skipping the dropped tail. [hasMoreContent]
  /// is forced `true` whenever videos were dropped.
  factory ProfileVideoCursorSnapshot.capped({
    required List<VideoEvent> videos,
    required int? paginationCursor,
    required bool hasMoreContent,
  }) {
    const max = ProfileSnapshotWindow.maxItems;
    if (videos.length <= max) {
      return ProfileVideoCursorSnapshot(
        videos: videos,
        paginationCursor: paginationCursor,
        hasMoreContent: hasMoreContent,
      );
    }
    final keptVideos = videos.sublist(0, max);
    return ProfileVideoCursorSnapshot(
      videos: keptVideos,
      paginationCursor: keptVideos.last.createdAt,
      hasMoreContent: true,
    );
  }

  /// The loaded videos, in feed order.
  final List<VideoEvent> videos;

  /// Unix timestamp cursor for the next `until` page, or `null` at the end.
  final int? paginationCursor;

  /// Whether more videos remain beyond the loaded set.
  final bool hasMoreContent;

  /// Serializes to a JSON string for cache storage.
  String toJson() => jsonEncode({
    'videos': videos.map((v) => v.toJson()).toList(),
    'paginationCursor': paginationCursor,
    'hasMoreContent': hasMoreContent,
  });
}
