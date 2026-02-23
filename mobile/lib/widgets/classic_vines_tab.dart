// ABOUTME: Classics tab widget showing pre-2017 Vine archive videos
// ABOUTME: Uses REST API when available, falls back to Nostr videos with embedded loop stats

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/classic_vines_provider.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/services/view_event_publisher.dart';
import 'package:openvine/state/video_feed_state.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/classic_viners_slider.dart';
import 'package:openvine/widgets/user_name.dart';
import 'package:openvine/widgets/video_thumbnail_widget.dart';
import 'package:rxdart/rxdart.dart';

/// Tab widget displaying Classics archive videos (pre-2017).
///
/// Handles its own:
/// - Riverpod provider watching (classicVinesFeedProvider)
/// - Loading/error/data states
/// - Empty state when REST API unavailable
class ClassicVinesTab extends ConsumerStatefulWidget {
  const ClassicVinesTab({super.key});

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

    return _ClassicVinesContent(
      videos: videos,
      isLoadingMore: feedState.isLoadingMore,
      hasMoreContent: feedState.hasMoreContent,
    );
  }
}

/// Content widget displaying classic Viners slider and video grid.
///
/// Uses a simple vertical layout (no scroll-to-hide) to ensure pull-to-refresh
/// works reliably. The slider scrolls away naturally as user scrolls the grid.
/// Supports infinite scroll pagination via scroll detection.
class _ClassicVinesContent extends ConsumerStatefulWidget {
  const _ClassicVinesContent({
    required this.videos,
    this.isLoadingMore = false,
    this.hasMoreContent = false,
  });

  final List<VideoEvent> videos;
  final bool isLoadingMore;
  final bool hasMoreContent;

  @override
  ConsumerState<_ClassicVinesContent> createState() =>
      _ClassicVinesContentState();
}

class _ClassicVinesContentState extends ConsumerState<_ClassicVinesContent> {
  final ScrollController _scrollController = ScrollController();
  late final StreamController<List<VideoEvent>> _videosStreamController;
  bool _isLoadingTriggered = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _videosStreamController = StreamController<List<VideoEvent>>.broadcast();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _videosStreamController.close();
    super.dispose();
  }

  void _onScroll() {
    if (!widget.hasMoreContent) return;
    if (widget.isLoadingMore) return;
    if (_isLoadingTriggered) return;

    final position = _scrollController.position;
    final maxScroll = position.maxScrollExtent;
    final currentScroll = position.pixels;

    // Trigger load more when within 200 pixels of the bottom
    if (currentScroll >= maxScroll - 200) {
      _triggerLoadMore();
    }
  }

  Future<void> _triggerLoadMore() async {
    if (_isLoadingTriggered) return;
    _isLoadingTriggered = true;

    try {
      Log.info(
        '📜 ClassicVinesTab: Loading more classics',
        name: 'ClassicVinesTab',
        category: LogCategory.video,
      );
      await ref.read(classicVinesFeedProvider.notifier).loadMore();
    } finally {
      if (mounted) {
        _isLoadingTriggered = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to provider changes and push to stream for fullscreen updates
    ref.listen(classicVinesFeedProvider, (previous, next) {
      if (next.hasValue && next.value != null) {
        _videosStreamController.add(next.value!.videos);
      }
    });

    return RefreshIndicator(
      color: VineTheme.onPrimary,
      backgroundColor: VineTheme.vineGreen,
      onRefresh: () async {
        Log.info(
          '🔄 ClassicVinesTab: Spinning to next batch of classics',
          name: 'ClassicVinesTab',
          category: LogCategory.video,
        );
        // Only refresh classics feed (roulette to next page)
        await ref.read(classicVinesFeedProvider.notifier).refresh();
      },
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Viners slider at top
          const SliverToBoxAdapter(child: ClassicVinersSlider()),
          // Video grid below
          _ClassicVideosSliverGrid(
            videos: widget.videos,
            onVideoTap: (videos, index) {
              Log.info(
                '🎯 ClassicVinesTab TAP: gridIndex=$index, '
                'videoId=${videos[index].id}',
                category: LogCategory.video,
              );
              context.push(
                PooledFullscreenVideoFeedScreen.path,
                extra: PooledFullscreenVideoFeedArgs(
                  videosStream: _videosStreamController.stream.startWith(
                    videos,
                  ),
                  initialIndex: index,
                  onLoadMore: () =>
                      ref.read(classicVinesFeedProvider.notifier).loadMore(),
                  contextTitle: 'Classics',
                  trafficSource: ViewTrafficSource.discoveryClassic,
                ),
              );
            },
          ),
          // Loading indicator at bottom
          if (widget.isLoadingMore || widget.hasMoreContent)
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                alignment: Alignment.center,
                child: widget.isLoadingMore
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: VineTheme.vineGreen,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
        ],
      ),
    );
  }
}

/// Sliver grid for classic videos using masonry layout
class _ClassicVideosSliverGrid extends ConsumerWidget {
  const _ClassicVideosSliverGrid({
    required this.videos,
    required this.onVideoTap,
  });

  final List<VideoEvent> videos;
  final void Function(List<VideoEvent> videos, int index) onVideoTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch broken video tracker
    final brokenTrackerAsync = ref.watch(brokenVideoTrackerProvider);

    return brokenTrackerAsync.when(
      loading: () => const SliverToBoxAdapter(
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => _buildGrid(context, ref, videos),
      data: (tracker) {
        final filteredVideos = videos
            .where((video) => !tracker.isVideoBroken(video.id))
            .toList();
        return _buildGrid(context, ref, filteredVideos);
      },
    );
  }

  Widget _buildGrid(
    BuildContext context,
    WidgetRef ref,
    List<VideoEvent> videosToShow,
  ) {
    if (videosToShow.isEmpty) {
      return const SliverToBoxAdapter(child: _ClassicVinesEmptyState());
    }

    // Responsive column count
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth >= 600 ? 3 : 2;

    return SliverPadding(
      padding: const EdgeInsets.all(4),
      sliver: SliverMasonryGrid.count(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        childCount: videosToShow.length,
        itemBuilder: (context, index) {
          final video = videosToShow[index];
          return _ClassicVideoItem(
            video: video,
            index: index,
            videos: videosToShow,
            onVideoTap: onVideoTap,
          );
        },
      ),
    );
  }
}

/// Individual video item for the classics grid
class _ClassicVideoItem extends StatelessWidget {
  const _ClassicVideoItem({
    required this.video,
    required this.index,
    required this.videos,
    required this.onVideoTap,
  });

  final VideoEvent video;
  final int index;
  final List<VideoEvent> videos;
  final void Function(List<VideoEvent> videos, int index) onVideoTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onVideoTap(videos, index),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Stack(
          children: [
            VideoThumbnailWidget(video: video),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.only(
                  left: 8,
                  right: 8,
                  bottom: 6,
                  top: 24,
                ),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xCC000000)],
                  ),
                ),
                child: UserName.fromPubKey(
                  video.pubkey,
                  embeddedName: video.authorName,
                  maxLines: 1,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    shadows: const [
                      Shadow(
                        offset: Offset(0, 1),
                        blurRadius: 3,
                        color: Color(0x80000000),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
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
