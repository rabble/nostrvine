// ABOUTME: Shared CacheSync payload for cursor-paginated profile video tabs.
// ABOUTME: Captures the loaded videos + relay cursor so a server-feed tab
// ABOUTME: (Collabs, …) renders instantly on reopen.

import 'dart:convert';

import 'package:models/models.dart';

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
