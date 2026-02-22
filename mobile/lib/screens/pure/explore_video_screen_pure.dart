// ABOUTME: Pure explore video screen using VideoFeedItem directly in PageView
// ABOUTME: Simplified implementation with direct VideoFeedItem usage

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/mixins/pagination_mixin.dart';
import 'package:openvine/mixins/video_prefetch_mixin.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/individual_video_providers.dart';
import 'package:openvine/screens/explore_screen.dart';
import 'package:openvine/utils/quiet_hours.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/services/view_event_publisher.dart';
import 'package:openvine/widgets/video_feed_item/video_feed_item.dart';

/// Pure explore video screen using VideoFeedItem directly in PageView
class ExploreVideoScreenPure extends ConsumerStatefulWidget {
  const ExploreVideoScreenPure({
    super.key,
    required this.startingVideo,
    required this.videoList,
    required this.contextTitle,
    this.startingIndex,
    this.onLoadMore,
    this.onNavigate,
    this.useLocalActiveState = false,
    this.trafficSource = ViewTrafficSource.unknown,
    this.sourceDetail,
  });

  final VideoEvent startingVideo;
  final List<VideoEvent> videoList;
  final String contextTitle;
  final int? startingIndex;
  final VoidCallback? onLoadMore;
  final void Function(int index)? onNavigate;

  /// When true, manages active video state locally instead of via URL routing.
  /// Used for custom contexts like lists that don't have router support.
  /// When true, videos will auto-play based on page position without URL changes.
  final bool useLocalActiveState;

  /// Traffic source for view event analytics.
  final ViewTrafficSource trafficSource;

  /// Additional context for the traffic source (e.g., hashtag name).
  final String? sourceDetail;

  @override
  ConsumerState<ExploreVideoScreenPure> createState() =>
      _ExploreVideoScreenPureState();
}

