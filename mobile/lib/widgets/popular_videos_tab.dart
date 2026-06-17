// ABOUTME: Popular Videos tab widget showing videos with the highest current watch volume
// ABOUTME: Uses REST API (sort=watching) with Nostr fallback (NIP-50 sort:hot) for active-watch ranking

import 'dart:async';

import 'package:analytics/analytics.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:feed_repository/feed_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/feed_repository_provider.dart';
import 'package:openvine/providers/popular_videos_feed_provider.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/services/top_hashtags_service.dart';
import 'package:openvine/services/view_event_publisher.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/composable_video_grid.dart';
import 'package:openvine/widgets/feed_refresh_control.dart';
import 'package:openvine/widgets/scroll_to_hide_mixin.dart';
import 'package:openvine/widgets/trending_hashtags_section.dart';
import 'package:unified_logger/unified_logger.dart';

/// Tab widget displaying popular videos by current watch volume.
///
/// Handles its own:
/// - Riverpod provider watching (videoEventsProvider)
/// - Analytics tracking (optional, for testability)
/// - Video sorting cache
/// - Loading/error/data states
/// - Full screen video navigation on tap
class PopularVideosTab extends ConsumerStatefulWidget {
  const PopularVideosTab({
    super.key,
    this.screenAnalytics,
    this.feedTracker,
    this.errorTracker,
  });

  /// Optional analytics services (for testing, defaults to singletons)
  final ScreenAnalyticsService? screenAnalytics;
  final FeedPerformanceTracker? feedTracker;
  final ErrorAnalyticsTracker? errorTracker;

  @override
  ConsumerState<PopularVideosTab> createState() => _PopularVideosTabState();
}

class _PopularVideosTabState extends ConsumerState<PopularVideosTab> {
  // Analytics services - use provided or create defaults
  late final ScreenAnalyticsService? _screenAnalytics;
  late final FeedPerformanceTracker? _feedTracker;
  late final ErrorAnalyticsTracker? _errorTracker;
  DateTime? _feedLoadStartTime;

  @override
  void initState() {
    super.initState();
    _screenAnalytics = widget.screenAnalytics;
    _feedTracker = widget.feedTracker;
    _errorTracker = widget.errorTracker;
  }

  @override
  Widget build(BuildContext context) {
    // Use popularVideosFeedProvider which tries REST API (sort=watching) first,
    // then falls back to Nostr (NIP-50 sort:hot) if unavailable.
    final feedAsync = ref.watch(popularVideosFeedProvider);

    Log.debug(
      '🔍 PopularVideosTab: AsyncValue state - isLoading: ${feedAsync.isLoading}, '
      'hasValue: ${feedAsync.hasValue}, hasError: ${feedAsync.hasError}',
      name: 'PopularVideosTab',
      category: LogCategory.video,
    );

    // Track feed loading start
    if (feedAsync.isLoading && _feedLoadStartTime == null) {
      _feedLoadStartTime = DateTime.now();
      _feedTracker?.startFeedLoad('popular');
    }

    // CRITICAL: Check hasValue FIRST before isLoading
    if (feedAsync.hasValue && feedAsync.value != null) {
      return _buildDataState(feedAsync.value!.videos);
    }

    if (feedAsync.hasError) {
      _trackErrorState(feedAsync.error);
      return RefreshableFeedStateView(
        onRefresh: _refreshPopularVideos,
        child: const _PopularVideosErrorState(),
      );
    }

    // Only show loading if we truly have no data yet
    _trackLoadingState();
    return const _PopularVideosLoadingState();
  }

  Future<void> _refreshPopularVideos() async {
    await ref.read(popularVideosFeedProvider.notifier).refresh();
  }

