// ABOUTME: Popular Videos tab widget showing trending videos sorted by loop count
// ABOUTME: Uses REST API (sort=loops) with Nostr fallback for accurate loop-based sorting

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/providers/popular_videos_feed_provider.dart';
import 'package:openvine/screens/fullscreen_video_feed_screen.dart';
import 'package:openvine/services/top_hashtags_service.dart';
import 'package:openvine/services/screen_analytics_service.dart';
import 'package:openvine/services/feed_performance_tracker.dart';
import 'package:openvine/services/error_analytics_tracker.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/composable_video_grid.dart';
import 'package:openvine/widgets/trending_hashtags_section.dart';

/// Tab widget displaying popular/trending videos sorted by loop count.
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
    // Use popularVideosFeedProvider which tries REST API (sort=loops) first,
    // then falls back to Nostr if unavailable
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
      return const _PopularVideosErrorState();
    }

    // Only show loading if we truly have no data yet
    _trackLoadingState();
    return const _PopularVideosLoadingState();
  }

  Widget _buildDataState(List<VideoEvent> videos) {
    // Videos are already sorted by loops from the provider (REST API or Nostr fallback)
    // and filtered for platform compatibility

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

    return _PopularVideosTrendingContent(videos: videos);
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

/// Content widget displaying trending hashtags and video grid
class _PopularVideosTrendingContent extends ConsumerWidget {
  const _PopularVideosTrendingContent({required this.videos});

  final List<VideoEvent> videos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hashtags = TopHashtagsService.instance.getTopHashtags(limit: 20);

    return Column(
      children: [
        TrendingHashtagsSection(
          hashtags: hashtags,
          isLoading: !TopHashtagsService.instance.isLoaded,
        ),
        Expanded(
          child: ComposableVideoGrid(
            videos: videos,
            thumbnailAspectRatio: 0.8,
            onVideoTap: (videoList, index) {
              Log.info(
                '🎯 PopularVideosTab TAP: gridIndex=$index, '
                'videoId=${videoList[index].id}',
                category: LogCategory.video,
              );
              // Navigate to fullscreen video feed
              context.push(
                FullscreenVideoFeedScreen.path,
                extra: FullscreenVideoFeedArgs(
                  source: StaticFeedSource(videoList),
                  initialIndex: index,
                  contextTitle: 'Popular Videos',
                ),
              );
            },
            onRefresh: () async {
              Log.info(
                '🔄 PopularVideosTab: Refreshing',
                category: LogCategory.video,
              );
              await ref.read(popularVideosFeedProvider.notifier).refresh();
            },
            emptyBuilder: () => const _PopularVideosEmptyState(),
          ),
        ),
      ],
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
          Icon(Icons.video_library, size: 64, color: VineTheme.secondaryText),
          const SizedBox(height: 16),
          Text(
            'No videos in Popular Videos',
            style: TextStyle(
              color: VineTheme.primaryText,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Check back later for new content',
            style: TextStyle(color: VineTheme.secondaryText, fontSize: 14),
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
          Icon(Icons.error, size: 64, color: VineTheme.likeRed),
          const SizedBox(height: 16),
          Text(
            'Failed to load trending videos',
            style: TextStyle(color: VineTheme.likeRed, fontSize: 18),
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
    return const Center(child: BrandedLoadingIndicator(size: 80));
  }
}
