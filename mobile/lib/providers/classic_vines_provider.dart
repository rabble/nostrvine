// ABOUTME: ClassicVines feed provider showing pre-2017 Vine archive videos
// ABOUTME: Uses REST API when available, falls back to Nostr videos with embedded stats

import 'package:openvine/extensions/video_event_extensions.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/providers/readiness_gate_providers.dart';
import 'package:openvine/state/video_feed_state.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'classic_vines_provider.g.dart';

/// ClassicVines feed provider - shows pre-2017 Vine archive sorted by loops
///
/// Uses REST API (Funnelcake) when available for comprehensive classic Vine data.
/// Falls back to Nostr discovery videos that have embedded loop stats (originalLoops > 0),
/// which includes imported classic Vines that have the loop count in their event tags.
@Riverpod(keepAlive: true)
class ClassicVinesFeed extends _$ClassicVinesFeed {
  int _currentLimit = 100;

  @override
  Future<VideoFeedState> build() async {
    // Watch appReady gate
    final isAppReady = ref.watch(appReadyProvider);

    Log.info(
      '🎬 ClassicVinesFeed: Building feed (appReady: $isAppReady)',
      name: 'ClassicVinesFeedProvider',
      category: LogCategory.video,
    );

    if (!isAppReady) {
      Log.info(
        '🎬 ClassicVinesFeed: App not ready, returning empty state',
        name: 'ClassicVinesFeedProvider',
        category: LogCategory.video,
      );
      return VideoFeedState(
        videos: const [],
        hasMoreContent: false,
        isLoadingMore: false,
      );
    }

    final analyticsService = ref.read(analyticsApiServiceProvider);
    final videoEventService = ref.read(videoEventServiceProvider);
    final funnelcakeAvailable =
        ref.watch(funnelcakeAvailableProvider).asData?.value ?? false;

    Log.info(
      '🎬 ClassicVinesFeed: Funnelcake available: $funnelcakeAvailable',
      name: 'ClassicVinesFeedProvider',
      category: LogCategory.video,
    );

    // Try REST API first (Funnelcake has comprehensive classic Vine data)
    if (funnelcakeAvailable) {
      try {
        final apiVideos = await analyticsService.getClassicVines(
          limit: _currentLimit,
        );

        Log.info(
          '✅ ClassicVinesFeed: Got ${apiVideos.length} classic vines from REST API',
          name: 'ClassicVinesFeedProvider',
          category: LogCategory.video,
        );

        // Log first video stats for debugging
        if (apiVideos.isNotEmpty) {
          final first = apiVideos.first;
          Log.info(
            '🎬 First video: loops=${first.originalLoops}, likes=${first.originalLikes}, '
            'title="${first.title ?? 'no title'}"',
            name: 'ClassicVinesFeedProvider',
            category: LogCategory.video,
          );
        }

        // Filter for platform compatibility (WebM not supported on iOS/macOS)
        final filteredVideos = apiVideos
            .where((v) => v.isSupportedOnCurrentPlatform)
            .toList();

        return VideoFeedState(
          videos: filteredVideos,
          hasMoreContent: filteredVideos.length >= 50,
          isLoadingMore: false,
          lastUpdated: DateTime.now(),
        );
      } catch (e) {
        Log.warning(
          '🎬 ClassicVinesFeed: REST API error, falling back to Nostr: $e',
          name: 'ClassicVinesFeedProvider',
          category: LogCategory.video,
        );
        // Fall through to Nostr fallback
      }
    }

    // Fallback: Get videos from Nostr that have embedded loop stats
    // These are imported classic Vines with originalLoops in their event tags
    Log.info(
      '🎬 ClassicVinesFeed: Using Nostr fallback - videos with embedded stats',
      name: 'ClassicVinesFeedProvider',
      category: LogCategory.video,
    );

    // Get all discovery videos and filter for those with embedded loop stats
    final allVideos = videoEventService.discoveryVideos;
    final classicVideos = allVideos
        .where((v) => v.originalLoops != null && v.originalLoops! > 0)
        .where((v) => v.isSupportedOnCurrentPlatform)
        .toList();

    // Sort by loops descending (most popular first)
    classicVideos.sort((a, b) {
      final aLoops = a.originalLoops ?? 0;
      final bLoops = b.originalLoops ?? 0;
      return bLoops.compareTo(aLoops);
    });

    Log.info(
      '✅ ClassicVinesFeed: Found ${classicVideos.length} videos with embedded stats from Nostr',
      name: 'ClassicVinesFeedProvider',
      category: LogCategory.video,
    );

    return VideoFeedState(
      videos: classicVideos.take(_currentLimit).toList(),
      hasMoreContent: classicVideos.length > _currentLimit,
      isLoadingMore: false,
      lastUpdated: DateTime.now(),
    );
  }

