// ABOUTME: Stateless helper that fetches REST-side loop counts / view stats
// ABOUTME: for one or more VideoEvents via the Funnelcake bulk-stats API.

import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:models/models.dart';
import 'package:unified_logger/unified_logger.dart';

/// Fetches loop counts and view stats from the Funnelcake REST API and merges
/// them into [VideoEvent] instances.
///
/// This fills the gap that exists on the deep-link and notification-tap code
/// paths: those paths fetch the raw Nostr event but skip the secondary
/// hydration step that the profile and home feed providers perform via
/// `POST /api/videos/stats/bulk`.
abstract class VideoStatsHydrationService {
  /// Hydrates [video] with REST-side stats and returns the enriched copy, or
  /// `null` if the API returned no stats entry for the given event ID.
  ///
  /// Any network error is propagated to the caller, which is responsible for
  /// logging and graceful degradation.
  static Future<VideoEvent?> hydrateVideo(
    VideoEvent video, {
    required FunnelcakeApiClient client,
  }) async {
    if (video.id.isEmpty) return null;

    Log.debug(
      'Hydrating stats for video ${video.id}',
      name: 'VideoStatsHydrationService',
      category: LogCategory.video,
    );

    final response = await client.getBulkVideoStats([video.id]);
    final stats = response.stats[video.id];

    if (stats == null) return null;

    final mergedTags = <String, String>{...video.rawTags};
    if (stats.loops != null) {
      mergedTags['loops'] = stats.loops!.toString();
    }
    if (stats.views != null) {
      mergedTags['views'] = stats.views!.toString();
    }

    return video.copyWith(
      rawTags: mergedTags,
      originalLoops: stats.loops ?? video.originalLoops,
    );
  }

  /// Hydrates [videos] with REST-side stats in bulk and returns enriched
  /// copies in the same order as the input list.
  ///
  /// Videos for which the API returned no entry are returned unchanged.
  static Future<List<VideoEvent>> hydrateVideos(
    List<VideoEvent> videos, {
    required FunnelcakeApiClient client,
  }) async {
    final ids = videos.map((v) => v.id).where((id) => id.isNotEmpty).toList();
    if (ids.isEmpty) return videos;

    Log.debug(
      'Hydrating stats for ${ids.length} video(s)',
      name: 'VideoStatsHydrationService',
      category: LogCategory.video,
    );

    final response = await client.getBulkVideoStats(ids);

    if (response.stats.isEmpty) return videos;

    final hydrated = videos.map((video) {
      final stats = response.stats[video.id];
      if (stats == null) return video;

      final mergedTags = <String, String>{...video.rawTags};
      if (stats.loops != null) {
        mergedTags['loops'] = stats.loops!.toString();
      }
      if (stats.views != null) {
        mergedTags['views'] = stats.views!.toString();
      }

      return video.copyWith(
        rawTags: mergedTags,
        originalLoops: stats.loops ?? video.originalLoops,
      );
    }).toList();

    Log.debug(
      'Stats hydration complete for ${ids.length} video(s)',
      name: 'VideoStatsHydrationService',
      category: LogCategory.video,
    );

    return hydrated;
  }
}
