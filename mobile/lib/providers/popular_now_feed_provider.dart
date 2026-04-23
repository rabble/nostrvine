// ABOUTME: PopularNow feed provider showing newest videos with REST API + Nostr fallback
// ABOUTME: Tries Funnelcake REST API first, falls back to Nostr subscription if unavailable

import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/extensions/video_event_extensions.dart';
import 'package:openvine/helpers/video_feed_builder.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/providers/feed_refresh_helpers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/readiness_gate_providers.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/services/video_filter_builder.dart';
import 'package:openvine/state/video_feed_state.dart';
import 'package:openvine/utils/video_nostr_enrichment.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:unified_logger/unified_logger.dart';

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
  int? _nextCursor; // Cursor for REST API pagination

  @override
  Future<VideoFeedState> build() async {
    // Watch content filter version — rebuilds when preferences change.
    ref.watch(contentFilterVersionProvider);
    ref.watch(divineHostFilterVersionProvider);

    // Watch blocklist version — rebuilds when block/unblock actions occur.
    ref.watch(blocklistVersionProvider);

    // Watch appReady gate - provider rebuilds when this changes
    final isAppReady = ref.watch(appReadyProvider);

    Log.info(
      '🆕 PopularNowFeed: Building feed for newest videos (appReady: $isAppReady)',
      name: 'PopularNowFeedProvider',
      category: LogCategory.video,
    );

    final videoEventService = ref.watch(videoEventServiceProvider);

    // If app is not ready, preserve existing data during background
    if (!isAppReady) {
      if (this.state.hasValue && this.state.value != null) {
        final existing = this.state.value!;
        if (existing.videos.isNotEmpty) {
          Log.info(
            '🆕 PopularNowFeed: App not ready, preserving ${existing.videos.length} cached videos',
            name: 'PopularNowFeedProvider',
            category: LogCategory.video,
          );
          return existing;
        }
      }
      Log.info(
        '🆕 PopularNowFeed: App not ready, no cached data yet',
        name: 'PopularNowFeedProvider',
        category: LogCategory.video,
      );
      return const VideoFeedState(videos: [], hasMoreContent: true);
    }

    // Read blocklist service for filtering blocked users
    final blocklistRepository = ref.read(contentBlocklistRepositoryProvider);

    // Try REST API first if available (use centralized availability check)
    final funnelcakeAvailable =
        ref.watch(funnelcakeAvailableProvider).asData?.value ?? false;
    final client = ref.read(funnelcakeApiClientProvider);
    if (funnelcakeAvailable) {
      Log.info(
        '🆕 PopularNowFeed: Trying Funnelcake REST API first',
        name: 'PopularNowFeedProvider',
        category: LogCategory.video,
      );

      try {
        final stats = await client.getRecentVideos();
        final apiVideos = stats.toVideoEvents();
        if (apiVideos.isNotEmpty) {
          _usingRestApi = true;
          // Store cursor for pagination (oldest video timestamp)
          _nextCursor = getOldestTimestamp(apiVideos);
          Log.info(
            '✅ PopularNowFeed: Got ${apiVideos.length} videos from REST API, cursor: $_nextCursor',
            name: 'PopularNowFeedProvider',
            category: LogCategory.video,
          );

          // Filter for platform compatibility, content preferences,
          // and blocked users
          final filteredVideos = videoEventService.filterVideoList(
            apiVideos
                .where((v) => v.isSupportedOnCurrentPlatform)
                .where(
                  (v) => !blocklistRepository.shouldFilterFromFeeds(v.pubkey),
                )
                .toList(),
          );

          _scheduleRestEnrichment(filteredVideos);

          return VideoFeedState(
            videos: filteredVideos,
            hasMoreContent:
                apiVideos.length >= AppConstants.paginationBatchSize,
            isInitialLoad: filteredVideos.isEmpty,
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
    _nextCursor = null;
    _builder = VideoFeedBuilder(videoEventService);

    // Configure feed for popularNow subscription type
    final config = VideoFeedConfig(
      subscriptionType: SubscriptionType.popularNow,
      subscribe: (service) async {
        await service.subscribeToVideoFeed(
          subscriptionType: SubscriptionType.popularNow,
          limit: AppConstants.paginationBatchSize,
          sortBy: VideoSortField.createdAt, // Newest videos first
        );
      },
      getVideos: (service) => service.popularNowVideos,
      filterVideos: _filterAndSortNostrVideos,
      sortVideos: (videos) => videos, // Sorting included in filter step
    );

    // Build feed using helper
    final state = await _builder!.buildFeed(config: config);

    // Check if still mounted after async gap
    if (!ref.mounted) {
      return const VideoFeedState(videos: [], hasMoreContent: false);
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
      final videoEventService = ref.read(videoEventServiceProvider);

      // If using REST API, load more using cursor-based pagination
      if (_usingRestApi) {
        final client = ref.read(funnelcakeApiClientProvider);

        Log.info(
          '🆕 PopularNowFeed: Loading more from REST API with cursor: $_nextCursor',
          name: 'PopularNowFeedProvider',
          category: LogCategory.video,
        );

        // Use cursor (before parameter) for pagination
        final stats = await client.getRecentVideos(before: _nextCursor);
        final apiVideos = stats.toVideoEvents();

        if (!ref.mounted) return;

        if (apiVideos.isNotEmpty) {
          // Deduplicate and merge (case-insensitive for Nostr IDs)
          final blocklistRepository = ref.read(
            contentBlocklistRepositoryProvider,
          );
          final existingIds = currentState.videos
              .map((v) => v.id.toLowerCase())
              .toSet();
          final newVideos = videoEventService.filterVideoList(
            apiVideos
                .where((v) => !existingIds.contains(v.id.toLowerCase()))
                .where((v) => v.isSupportedOnCurrentPlatform)
                .where(
                  (v) => !blocklistRepository.shouldFilterFromFeeds(v.pubkey),
                )
                .toList(),
          );

          // Update cursor for next pagination
          _nextCursor = getOldestTimestamp(apiVideos);

          if (newVideos.isNotEmpty) {
            final allVideos = [...currentState.videos, ...newVideos];
            Log.info(
              '🆕 PopularNowFeed: Loaded ${newVideos.length} new videos from REST API (total: ${allVideos.length})',
              name: 'PopularNowFeedProvider',
              category: LogCategory.video,
            );

            state = AsyncData(
              VideoFeedState(
                videos: allVideos,
                hasMoreContent:
                    apiVideos.length >= AppConstants.paginationBatchSize,
                lastUpdated: DateTime.now(),
              ),
            );
            _scheduleRestEnrichment(newVideos);
          } else {
            Log.info(
              '🆕 PopularNowFeed: All returned videos already in state',
              name: 'PopularNowFeedProvider',
              category: LogCategory.video,
            );
            state = AsyncData(
              currentState.copyWith(
                hasMoreContent: false,
                isLoadingMore: false,
              ),
            );
          }
        } else {
          Log.info(
            '🆕 PopularNowFeed: No more videos available from REST API',
            name: 'PopularNowFeedProvider',
            category: LogCategory.video,
          );
          state = AsyncData(
            currentState.copyWith(hasMoreContent: false, isLoadingMore: false),
          );
        }
        return;
      }

      // Nostr mode - load more from relay
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
    final updatedVideos = _filterAndSortNostrVideos(
      videoEventService.popularNowVideos.toList(),
    );

    state = AsyncData(
      VideoFeedState(
        videos: updatedVideos,
        hasMoreContent:
            updatedVideos.length >= AppConstants.hasMoreContentThreshold,
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

    final videoEventService = ref.read(videoEventServiceProvider);
    final currentState = state.value;

    if (currentState != null && ref.mounted) {
      state = AsyncData(
        currentState.copyWith(
          isRefreshing: true,
          isInitialLoad: false,
          error: null,
        ),
      );
    }

    // If using REST API, try to refresh from there first
    if (_usingRestApi) {
      try {
        final client = ref.read(funnelcakeApiClientProvider);
        final stats = await client.getRecentVideos();
        final apiVideos = stats.toVideoEvents();

        // Check if provider is still mounted after async gap
        if (!ref.mounted) return;

        if (apiVideos.isNotEmpty) {
          // Reset cursor for pagination
          _nextCursor = getOldestTimestamp(apiVideos);

          final blocklistRepository = ref.read(
            contentBlocklistRepositoryProvider,
          );
          final filteredVideos = videoEventService.filterVideoList(
            apiVideos
                .where((v) => v.isSupportedOnCurrentPlatform)
                .where(
                  (v) => !blocklistRepository.shouldFilterFromFeeds(v.pubkey),
                )
                .toList(),
          );

          state = AsyncData(
            VideoFeedState(
              videos: filteredVideos,
              hasMoreContent:
                  apiVideos.length >= AppConstants.paginationBatchSize,
              lastUpdated: DateTime.now(),
            ),
          );
          _scheduleRestEnrichment(filteredVideos);

          Log.info(
            '✅ PopularNowFeed: Refreshed ${filteredVideos.length} videos from REST API, cursor: $_nextCursor',
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

    // Reset cursor state before forced Nostr refresh
    _usingRestApi = false;
    _nextCursor = null;

    try {
      await videoEventService.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.popularNow,
        limit: AppConstants.paginationBatchSize,
        sortBy: VideoSortField.createdAt,
        force: true,
      );

      if (!ref.mounted) return;

      final refreshedVideos = _filterAndSortNostrVideos(
        videoEventService.popularNowVideos.toList(),
      );

      state = AsyncData(
        VideoFeedState(
          videos: refreshedVideos,
          hasMoreContent:
              refreshedVideos.length >= AppConstants.hasMoreContentThreshold,
          lastUpdated: DateTime.now(),
        ),
      );
    } catch (e) {
      if (!ref.mounted) return;
      if (currentState != null) {
        state = AsyncData(
          currentState.copyWith(isRefreshing: false, error: e.toString()),
        );
        return;
      }

      state = AsyncData(
        VideoFeedState(
          videos: const [],
          hasMoreContent: false,
          error: e.toString(),
        ),
      );
    }
  }

  /// Filters videos for platform compatibility, content preferences,
  /// and blocked users, then sorts by timestamp (newest first) with
  /// secondary sort by ID for stable ordering.
  List<VideoEvent> _filterAndSortNostrVideos(List<VideoEvent> videos) {
    final blocklistRepository = ref.read(contentBlocklistRepositoryProvider);
    final videoEventService = ref.read(videoEventServiceProvider);
    final filtered = videoEventService.filterVideoList(
      videos
          .where((v) => v.isSupportedOnCurrentPlatform)
          .where((v) => !blocklistRepository.shouldFilterFromFeeds(v.pubkey))
          .toList(),
    );
    filtered.sort((a, b) {
      final timeCompare = b.timestamp.compareTo(a.timestamp);
      if (timeCompare != 0) return timeCompare;
      return a.id.compareTo(b.id);
    });
    return filtered;
  }

  void _scheduleRestEnrichment(List<VideoEvent> videos) {
    if (videos.isEmpty) return;

    enrichVideosInBackground(
      videos,
      nostrService: ref.read(nostrServiceProvider),
      callerName: 'PopularNowFeedProvider',
      onEnriched: (enrichedVideos) {
        if (!ref.mounted || !_usingRestApi || !state.hasValue) return;

        final currentState = state.value;
        if (currentState == null || currentState.videos.isEmpty) return;

        final mergedVideos = mergeEnrichedVideos(
          existing: currentState.videos,
          enriched: enrichedVideos,
        );

        if (videoListsEqual(currentState.videos, mergedVideos)) {
          return;
        }

        state = AsyncData(
          currentState.copyWith(
            videos: mergedVideos,
            lastUpdated: DateTime.now(),
          ),
        );

        Log.info(
          '🆕 PopularNowFeed: Applied background Nostr enrichment to ${enrichedVideos.length} videos',
          name: 'PopularNowFeedProvider',
          category: LogCategory.video,
        );
      },
    );
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
