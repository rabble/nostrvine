// ABOUTME: For You recommendations provider - ML-powered personalized video feed
// ABOUTME: Uses Funnelcake REST API for Gorse-based recommendations (staging only)

import 'package:openvine/extensions/video_event_extensions.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/providers/readiness_gate_providers.dart';
import 'package:openvine/state/video_feed_state.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

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
      return VideoFeedState(
        videos: const [],
        hasMoreContent: false,
        isLoadingMore: false,
      );
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
      return VideoFeedState(
        videos: const [],
        hasMoreContent: false,
        isLoadingMore: false,
      );
    }

    final analyticsService = ref.read(analyticsApiServiceProvider);
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
      return VideoFeedState(
        videos: const [],
        hasMoreContent: false,
        isLoadingMore: false,
      );
    }

    try {
      final result = await analyticsService.getRecommendations(
        pubkey: currentUserPubkey,
        limit: _currentLimit,
        fallback: 'popular',
      );

      Log.info(
        '✅ ForYouFeed: Got ${result.videos.length} recommendations, source: ${result.source}',
        name: 'ForYouFeedProvider',
        category: LogCategory.video,
      );

      // Filter for platform compatibility (WebM not supported on iOS/macOS)
      final filteredVideos = result.videos
          .where((v) => v.isSupportedOnCurrentPlatform)
          .toList();

      return VideoFeedState(
        videos: filteredVideos,
        hasMoreContent: filteredVideos.length >= 20,
        isLoadingMore: false,
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
        isLoadingMore: false,
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

      final analyticsService = ref.read(analyticsApiServiceProvider);
      final newLimit = _currentLimit + 30;
      final result = await analyticsService.getRecommendations(
        pubkey: currentUserPubkey,
        limit: newLimit,
        fallback: 'popular',
      );

      if (!ref.mounted) return;

      final filteredVideos = result.videos
          .where((v) => v.isSupportedOnCurrentPlatform)
          .toList();
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
          isLoadingMore: false,
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
    ref.invalidateSelf();
    await future; // Wait for rebuild to complete
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
