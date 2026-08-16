// ABOUTME: Typed repository and diagnostics for creator analytics data loading.
// ABOUTME: Normalizes Funnelcake responses and tracks metric provenance.

import 'dart:math' as math;

import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:models/models.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:videos_repository/videos_repository.dart';

/// Provenance source for analytics values.
enum AnalyticsDataSource {
  authorVideos,
  bulkVideoStats,
  videoViewsEndpoint,
  socialCounts,
}

/// Diagnostics to explain data quality and endpoint contribution.
class CreatorAnalyticsDiagnostics {
  const CreatorAnalyticsDiagnostics({
    required this.totalVideos,
    required this.videosWithAnyViews,
    required this.videosMissingViews,
    required this.videosHydratedByBulkStats,
    required this.videosHydratedByViewsEndpoint,
    required this.sourcesUsed,
    required this.fetchedAt,
    this.failedSources = const {},
    this.videoCatalogTruncated = false,
  });

  final int totalVideos;
  final int videosWithAnyViews;
  final int videosMissingViews;
  final int videosHydratedByBulkStats;
  final int videosHydratedByViewsEndpoint;
  final Set<AnalyticsDataSource> sourcesUsed;
  final Set<AnalyticsDataSource> failedSources;
  final DateTime fetchedAt;
  final bool videoCatalogTruncated;

  bool get hasAnyViewData => videosWithAnyViews > 0;
}

/// Final creator analytics payload returned to UI.
class CreatorAnalyticsSnapshot {
  const CreatorAnalyticsSnapshot({
    required this.videos,
    required this.socialCounts,
    required this.diagnostics,
  });

  final List<VideoEvent> videos;
  final SocialCounts? socialCounts;
  final CreatorAnalyticsDiagnostics diagnostics;
}

/// Repository used by creator analytics screens.
abstract class CreatorAnalyticsRepository {
  Future<CreatorAnalyticsSnapshot> fetchCreatorAnalytics(String pubkey);
}