class _ExploreVideoScreenPureState extends ConsumerState<ExploreVideoScreenPure>
    with PaginationMixin, VideoPrefetchMixin {
  late int _initialIndex;
  late int _currentPage; // Track current page for local active state management
  late PageController _pageController;
  bool _awaitingLoadMoreConfirmation = false;
  bool _isLoadingMoreFromNudge = false;
  int? _lastPromptedVideoCount;
  bool _shouldResumeAfterBreakPrompt = false;

  @override
  void initState() {
    super.initState();

    // Find starting video index in the tab-specific list passed from parent
    _initialIndex =
        widget.startingIndex ??
        widget.videoList.indexWhere(
          (video) => video.id == widget.startingVideo.id,
        );

    if (_initialIndex == -1) {
      _initialIndex = 0; // Fallback to first video
    }

    _currentPage = _initialIndex;
    _pageController = PageController(initialPage: _initialIndex);

    Log.info(
      '🎯 ExploreVideoScreenPure: Initialized with ${widget.videoList.length} videos, starting at index $_initialIndex, useLocalActiveState=${widget.useLocalActiveState}',
      category: LogCategory.video,
    );
  }

  @override
  void didUpdateWidget(covariant ExploreVideoScreenPure oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.videoList.length != oldWidget.videoList.length) {
      _awaitingLoadMoreConfirmation = false;
      _isLoadingMoreFromNudge = false;
      _lastPromptedVideoCount = null;
      _shouldResumeAfterBreakPrompt = false;
    }
  }

  Future<void> _pauseCurrentVideoForBreakPrompt(List<VideoEvent> videos) async {
    if (_currentPage < 0 || _currentPage >= videos.length) return;

    final video = videos[_currentPage];
    final videoUrl = video.videoUrl;
    if (videoUrl == null || videoUrl.isEmpty) return;

    final params = VideoControllerParams(
      videoId: video.id,
      videoUrl: videoUrl,
      videoEvent: video,
    );
    final controller = ref.read(individualVideoControllerProvider(params));
    _shouldResumeAfterBreakPrompt = controller.value.isPlaying;
    if (_shouldResumeAfterBreakPrompt) {
      await safePause(controller, video.id);
    }
  }

  Future<void> _resumeCurrentVideoAfterBreakPrompt(
    List<VideoEvent> videos,
  ) async {
    if (!_shouldResumeAfterBreakPrompt) return;
    if (_currentPage < 0 || _currentPage >= videos.length) return;

    final video = videos[_currentPage];
    final videoUrl = video.videoUrl;
    if (videoUrl == null || videoUrl.isEmpty) return;

    final params = VideoControllerParams(
      videoId: video.id,
      videoUrl: videoUrl,
      videoEvent: video,
    );
    final controller = ref.read(individualVideoControllerProvider(params));
    await safePlay(controller, video.id);
    _shouldResumeAfterBreakPrompt = false;
  }

  Future<void> _dismissBreakPrompt(List<VideoEvent> videos) async {
    if (_awaitingLoadMoreConfirmation) {
      setState(() {
        _awaitingLoadMoreConfirmation = false;
      });
    }
    await _resumeCurrentVideoAfterBreakPrompt(videos);
  }

  void _showBreakPrompt(List<VideoEvent> videos) {
    if (_awaitingLoadMoreConfirmation ||
        _lastPromptedVideoCount == videos.length) {
      return;
    }

    setState(() {
      _awaitingLoadMoreConfirmation = true;
    });
    _pauseCurrentVideoForBreakPrompt(videos);
  }

  Future<void> _triggerLoadMore(List<VideoEvent> videos) async {
    final onLoadMore = widget.onLoadMore;
    if (onLoadMore == null || _isLoadingMoreFromNudge) return;

    await _resumeCurrentVideoAfterBreakPrompt(videos);

    final currentVideoCount = videos.length;
    setState(() {
      _awaitingLoadMoreConfirmation = false;
      _isLoadingMoreFromNudge = true;
      _lastPromptedVideoCount = currentVideoCount;
    });

    onLoadMore();

    // Fallback reset in case source state doesn't change quickly.
    Future<void>.delayed(const Duration(seconds: 4), () {
      if (!mounted) return;
      if (_isLoadingMoreFromNudge) {
        setState(() {
          _isLoadingMoreFromNudge = false;
        });
      }
    });
  }

  bool _isForwardSwipeAtFeedEnd(ScrollNotification notification) {
    final isAtMaxExtent =
        notification.metrics.pixels >=
        notification.metrics.maxScrollExtent - 0.5;

    if (!isAtMaxExtent) return false;

    if (notification is OverscrollNotification) {
      return notification.overscroll > 0;
    }
    if (notification is ScrollUpdateNotification) {
      return (notification.scrollDelta ?? 0) > 0;
    }
    if (notification is UserScrollNotification) {
      return notification.direction == ScrollDirection.reverse;
    }

    return false;
  }

  @override
  void dispose() {
    _pageController.dispose();
    Log.info(
      '🛑 ExploreVideoScreenPure disposing',
      name: 'ExploreVideoScreen',
      category: LogCategory.video,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use the tab-specific sorted list from parent (maintains sort order from grid)
    // Apply broken video filter if available
    final brokenTrackerAsync = ref.watch(brokenVideoTrackerProvider);

    final videos = brokenTrackerAsync.maybeWhen(
      data: (tracker) => widget.videoList
          .where((video) => !tracker.isVideoBroken(video.id))
          .toList(),
      orElse: () => widget.videoList, // No filtering if tracker not ready
    );

    if (videos.isEmpty) {
      return const Center(child: Text('No videos available'));
    }

    final nudgesEnabled = ref.watch(
      isFeatureEnabledProvider(FeatureFlag.feedBreakNudges),
    );
    final showEndNudgeModal = nudgesEnabled;
    final useSleepCopy = isQuietHoursNow();

    // Use tab-specific video list from parent (preserves grid sort order)
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              // On the last video, a second swipe up produces overscroll.
              if (showEndNudgeModal &&
                  _currentPage >= videos.length - 1 &&
                  _isForwardSwipeAtFeedEnd(notification)) {
                if (!_awaitingLoadMoreConfirmation &&
                    _lastPromptedVideoCount != videos.length) {
                  _showBreakPrompt(videos);
                } else if (_awaitingLoadMoreConfirmation &&
                    widget.onLoadMore != null) {
                  _triggerLoadMore(videos);
                }
              }
              return false;
            },
            child: PageView.builder(
              itemCount: videos.length,
              controller: _pageController,
              scrollDirection: Axis.vertical,
              onPageChanged: (index) {
                Log.debug(
                  '📄 Page changed to index $index (${videos[index].id}...)',
                  name: 'ExploreVideoScreen',
                  category: LogCategory.video,
                );

                _currentPage = index;
                if (widget.useLocalActiveState) {
                  setState(() {});
                }

                // Update URL to trigger reactive video playback via router
                // Use custom navigation callback if provided, otherwise default to explore
                // Skip URL navigation when using local active state
                if (widget.onNavigate != null) {
                  widget.onNavigate!(index);
                } else if (!widget.useLocalActiveState) {
                  context.go(ExploreScreen.pathForIndex(index));
                }

                // Trigger pagination behavior
                final onLoadMore = widget.onLoadMore;
                if (onLoadMore != null && !showEndNudgeModal) {
                  checkForPagination(
                    currentIndex: index,
                    totalItems: videos.length,
                    onLoadMore: onLoadMore,
                  );
                }
                if (showEndNudgeModal) {
                  final isAtEnd = index >= videos.length - 1;
                  if (!isAtEnd && _awaitingLoadMoreConfirmation) {
                    _dismissBreakPrompt(videos);
                  }
                }

                // Prefetch videos around current index
                checkForPrefetch(currentIndex: index, videos: videos);

                // Pre-initialize controllers for adjacent videos
                preInitializeControllers(
                  ref: ref,
                  currentIndex: index,
                  videos: videos,
                );

                // Dispose controllers outside the keep range to free memory
                disposeControllersOutsideRange(
                  ref: ref,
                  currentIndex: index,
                  videos: videos,
                );
              },
              itemBuilder: (context, index) {
                return VideoFeedItem(
                  key: ValueKey('video-${videos[index].id}'),
                  video: videos[index],
                  index: index,
                  hasBottomNavigation: false,
                  contextTitle: widget.contextTitle,
                  trafficSource: widget.trafficSource,
                  sourceDetail: widget.sourceDetail,
                  // When using local active state, override provider-based activation
                  isActiveOverride: widget.useLocalActiveState
                      ? (_currentPage == index)
                      : null,
                  disableTapNavigation: widget.useLocalActiveState,
                );
              },
            ),
          ),
          if (showEndNudgeModal &&
              _awaitingLoadMoreConfirmation &&
              _currentPage >= videos.length - 1)
            _EndOfFeedNudgeOverlay(
              useSleepCopy: useSleepCopy,
              isLoadingMore: _isLoadingMoreFromNudge,
              showLoadMoreAction: widget.onLoadMore != null,
              onShowMore: () => _triggerLoadMore(videos),
              onDismiss: () => _dismissBreakPrompt(videos),
            ),
        ],
      ),
    );
  }
}

