// ABOUTME: For You tab widget showing ML-powered personalized video recommendations
// ABOUTME: Uses Gorse-based recommendations from Funnelcake REST API (staging only)

import 'package:divine_ui/divine_ui.dart';
import 'package:feed_repository/feed_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/providers/feed_repository_provider.dart';
import 'package:openvine/providers/for_you_provider.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/services/feed_performance_tracker.dart';
import 'package:openvine/services/view_event_publisher.dart';
import 'package:openvine/state/video_feed_state.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/composable_video_grid.dart';
import 'package:openvine/widgets/feed_refresh_control.dart';
import 'package:openvine/widgets/scroll_to_hide_mixin.dart';
import 'package:unified_logger/unified_logger.dart';

/// Tab widget displaying For You personalized recommendations.
///
/// Handles its own:
/// - Riverpod provider watching (forYouFeedProvider)
/// - Loading/error/data states
/// - Empty state when recommendations unavailable
class ForYouTab extends ConsumerStatefulWidget {
  const ForYouTab({super.key, this.feedTracker});

  /// Optional analytics tracker (for testing, defaults to singleton).
  final FeedPerformanceTracker? feedTracker;

  @override
  ConsumerState<ForYouTab> createState() => _ForYouTabState();
}

class _ForYouTabState extends ConsumerState<ForYouTab> {
  late final FeedPerformanceTracker? _feedTracker;
  DateTime? _feedLoadStartTime;

  @override
  void initState() {
    super.initState();
    _feedTracker = widget.feedTracker;
  }

  @override
  Widget build(BuildContext context) {
    final forYouAsync = ref.watch(forYouFeedProvider);
    final isAvailableAsync = ref.watch(forYouAvailableProvider);
    final isAvailable = isAvailableAsync;

    Log.debug(
      '🎯 ForYouTab: AsyncValue state - isLoading: ${forYouAsync.isLoading}, '
      'hasValue: ${forYouAsync.hasValue}, isAvailable: $isAvailable',
      name: 'ForYouTab',
      category: LogCategory.video,
    );

    // If not available, show unavailable state
    if (!isAvailable) {
      return RefreshableFeedStateView(
        autoRefresh: true,
        onRefresh: _refreshForYou,
        child: const _ForYouUnavailableState(),
      );
    }

    // Track feed loading start
    if (forYouAsync.isLoading && _feedLoadStartTime == null) {
      _feedLoadStartTime = DateTime.now();
      _feedTracker?.startFeedLoad('for_you');
    }

    // Check hasValue FIRST before isLoading
    if (forYouAsync.hasValue && forYouAsync.value != null) {
      return _buildDataState(forYouAsync.value!);
    }

    if (forYouAsync.hasError) {
      _feedTracker?.trackFeedError(
        'for_you',
        errorType: 'load_failed',
        errorMessage: forYouAsync.error.toString(),
      );
      _feedLoadStartTime = null;
      return RefreshableFeedStateView(
        onRefresh: _refreshForYou,
        child: _ForYouErrorState(error: forYouAsync.error.toString()),
      );
    }

    // Show loading state
    return const _ForYouLoadingState();
  }

  Widget _buildDataState(VideoFeedState feedState) {
    final videos = feedState.videos;

    Log.info(
      '✅ ForYouTab: Data state - ${videos.length} videos',
      name: 'ForYouTab',
      category: LogCategory.video,
    );

    // Track feed loaded with videos
    if (_feedLoadStartTime != null) {
      _feedTracker?.markFirstVideosReceived('for_you', videos.length);
      _feedTracker?.markFeedDisplayed('for_you', videos.length);
      _feedLoadStartTime = null;
    }

    if (videos.isEmpty) {
      _feedTracker?.trackEmptyFeed('for_you');
    }

    return _ForYouContent(
      videos: videos,
      isLoadingMore: feedState.isLoadingMore,
      hasMoreContent: feedState.hasMoreContent,
    );
  }

  Future<void> _refreshForYou() async {
    ref.read(funnelcakeAvailableProvider.notifier).refresh();
    await ref.read(funnelcakeAvailableProvider.future);
    await ref.read(forYouFeedProvider.notifier).refresh();
  }
}

