// ABOUTME: ClassicVines feed provider showing pre-2017 Vine archive videos
// ABOUTME: Uses REST API when available, falls back to Nostr videos with embedded stats

import 'dart:async';
import 'dart:math';

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
/// Uses REST API (Funnelcake) with offset pagination to load pages on demand.
/// Each page is 100 videos. With ~10k classic vines, there are ~100 pages.
///
/// Pull-to-refresh spins to the next page of classics.
@Riverpod(keepAlive: true)
class ClassicVinesFeed extends _$ClassicVinesFeed {
  static const int _pageSize = 100;
  static const int _totalClassicVines = 10000; // Approximate total

  /// Max random offset — draws from top 500 most-looped vines
  static const int _maxRandomOffset = 400;

  final Random _random = Random();

  /// Random starting offset for the current session (0–400)
  int _randomOffset = 0;

  /// Number of additional pages appended via loadMore
  int _loadMorePages = 0;

  @override
  Future<VideoFeedState> build() async {
    // Watch content filter version — rebuilds when preferences change.
    ref.watch(contentFilterVersionProvider);

    // Watch appReady gate
    final isAppReady = ref.watch(appReadyProvider);

    Log.info(
      '🎬 ClassicVinesFeed: Building feed (appReady: $isAppReady)',
      name: 'ClassicVinesFeedProvider',
      category: LogCategory.video,
    );

    if (!isAppReady) {
      // Preserve existing data during background — don't wipe the feed
      if (state.hasValue && state.value != null) {
        final existing = state.value!;
        if (existing.videos.isNotEmpty) {
          return existing;
        }
      }
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

    // Pick a random offset within the top 500 most-looped vines
    _randomOffset = _random.nextInt(_maxRandomOffset + 1);
    _loadMorePages = 0;

    // Try REST API first (Funnelcake has comprehensive classic Vine data)
    if (funnelcakeAvailable) {
      try {
        final videos = await analyticsService.getClassicVines(
          limit: _pageSize,
          offset: _randomOffset,
          sort: 'loops',
        );

        // Filter for platform compatibility, content preferences, and shuffle
        final filteredVideos = videoEventService.filterVideoList(
          videos.where((v) => v.isSupportedOnCurrentPlatform).toList(),
        )..shuffle(_random);

        Log.info(
          '🎬 ClassicVinesFeed: Loaded ${filteredVideos.length} videos '
          '(offset: $_randomOffset, shuffled)',
          name: 'ClassicVinesFeedProvider',
          category: LogCategory.video,
        );

        final nextOffset = _randomOffset + _pageSize;
        return VideoFeedState(
          videos: filteredVideos,
          hasMoreContent: nextOffset < _totalClassicVines,
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
    Log.info(
      '🎬 ClassicVinesFeed: Using Nostr fallback',
      name: 'ClassicVinesFeedProvider',
      category: LogCategory.video,
    );

    final allVideos = videoEventService.discoveryVideos;
    final classicVideos = videoEventService.filterVideoList(
      allVideos
          .where((v) => v.originalLoops != null && v.originalLoops! > 0)
          .where((v) => v.isSupportedOnCurrentPlatform)
          .toList(),
    )..sort((a, b) => (b.originalLoops ?? 0).compareTo(a.originalLoops ?? 0));

    // Take top entries then shuffle for variety
    final topClassics = classicVideos.take(_pageSize).toList()
      ..shuffle(_random);

    return VideoFeedState(
      videos: topClassics,
      hasMoreContent: classicVideos.length > _pageSize,
      isLoadingMore: false,
      lastUpdated: DateTime.now(),
    );
  }

  /// Refresh with a new random slice of classic vines
  Future<void> refresh() async {
    final analyticsService = ref.read(analyticsApiServiceProvider);
    final funnelcakeAvailable =
        ref.read(funnelcakeAvailableProvider).asData?.value ?? false;

    if (!funnelcakeAvailable) {
      // Can't paginate without API — invalidate to re-run build()
      ref.invalidateSelf();
      return;
    }

    // Pick a new random offset for a fresh slice
    _randomOffset = _random.nextInt(_maxRandomOffset + 1);
    _loadMorePages = 0;

    Log.info(
      '🎬 ClassicVinesFeed: Refreshing with new offset $_randomOffset',
      name: 'ClassicVinesFeedProvider',
      category: LogCategory.video,
    );

    state = const AsyncLoading();

    try {
      final videos = await analyticsService.getClassicVines(
        limit: _pageSize,
        offset: _randomOffset,
        sort: 'loops',
      );

      final videoEventService = ref.read(videoEventServiceProvider);
      final filteredVideos = videoEventService.filterVideoList(
        videos.where((v) => v.isSupportedOnCurrentPlatform).toList(),
      )..shuffle(_random);

      final nextOffset = _randomOffset + _pageSize;
      state = AsyncData(
        VideoFeedState(
          videos: filteredVideos,
          hasMoreContent: nextOffset < _totalClassicVines,
          isLoadingMore: false,
          lastUpdated: DateTime.now(),
        ),
      );
    } catch (e) {
      Log.error(
        '🎬 ClassicVinesFeed: Error refreshing (offset $_randomOffset): $e',
        name: 'ClassicVinesFeedProvider',
        category: LogCategory.video,
      );
      state = AsyncError(e, StackTrace.current);
    }
  }

  /// Load more videos (append next sequential page from current offset)
  Future<void> loadMore() async {
    if (!state.hasValue || state.value == null) return;
    final currentState = state.value!;
    if (currentState.isLoadingMore) return;

    final analyticsService = ref.read(analyticsApiServiceProvider);
    final funnelcakeAvailable =
        ref.read(funnelcakeAvailableProvider).asData?.value ?? false;

    if (!funnelcakeAvailable || !currentState.hasMoreContent) return;

    state = AsyncData(currentState.copyWith(isLoadingMore: true));

    try {
      _loadMorePages++;
      final nextOffset = _randomOffset + _loadMorePages * _pageSize;

      final videos = await analyticsService.getClassicVines(
        limit: _pageSize,
        offset: nextOffset,
        sort: 'loops',
      );

      final videoEventService = ref.read(videoEventServiceProvider);
      final filteredVideos = videoEventService.filterVideoList(
        videos.where((v) => v.isSupportedOnCurrentPlatform).toList(),
      );

      final allVideos = [...currentState.videos, ...filteredVideos];
      final followingOffset = nextOffset + _pageSize;

      Log.info(
        '🎬 ClassicVinesFeed: Loaded ${filteredVideos.length} more '
        '(offset: $nextOffset, total: ${allVideos.length})',
        name: 'ClassicVinesFeedProvider',
        category: LogCategory.video,
      );

      state = AsyncData(
        VideoFeedState(
          videos: allVideos,
          hasMoreContent: followingOffset < _totalClassicVines,
          isLoadingMore: false,
          lastUpdated: DateTime.now(),
        ),
      );
    } catch (e) {
      _loadMorePages--; // Revert so retry works
      Log.error(
        '🎬 ClassicVinesFeed: Error loading more: $e',
        name: 'ClassicVinesFeedProvider',
        category: LogCategory.video,
      );
      state = AsyncData(
        currentState.copyWith(isLoadingMore: false, error: e.toString()),
      );
    }
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
/// Aggregates videos by pubkey and sorts by total loop count.
/// Also triggers profile prefetching for Viners without avatars.
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

  // Get top 20 Viners
  final topViners = viners.take(20).toList();

  // Prefetch profiles for Viners without avatars from REST API
  // This ensures avatar images are available when the slider renders
  final vinersNeedingProfiles = topViners
      .where((v) => v.authorAvatar == null || v.authorAvatar!.isEmpty)
      .map((v) => v.pubkey)
      .toList();

  if (vinersNeedingProfiles.isNotEmpty) {
    Log.info(
      '🎬 TopClassicViners: Prefetching ${vinersNeedingProfiles.length} profiles for Viners without avatars',
      name: 'ClassicVinesProvider',
      category: LogCategory.video,
    );
    // Fire-and-forget profile prefetch - don't await
    final userProfileService = ref.read(userProfileServiceProvider);
    unawaited(
      userProfileService.prefetchProfilesImmediately(vinersNeedingProfiles),
    );
  }

  return topViners;
}

/// Helper class for aggregating Viner stats
class _VinerAggregator {
  int totalLoops = 0;
  int videoCount = 0;
  String? authorName; // Capture from first video with a name
  String? authorAvatar; // Capture from first video with an avatar
}
