// ABOUTME: PopularNow feed provider showing newest videos with REST API + Nostr fallback
// ABOUTME: Tries Funnelcake REST API first, falls back to Nostr subscription if unavailable

import 'package:openvine/helpers/video_feed_builder.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/extensions/video_event_extensions.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/providers/readiness_gate_providers.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/services/video_filter_builder.dart';
import 'package:openvine/state/video_feed_state.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'popular_now_feed_provider.g.dart';

/// PopularNow feed provider - shows newest videos (sorted by creation time)
///
/// Strategy: Try Funnelcake REST API first for better performance and engagement
/// sorting, fall back to Nostr subscription if REST API is unavailable.
///
/// Rebuilds when:
/// - Poll interval elapses (uses same auto-refresh as home feed)
/// - User pulls to refresh
/// - VideoEventService updates with new videos
/// - appReady gate becomes true (triggers rebuild to start subscription)
@Riverpod(keepAlive: true) // Keep alive to prevent state loss on tab switches
class PopularNowFeed extends _$PopularNowFeed {
  VideoFeedBuilder? _builder;
  bool _usingRestApi = false;

  @override
  Future<VideoFeedState> build() async {
    // Watch appReady gate - provider rebuilds when this changes
    final isAppReady = ref.watch(appReadyProvider);

    Log.info(
      '🆕 PopularNowFeed: Building feed for newest videos (appReady: $isAppReady)',
      name: 'PopularNowFeedProvider',
      category: LogCategory.video,
    );

    final videoEventService = ref.watch(videoEventServiceProvider);

    // If app is not ready, return empty state - will rebuild when appReady becomes true
    if (!isAppReady) {
      Log.info(
        '🆕 PopularNowFeed: App not ready, returning empty state (will rebuild when ready)',
        name: 'PopularNowFeedProvider',
        category: LogCategory.video,
      );
      return VideoFeedState(
        videos: const [],
        hasMoreContent: true, // Assume there's content to load when ready
        isLoadingMore: false,
      );
    }

    // Try REST API first if available
    final analyticsService = ref.read(analyticsApiServiceProvider);
    if (analyticsService.isAvailable) {
      Log.info(
        '🆕 PopularNowFeed: Trying Funnelcake REST API first',
        name: 'PopularNowFeedProvider',
        category: LogCategory.video,
      );

      try {
        final apiVideos = await analyticsService.getRecentVideos(limit: 100);
        if (apiVideos.isNotEmpty) {
          _usingRestApi = true;
          Log.info(
            '✅ PopularNowFeed: Got ${apiVideos.length} videos from REST API',
            name: 'PopularNowFeedProvider',
            category: LogCategory.video,
          );

          // Filter for platform compatibility
          final filteredVideos = apiVideos
              .where((v) => v.isSupportedOnCurrentPlatform)
              .toList();

          return VideoFeedState(
            videos: filteredVideos,
            hasMoreContent: filteredVideos.length >= 50,
            isLoadingMore: false,
            lastUpdated: DateTime.now(),
          );
        }
        Log.warning(
          '🆕 PopularNowFeed: REST API returned empty, falling back to Nostr',
          name: 'PopularNowFeedProvider',
          category: LogCategory.video,
        );
      } catch (e) {
        Log.warning(
          '🆕 PopularNowFeed: REST API failed ($e), falling back to Nostr',
          name: 'PopularNowFeedProvider',
          category: LogCategory.video,
        );
      }
    }

    // Fall back to Nostr subscription
    _usingRestApi = false;
    _builder = VideoFeedBuilder(videoEventService);

    // Configure feed for popularNow subscription type
    final config = VideoFeedConfig(
      subscriptionType: SubscriptionType.popularNow,
      subscribe: (service) async {
        await service.subscribeToVideoFeed(
          subscriptionType: SubscriptionType.popularNow,
          limit: 100,
          sortBy: VideoSortField.createdAt, // Newest videos first
        );
      },
      getVideos: (service) => service.popularNowVideos,
      filterVideos: (videos) {
        // Filter out WebM videos on iOS/macOS (not supported by AVPlayer)
        return videos.where((v) => v.isSupportedOnCurrentPlatform).toList();
      },
      sortVideos: (videos) {
        final sorted = List<VideoEvent>.from(videos);
        sorted.sort((a, b) {
          final timeCompare = b.timestamp.compareTo(a.timestamp);
          if (timeCompare != 0) return timeCompare;
          // Secondary sort by ID for stable ordering
          return a.id.compareTo(b.id);
        });
        return sorted;
      },
    );

    // Build feed using helper
    final state = await _builder!.buildFeed(config: config);

    // Check if still mounted after async gap
    if (!ref.mounted) {
      return VideoFeedState(
        videos: const [],
        hasMoreContent: false,
        isLoadingMore: false,
      );
    }

    // Set up continuous listener for updates
    _builder!.setupContinuousListener(
      config: config,
      onUpdate: (newState) {
        if (ref.mounted) {
          this.state = AsyncData(newState);
        }
      },
    );

    // Register for video update callbacks to auto-refresh when any video is updated
    final unregisterVideoUpdate = videoEventService.addVideoUpdateListener((
      updated,
    ) {
      if (ref.mounted) {
        refreshFromService();
      }
    });

    // Clean up on dispose
    ref.onDispose(() {
      _builder?.cleanup();
      _builder = null;
      unregisterVideoUpdate(); // Clean up video update callback
      Log.info(
        '🆕 PopularNowFeed: Disposed',
        name: 'PopularNowFeedProvider',
        category: LogCategory.video,
      );
    });

    Log.info(
      '✅ PopularNowFeed: Feed built with ${state.videos.length} videos (Nostr fallback)',
      name: 'PopularNowFeedProvider',
      category: LogCategory.video,
    );

    return state;
  }