/// Funnelcake-backed implementation with layered fallbacks.
///
/// Social counts are cached per-pubkey for [socialCountsCacheDuration]
/// (default 5 min) to avoid redundant requests when the analytics screen
/// is reopened within a short period.
class FunnelcakeCreatorAnalyticsRepository
    implements CreatorAnalyticsRepository {
  FunnelcakeCreatorAnalyticsRepository(
    this._client, {
    Duration socialCountsCacheDuration = const Duration(minutes: 5),
  }) : _socialCountsCacheDuration = socialCountsCacheDuration;

  final FunnelcakeApiClient _client;
  final Duration _socialCountsCacheDuration;

  final _socialCountsCache = <String, SocialCounts?>{};
  final _socialCountsCachedAt = <String, DateTime>{};

  bool _isSocialCountsCacheValid(String pubkey) {
    final cachedAt = _socialCountsCachedAt[pubkey];
    return cachedAt != null &&
        DateTime.now().difference(cachedAt) < _socialCountsCacheDuration;
  }

  Future<SocialCounts?> _getSocialCounts(String pubkey) async {
    if (_isSocialCountsCacheValid(pubkey)) {
      return _socialCountsCache[pubkey];
    }
    final result = await _client.getSocialCounts(pubkey);
    _socialCountsCache[pubkey] = result;
    _socialCountsCachedAt[pubkey] = DateTime.now();
    return result;
  }

  @override
  Future<CreatorAnalyticsSnapshot> fetchCreatorAnalytics(String pubkey) async {
    if (!_client.isAvailable) {
      throw const FunnelcakeNotConfiguredException();
    }
    if (pubkey.isEmpty) {
      throw const FunnelcakeException('Pubkey cannot be empty');
    }

    final sourcesUsed = <AnalyticsDataSource>{};
    final failedSources = <AnalyticsDataSource>{};

    final socialFuture = _getSocialCountsTolerant(pubkey, failedSources);
    final authorResult = await _fetchAuthorVideos(pubkey);
    if (authorResult.videos.isNotEmpty) {
      sourcesUsed.add(AnalyticsDataSource.authorVideos);
    }

    final bulkResult = await _enrichVideosWithBulkStatsTolerant(
      authorResult.videos,
      failedSources,
    );
    var hydratedVideos = bulkResult.videos;
    if (bulkResult.hydratedCount > 0) {
      sourcesUsed.add(AnalyticsDataSource.bulkVideoStats);
    }

    final endpointResult = await _hydrateVideoViewsTolerant(
      hydratedVideos,
      failedSources,
    );
    hydratedVideos = endpointResult.videos;
    if (endpointResult.hydratedCount > 0) {
      sourcesUsed.add(AnalyticsDataSource.videoViewsEndpoint);
    }

    // Collapse edited addressable videos AFTER hydration so the cross-source
    // max-merge sees each edit sibling's hydrated counts — matching the profile
    // feed's getAuthorFeed (hydrate-then-merge). Collapsing first would fetch
    // stats only for the surviving event id and drop older edits' counts.
    final videos = mergeProfileFeedVideoLists(const [], hydratedVideos);

    final social = await socialFuture;
    if (social != null) {
      sourcesUsed.add(AnalyticsDataSource.socialCounts);
    }
    final withViewData = videos
        .where((video) => extractViewLikeCount(video) != null)
        .length;

    return CreatorAnalyticsSnapshot(
      videos: videos,
      socialCounts: social,
      diagnostics: CreatorAnalyticsDiagnostics(
        totalVideos: videos.length,
        videosWithAnyViews: withViewData,
        videosMissingViews: videos.length - withViewData,
        videosHydratedByBulkStats: bulkResult.hydratedCount,
        videosHydratedByViewsEndpoint: endpointResult.hydratedCount,
        sourcesUsed: sourcesUsed,
        failedSources: failedSources,
        fetchedAt: DateTime.now(),
        videoCatalogTruncated: authorResult.truncated,
      ),
    );
  }

  Future<_AuthorVideosResult> _fetchAuthorVideos(
    String pubkey, {
    int maxPages = 4,
    int pageSize = 100,
  }) async {
    final collected = <VideoEvent>[];
    int? before;
    var truncated = false;

    for (var page = 0; page < maxPages; page++) {
      final result = await _client.getVideosByAuthor(
        pubkey: pubkey,
        limit: pageSize,
        before: before,
      );
      final videos = result.videos;

      if (videos.isEmpty) break;
      final batch = videos.toVideoEvents();
      collected.addAll(batch);

      final hasMore = result.hasMore ?? videos.length >= pageSize;
      if (!hasMore) break;

      final oldestCreatedAt = videos.fold<int>(1 << 31, (oldest, video) {
        final createdAt = video.createdAt.millisecondsSinceEpoch ~/ 1000;
        return createdAt > 0 && createdAt < oldest ? createdAt : oldest;
      });
      if (oldestCreatedAt == (1 << 31)) break;
      truncated = page == maxPages - 1;
      before = oldestCreatedAt - 1;
      if (before <= 0) break;
    }

    // Guard: the author endpoint can leak videos where the pubkey is a
    // p-tagged collaborator rather than the event author. Mirrors the profile
    // feed's getAuthorFeed filter. Edit siblings are collapsed later, after
    // hydration, by the caller.
    final authored = collected
        .where((video) => !video.isRepost && video.pubkey == pubkey)
        .toList();
    return _AuthorVideosResult(videos: authored, truncated: truncated);
  }

  Future<SocialCounts?> _getSocialCountsTolerant(
    String pubkey,
    Set<AnalyticsDataSource> failedSources,
  ) async {
    try {
      return await _getSocialCounts(pubkey);
    } on Object catch (e, stackTrace) {
      failedSources.add(AnalyticsDataSource.socialCounts);
      Log.error(
        'Failed to fetch creator analytics social counts',
        name: 'CreatorAnalyticsRepository',
        category: LogCategory.video,
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<_HydrationResult> _enrichVideosWithBulkStatsTolerant(
    List<VideoEvent> videos,
    Set<AnalyticsDataSource> failedSources,
  ) async {
    try {
      return await _enrichVideosWithBulkStats(videos);
    } on Object catch (e, stackTrace) {
      failedSources.add(AnalyticsDataSource.bulkVideoStats);
      Log.error(
        'Failed to hydrate creator analytics videos with bulk stats',
        name: 'CreatorAnalyticsRepository',
        category: LogCategory.video,
        error: e,
        stackTrace: stackTrace,
      );
      return _HydrationResult(videos: videos, hydratedCount: 0);
    }
  }

  Future<_HydrationResult> _enrichVideosWithBulkStats(
    List<VideoEvent> videos,
  ) async {
    if (videos.isEmpty) {
      return const _HydrationResult(videos: [], hydratedCount: 0);
    }

    final ids = videos.map((video) => video.id).where((id) => id.isNotEmpty);
    final chunks = _chunkStrings(ids.toList(), 100);
    final statsById = <String, BulkVideoStatsEntry>{};

    for (final chunk in chunks) {
      final chunkResponse = await _client.getBulkVideoStats(chunk);
      statsById.addAll(chunkResponse.stats);
    }

    if (statsById.isEmpty) {
      return _HydrationResult(videos: videos, hydratedCount: 0);
    }

    var hydratedCount = 0;
    final hydrated = videos.map((video) {
      final stats = statsById[video.id];
      if (stats == null) return video;

      final mergedTags = <String, String>{...video.rawTags};
      var updated = false;
      // rawTags['loops'] / originalLoops mean "archival Vine loop count";
      // only embedded_loops qualifies — bulk `loops` is a live computed
      // value that would clobber the Vine-era count.
      if (stats.embeddedLoops != null) {
        mergedTags['loops'] = stats.embeddedLoops!.toString();
        updated = true;
      }
      if (stats.views != null) {
        mergedTags['views'] = stats.views!.toString();
        updated = true;
      }
      if (video.nostrLikeCount != stats.reactions ||
          video.nostrCommentCount != stats.comments ||
          video.nostrRepostCount != stats.reposts) {
        updated = true;
      }
      if (updated) hydratedCount++;

      return video.copyWith(
        rawTags: mergedTags,
        originalLoops: stats.embeddedLoops ?? video.originalLoops,
        originalLikes: video.originalLikes,
        originalComments: video.originalComments,
        originalReposts: video.originalReposts,
        nostrLikeCount: stats.reactions,
        nostrCommentCount: stats.comments,
        nostrRepostCount: stats.reposts,
      );
    }).toList();

    return _HydrationResult(videos: hydrated, hydratedCount: hydratedCount);
  }

  Future<_HydrationResult> _hydrateVideoViewsTolerant(
    List<VideoEvent> videos,
    Set<AnalyticsDataSource> failedSources,
  ) async {
    try {
      final result = await _hydrateVideoViews(videos);
      if (result.hadFailures) {
        failedSources.add(AnalyticsDataSource.videoViewsEndpoint);
      }
      return result;
    } on Object catch (e, stackTrace) {
      failedSources.add(AnalyticsDataSource.videoViewsEndpoint);
      Log.error(
        'Failed to hydrate creator analytics videos with view counts',
        name: 'CreatorAnalyticsRepository',
        category: LogCategory.video,
        error: e,
        stackTrace: stackTrace,
      );
      return _HydrationResult(videos: videos, hydratedCount: 0);
    }
  }

  Future<_HydrationResult> _hydrateVideoViews(List<VideoEvent> videos) async {
    if (videos.isEmpty) {
      return const _HydrationResult(videos: [], hydratedCount: 0);
    }

    final missingViewVideos = videos.where((video) {
      final hasViews = extractViewLikeCount(video) != null;
      return !hasViews && video.id.isNotEmpty;
    }).toList();

    if (missingViewVideos.isEmpty) {
      return _HydrationResult(videos: videos, hydratedCount: 0);
    }

    final fetchedViews = <String, int>{};
    var hadFailures = false;
    final chunks = <List<VideoEvent>>[];
    for (var i = 0; i < missingViewVideos.length; i += 12) {
      final end = math.min(i + 12, missingViewVideos.length);
      chunks.add(missingViewVideos.sublist(i, end));
    }

    for (final chunk in chunks) {
      final counts = await Future.wait(
        chunk.map((video) async {
          try {
            return await _client.getVideoViews(video.id);
          } on Object catch (e, stackTrace) {
            hadFailures = true;
            Log.error(
              'Failed to hydrate creator analytics video view count',
              name: 'CreatorAnalyticsRepository',
              category: LogCategory.video,
              error: e,
              stackTrace: stackTrace,
            );
            return null;
          }
        }),
      );
      for (var i = 0; i < chunk.length; i++) {
        final count = counts[i];
        if (count != null) {
          fetchedViews[chunk[i].id] = count;
        }
      }
    }

    if (fetchedViews.isEmpty) {
      return _HydrationResult(
        videos: videos,
        hydratedCount: 0,
        hadFailures: hadFailures,
      );
    }

    var hydratedCount = 0;
    final hydrated = videos.map((video) {
      final count = fetchedViews[video.id];
      if (count == null) return video;
      hydratedCount++;
      final mergedTags = <String, String>{...video.rawTags, 'views': '$count'};
      return video.copyWith(rawTags: mergedTags);
    }).toList();

    return _HydrationResult(
      videos: hydrated,
      hydratedCount: hydratedCount,
      hadFailures: hadFailures,
    );
  }

  List<List<String>> _chunkStrings(List<String> input, int chunkSize) {
    if (input.isEmpty) return const [];
    final chunks = <List<String>>[];
    for (var i = 0; i < input.length; i += chunkSize) {
      final end = math.min(i + chunkSize, input.length);
      chunks.add(input.sublist(i, end));
    }
    return chunks;
  }
}

class _HydrationResult {
  const _HydrationResult({
    required this.videos,
    required this.hydratedCount,
    this.hadFailures = false,
  });

  final List<VideoEvent> videos;
  final int hydratedCount;
  final bool hadFailures;
}

class _AuthorVideosResult {
  const _AuthorVideosResult({required this.videos, required this.truncated});

  final List<VideoEvent> videos;
  final bool truncated;
}

/// Extracts view-like counts from known tags and fallbacks.
int? extractViewLikeCount(VideoEvent video) {
  int? parse(String? value) {
    if (value == null) return null;
    final normalized = value.replaceAll(',', '').trim();
    if (normalized.isEmpty) return null;
    final asInt = int.tryParse(normalized);
    if (asInt != null) return asInt;
    final asDouble = double.tryParse(normalized);
    return asDouble?.toInt();
  }

  const keys = [
    'views',
    'view_count',
    'total_views',
    'unique_views',
    'unique_viewers',
    'loops',
    'loop_count',
    'total_loops',
    'embedded_loops',
    'computed_loops',
  ];

  for (final key in keys) {
    final parsed = parse(video.rawTags[key]);
    if (parsed != null) return parsed;
  }
  return video.originalLoops;
}
