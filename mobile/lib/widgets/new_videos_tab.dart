// ABOUTME: New Videos tab widget showing recent videos sorted by time
// ABOUTME: Extracted from ExploreScreen for better separation of concerns

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/extensions/video_event_extensions.dart';
import 'package:openvine/providers/popular_now_feed_provider.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/services/view_event_publisher.dart';
import 'package:openvine/services/error_analytics_tracker.dart';
import 'package:openvine/services/feed_performance_tracker.dart';
import 'package:openvine/services/screen_analytics_service.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/composable_video_grid.dart';
import 'package:rxdart/rxdart.dart';

/// Tab widget displaying new/recent videos sorted by time.
///
/// Handles its own:
/// - Riverpod provider watching (popularNowFeedProvider)
/// - Analytics tracking (optional, for testability)
/// - Loading/error/data states
/// - Full screen video navigation on tap
class NewVideosTab extends ConsumerStatefulWidget {
  const NewVideosTab({
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
  ConsumerState<NewVideosTab> createState() => _NewVideosTabState();
}

class _NewVideosTabState extends ConsumerState<NewVideosTab> {
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
    final popularNowAsync = ref.watch(popularNowFeedProvider);

    Log.debug(
      '🔍 NewVinesTab: AsyncValue state - isLoading: ${popularNowAsync.isLoading}, '
      'hasValue: ${popularNowAsync.hasValue}, hasError: ${popularNowAsync.hasError}',
      name: 'NewVideosTab',
      category: LogCategory.video,
    );

    // Track feed loading start
    if (popularNowAsync.isLoading && _feedLoadStartTime == null) {
      _feedLoadStartTime = DateTime.now();
      _feedTracker?.startFeedLoad('new_vines');
    }

    // CRITICAL: Check hasValue FIRST before isLoading
    // StreamProviders can have both isLoading:true and hasValue:true during rebuilds
    if (popularNowAsync.hasValue && popularNowAsync.value != null) {
      final allVideos = popularNowAsync.value!.videos;
      // Filter out WebM videos on iOS/macOS (not supported by AVPlayer)
      final videos = allVideos
          .where((v) => v.isSupportedOnCurrentPlatform)
          .toList();

      Log.info(
        '✅ NewVinesTab: Data state - ${videos.length} videos '
        '(filtered from ${allVideos.length} total)',
        name: 'NewVideosTab',
        category: LogCategory.video,
      );

      // Track feed loaded with videos
      if (_feedLoadStartTime != null) {
        _feedTracker?.markFirstVideosReceived('new_vines', videos.length);
        _feedTracker?.markFeedDisplayed('new_vines', videos.length);
        _screenAnalytics?.markDataLoaded(
          'explore_screen',
          dataMetrics: {'tab': 'new_vines', 'video_count': videos.length},
        );
        _feedLoadStartTime = null;
      }

      // Track empty feed
      if (videos.isEmpty) {
        _feedTracker?.trackEmptyFeed('new_vines');
      }

      // Get feed state for pagination info
      final feedState = popularNowAsync.value!;
      return _NewVideosContent(
        videos: videos,
        isLoadingMore: feedState.isLoadingMore,
        hasMoreContent: feedState.hasMoreContent,
      );
    }

    if (popularNowAsync.hasError) {
      _trackErrorState(popularNowAsync.error);
      return _NewVideosErrorState(error: popularNowAsync.error);
    }

    // Only show loading if we truly have no data yet
    _trackLoadingState();
    return const _NewVideosLoadingState();
  }

  void _trackLoadingState() {
    Log.info(
      '⏳ NewVinesTab: Showing loading indicator',
      name: 'NewVideosTab',
      category: LogCategory.video,
    );

    // Track slow loading after 5 seconds
    if (_feedLoadStartTime != null) {
      final elapsed = DateTime.now()
          .difference(_feedLoadStartTime!)
          .inMilliseconds;
      if (elapsed > 5000) {
        _errorTracker?.trackSlowOperation(
          operation: 'new_vines_feed_load',
          durationMs: elapsed,
          thresholdMs: 5000,
          location: 'explore_new_vines',
        );
      }
    }
  }

  void _trackErrorState(Object? error) {
    Log.error(
      '❌ NewVinesTab: Error state - $error',
      name: 'NewVideosTab',
      category: LogCategory.video,
    );

    // Track error
    final loadTime = _feedLoadStartTime != null
        ? DateTime.now().difference(_feedLoadStartTime!).inMilliseconds
        : null;
    _feedTracker?.trackFeedError(
      'new_vines',
      errorType: 'load_failed',
      errorMessage: error.toString(),
    );
    _errorTracker?.trackFeedLoadError(
      feedType: 'new_vines',
      errorType: 'provider_error',
      errorMessage: error.toString(),
      loadTimeMs: loadTime,
    );
    _feedLoadStartTime = null;
  }
}

/// Content widget displaying the video grid
class _NewVideosContent extends ConsumerStatefulWidget {
  const _NewVideosContent({
    required this.videos,
    this.isLoadingMore = false,
    this.hasMoreContent = false,
  });

