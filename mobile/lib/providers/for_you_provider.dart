// ABOUTME: For You recommendations provider - ML-powered personalized video feed
// ABOUTME: Uses Funnelcake REST API for Gorse-based recommendations (staging only)

import 'package:openvine/extensions/video_event_extensions.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/providers/feed_refresh_helpers.dart';
import 'package:openvine/providers/readiness_gate_providers.dart';
import 'package:openvine/state/video_feed_state.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:unified_logger/unified_logger.dart';

part 'for_you_provider.g.dart';

/// For You recommendations feed provider - ML-powered personalized videos
///
/// Uses Gorse-based recommendations from Funnelcake REST API.
/// Falls back to popular videos when personalization isn't available.
/// Currently only enabled on staging environment for testing.
@Riverpod(keepAlive: true)
class ForYouFeed extends _$ForYouFeed {
  int _currentLimit = 50;

  @override
  Future<VideoFeedState> build() async {
    // Watch content filter version — rebuilds when preferences change.
    ref.watch(contentFilterVersionProvider);
    ref.watch(divineHostFilterVersionProvider);

    // Watch blocklist version — rebuilds when block/unblock actions occur.
    ref.watch(blocklistVersionProvider);

    // Watch appReady gate
    final isAppReady = ref.watch(appReadyProvider);

    Log.info(
      '🎯 ForYouFeed: Building feed (appReady: $isAppReady)',
      name: 'ForYouFeedProvider',
      category: LogCategory.video,
    );

    if (!isAppReady) {
      // Preserve existing data during background — don't wipe the feed
      if (state.hasValue && state.value != null) {
        final existing = state.value!;
        if (existing.videos.isNotEmpty) {
          Log.info(
            '🎯 ForYouFeed: App not ready, preserving ${existing.videos.length} cached videos',
            name: 'ForYouFeedProvider',
            category: LogCategory.video,
          );
          return existing;
        }
      }
      Log.info(
        '🎯 ForYouFeed: App not ready, no cached data yet',
        name: 'ForYouFeedProvider',
        category: LogCategory.video,
      );
      return const VideoFeedState(videos: [], hasMoreContent: false);
    }

    // Get current user pubkey
    final authService = ref.read(authServiceProvider);
    final currentUserPubkey = authService.currentPublicKeyHex;

    if (currentUserPubkey == null) {
      Log.warning(
        '🎯 ForYouFeed: No user logged in, returning empty state',
        name: 'ForYouFeedProvider',
        category: LogCategory.video,
      );
      return const VideoFeedState(videos: [], hasMoreContent: false);
    }

    final funnelcakeAvailable =
        ref.watch(funnelcakeAvailableProvider).asData?.value ?? false;

    Log.info(
      '🎯 ForYouFeed: Funnelcake available: $funnelcakeAvailable',
      name: 'ForYouFeedProvider',
      category: LogCategory.video,
    );

    if (!funnelcakeAvailable) {
      Log.warning(
        '🎯 ForYouFeed: Funnelcake not available, returning empty state',
        name: 'ForYouFeedProvider',
        category: LogCategory.video,
      );
      return const VideoFeedState(videos: [], hasMoreContent: false);
    }

    return _fetchRecommendations(limit: _currentLimit);
  }

