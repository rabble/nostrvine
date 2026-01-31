// ABOUTME: Classics tab widget showing pre-2017 Vine archive videos
// ABOUTME: Uses REST API when available, falls back to Nostr videos with embedded loop stats

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/providers/classic_vines_provider.dart';
import 'package:openvine/state/video_feed_state.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/classic_viners_slider.dart';
import 'package:openvine/widgets/composable_video_grid.dart';
import 'package:openvine/widgets/scroll_to_hide_mixin.dart';

/// Tab widget displaying Classics archive videos (pre-2017).
///
/// Handles its own:
/// - Riverpod provider watching (classicVinesFeedProvider)
/// - Loading/error/data states
/// - Empty state when REST API unavailable
class ClassicVinesTab extends ConsumerStatefulWidget {
  const ClassicVinesTab({super.key, required this.onVideoTap});

  /// Callback when a video is tapped to enter feed mode
  final void Function(List<VideoEvent> videos, int index) onVideoTap;

  @override
  ConsumerState<ClassicVinesTab> createState() => _ClassicVinesTabState();
}

class _ClassicVinesTabState extends ConsumerState<ClassicVinesTab> {
  @override
  Widget build(BuildContext context) {
    final classicVinesAsync = ref.watch(classicVinesFeedProvider);
    final isAvailableAsync = ref.watch(classicVinesAvailableProvider);
    final isAvailable = isAvailableAsync.asData?.value ?? false;

    Log.debug(
      '🎬 ClassicVinesTab: AsyncValue state - isLoading: ${classicVinesAsync.isLoading}, '
      'hasValue: ${classicVinesAsync.hasValue}, isAvailable: $isAvailable',
      name: 'ClassicVinesTab',
      category: LogCategory.video,
    );

    // If REST API not available (or still checking), show unavailable state
    if (!isAvailable) {
      return const _ClassicVinesUnavailableState();
    }

    // Check hasValue FIRST before isLoading
    if (classicVinesAsync.hasValue && classicVinesAsync.value != null) {
      return _buildDataState(classicVinesAsync.value!);
    }

    if (classicVinesAsync.hasError) {
      return _ClassicVinesErrorState(error: classicVinesAsync.error.toString());
    }

    // Show loading state
    return const _ClassicVinesLoadingState();
  }

  Widget _buildDataState(VideoFeedState feedState) {
    final videos = feedState.videos;

    Log.info(
      '✅ ClassicVinesTab: Data state - ${videos.length} videos',
      name: 'ClassicVinesTab',
      category: LogCategory.video,
    );

    if (videos.isEmpty) {
      return const _ClassicVinesEmptyState();
    }

    return _ClassicVinesContent(videos: videos, onVideoTap: widget.onVideoTap);
  }
}

/// Content widget displaying classic Viners slider and video grid.
///
/// Viners slider pushes up as user scrolls down (1:1 with scroll distance).
/// When scrolling up, slider slides back in as an overlay with animation.
class _ClassicVinesContent extends ConsumerStatefulWidget {
  const _ClassicVinesContent({required this.videos, required this.onVideoTap});

  final List<VideoEvent> videos;
  final void Function(List<VideoEvent> videos, int index) onVideoTap;

  @override
  ConsumerState<_ClassicVinesContent> createState() =>
      _ClassicVinesContentState();
}

class _ClassicVinesContentState extends ConsumerState<_ClassicVinesContent>
    with ScrollToHideMixin {
  @override
  Widget build(BuildContext context) {
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
              padding: EdgeInsets.only(
                left: 4,
                right: 4,
                bottom: 4,
                top: headerHeight > 0 ? headerHeight + 4 : 4,
              ),
              onVideoTap: widget.onVideoTap,
              onRefresh: () async {
                Log.info(
                  '🔄 ClassicVinesTab: Spinning to next batch of classics',
                  name: 'ClassicVinesTab',
                  category: LogCategory.video,
                );
                // Only refresh classics feed (roulette to next page)
                // Don't refresh trending hashtags - it can cause disposal errors
                await ref.read(classicVinesFeedProvider.notifier).refresh();
              },
              emptyBuilder: () => const _ClassicVinesEmptyState(),
            ),
          ),
        ),
        // Viners slider overlay on top, animated when returning
        AnimatedPositioned(
          duration: headerFullyHidden
              ? const Duration(milliseconds: 250)
              : Duration.zero,
          curve: Curves.easeOut,
          top: headerOffset,
          left: 0,
          right: 0,
          child: ClassicVinersSlider(key: headerKey),
        ),
      ],
    );
  }
}

/// Unavailable state when REST API is not connected
class _ClassicVinesUnavailableState extends StatelessWidget {
  const _ClassicVinesUnavailableState();

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
              'Classics Unavailable',
              style: TextStyle(
                color: VineTheme.primaryText,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Classics are only available when connected to Funnelcake relays.',
              style: TextStyle(
                color: VineTheme.secondaryText,
                fontSize: 14,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: VineTheme.cardBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: VineTheme.vineGreen.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: VineTheme.vineGreen,
                    size: 20,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Switch to a Funnelcake-enabled relay in Settings to access the Classics archive.',
                    style: TextStyle(
                      color: VineTheme.secondaryText,
                      fontSize: 13,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Empty state widget for ClassicVinesTab
class _ClassicVinesEmptyState extends StatelessWidget {
  const _ClassicVinesEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: VineTheme.secondaryText),
          const SizedBox(height: 16),
          Text(
            'No Classics Found',
            style: TextStyle(
              color: VineTheme.primaryText,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'The Classics archive is being loaded',
            style: TextStyle(color: VineTheme.secondaryText, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

/// Error state widget for ClassicVinesTab
class _ClassicVinesErrorState extends StatelessWidget {
  const _ClassicVinesErrorState({required this.error});

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
            'Failed to load Classics',
            style: TextStyle(color: VineTheme.likeRed, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: TextStyle(color: VineTheme.secondaryText, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Loading state widget for ClassicVinesTab
class _ClassicVinesLoadingState extends StatelessWidget {
  const _ClassicVinesLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(child: BrandedLoadingIndicator(size: 80));
  }
}
