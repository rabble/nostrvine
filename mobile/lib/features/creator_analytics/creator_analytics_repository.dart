// ABOUTME: Typed repository and diagnostics for creator analytics data loading.
// ABOUTME: Normalizes Funnelcake responses and tracks metric provenance.

import 'dart:math' as math;

import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:models/models.dart';

/// Provenance source for analytics values.
enum AnalyticsDataSource { authorVideos, bulkVideoStats, videoViewsEndpoint }

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
  });

  final int totalVideos;
  final int videosWithAnyViews;
  final int videosMissingViews;
  final int videosHydratedByBulkStats;
  final int videosHydratedByViewsEndpoint;
  final Set<AnalyticsDataSource> sourcesUsed;
  final DateTime fetchedAt;

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

    final socialFuture = _getSocialCounts(pubkey);
    final videos = await _fetchAuthorVideos(pubkey);
    if (videos.isNotEmpty) {
      sourcesUsed.add(AnalyticsDataSource.authorVideos);
    }

    final bulkResult = await _enrichVideosWithBulkStats(videos);
    var hydratedVideos = bulkResult.videos;
    if (bulkResult.hydratedCount > 0) {
      sourcesUsed.add(AnalyticsDataSource.bulkVideoStats);
    }

    final endpointResult = await _hydrateVideoViews(hydratedVideos);
    hydratedVideos = endpointResult.videos;
    if (endpointResult.hydratedCount > 0) {
      sourcesUsed.add(AnalyticsDataSource.videoViewsEndpoint);
    }

    final social = await socialFuture;
    final withViewData = hydratedVideos
        .where((video) => extractViewLikeCount(video) != null)
        .length;

    return CreatorAnalyticsSnapshot(
      videos: hydratedVideos,
      socialCounts: social,
      diagnostics: CreatorAnalyticsDiagnostics(
        totalVideos: hydratedVideos.length,
        videosWithAnyViews: withViewData,
        videosMissingViews: hydratedVideos.length - withViewData,
        videosHydratedByBulkStats: bulkResult.hydratedCount,
        videosHydratedByViewsEndpoint: endpointResult.hydratedCount,
        sourcesUsed: sourcesUsed,
        fetchedAt: DateTime.now(),
      ),
    );
  }

  Future<List<VideoEvent>> _fetchAuthorVideos(
    String pubkey, {
    int maxPages = 4,
    int pageSize = 100,
  }) async {
    final collected = <VideoEvent>[];
    int? before;

    for (var page = 0; page < maxPages; page++) {
      final result = await _client.getVideosByAuthor(
        pubkey: pubkey,
        limit: pageSize,
        before: before,
      );
      final videos = result.videos;

      if (videos.isEmpty) break;
      final batch = videos.map((stats) => stats.toVideoEvent()).toList();
      collected.addAll(batch);

      if (batch.length < pageSize) break;

      final oldestCreatedAt = batch.fold<int>(
        1 << 31,
        (oldest, video) => video.createdAt > 0 && video.createdAt < oldest
            ? video.createdAt
            : oldest,
      );
      if (oldestCreatedAt == (1 << 31)) break;
      before = oldestCreatedAt - 1;
      if (before <= 0) break;
    }

    final seen = <String>{};
    return collected.where((video) => seen.add(video.id)).toList();
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
      if (stats.loops != null) {
        mergedTags['loops'] = stats.loops!.toString();
        updated = true;
      }
      if (stats.views != null) {
        mergedTags['views'] = stats.views!.toString();
        updated = true;
      }
      if (updated) hydratedCount++;

      return video.copyWith(
        rawTags: mergedTags,
        originalLoops: stats.loops ?? video.originalLoops,
      );
    }).toList();

    return _HydrationResult(videos: hydrated, hydratedCount: hydratedCount);
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
    final chunks = <List<VideoEvent>>[];
    for (var i = 0; i < missingViewVideos.length; i += 12) {
      final end = math.min(i + 12, missingViewVideos.length);
      chunks.add(missingViewVideos.sublist(i, end));
    }

    for (final chunk in chunks) {
      final counts = await Future.wait(
        chunk.map((video) => _client.getVideoViews(video.id)),
      );
      for (var i = 0; i < chunk.length; i++) {
        fetchedViews[chunk[i].id] = counts[i];
      }
    }

    if (fetchedViews.isEmpty) {
      return _HydrationResult(videos: videos, hydratedCount: 0);
    }

    var hydratedCount = 0;
    final hydrated = videos.map((video) {
      final count = fetchedViews[video.id];
      if (count == null) return video;
      hydratedCount++;
      final mergedTags = <String, String>{...video.rawTags, 'views': '$count'};
      return video.copyWith(rawTags: mergedTags);
    }).toList();

    return _HydrationResult(videos: hydrated, hydratedCount: hydratedCount);
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
  const _HydrationResult({required this.videos, required this.hydratedCount});

  final List<VideoEvent> videos;
  final int hydratedCount;
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
