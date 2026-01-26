// ABOUTME: Popular Videos feed provider showing videos sorted by loop count
// ABOUTME: Tries Funnelcake REST API (sort=loops) first, falls back to Nostr if unavailable

import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/extensions/video_event_extensions.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/providers/readiness_gate_providers.dart';
import 'package:openvine/providers/video_events_providers.dart';
import 'package:openvine/state/video_feed_state.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'popular_videos_feed_provider.g.dart';

/// Popular Videos feed provider - shows videos sorted by loop count (highest first)
///
/// Strategy: Try Funnelcake REST API first (sort=loops) for accurate loop counts,
/// fall back to Nostr subscription with local sorting if REST API is unavailable.
///
/// Rebuilds when:
/// - Pull to refresh
/// - appReady gate becomes true
@Riverpod(keepAlive: true)
class PopularVideosFeed extends _$PopularVideosFeed {
  bool _usingRestApi = false;
  int? _nextCursor;

  @override
  Future<VideoFeedState> build() async {
    // Reset state
    _usingRestApi = false;
    _nextCursor = null;

    // Watch appReady gate
    final isAppReady = ref.watch(appReadyProvider);

    Log.info(
      'PopularVideosFeed: Building (appReady: $isAppReady)',
      name: 'PopularVideosFeedProvider',
      category: LogCategory.video,
    );

    if (!isAppReady) {
      return VideoFeedState(
        videos: const [],
        hasMoreContent: true,
        isLoadingMore: false,
      );
    }

    // Try REST API first
    final analyticsService = ref.read(analyticsApiServiceProvider);
    if (analyticsService.isAvailable) {
      Log.info(
        'PopularVideosFeed: Trying Funnelcake REST API (sort=loops)',
        name: 'PopularVideosFeedProvider',
        category: LogCategory.video,
      );

      try {
        final apiVideos = await analyticsService.getVideosByLoops(limit: 100);
        if (apiVideos.isNotEmpty) {
          _usingRestApi = true;
          _nextCursor = _getOldestTimestamp(apiVideos);

          // Filter for platform compatibility
          final filteredVideos = apiVideos
              .where((v) => v.isSupportedOnCurrentPlatform)
              .toList();

          Log.info(
            'PopularVideosFeed: Got ${filteredVideos.length} videos from REST API (top loops: ${filteredVideos.isNotEmpty ? filteredVideos.first.originalLoops : 0})',
            name: 'PopularVideosFeedProvider',
            category: LogCategory.video,
          );

          return VideoFeedState(
            videos: filteredVideos,
            hasMoreContent:
                apiVideos.length >= AppConstants.paginationBatchSize,
            isLoadingMore: false,
            lastUpdated: DateTime.now(),
          );
        }
        Log.warning(
          'PopularVideosFeed: REST API returned empty, falling back to Nostr',
          name: 'PopularVideosFeedProvider',
          category: LogCategory.video,
        );
      } catch (e) {
        Log.warning(
          'PopularVideosFeed: REST API failed ($e), falling back to Nostr',
          name: 'PopularVideosFeedProvider',
          category: LogCategory.video,
        );
      }
    }

    // Fall back to Nostr via videoEventsProvider
    _usingRestApi = false;
    Log.info(
      'PopularVideosFeed: Using Nostr fallback (videoEventsProvider)',
      name: 'PopularVideosFeedProvider',
      category: LogCategory.video,
    );

    // Watch videoEventsProvider for Nostr data
    final videoEventsAsync = ref.watch(videoEventsProvider);

    return videoEventsAsync.when(
      data: (videos) {
        // Filter for platform compatibility
        var filteredVideos = videos
            .where((v) => v.isSupportedOnCurrentPlatform)
            .toList();

        // Sort by loop count locally (Nostr doesn't provide loop-sorted data)
        filteredVideos.sort((a, b) {
          final aLoops = a.originalLoops ?? 0;
          final bLoops = b.originalLoops ?? 0;
          return bLoops.compareTo(aLoops);
        });

        Log.info(
          'PopularVideosFeed: Nostr fallback - ${filteredVideos.length} videos (top loops: ${filteredVideos.isNotEmpty ? filteredVideos.first.originalLoops : 0})',
          name: 'PopularVideosFeedProvider',
          category: LogCategory.video,
        );

        return VideoFeedState(
          videos: filteredVideos,
          hasMoreContent:
              filteredVideos.length >= AppConstants.hasMoreContentThreshold,
          isLoadingMore: false,
          lastUpdated: DateTime.now(),
        );
      },
      loading: () => VideoFeedState(
        videos: const [],
        hasMoreContent: true,
        isLoadingMore: true,
      ),
      error: (error, _) {
        Log.error(
          'PopularVideosFeed: Nostr fallback error - $error',
          name: 'PopularVideosFeedProvider',
          category: LogCategory.video,
        );
        return VideoFeedState(
          videos: const [],
          hasMoreContent: false,
          isLoadingMore: false,
          error: error.toString(),
        );
      },
    );
  }

