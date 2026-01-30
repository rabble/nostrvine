// ABOUTME: For You tab widget showing ML-powered personalized video recommendations
// ABOUTME: Uses Gorse-based recommendations from Funnelcake REST API (staging only)

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/providers/for_you_provider.dart';
import 'package:openvine/state/video_feed_state.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/composable_video_grid.dart';

/// Tab widget displaying For You personalized recommendations.
///
/// Handles its own:
/// - Riverpod provider watching (forYouFeedProvider)
/// - Loading/error/data states
/// - Empty state when recommendations unavailable
class ForYouTab extends ConsumerStatefulWidget {
  const ForYouTab({super.key, required this.onVideoTap});

  /// Callback when a video is tapped to enter feed mode
  final void Function(List<VideoEvent> videos, int index) onVideoTap;

  @override
  ConsumerState<ForYouTab> createState() => _ForYouTabState();
}

class _ForYouTabState extends ConsumerState<ForYouTab> {
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
      return const _ForYouUnavailableState();
    }

    // Check hasValue FIRST before isLoading
    if (forYouAsync.hasValue && forYouAsync.value != null) {
      return _buildDataState(forYouAsync.value!);
    }

    if (forYouAsync.hasError) {
      return _ForYouErrorState(error: forYouAsync.error.toString());
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

    if (videos.isEmpty) {
      return const _ForYouEmptyState();
    }

    return _ForYouContent(videos: videos, onVideoTap: widget.onVideoTap);
  }
}

/// Content widget displaying personalized video recommendations grid
class _ForYouContent extends ConsumerWidget {
  const _ForYouContent({required this.videos, required this.onVideoTap});

  final List<VideoEvent> videos;
  final void Function(List<VideoEvent> videos, int index) onVideoTap;

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
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        // Tappable header - "The Divine Algorithm"
        GestureDetector(
          onTap: () => _showAlgorithmExplainer(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, color: VineTheme.vineGreen, size: 20),
                const SizedBox(width: 8),
                Text(
                  'The Divine Algorithm',
                  style: TextStyle(
                    color: VineTheme.vineGreen,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.info_outline,
                  color: VineTheme.secondaryText,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
        // Video grid
        Expanded(
          child: ComposableVideoGrid(
            videos: videos,
            thumbnailAspectRatio: 1.0, // Square thumbnails
            onVideoTap: onVideoTap,
            onRefresh: () async {
              Log.info(
                '🔄 ForYouTab: Refreshing recommendations',
                name: 'ForYouTab',
                category: LogCategory.video,
              );
              await ref.read(forYouFeedProvider.notifier).refresh();
            },
            emptyBuilder: () => const _ForYouEmptyState(),
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
                  Icon(
                    Icons.auto_awesome,
                    color: VineTheme.vineGreen,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'The Divine Algorithm',
                      style: TextStyle(
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
                'Powered by Gorse, an open-source recommendation engine',
                style: TextStyle(
                  color: VineTheme.vineGreen,
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 24),

              // Section: How it works
              _buildSectionTitle('How It Works'),
              const SizedBox(height: 12),
              Text(
                'Divine pays attention to how you interact with content to understand what you enjoy. Every time you watch a video, give it a reaction, leave a comment, or repost it, the system takes note.',
                style: _bodyTextStyle,
              ),
              const SizedBox(height: 16),
              Text(
                'Different actions signal different levels of interest:',
                style: _bodyTextStyle,
              ),
              const SizedBox(height: 12),

              // Interaction weights
              _buildInteractionItem(
                Icons.repeat,
                'Reposts',
                'Strongest signal — sharing with your followers is a powerful endorsement',
              ),
              _buildInteractionItem(
                Icons.chat_bubble_outline,
                'Comments',
                'Strong signal — you were engaged enough to respond',
              ),
              _buildInteractionItem(
                Icons.favorite_outline,
                'Reactions',
                'Medium signal — a quick way to show appreciation',
              ),
              _buildInteractionItem(
                Icons.play_circle_outline,
                'Views',
                'Light signal — indicates basic interest',
              ),
              const SizedBox(height: 24),

              // Section: Cold start
              _buildSectionTitle('New to Divine?'),
              const SizedBox(height: 12),
              Text(
                "If you haven't built up a viewing history yet, we show a mix of what's currently popular and trending alongside recent uploads. This gives you a great starting point to explore.",
                style: _bodyTextStyle,
              ),
              const SizedBox(height: 12),
              Text(
                'As you watch, like, and engage with content, recommendations gradually become more personalized. Over time, your For You feed surfaces videos from creators you might never have discovered on your own.',
                style: _bodyTextStyle,
              ),
              const SizedBox(height: 24),

              // Section: Future vision
              _buildSectionTitle('Your Algorithm, Your Choice'),
              const SizedBox(height: 12),
              Text(
                "Divine's vision is to give you true algorithmic choice. Instead of being locked into a single black-box algorithm, you'll be able to choose from multiple recommendation approaches:",
                style: _bodyTextStyle,
              ),
              const SizedBox(height: 12),
              _buildFutureFeatureItem('Personalized "For You" feed'),
              _buildFutureFeatureItem(
                'Chronological timeline from creators you follow',
              ),
              _buildFutureFeatureItem('Trending and popular content'),
              _buildFutureFeatureItem(
                'Community-created custom feeds for topics like music, comedy, or art',
              ),
              const SizedBox(height: 16),
              Text(
                'This puts you in control of your attention rather than leaving it up to the platform. You should know how your feed is curated and have the power to change it whenever you want.',
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
                    Icon(Icons.code, color: VineTheme.vineGreen, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Open Source & Transparent',
                            style: TextStyle(
                              color: VineTheme.vineGreen,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "We're building an open system where developers can implement their own algorithms, and you can choose which ones to use — or opt out entirely.",
                            style: TextStyle(
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
      style: TextStyle(
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
                  style: TextStyle(
                    color: VineTheme.whiteText,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
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
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle_outline,
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
      TextStyle(color: VineTheme.primaryText, fontSize: 14, height: 1.5);
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
            Icon(Icons.cloud_off, size: 64, color: VineTheme.secondaryText),
            const SizedBox(height: 16),
            Text(
              'For You Unavailable',
              style: TextStyle(
                color: VineTheme.primaryText,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Personalized recommendations require connection to Funnelcake.',
              style: TextStyle(
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
          Icon(Icons.auto_awesome, size: 64, color: VineTheme.secondaryText),
          const SizedBox(height: 16),
          Text(
            'No Recommendations Yet',
            style: TextStyle(
              color: VineTheme.primaryText,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Watch and like some videos to get personalized recommendations.',
              style: TextStyle(color: VineTheme.secondaryText, fontSize: 14),
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
          Icon(Icons.error, size: 64, color: VineTheme.likeRed),
          const SizedBox(height: 16),
          Text(
            'Failed to load recommendations',
            style: TextStyle(color: VineTheme.likeRed, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error,
              style: TextStyle(color: VineTheme.secondaryText, fontSize: 12),
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
    return const Center(child: BrandedLoadingIndicator(size: 80));
  }
}