  final List<VideoEvent> videos;
  final bool isLoadingMore;
  final bool hasMoreContent;

  @override
  ConsumerState<_NewVideosContent> createState() => _NewVideosContentState();
}

class _NewVideosContentState extends ConsumerState<_NewVideosContent> {
  late final StreamController<List<VideoEvent>> _videosStreamController;

  @override
  void initState() {
    super.initState();
    _videosStreamController = StreamController<List<VideoEvent>>.broadcast();
  }

  @override
  void dispose() {
    _videosStreamController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listen to provider changes and push to stream for fullscreen updates
    ref.listen(popularNowFeedProvider, (previous, next) {
      if (next.hasValue) {
        final videos = next.value!.videos
            .where((v) => v.isSupportedOnCurrentPlatform)
            .toList();
        _videosStreamController.add(videos);
      }
    });

    return ComposableVideoGrid(
      videos: widget.videos,
      useMasonryLayout: true,
      onVideoTap: (videoList, index) {
        Log.info(
          '🎯 NewVideosTab TAP: gridIndex=$index, '
          'videoId=${videoList[index].id}',
          category: LogCategory.video,
        );
        context.push(
          PooledFullscreenVideoFeedScreen.path,
          extra: PooledFullscreenVideoFeedArgs(
            videosStream: _videosStreamController.stream.startWith(videoList),
            initialIndex: index,
            onLoadMore: () =>
                ref.read(popularNowFeedProvider.notifier).loadMore(),
            contextTitle: 'New Videos',
            trafficSource: ViewTrafficSource.discoveryNew,
          ),
        );
      },
      onRefresh: () async {
        Log.info(
          '🔄 NewVideosTab: Refreshing feed',
          category: LogCategory.video,
        );
        await ref.read(popularNowFeedProvider.notifier).refresh();
      },
      onLoadMore: () async {
        Log.info('📜 NewVideosTab: Loading more', category: LogCategory.video);
        await ref.read(popularNowFeedProvider.notifier).loadMore();
      },
      isLoadingMore: widget.isLoadingMore,
      hasMoreContent: widget.hasMoreContent,
      emptyBuilder: _NewVideosEmptyState.new,
    );
  }
}

/// Empty state widget for NewVideosTab
class _NewVideosEmptyState extends StatelessWidget {
  const _NewVideosEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.video_library, size: 64, color: VineTheme.secondaryText),
          const SizedBox(height: 16),
          Text(
            'No videos in New Videos',
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

/// Error state widget for NewVideosTab
class _NewVideosErrorState extends StatelessWidget {
  const _NewVideosErrorState({required this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error, size: 64, color: VineTheme.likeRed),
          const SizedBox(height: 16),
          Text(
            'Failed to load videos',
            style: TextStyle(color: VineTheme.likeRed, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            '$error',
            style: TextStyle(color: VineTheme.secondaryText, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Loading state widget for NewVideosTab
class _NewVideosLoadingState extends StatelessWidget {
  const _NewVideosLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(child: BrandedLoadingIndicator(size: 80));
  }
}