  /// Load more classic vines
  Future<void> loadMore() async {
    final currentState = await future;

    if (!ref.mounted || currentState.isLoadingMore) {
      return;
    }

    state = AsyncData(currentState.copyWith(isLoadingMore: true));

    try {
      final funnelcakeAvailable =
          ref.read(funnelcakeAvailableProvider).asData?.value ?? false;
      if (!funnelcakeAvailable) {
        state = AsyncData(currentState.copyWith(isLoadingMore: false));
        return;
      }

      final analyticsService = ref.read(analyticsApiServiceProvider);
      final newLimit = _currentLimit + 50;
      final apiVideos = await analyticsService.getClassicVines(limit: newLimit);

      if (!ref.mounted) return;

      final filteredVideos = apiVideos
          .where((v) => v.isSupportedOnCurrentPlatform)
          .toList();
      final newEventsLoaded =
          filteredVideos.length - currentState.videos.length;

      Log.info(
        '🎬 ClassicVinesFeed: Loaded $newEventsLoaded more classic vines (total: ${filteredVideos.length})',
        name: 'ClassicVinesFeedProvider',
        category: LogCategory.video,
      );

      _currentLimit = newLimit;

      state = AsyncData(
        VideoFeedState(
          videos: filteredVideos,
          hasMoreContent: newEventsLoaded > 0,
          isLoadingMore: false,
          lastUpdated: DateTime.now(),
        ),
      );
    } catch (e) {
      Log.error(
        '🎬 ClassicVinesFeed: Error loading more: $e',
        name: 'ClassicVinesFeedProvider',
        category: LogCategory.video,
      );

      if (!ref.mounted) return;
      final currentState = await future;
      if (!ref.mounted) return;
      state = AsyncData(
        currentState.copyWith(isLoadingMore: false, error: e.toString()),
      );
    }
  }

  /// Refresh the classic vines feed
  Future<void> refresh() async {
    Log.info(
      '🎬 ClassicVinesFeed: Refreshing feed',
      name: 'ClassicVinesFeedProvider',
      category: LogCategory.video,
    );

    _currentLimit = 100; // Reset limit on refresh
    ref.invalidateSelf();
  }
}

/// Provider to check if classic vines feed is loading
@riverpod
bool classicVinesFeedLoading(Ref ref) {
  final asyncState = ref.watch(classicVinesFeedProvider);
  if (asyncState.isLoading) return true;

  final state = asyncState.hasValue ? asyncState.value : null;
  if (state == null) return false;

  return state.isLoadingMore;
}

/// Provider to get current classic vines feed video count
@riverpod
int classicVinesFeedCount(Ref ref) {
  final asyncState = ref.watch(classicVinesFeedProvider);
  return asyncState.hasValue ? (asyncState.value?.videos.length ?? 0) : 0;
}

/// Provider to check if classic vines are available
///
/// Delegates to the centralized funnelcakeAvailableProvider.
/// Classic vines require Funnelcake REST API to be available.
@riverpod
Future<bool> classicVinesAvailable(Ref ref) async {
  final funnelcakeAsync = ref.watch(funnelcakeAvailableProvider);
  return funnelcakeAsync.asData?.value ?? false;
}

/// Data model for a top classic Viner
class ClassicViner {
  const ClassicViner({
    required this.pubkey,
    required this.totalLoops,
    required this.videoCount,
    this.authorName,
    this.authorAvatar,
  });

  final String pubkey;
  final int totalLoops;
  final int videoCount;
  final String? authorName; // Display name from classic Vine data
  final String? authorAvatar; // Profile picture URL from API
}

/// Provider for top classic Viners derived from classic videos
///
/// Aggregates videos by pubkey and sorts by total loop count
@riverpod
Future<List<ClassicViner>> topClassicViners(Ref ref) async {
  final classicVinesAsync = ref.watch(classicVinesFeedProvider);

  // Wait for classic vines to load - check if has value
  if (!classicVinesAsync.hasValue || classicVinesAsync.value == null) {
    return const [];
  }

  final feedState = classicVinesAsync.value!;
  if (feedState.videos.isEmpty) {
    return const [];
  }

  // Aggregate by pubkey
  final vinerMap = <String, _VinerAggregator>{};

  for (final video in feedState.videos) {
    final aggregator = vinerMap.putIfAbsent(
      video.pubkey,
      () => _VinerAggregator(),
    );
    final loops = video.originalLoops ?? 0;
    aggregator.totalLoops = aggregator.totalLoops + loops;
    aggregator.videoCount += 1;
    // Capture author name from first video that has one
    if (aggregator.authorName == null && video.authorName != null) {
      aggregator.authorName = video.authorName;
    }
    // Capture author avatar from first video that has one
    if (aggregator.authorAvatar == null && video.authorAvatar != null) {
      aggregator.authorAvatar = video.authorAvatar;
    }
  }

  // Convert to ClassicViner list and sort by total loops
  final viners =
      vinerMap.entries
          .map(
            (e) => ClassicViner(
              pubkey: e.key,
              totalLoops: e.value.totalLoops,
              videoCount: e.value.videoCount,
              authorName: e.value.authorName,
              authorAvatar: e.value.authorAvatar,
            ),
          )
          .where((v) => v.totalLoops > 0)
          .toList()
        ..sort((a, b) => b.totalLoops.compareTo(a.totalLoops));

  Log.info(
    '🎬 TopClassicViners: Found ${viners.length} unique Viners',
    name: 'ClassicVinesProvider',
    category: LogCategory.video,
  );

  // Return top 20 Viners
  return viners.take(20).toList();
}

/// Helper class for aggregating Viner stats
class _VinerAggregator {
  int totalLoops = 0;
  int videoCount = 0;
  String? authorName; // Capture from first video with a name
  String? authorAvatar; // Capture from first video with an avatar
}