  Widget _buildDataState(List<VideoEvent> videos) {
    // Videos are already sorted by current watch volume from the provider
    // (REST API sort=watching, or NIP-50 sort:hot fallback) and filtered for
    // platform compatibility

    Log.info(
      '✅ PopularVideosTab: Data state - ${videos.length} videos '
      '(top loops: ${videos.isNotEmpty ? videos.first.originalLoops ?? 0 : 0})',
      name: 'PopularVideosTab',
      category: LogCategory.video,
    );

    // Track feed loaded with videos
    if (_feedLoadStartTime != null) {
      _feedTracker?.markFirstVideosReceived('popular', videos.length);
      _feedTracker?.markFeedDisplayed('popular', videos.length);
      _screenAnalytics?.markDataLoaded(
        'explore_screen',
        dataMetrics: {'tab': 'popular', 'video_count': videos.length},
      );
      _feedLoadStartTime = null;
    }

    // Track empty feed
    if (videos.isEmpty) {
      _feedTracker?.trackEmptyFeed('popular');
    }

    // Get the feed state for pagination info
    final feedState = ref.watch(popularVideosFeedProvider).value;
    return _PopularVideosTrendingContent(
      videos: videos,
      isLoadingMore: feedState?.isLoadingMore ?? false,
      hasMoreContent: feedState?.hasMoreContent ?? false,
    );
  }

  void _trackErrorState(Object? error) {
    Log.error(
      '❌ PopularVideosTab: Error state - $error',
      name: 'PopularVideosTab',
      category: LogCategory.video,
    );

    final loadTime = _feedLoadStartTime != null
        ? DateTime.now().difference(_feedLoadStartTime!).inMilliseconds
        : null;
    _feedTracker?.trackFeedError(
      'popular',
      errorType: 'load_failed',
      errorMessage: error.toString(),
    );
    _errorTracker?.trackFeedLoadError(
      feedType: 'popular',
      errorType: 'provider_error',
      errorMessage: error.toString(),
      loadTimeMs: loadTime,
    );
    _feedLoadStartTime = null;
  }

  void _trackLoadingState() {
    Log.info(
      '⏳ PopularVideosTab: Showing loading indicator',
      name: 'PopularVideosTab',
      category: LogCategory.video,
    );

    if (_feedLoadStartTime != null) {
      final elapsed = DateTime.now()
          .difference(_feedLoadStartTime!)
          .inMilliseconds;
      if (elapsed > 5000) {
        _errorTracker?.trackSlowOperation(
          operation: 'popular_feed_load',
          durationMs: elapsed,
          thresholdMs: 5000,
          location: 'explore_popular',
        );
      }
    }
  }
}

/// Content widget displaying trending hashtags and video grid.
///
/// Hashtags push up as user scrolls down (1:1 with scroll distance).
/// When scrolling up, hashtags slide back in as an overlay with animation.
class _PopularVideosTrendingContent extends ConsumerStatefulWidget {
  const _PopularVideosTrendingContent({
    required this.videos,
    required this.isLoadingMore,
    required this.hasMoreContent,
  });

  final List<VideoEvent> videos;
  final bool isLoadingMore;
  final bool hasMoreContent;

  @override
  ConsumerState<_PopularVideosTrendingContent> createState() =>
      _PopularVideosTrendingContentState();
}