  /// Load more videos
  Future<void> loadMore() async {
    final currentState = await future;

    if (!ref.mounted || currentState.isLoadingMore) return;
    if (!currentState.hasMoreContent) return;

    state = AsyncData(currentState.copyWith(isLoadingMore: true));

    try {
      if (_usingRestApi) {
        final analyticsService = ref.read(analyticsApiServiceProvider);

        Log.info(
          'PopularVideosFeed: Loading more from REST API (cursor: $_nextCursor)',
          name: 'PopularVideosFeedProvider',
          category: LogCategory.video,
        );

        final apiVideos = await analyticsService.getVideosByLoops(
          limit: 50,
          before: _nextCursor,
        );

        if (!ref.mounted) return;

        if (apiVideos.isNotEmpty) {
          final existingIds = currentState.videos.map((v) => v.id).toSet();
          final newVideos = apiVideos
              .where((v) => !existingIds.contains(v.id))
              .where((v) => v.isSupportedOnCurrentPlatform)
              .toList();

          _nextCursor = _getOldestTimestamp(apiVideos);

          if (newVideos.isNotEmpty) {
            final allVideos = [...currentState.videos, ...newVideos];
            Log.info(
              'PopularVideosFeed: Loaded ${newVideos.length} more videos (total: ${allVideos.length})',
              name: 'PopularVideosFeedProvider',
              category: LogCategory.video,
            );

            state = AsyncData(
              VideoFeedState(
                videos: allVideos,
                hasMoreContent:
                    apiVideos.length >= AppConstants.paginationBatchSize,
                isLoadingMore: false,
                lastUpdated: DateTime.now(),
              ),
            );
          } else {
            state = AsyncData(
              currentState.copyWith(
                hasMoreContent:
                    apiVideos.length >= AppConstants.paginationBatchSize,
                isLoadingMore: false,
              ),
            );
          }
        } else {
          state = AsyncData(
            currentState.copyWith(hasMoreContent: false, isLoadingMore: false),
          );
        }
        return;
      }

      // Nostr mode - delegate to videoEventsProvider
      await ref.read(videoEventsProvider.notifier).loadMoreEvents();

      if (!ref.mounted) return;
      state = AsyncData(currentState.copyWith(isLoadingMore: false));
    } catch (e) {
      Log.error(
        'PopularVideosFeed: Error loading more: $e',
        name: 'PopularVideosFeedProvider',
        category: LogCategory.video,
      );

      if (!ref.mounted) return;
      state = AsyncData(
        currentState.copyWith(isLoadingMore: false, error: e.toString()),
      );
    }
  }

  /// Refresh the feed
  Future<void> refresh() async {
    Log.info(
      'PopularVideosFeed: Refreshing (will try REST API first)',
      name: 'PopularVideosFeedProvider',
      category: LogCategory.video,
    );

    if (_usingRestApi) {
      try {
        final analyticsService = ref.read(analyticsApiServiceProvider);
        final apiVideos = await analyticsService.getVideosByLoops(
          limit: 100,
          forceRefresh: true,
        );

        if (!ref.mounted) return;

        if (apiVideos.isNotEmpty) {
          _nextCursor = _getOldestTimestamp(apiVideos);

          final filteredVideos = apiVideos
              .where((v) => v.isSupportedOnCurrentPlatform)
              .toList();

          state = AsyncData(
            VideoFeedState(
              videos: filteredVideos,
              hasMoreContent:
                  apiVideos.length >= AppConstants.paginationBatchSize,
              isLoadingMore: false,
              lastUpdated: DateTime.now(),
            ),
          );

          Log.info(
            'PopularVideosFeed: Refreshed ${filteredVideos.length} videos from REST API',
            name: 'PopularVideosFeedProvider',
            category: LogCategory.video,
          );
          return;
        }
      } catch (e) {
        Log.warning(
          'PopularVideosFeed: REST API refresh failed, falling back to invalidate',
          name: 'PopularVideosFeedProvider',
          category: LogCategory.video,
        );
      }
    }

    // Reset and rebuild
    _usingRestApi = false;
    _nextCursor = null;
    ref.invalidateSelf();
  }

  int? _getOldestTimestamp(List<VideoEvent> videos) {
    if (videos.isEmpty) return null;
    return videos.map((v) => v.createdAt).reduce((a, b) => a < b ? a : b);
  }
}