  Future<VideoFeedState> _fetchRecommendations({required int limit}) async {
    try {
      final authService = ref.read(authServiceProvider);
      final currentUserPubkey = authService.currentPublicKeyHex;
      if (currentUserPubkey == null) {
        return const VideoFeedState(videos: [], hasMoreContent: false);
      }

      final client = ref.read(funnelcakeApiClientProvider);
      final response = await client.getRecommendations(
        pubkey: currentUserPubkey,
        limit: limit,
      );
      final resultVideos = response.videos
          .map((v) => v.toVideoEvent())
          .toList();

      Log.info(
        '✅ ForYouFeed: Got ${resultVideos.length} recommendations, source: ${response.source}',
        name: 'ForYouFeedProvider',
        category: LogCategory.video,
      );

      // Filter for platform compatibility, content preferences,
      // and blocked users
      final videoEventService = ref.read(videoEventServiceProvider);
      final blocklistService = ref.read(contentBlocklistServiceProvider);
      final filteredVideos = videoEventService.filterVideoList(
        resultVideos
            .where((v) => v.isSupportedOnCurrentPlatform)
            .where((v) => !blocklistService.shouldFilterFromFeeds(v.pubkey))
            .toList(),
      );

      return VideoFeedState(
        videos: filteredVideos,
        hasMoreContent: filteredVideos.length >= 20,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      Log.error(
        '🎯 ForYouFeed: Error fetching recommendations: $e',
        name: 'ForYouFeedProvider',
        category: LogCategory.video,
      );
      return VideoFeedState(
        videos: const [],
        hasMoreContent: false,
        error: e.toString(),
      );
    }
  }

  /// Load more recommendations
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

      final authService = ref.read(authServiceProvider);
      final currentUserPubkey = authService.currentPublicKeyHex;
      if (currentUserPubkey == null) {
        state = AsyncData(currentState.copyWith(isLoadingMore: false));
        return;
      }

      final client = ref.read(funnelcakeApiClientProvider);
      final newLimit = _currentLimit + 30;
      final response = await client.getRecommendations(
        pubkey: currentUserPubkey,
        limit: newLimit,
      );
      final resultVideos = response.videos
          .map((v) => v.toVideoEvent())
          .toList();

      if (!ref.mounted) return;

      final videoEventService = ref.read(videoEventServiceProvider);
      final blocklistService = ref.read(contentBlocklistServiceProvider);
      final filteredVideos = videoEventService.filterVideoList(
        resultVideos
            .where((v) => v.isSupportedOnCurrentPlatform)
            .where((v) => !blocklistService.shouldFilterFromFeeds(v.pubkey))
            .toList(),
      );
      final newEventsLoaded =
          filteredVideos.length - currentState.videos.length;

      Log.info(
        '🎯 ForYouFeed: Loaded $newEventsLoaded more recommendations (total: ${filteredVideos.length})',
        name: 'ForYouFeedProvider',
        category: LogCategory.video,
      );

      _currentLimit = newLimit;

      state = AsyncData(
        VideoFeedState(
          videos: filteredVideos,
          hasMoreContent: newEventsLoaded > 0,
          lastUpdated: DateTime.now(),
        ),
      );
    } catch (e) {
      Log.error(
        '🎯 ForYouFeed: Error loading more: $e',
        name: 'ForYouFeedProvider',
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

  /// Refresh the For You feed
  Future<void> refresh() async {
    Log.info(
      '🎯 ForYouFeed: Refreshing feed - fetching fresh recommendations',
      name: 'ForYouFeedProvider',
      category: LogCategory.video,
    );

    _currentLimit = 50; // Reset limit on refresh

    await staleWhileRevalidate(
      getCurrentState: () => state,
      isMounted: () => ref.mounted,
      setState: (s) => state = s,
      fetchFresh: () => _fetchRecommendations(limit: _currentLimit),
    );
  }
}

/// Provider to check if For You tab should be visible
///
/// Available when Funnelcake REST API is available (has recommendations endpoint).
@riverpod
bool forYouAvailable(Ref ref) {
  final funnelcakeAvailable =
      ref.watch(funnelcakeAvailableProvider).asData?.value ?? false;

  // Show when Funnelcake is available (production, staging, or dev with Funnelcake)
  return funnelcakeAvailable;
}

/// Provider to check if For You feed is loading
@riverpod
bool forYouFeedLoading(Ref ref) {
  final asyncState = ref.watch(forYouFeedProvider);
  if (asyncState.isLoading) return true;

  final state = asyncState.hasValue ? asyncState.value : null;
  if (state == null) return false;

  return state.isLoadingMore;
}

/// Provider to get current For You feed video count
@riverpod
int forYouFeedCount(Ref ref) {
  final asyncState = ref.watch(forYouFeedProvider);
  return asyncState.hasValue ? (asyncState.value?.videos.length ?? 0) : 0;
}