class _PopularVideosTrendingContentState
    extends ConsumerState<_PopularVideosTrendingContent>
    with ScrollToHideMixin {
  @override
  Widget build(BuildContext context) {
    final popularVideosFeedNotifier = ref.read(
      popularVideosFeedProvider.notifier,
    );
    final hashtags = TopHashtagsService.instance.getTopHashtags(limit: 20);

    measureHeaderHeight();

    return Stack(
      children: [
        // Grid takes full space
        Positioned.fill(
          child: NotificationListener<ScrollNotification>(
            onNotification: handleScrollNotification,
            child: ComposableVideoGrid(
              videos: widget.videos,
              useMasonryLayout: true,
              // Explore grids are edge-to-edge; the 4px gap between columns
              // comes from `crossAxisSpacing` inside ComposableVideoGrid, not
              // from outer side padding.
              padding: EdgeInsets.only(
                bottom: 4,
                top: headerHeight > 0 ? headerHeight + 4 : 4,
              ),
              onVideoTap: (videoList, index) {
                Log.info(
                  '🎯 PopularVideosTab TAP: gridIndex=$index, '
                  'videoId=${videoList[index].id}',
                  category: LogCategory.video,
                );
                context.push(
                  PooledFullscreenVideoFeedScreen.path,
                  extra: PooledFullscreenVideoFeedArgs(
                    source: const PopularViewSource(),
                    feedRepository: ref.read(feedRepositoryProvider),
                    initialIndex: index,
                    initialVideoId: videoList[index].id,
                    contextTitle: context.l10n.popularVideosContextTitle,
                    trafficSource: ViewTrafficSource.discoveryPopular,
                  ),
                );
              },
              onRefresh: () async {
                Log.info(
                  '🔄 PopularVideosTab: Refreshing',
                  category: LogCategory.video,
                );
                await popularVideosFeedNotifier.refresh();
              },
              onLoadMore: () async {
                Log.info(
                  '📜 PopularVideosTab: Loading more',
                  category: LogCategory.video,
                );
                await popularVideosFeedNotifier.loadMore();
              },
              isLoadingMore: widget.isLoadingMore,
              hasMoreContent: widget.hasMoreContent,
              emptyBuilder: () => const _PopularVideosEmptyState(),
            ),
          ),
        ),
        // Hashtags overlay on top, animated when returning
        AnimatedPositioned(
          duration: headerFullyHidden
              ? const Duration(milliseconds: 250)
              : Duration.zero,
          curve: Curves.easeOut,
          top: headerOffset,
          left: 0,
          right: 0,
          child: TrendingHashtagsSection(
            key: headerKey,
            hashtags: hashtags,
            isLoading: !TopHashtagsService.instance.isLoaded,
            leading: const _PopularFeedVariantToggle(),
          ),
        ),
      ],
    );
  }
}

class _PopularFeedVariantToggle extends ConsumerWidget {
  const _PopularFeedVariantToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(popularVideosVariantProvider);

    return Semantics(
      label: context.l10n.popularVideosFeedSourceLabel,
      child: Container(
        key: const Key('popular-feed-variant-toggle'),
        height: 32,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: VineTheme.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: VineTheme.outlineMuted),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PopularFeedVariantButton(
              label: context.l10n.categoryGallerySortNew,
              variant: PopularVideosVariant.native,
              selected: selected == PopularVideosVariant.native,
            ),
            _PopularFeedVariantButton(
              label: context.l10n.categoryGallerySortClassic,
              variant: PopularVideosVariant.classic,
              selected: selected == PopularVideosVariant.classic,
            ),
          ],
        ),
      ),
    );
  }
}

class _PopularFeedVariantButton extends ConsumerWidget {
  const _PopularFeedVariantButton({
    required this.label,
    required this.variant,
    required this.selected,
  });

  final String label;
  final PopularVideosVariant variant;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (selected) return;
          ref.read(popularVideosVariantProvider.notifier).state = variant;
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 28,
          constraints: const BoxConstraints(minWidth: 54),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: selected ? VineTheme.vineGreen : VineTheme.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: VineTheme.labelMediumFont(
              color: selected
                  ? VineTheme.primaryDarkGreen
                  : VineTheme.onSurfaceMuted55,
            ),
          ),
        ),
      ),
    );
  }
}

/// Empty state widget for PopularVideosTab
class _PopularVideosEmptyState extends StatelessWidget {
  const _PopularVideosEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.video_library,
            size: 64,
            color: VineTheme.secondaryText,
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.popularVideosEmptyTitle,
            style: const TextStyle(
              color: VineTheme.primaryText,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.popularVideosEmptySubtitle,
            style: const TextStyle(
              color: VineTheme.secondaryText,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

/// Error state widget for PopularVideosTab
class _PopularVideosErrorState extends StatelessWidget {
  const _PopularVideosErrorState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, size: 64, color: VineTheme.likeRed),
          const SizedBox(height: 16),
          Text(
            context.l10n.popularVideosErrorTitle,
            style: const TextStyle(color: VineTheme.likeRed, fontSize: 18),
          ),
        ],
      ),
    );
  }
}

/// Loading state widget for PopularVideosTab
class _PopularVideosLoadingState extends StatelessWidget {
  const _PopularVideosLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(child: BrandedLoadingIndicator());
  }
}
