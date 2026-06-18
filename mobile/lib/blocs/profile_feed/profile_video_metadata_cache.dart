// ABOUTME: Engagement-count backfill cache for the profile/author feed.
// ABOUTME: Holds REST-sourced metadata (loops, views, likes, …) so Nostr-only
// ABOUTME: videos on the load-more fallback path keep their counts.

import 'package:models/models.dart';

/// Backfill cache for engagement counts, used on the Nostr-fallback loadMore
/// branch where there is no REST hydration.
class ProfileVideoMetadataCache {
  final Map<String, _MetadataEntry> _entries = {};

  /// Records the engagement metadata of any [videos] that carry it, keyed by
  /// lowercased event id.
  void cache(List<VideoEvent> videos) {
    for (final video in videos) {
      if (video.originalLoops != null ||
          video.rawTags['views'] != null ||
          video.originalLikes != null ||
          video.originalComments != null ||
          video.originalReposts != null ||
          video.nostrLikeCount != null) {
        _entries[video.id.toLowerCase()] = _MetadataEntry(
          originalLoops: video.originalLoops,
          views: video.rawTags['views'],
          originalLikes: video.originalLikes,
          originalComments: video.originalComments,
          originalReposts: video.originalReposts,
          nostrLikeCount: video.nostrLikeCount,
        );
      }
    }
  }

  /// Backfills missing engagement counts on [videos] from prior hydration,
  /// leaving any field that already has a value untouched.
  List<VideoEvent> apply(List<VideoEvent> videos) {
    return videos.map((video) {
      final cached = _entries[video.id.toLowerCase()];
      if (cached == null) return video;
      final currentViews = video.rawTags['views'];
      final shouldApply =
          (video.originalLoops == null && cached.originalLoops != null) ||
          (currentViews == null && cached.views != null) ||
          (video.originalLikes == null && cached.originalLikes != null) ||
          (video.originalComments == null && cached.originalComments != null) ||
          (video.originalReposts == null && cached.originalReposts != null) ||
          (video.nostrLikeCount == null && cached.nostrLikeCount != null);
      if (!shouldApply) return video;
      return video.copyWith(
        originalLoops: video.originalLoops ?? cached.originalLoops,
        rawTags: currentViews == null && cached.views != null
            ? {...video.rawTags, 'views': cached.views!}
            : video.rawTags,
        originalLikes: video.originalLikes ?? cached.originalLikes,
        originalComments: video.originalComments ?? cached.originalComments,
        originalReposts: video.originalReposts ?? cached.originalReposts,
        nostrLikeCount: video.nostrLikeCount ?? cached.nostrLikeCount,
      );
    }).toList();
  }
}

/// Cached engagement metadata used to backfill Nostr-only videos.
class _MetadataEntry {
  const _MetadataEntry({
    this.originalLoops,
    this.views,
    this.originalLikes,
    this.originalComments,
    this.originalReposts,
    this.nostrLikeCount,
  });

  final int? originalLoops;
  final String? views;
  final int? originalLikes;
  final int? originalComments;
  final int? originalReposts;
  final int? nostrLikeCount;
}