/// Content widget displaying personalized video recommendations grid.
///
/// Header pushes up as user scrolls down (1:1 with scroll distance).
/// When scrolling up, header slides back in as an overlay with animation.
class _ForYouContent extends ConsumerStatefulWidget {
  const _ForYouContent({
    required this.videos,
    required this.isLoadingMore,
    required this.hasMoreContent,
  });

  final List<VideoEvent> videos;
  final bool isLoadingMore;
  final bool hasMoreContent;

  @override
  ConsumerState<_ForYouContent> createState() => _ForYouContentState();
}

class _ForYouContentState extends ConsumerState<_ForYouContent>
    with ScrollToHideMixin {
  void _showAlgorithmExplainer(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: VineTheme.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const _AlgorithmExplainerSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final forYouFeedNotifier = ref.read(forYouFeedProvider.notifier);

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
                  '🎯 ForYouTab TAP: gridIndex=$index, '
                  'videoId=${videoList[index].id}',
                  category: LogCategory.video,
                );
                context.push(
                  PooledFullscreenVideoFeedScreen.path,
                  extra: PooledFullscreenVideoFeedArgs(
                    source: const ForYouViewSource(),
                    feedRepository: ref.read(feedRepositoryProvider),
                    initialIndex: index,
                    initialVideoId: videoList[index].id,
                    contextTitle: context.l10n.feedModeForYou,
                    trafficSource: ViewTrafficSource.discoveryForYou,
                  ),
                );
              },
              onRefresh: () async {
                Log.info(
                  '🔄 ForYouTab: Refreshing recommendations',
                  name: 'ForYouTab',
                  category: LogCategory.video,
                );
                await forYouFeedNotifier.refresh();
              },
              onLoadMore: () async {
                Log.info(
                  '📜 ForYouTab: Loading more recommendations',
                  name: 'ForYouTab',
                  category: LogCategory.video,
                );
                await forYouFeedNotifier.loadMore();
              },
              isLoadingMore: widget.isLoadingMore,
              hasMoreContent: widget.hasMoreContent,
              emptyBuilder: () => const _ForYouEmptyState(),
            ),
          ),
        ),
        // Header overlay on top, animated when returning
        AnimatedPositioned(
          duration: headerFullyHidden
              ? const Duration(milliseconds: 250)
              : Duration.zero,
          curve: Curves.easeOut,
          top: headerOffset,
          left: 0,
          right: 0,
          child: GestureDetector(
            key: headerKey,
            onTap: () => _showAlgorithmExplainer(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: VineTheme.backgroundColor,
              child: Row(
                children: [
                  const DivineIcon(
                    icon: DivineIconName.sparkle,
                    color: VineTheme.vineGreen,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    context.l10n.forYouAlgorithmTitle,
                    style: const TextStyle(
                      color: VineTheme.vineGreen,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const DivineIcon(
                    icon: DivineIconName.info,
                    color: VineTheme.secondaryText,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Bottom sheet explaining how the Divine Algorithm works
class _AlgorithmExplainerSheet extends StatelessWidget {
  const _AlgorithmExplainerSheet();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: ListView(
            controller: scrollController,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: VineTheme.secondaryText.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Title
              Row(
                children: [
                  const DivineIcon(
                    icon: DivineIconName.sparkle,
                    color: VineTheme.vineGreen,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      context.l10n.forYouAlgorithmTitle,
                      style: const TextStyle(
                        color: VineTheme.whiteText,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.forYouAlgorithmSubtitle,
                style: const TextStyle(
                  color: VineTheme.vineGreen,
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 24),

              // Section: How it works
              _buildSectionTitle(context.l10n.forYouAlgorithmHowItWorksTitle),
              const SizedBox(height: 12),
              Text(
                context.l10n.forYouAlgorithmHowItWorksBody,
                style: _bodyTextStyle,
              ),
              const SizedBox(height: 16),
              Text(
                context.l10n.forYouAlgorithmInteractionsIntro,
                style: _bodyTextStyle,
              ),
              const SizedBox(height: 12),

              // Interaction weights
              _buildInteractionItem(
                Icons.repeat,
                context.l10n.metadataRepostsLabel,
                context.l10n.forYouAlgorithmRepostsDescription,
              ),
              _buildInteractionItem(
                Icons.chat_bubble_outline,
                context.l10n.profileCommentsSection,
                context.l10n.forYouAlgorithmCommentsDescription,
              ),
              _buildInteractionItem(
                Icons.favorite_outline,
                context.l10n.forYouAlgorithmReactionsTitle,
                context.l10n.forYouAlgorithmReactionsDescription,
              ),
              _buildInteractionItem(
                Icons.play_circle_outline,
                context.l10n.analyticsViews,
                context.l10n.forYouAlgorithmViewsDescription,
              ),
              const SizedBox(height: 24),

              // Section: Cold start
              _buildSectionTitle(context.l10n.forYouAlgorithmNewToDivineTitle),
              const SizedBox(height: 12),
              Text(
                context.l10n.forYouAlgorithmNewToDivineBody1,
                style: _bodyTextStyle,
              ),
              const SizedBox(height: 12),
              Text(
                context.l10n.forYouAlgorithmNewToDivineBody2,
                style: _bodyTextStyle,
              ),
              const SizedBox(height: 24),

              // Section: Future vision
              _buildSectionTitle(context.l10n.forYouAlgorithmChoiceTitle),
              const SizedBox(height: 12),
              Text(
                context.l10n.forYouAlgorithmChoiceBody,
                style: _bodyTextStyle,
              ),
              const SizedBox(height: 12),
              _buildFutureFeatureItem(
                context.l10n.forYouAlgorithmChoicePersonalizedFeed,
              ),
              _buildFutureFeatureItem(
                context.l10n.forYouAlgorithmChoiceChronological,
              ),
              _buildFutureFeatureItem(
                context.l10n.forYouAlgorithmChoiceTrending,
              ),
              _buildFutureFeatureItem(
                context.l10n.forYouAlgorithmChoiceCustomFeeds,
              ),
              const SizedBox(height: 16),
              Text(
                context.l10n.forYouAlgorithmChoiceClosing,
                style: _bodyTextStyle,
              ),
              const SizedBox(height: 24),

              // Open source callout
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: VineTheme.vineGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: VineTheme.vineGreen.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const DivineIcon(
                      icon: DivineIconName.bracketsAngle,
                      color: VineTheme.vineGreen,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.forYouAlgorithmOpenSourceTitle,
                            style: const TextStyle(
                              color: VineTheme.vineGreen,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            context.l10n.forYouAlgorithmOpenSourceBody,
                            style: const TextStyle(
                              color: VineTheme.secondaryText,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: VineTheme.whiteText,
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildInteractionItem(
    IconData icon,
    String title,
    String description,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: VineTheme.cardBackground,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: VineTheme.vineGreen, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: VineTheme.whiteText,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    color: VineTheme.secondaryText,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFutureFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 8, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DivineIcon(
            icon: DivineIconName.checkCircle,
            color: VineTheme.vineGreen,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: _bodyTextStyle)),
        ],
      ),
    );
  }

  static TextStyle get _bodyTextStyle =>
      const TextStyle(color: VineTheme.primaryText, fontSize: 14, height: 1.5);
}

/// Unavailable state when recommendations are not available
class _ForYouUnavailableState extends StatelessWidget {
  const _ForYouUnavailableState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.cloud_off,
              size: 64,
              color: VineTheme.secondaryText,
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.forYouUnavailableTitle,
              style: const TextStyle(
                color: VineTheme.primaryText,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.forYouUnavailableDescription,
              style: const TextStyle(
                color: VineTheme.secondaryText,
                fontSize: 14,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Empty state widget for ForYouTab
class _ForYouEmptyState extends StatelessWidget {
  const _ForYouEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const DivineIcon(
            icon: DivineIconName.sparkle,
            size: 64,
            color: VineTheme.secondaryText,
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.forYouEmptyTitle,
            style: const TextStyle(
              color: VineTheme.primaryText,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              context.l10n.forYouEmptyDescription,
              style: const TextStyle(
                color: VineTheme.secondaryText,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

/// Error state widget for ForYouTab
class _ForYouErrorState extends StatelessWidget {
  const _ForYouErrorState({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, size: 64, color: VineTheme.likeRed),
          const SizedBox(height: 16),
          Text(
            context.l10n.forYouErrorTitle,
            style: const TextStyle(color: VineTheme.likeRed, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error,
              style: const TextStyle(
                color: VineTheme.secondaryText,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

/// Loading state widget for ForYouTab
class _ForYouLoadingState extends StatelessWidget {
  const _ForYouLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(child: BrandedLoadingIndicator());
  }
}
