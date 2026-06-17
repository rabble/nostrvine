// ABOUTME: Shared CacheSync payload for ID-list-backed profile video tabs.
// ABOUTME: Captures the resolved scrolled-through window so a tab (Liked,
// ABOUTME: Reposts, Saved, …) renders instantly on reopen.

import 'dart:convert';

import 'package:models/models.dart';
import 'package:openvine/blocs/profile_shared/profile_snapshot_window.dart';

/// A point-in-time snapshot of an ID-list-backed profile video tab.
///
/// Serialized into `CacheSync` so reopening the tab restores the full
/// scrolled-through list of videos instantly, then revalidates in the
/// background. Holds the full ordered [itemIds] (cheap strings — liked event
/// IDs, reposted addressable IDs, bookmark IDs, …) so pagination and
/// reconciliation can resume without a fresh relay fetch.
class ProfileVideoListSnapshot {
  const ProfileVideoListSnapshot({
    required this.videos,
    required this.itemIds,
    required this.nextPageOffset,
    required this.hasMoreContent,
  });

  /// Deserializes from a JSON string produced by [toJson].
  factory ProfileVideoListSnapshot.fromJson(String json) {
    final data = jsonDecode(json) as Map<String, dynamic>;
    final videos = (data['videos'] as List<dynamic>? ?? const [])
        .map((e) => VideoEvent.fromJson(e as Map<String, dynamic>))
        .toList();
    final itemIds = (data['itemIds'] as List<dynamic>? ?? const [])
        .cast<String>();
    return ProfileVideoListSnapshot(
      videos: videos,
      itemIds: itemIds,
      nextPageOffset: data['nextPageOffset'] as int? ?? videos.length,
      hasMoreContent: data['hasMoreContent'] as bool? ?? false,
    );
  }

  /// Builds a snapshot capped to [ProfileSnapshotWindow.maxItems].
  ///
  /// Keeps the **head** of both lists (the most-recent items the user sees
  /// first on reopen) and clamps [nextPageOffset] into the kept ID range.
  /// When anything is dropped, [hasMoreContent] is forced `true` so pagination
  /// (which re-resolves the full ID list via the reopen revalidation) knows
  /// there is more beyond the persisted window.
  factory ProfileVideoListSnapshot.capped({
    required List<VideoEvent> videos,
    required List<String> itemIds,
    required int nextPageOffset,
    required bool hasMoreContent,
  }) {
    const max = ProfileSnapshotWindow.maxItems;
    if (videos.length <= max && itemIds.length <= max) {
      return ProfileVideoListSnapshot(
        videos: videos,
        itemIds: itemIds,
        nextPageOffset: nextPageOffset,
        hasMoreContent: hasMoreContent,
      );
    }
    final keptVideos = videos.length > max ? videos.sublist(0, max) : videos;
    final keptIds = itemIds.length > max ? itemIds.sublist(0, max) : itemIds;
    return ProfileVideoListSnapshot(
      videos: keptVideos,
      itemIds: keptIds,
      nextPageOffset: nextPageOffset.clamp(0, keptIds.length),
      hasMoreContent:
          hasMoreContent || videos.length > max || itemIds.length > max,
    );
  }

  /// The resolved videos, ordered most-recent-first.
  final List<VideoEvent> videos;

  /// The full ordered list of item IDs (drives pagination + reconciliation).
  final List<String> itemIds;

  /// Offset into [itemIds] for the next page fetch.
  final int nextPageOffset;

  /// Whether more items remain beyond [nextPageOffset].
  final bool hasMoreContent;

  /// Serializes to a JSON string for cache storage.
  String toJson() => jsonEncode({
    'videos': videos.map((v) => v.toJson()).toList(),
    'itemIds': itemIds,
    'nextPageOffset': nextPageOffset,
    'hasMoreContent': hasMoreContent,
  });
}