  /// Load more historical events
  Future<void> loadMore() async {
    final currentState = await future;

    if (!ref.mounted || currentState.isLoadingMore) {
      return;
    }

    // Update state to show loading
    state = AsyncData(currentState.copyWith(isLoadingMore: true));

    try {
      // If using REST API, load more from there
      if (_usingRestApi) {
        final analyticsService = ref.read(analyticsApiServiceProvider);
        final currentCount = currentState.videos.length;
        final newLimit = currentCount + 50;

        final apiVideos = await analyticsService.getRecentVideos(
          limit: newLimit,
          forceRefresh: true,
        );

        if (!ref.mounted) return;

        final filteredVideos = apiVideos
            .where((v) => v.isSupportedOnCurrentPlatform)
            .toList();
        final newEventsLoaded = filteredVideos.length - currentCount;

        Log.info(
          '🆕 PopularNowFeed: Loaded $newEventsLoaded new videos from REST API (total: ${filteredVideos.length})',
          name: 'PopularNowFeedProvider',
          category: LogCategory.video,
        );

        state = AsyncData(
          VideoFeedState(
            videos: filteredVideos,
            hasMoreContent: newEventsLoaded > 0,
            isLoadingMore: false,
            lastUpdated: DateTime.now(),
          ),
        );
        return;
      }

      // Nostr mode - load more from relay
      final videoEventService = ref.read(videoEventServiceProvider);
      final eventCountBefore = videoEventService.getEventCount(
        SubscriptionType.popularNow,
      );

      // Load more events for popularNow subscription type
      await videoEventService.loadMoreEvents(
        SubscriptionType.popularNow,
        limit: 50,
      );

      if (!ref.mounted) return;

      final eventCountAfter = videoEventService.getEventCount(
        SubscriptionType.popularNow,
      );
      final newEventsLoaded = eventCountAfter - eventCountBefore;

      Log.info(
        '🆕 PopularNowFeed: Loaded $newEventsLoaded new events from Nostr (total: $eventCountAfter)',
        name: 'PopularNowFeedProvider',
        category: LogCategory.video,
      );

      // Reset loading state - state will auto-update via listener
      final newState = await future;
      if (!ref.mounted) return;
      state = AsyncData(
        newState.copyWith(
          isLoadingMore: false,
          hasMoreContent: newEventsLoaded > 0,
        ),
      );
    } catch (e) {
      Log.error(
        '🆕 PopularNowFeed: Error loading more: $e',
        name: 'PopularNowFeedProvider',
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

  /// Refresh state from VideoEventService without re-subscribing to relay
  /// Call this after a video is updated to sync the provider's state
  /// Only applies to Nostr mode - REST API mode re-fetches on refresh()
  void refreshFromService() {
    // Skip if using REST API - refreshFromService is only for Nostr mode
    if (_usingRestApi) return;

    final videoEventService = ref.read(videoEventServiceProvider);
    var updatedVideos = videoEventService.popularNowVideos.toList();

    // Apply same filtering as build()
    updatedVideos = updatedVideos
        .where((v) => v.isSupportedOnCurrentPlatform)
        .toList();

    // Sort by timestamp (newest first)
    updatedVideos.sort((a, b) {
      final timeCompare = b.timestamp.compareTo(a.timestamp);
      if (timeCompare != 0) return timeCompare;
      return a.id.compareTo(b.id);
    });

    state = AsyncData(
      VideoFeedState(
        videos: updatedVideos,
        hasMoreContent: updatedVideos.length >= 10,
        isLoadingMore: false,
        lastUpdated: DateTime.now(),
      ),
    );
  }

  /// Refresh the feed - invalidates self to re-run build() with REST API fallback logic
  Future<void> refresh() async {
    Log.info(
      '🆕 PopularNowFeed: Refreshing feed (will try REST API first)',
      name: 'PopularNowFeedProvider',
      category: LogCategory.video,
    );

    // If using REST API, try to refresh from there first
    if (_usingRestApi) {
      try {
        final analyticsService = ref.read(analyticsApiServiceProvider);
        final apiVideos = await analyticsService.getRecentVideos(
          limit: 100,
          forceRefresh: true,
        );

        if (apiVideos.isNotEmpty) {
          final filteredVideos = apiVideos
              .where((v) => v.isSupportedOnCurrentPlatform)
              .toList();

          state = AsyncData(
            VideoFeedState(
              videos: filteredVideos,
              hasMoreContent: filteredVideos.length >= 50,
              isLoadingMore: false,
              lastUpdated: DateTime.now(),
            ),
          );

          Log.info(
            '✅ PopularNowFeed: Refreshed ${filteredVideos.length} videos from REST API',
            name: 'PopularNowFeedProvider',
            category: LogCategory.video,
          );
          return;
        }
      } catch (e) {
        Log.warning(
          '🆕 PopularNowFeed: REST API refresh failed, falling back to Nostr',
          name: 'PopularNowFeedProvider',
          category: LogCategory.video,
        );
      }
    }

    // Invalidate to re-run build() which will try REST API then Nostr
    ref.invalidateSelf();
  }
}

/// Provider to check if popularNow feed is loading
@riverpod
bool popularNowFeedLoading(Ref ref) {
  final asyncState = ref.watch(popularNowFeedProvider);
  if (asyncState.isLoading) return true;

  final state = asyncState.hasValue ? asyncState.value : null;
  if (state == null) return false;

  return state.isLoadingMore;
}

/// Provider to get current popularNow feed video count
@riverpod
int popularNowFeedCount(Ref ref) {
  final asyncState = ref.watch(popularNowFeedProvider);
  return asyncState.hasValue ? (asyncState.value?.videos.length ?? 0) : 0;
}