class _EndOfFeedNudgeOverlay extends StatelessWidget {
  const _EndOfFeedNudgeOverlay({
    required this.useSleepCopy,
    required this.isLoadingMore,
    required this.showLoadMoreAction,
    required this.onShowMore,
    required this.onDismiss,
  });

  final bool useSleepCopy;
  final bool isLoadingMore;
  final bool showLoadMoreAction;
  final VoidCallback onShowMore;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final title = useSleepCopy
        ? "You've watched a lot tonight."
        : "You've watched a lot of videos...";
    final subtitle = useSleepCopy
        ? 'End of feed. Time to sleep and make tomorrow.'
        : 'Now go MAKE some.';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: (details) {
        if ((details.primaryDelta ?? 0) > 14) {
          onDismiss();
        }
      },
      onVerticalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) > 220) {
          onDismiss();
        }
      },
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.55),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.84),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.greenAccent.withValues(alpha: 0.45),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.local_florist, color: Colors.greenAccent),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Record one quick idea while it is fresh.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: onDismiss,
                          child: const Text('Keep Watching'),
                        ),
                        if (showLoadMoreAction) ...[
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: isLoadingMore ? null : onShowMore,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.greenAccent,
                              side: const BorderSide(color: Colors.greenAccent),
                            ),
                            child: isLoadingMore
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Show More'),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Swipe down to return to the video.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.62),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
