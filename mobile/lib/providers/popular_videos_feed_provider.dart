// ABOUTME: Popular Videos feed provider showing trending videos (recent engagement)
// ABOUTME: Tries Funnelcake REST API (sort=trending) first, falls back to Nostr if unavailable

import 'package:models/models.dart' hide LogCategory;
import 'package:nostr_sdk/nostr_sdk.dart' show Filter;
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/extensions/video_event_extensions.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/readiness_gate_providers.dart';
import 'package:openvine/providers/video_events_providers.dart';
import 'package:openvine/state/video_feed_state.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'popular_videos_feed_provider.g.dart';

/// Popular Videos feed provider - shows trending videos by recent engagement
///
/// Strategy: Try Funnelcake REST API first (sort=trending) for current popularity,
/// fall back to Nostr subscription with local engagement sorting if REST API is unavailable.
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
      // Preserve existing data during background — don't wipe the feed
      if (state.hasValue && state.value != null) {
        final existing = state.value!;
        if (existing.videos.isNotEmpty) {
          return existing;
        }
      }
      return VideoFeedState(
        videos: const [],
        hasMoreContent: true,
        isLoadingMore: false,
      );
    }

    // Try REST API first (use centralized availability check)
    final analyticsService = ref.read(analyticsApiServiceProvider);

    // Quick sync check: is API even configured?
    final apiConfigured = analyticsService.isAvailable;

    // If API is NOT configured, go straight to Nostr fallback
    // Otherwise, wait for the async availability check
    final funnelcakeAvailableAsync = ref.watch(funnelcakeAvailableProvider);

    // Determine if we should use Funnelcake
    final bool useFunnelcake;
    if (!apiConfigured) {
      // No API URL = definitely use Nostr
      useFunnelcake = false;
      Log.info(
        'PopularVideosFeed: No API URL configured, using Nostr',
        name: 'PopularVideosFeedProvider',
        category: LogCategory.video,
      );
    } else if (funnelcakeAvailableAsync.isLoading) {
      // API configured but still checking availability - wait for it
      Log.info(
        'PopularVideosFeed: Waiting for Funnelcake availability check...',
        name: 'PopularVideosFeedProvider',
        category: LogCategory.video,
      );
      return VideoFeedState(
        videos: const [],
        hasMoreContent: true,
        isLoadingMore: true,
      );
    } else {
      // API configured and check complete - use result
      useFunnelcake = funnelcakeAvailableAsync.asData?.value ?? false;
    }

    if (useFunnelcake) {
      Log.info(
        'PopularVideosFeed: Trying Funnelcake REST API (sort=trending)',
        name: 'PopularVideosFeedProvider',
        category: LogCategory.video,
      );

      try {
        var apiVideos = await analyticsService.getTrendingVideos(limit: 100);

        // If trending returns too few videos, supplement with recent videos
        if (apiVideos.length < 10) {
          Log.info(
            'PopularVideosFeed: Trending returned only ${apiVideos.length} videos, supplementing with recent',
            name: 'PopularVideosFeedProvider',
            category: LogCategory.video,
          );
          final recentVideos = await analyticsService.getRecentVideos(
            limit: 100,
          );
          // Merge: trending first, then recent (excluding duplicates)
          // Use case-insensitive comparison for Nostr IDs
          final existingIds = apiVideos.map((v) => v.id.toLowerCase()).toSet();
          final additionalVideos = recentVideos
              .where((v) => !existingIds.contains(v.id.toLowerCase()))
              .toList();
          apiVideos = [...apiVideos, ...additionalVideos];
        }

        if (apiVideos.isNotEmpty) {
          _usingRestApi = true;
          _nextCursor = _getOldestTimestamp(apiVideos);

          // Filter for platform compatibility
          final filteredVideos = apiVideos
              .where((v) => v.isSupportedOnCurrentPlatform)
              .toList();

          // Enrich REST API videos with Nostr tags for ProofMode badge
          final enrichedVideos = await _enrichWithNostrTags(filteredVideos);

          Log.info(
            'PopularVideosFeed: Got ${enrichedVideos.length} videos from REST API (trending + recent)',
            name: 'PopularVideosFeedProvider',
            category: LogCategory.video,
          );

          return VideoFeedState(
            videos: enrichedVideos,
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

        // Sort by likes for trending (use nostrLikeCount, fall back to originalLikes)
        filteredVideos.sort((a, b) {
          final aLikes = a.nostrLikeCount ?? a.originalLikes ?? 0;
          final bLikes = b.nostrLikeCount ?? b.originalLikes ?? 0;
          return bLikes.compareTo(aLikes);
        });

        Log.info(
          'PopularVideosFeed: Nostr fallback - ${filteredVideos.length} videos sorted by likes',
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

        final apiVideos = await analyticsService.getTrendingVideos(
          limit: 50,
          before: _nextCursor,
        );

        if (!ref.mounted) return;

        if (apiVideos.isNotEmpty) {
          // Case-insensitive deduplication for Nostr IDs
          final existingIds = currentState.videos
              .map((v) => v.id.toLowerCase())
              .toSet();
          final newVideos = apiVideos
              .where((v) => !existingIds.contains(v.id.toLowerCase()))
              .where((v) => v.isSupportedOnCurrentPlatform)
              .toList();

          _nextCursor = _getOldestTimestamp(apiVideos);

          if (newVideos.isNotEmpty) {
            // Enrich REST API videos with Nostr tags for ProofMode badge
            final enrichedNewVideos = await _enrichWithNostrTags(newVideos);
            final allVideos = [...currentState.videos, ...enrichedNewVideos];
            Log.info(
              'PopularVideosFeed: Loaded ${enrichedNewVideos.length} more videos (total: ${allVideos.length})',
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
        final apiVideos = await analyticsService.getTrendingVideos(
          limit: 100,
          forceRefresh: true,
        );

        if (!ref.mounted) return;

        if (apiVideos.isNotEmpty) {
          _nextCursor = _getOldestTimestamp(apiVideos);

          final filteredVideos = apiVideos
              .where((v) => v.isSupportedOnCurrentPlatform)
              .toList();

          // Enrich REST API videos with Nostr tags for ProofMode badge
          final enrichedVideos = await _enrichWithNostrTags(filteredVideos);

          state = AsyncData(
            VideoFeedState(
              videos: enrichedVideos,
              hasMoreContent:
                  apiVideos.length >= AppConstants.paginationBatchSize,
              isLoadingMore: false,
              lastUpdated: DateTime.now(),
            ),
          );

          Log.info(
            'PopularVideosFeed: Refreshed ${enrichedVideos.length} videos from REST API',
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

  /// Enrich REST API videos with raw Nostr tags for ProofMode/C2PA badges.
  ///
  /// REST API responses don't include the raw Nostr event tags array,
  /// so ProofMode/C2PA/verification tags are missing. This method fetches
  /// the full events from Nostr relays by ID and merges their rawTags.
  Future<List<VideoEvent>> _enrichWithNostrTags(List<VideoEvent> videos) async {
    if (videos.isEmpty) return videos;

    // Collect IDs of videos that have empty rawTags
    final idsToEnrich = videos
        .where((v) => v.rawTags.isEmpty)
        .map((v) => v.id)
        .toList();

    if (idsToEnrich.isEmpty) return videos;

    try {
      final nostrService = ref.read(nostrServiceProvider);

      // Batch query Nostr relays for the full events
      final filter = Filter(
        ids: idsToEnrich,
        kinds: [34236],
        limit: idsToEnrich.length,
      );
      final nostrEvents = await nostrService
          .queryEvents([filter])
          .timeout(const Duration(seconds: 5));

      if (nostrEvents.isEmpty) return videos;

      // Build a lookup map: event ID -> rawTags from parsed VideoEvent
      final nostrTagsMap = <String, Map<String, String>>{};
      for (final event in nostrEvents) {
        try {
          final parsed = VideoEvent.fromNostrEvent(event, permissive: true);
          if (parsed.rawTags.isNotEmpty) {
            nostrTagsMap[parsed.id] = parsed.rawTags;
          }
        } catch (_) {
          // Skip events that fail to parse
        }
      }

      if (nostrTagsMap.isEmpty) return videos;

      // Merge rawTags into REST API videos
      return videos.map((video) {
        final tags = nostrTagsMap[video.id];
        if (tags != null && tags.isNotEmpty) {
          return video.copyWith(rawTags: tags);
        }
        return video;
      }).toList();
    } catch (e) {
      // Non-fatal: return original videos if enrichment fails
      Log.warning(
        'PopularVideosFeed: Failed to enrich with Nostr tags: $e',
        name: 'PopularVideosFeedProvider',
        category: LogCategory.video,
      );
      return videos;
    }
  }
}
