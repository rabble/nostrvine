// ABOUTME: Popular Videos feed provider showing age-decayed popular videos.
// ABOUTME: Uses VideosRepository's v2 Popular path for Explore pagination.

import 'package:flutter_riverpod/legacy.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
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
import 'package:videos_repository/videos_repository.dart';

part 'popular_videos_feed_provider.g.dart';

/// Selected source for the Popular tab's v2 feed.
final popularVideosVariantProvider = StateProvider<PopularVideosVariant>(
  (ref) => PopularVideosVariant.native,
);

/// Popular Videos feed provider - shows trending videos by recent engagement.
///
/// Delegates video fetching to [VideosRepository.getPopularVideos] with the
/// selected native/classic variant.
///
/// Rebuilds when:
/// - Pull to refresh
/// - appReady gate becomes true
/// - Content filter preferences change
@Riverpod(keepAlive: true)
class PopularVideosFeed extends _$PopularVideosFeed {
  String? _nextCursor;

  @override
  Future<VideoFeedState> build() async {
    // Watch content filter version — rebuilds when preferences change.
    ref.watch(contentFilterVersionProvider);
    ref.watch(divineHostFilterVersionProvider);

    // Watch blocklist version — rebuilds when block/unblock actions occur.
    ref.watch(blocklistVersionProvider);

    // Watch the user-selected native/classic split.
    final variant = ref.watch(popularVideosVariantProvider);
    _nextCursor = null;

    // Watch appReady gate
    final isAppReady = ref.watch(appReadyProvider);

    Log.info(
      'PopularVideosFeed: Building (appReady: $isAppReady, variant: ${variant.name})',
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

    return _loadFirstPage(variant);
  }

  Future<VideoFeedState> _loadFirstPage(
    PopularVideosVariant variant, {
    bool skipCache = false,
    bool preserveExistingOnError = false,
  }) async {
    try {
      final page = await _fetchFirstPage(variant, skipCache: skipCache);

      if (!ref.mounted) {
        return const VideoFeedState(videos: [], hasMoreContent: true);
      }

      if (page.videos.isNotEmpty) {
        _applyPage(page);

        final filteredVideos = _filterVideos(page.videos, variant);
        _scheduleEnrichment(filteredVideos);

        Log.info(
          'PopularVideosFeed: Got ${filteredVideos.length} trending videos',
          name: 'PopularVideosFeedProvider',
          category: LogCategory.video,
        );

        return VideoFeedState(
          videos: filteredVideos,
          hasMoreContent: _pageHasMoreContent(page),
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
      if (preserveExistingOnError) rethrow;
      return VideoFeedState(
        videos: const [],
        hasMoreContent: false,
        error: e.toString(),
      );
    }
  }

  Future<PopularVideosPage> _fetchFirstPage(
    PopularVideosVariant variant, {
    required bool skipCache,
  }) async {
    final videosRepository = ref.read(videosRepositoryProvider);
    return videosRepository.getPopularVideosPage(
      limit: AppConstants.paginationBatchSize,
      variant: variant,
      skipCache: skipCache,
    );
  }

  /// Load more videos for pagination.
  Future<void> loadMore() async {
    final currentState = await future;

    if (!ref.mounted || currentState.isLoadingMore) return;
    if (!currentState.hasMoreContent) return;

    state = AsyncData(currentState.copyWith(isLoadingMore: true));

    try {
      final variant = ref.read(popularVideosVariantProvider);
      final newVideos = await _fetchNextPage();

      if (!ref.mounted) return;

      if (newVideos.videos.isEmpty) {
        state = AsyncData(
          currentState.copyWith(hasMoreContent: false, isLoadingMore: false),
        );
        return;
      }

      _applyPage(newVideos);

      // Deduplicate against existing videos
      final existingIds = currentState.videos
          .map((v) => v.id.toLowerCase())
          .toSet();
      final dedupedNew = newVideos.videos
          .where((v) => !existingIds.contains(v.id.toLowerCase()))
          .toList();

      final filteredNew = _filterVideos(dedupedNew, variant);

      if (filteredNew.isEmpty) {
        state = AsyncData(
          currentState.copyWith(
            hasMoreContent: _pageHasMoreContent(newVideos),
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
          hasMoreContent: _pageHasMoreContent(newVideos),
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

  Future<PopularVideosPage> _fetchNextPage() async {
    final videosRepository = ref.read(videosRepositoryProvider);
    return videosRepository.getPopularVideosPage(
      limit: AppConstants.paginationBatchSize,
      cursor: _nextCursor,
      variant: ref.read(popularVideosVariantProvider),
    );
  }

  /// Refresh the feed while preserving visible videos during revalidation.
  Future<void> refresh() async {
    Log.info(
      'PopularVideosFeed: Refreshing',
      name: 'PopularVideosFeedProvider',
      category: LogCategory.video,
    );

    final variant = ref.read(popularVideosVariantProvider);
    await staleWhileRevalidate(
      getCurrentState: () => state,
      isMounted: () => ref.mounted,
      setState: (s) => state = s,
      fetchFresh: () => _loadFirstPage(
        variant,
        skipCache: true,
        preserveExistingOnError: true,
      ),
    );
  }

  /// Applies platform compatibility, content preference,
  /// and blocked user filters.
  List<VideoEvent> _filterVideos(
    List<VideoEvent> videos,
    PopularVideosVariant variant,
  ) {
    final videoEventService = ref.read(videoEventServiceProvider);
    final blocklistRepository = ref.read(contentBlocklistRepositoryProvider);
    final compatibleVideos = videos
        .where((v) => v.isSupportedOnCurrentPlatform)
        .where((v) => !blocklistRepository.shouldFilterFromFeeds(v.pubkey));
    final platformVideos = variant == PopularVideosVariant.native
        ? compatibleVideos.where((v) => !v.isOriginalVine)
        : compatibleVideos;
    return videoEventService.filterVideoList(platformVideos.toList());
  }

  void _applyPage(PopularVideosPage page) {
    _nextCursor = page.nextCursor;
  }

  bool _pageHasMoreContent(PopularVideosPage page) {
    return page.hasMore;
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
