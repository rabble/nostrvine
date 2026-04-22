// ABOUTME: Popular Videos feed provider showing trending videos
// ABOUTME: Uses VideosRepository which tries Funnelcake, NIP-50, then
// ABOUTME: client-side engagement sorting as fallbacks.

import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/extensions/video_event_extensions.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/feed_refresh_helpers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/readiness_gate_providers.dart';
import 'package:openvine/state/video_feed_state.dart';
import 'package:openvine/utils/video_nostr_enrichment.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:unified_logger/unified_logger.dart';

part 'popular_videos_feed_provider.g.dart';

/// Popular Videos feed provider - shows trending videos by recent engagement.
///
/// Delegates video fetching to [VideosRepository.getPopularVideos], which
/// implements a 3-tier fallback: Funnelcake REST API → NIP-50 sort:hot →
/// client-side engagement sorting.
///
/// Rebuilds when:
/// - Pull to refresh
/// - appReady gate becomes true
/// - Content filter preferences change
@Riverpod(keepAlive: true)
class PopularVideosFeed extends _$PopularVideosFeed {
  int? _nextCursor;

  @override
  Future<VideoFeedState> build() async {
    _nextCursor = null;

    // Watch content filter version — rebuilds when preferences change.
    ref.watch(contentFilterVersionProvider);
    ref.watch(divineHostFilterVersionProvider);

    // Watch blocklist version — rebuilds when block/unblock actions occur.
    ref.watch(blocklistVersionProvider);

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
      return const VideoFeedState(videos: [], hasMoreContent: true);
    }

    return _loadFirstPage();
  }

  Future<VideoFeedState> _loadFirstPage() async {
    try {
      final videosRepository = ref.read(videosRepositoryProvider);
      final videos = await videosRepository.getPopularVideos(
        limit: AppConstants.paginationBatchSize,
      );

      if (!ref.mounted) {
        return const VideoFeedState(videos: [], hasMoreContent: true);
      }

      if (videos.isNotEmpty) {
        _nextCursor = getOldestTimestamp(videos);

        final filteredVideos = _filterVideos(videos);
        _scheduleEnrichment(filteredVideos);

        Log.info(
          'PopularVideosFeed: Got ${filteredVideos.length} trending videos',
          name: 'PopularVideosFeedProvider',
          category: LogCategory.video,
        );

        return VideoFeedState(
          videos: filteredVideos,
          hasMoreContent: videos.length >= AppConstants.paginationBatchSize,
          lastUpdated: DateTime.now(),
        );
      }

      Log.warning(
        'PopularVideosFeed: No videos returned',
        name: 'PopularVideosFeedProvider',
        category: LogCategory.video,
      );

      return const VideoFeedState(videos: [], hasMoreContent: false);
    } catch (e) {
      Log.error(
        'PopularVideosFeed: Error loading videos: $e',
        name: 'PopularVideosFeedProvider',
        category: LogCategory.video,
      );
      return VideoFeedState(
        videos: const [],
        hasMoreContent: false,
        error: e.toString(),
      );
    }
  }

  /// Load more videos for pagination.
  Future<void> loadMore() async {
    final currentState = await future;

    if (!ref.mounted || currentState.isLoadingMore) return;
    if (!currentState.hasMoreContent) return;

    state = AsyncData(currentState.copyWith(isLoadingMore: true));

    try {
      final videosRepository = ref.read(videosRepositoryProvider);
      final newVideos = await videosRepository.getPopularVideos(
        limit: 50,
        until: _nextCursor,
      );

      if (!ref.mounted) return;

      if (newVideos.isEmpty) {
        state = AsyncData(
          currentState.copyWith(hasMoreContent: false, isLoadingMore: false),
        );
        return;
      }

      _nextCursor = getOldestTimestamp(newVideos);

      // Deduplicate against existing videos
      final existingIds = currentState.videos
          .map((v) => v.id.toLowerCase())
          .toSet();
      final dedupedNew = newVideos
          .where((v) => !existingIds.contains(v.id.toLowerCase()))
          .toList();

      final filteredNew = _filterVideos(dedupedNew);

      if (filteredNew.isEmpty) {
        state = AsyncData(
          currentState.copyWith(
            hasMoreContent:
                newVideos.length >= AppConstants.paginationBatchSize,
            isLoadingMore: false,
          ),
        );
        return;
      }
      final allVideos = [...currentState.videos, ...filteredNew];

      Log.info(
        'PopularVideosFeed: Loaded ${filteredNew.length} more videos '
        '(total: ${allVideos.length})',
        name: 'PopularVideosFeedProvider',
        category: LogCategory.video,
      );

      state = AsyncData(
        VideoFeedState(
          videos: allVideos,
          hasMoreContent: newVideos.length >= AppConstants.paginationBatchSize,
          lastUpdated: DateTime.now(),
        ),
      );

      _scheduleEnrichment(filteredNew);
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

  /// Refresh the feed by resetting cursor and rebuilding.
  Future<void> refresh() async {
    Log.info(
      'PopularVideosFeed: Refreshing',
      name: 'PopularVideosFeedProvider',
      category: LogCategory.video,
    );

    _nextCursor = null;

    await staleWhileRevalidate(
      getCurrentState: () => state,
      isMounted: () => ref.mounted,
      setState: (s) => state = s,
      fetchFresh: _loadFirstPage,
    );
  }

  /// Applies platform compatibility, content preference,
  /// and blocked user filters.
  List<VideoEvent> _filterVideos(List<VideoEvent> videos) {
    final videoEventService = ref.read(videoEventServiceProvider);
    final blocklistRepository = ref.read(contentBlocklistRepositoryProvider);
    return videoEventService.filterVideoList(
      videos
          .where((v) => v.isSupportedOnCurrentPlatform)
          .where((v) => !blocklistRepository.shouldFilterFromFeeds(v.pubkey))
          .toList(),
    );
  }

  void _scheduleEnrichment(List<VideoEvent> videos) {
    if (videos.isEmpty) return;

    enrichVideosInBackground(
      videos,
      nostrService: ref.read(nostrServiceProvider),
      callerName: 'PopularVideosFeedProvider',
      onEnriched: (enrichedVideos) {
        if (!ref.mounted || !state.hasValue) return;

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
          'PopularVideosFeed: Applied background Nostr enrichment to ${enrichedVideos.length} videos',
          name: 'PopularVideosFeedProvider',
          category: LogCategory.video,
        );
      },
    );
  }
}
