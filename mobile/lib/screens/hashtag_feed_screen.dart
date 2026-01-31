// ABOUTME: Screen displaying videos filtered by a specific hashtag
// ABOUTME: Allows users to explore all videos with a particular hashtag

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/screens/hashtag_screen_router.dart';
import 'package:openvine/services/hashtag_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/composable_video_grid.dart';
import 'package:openvine/widgets/video_feed_item/video_feed_item.dart';

class HashtagFeedScreen extends ConsumerStatefulWidget {
  const HashtagFeedScreen({
    required this.hashtag,
    this.embedded = false,
    this.onVideoTap,
    super.key,
  });
  final String hashtag;
  // If true, don't show Scaffold/AppBar (for embedding in explore)
  final bool embedded;
  // Callback for video navigation when embedded
  final void Function(List<VideoEvent> videos, int index)? onVideoTap;

  @override
  ConsumerState<HashtagFeedScreen> createState() => _HashtagFeedScreenState();
}

class _HashtagFeedScreenState extends ConsumerState<HashtagFeedScreen> {
  /// Tracks whether we've completed the initial subscription attempt.
  /// Used to show loading state until subscription has been tried.
  bool _subscriptionAttempted = false;

  /// Cached videos from Funnelcake REST API for popularity ordering.
  /// When available, these provide engagement-based sorting.
  List<VideoEvent>? _popularVideos;

  @override
  void initState() {
    super.initState();
    // Subscribe to videos with this hashtag
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return; // Safety check: don't use ref if widget is disposed

      _loadHashtagVideos();
    });
  }

  /// Load videos from both Funnelcake REST API and WebSocket in parallel.
  /// Funnelcake is fast and provides complete video data - show immediately.
  /// WebSocket provides real-time updates and additional videos.
  Future<void> _loadHashtagVideos({bool forceRefresh = false}) async {
    if (!mounted) return;

    Log.info(
      '🏷️ HashtagFeedScreen: Loading #${widget.hashtag}'
      '${forceRefresh ? ' (force refresh)' : ''}',
      category: LogCategory.video,
    );

    final hashtagService = ref.read(hashtagServiceProvider);

    // Run both fetches in parallel for speed
    // Always try Funnelcake - it will fail fast if unavailable
    final futures = <Future<void>>[
      _fetchFromFunnelcake(forceRefresh: forceRefresh),
      _subscribeViaWebSocket(hashtagService),
    ];

    // Both run in parallel - Funnelcake shows results immediately via setState
    await Future.wait(futures);

    if (!mounted) return;
    setState(() => _subscriptionAttempted = true);
  }

  /// Fetch videos from Funnelcake REST API and update state immediately.
  /// Uses a short timeout to fail fast and fall back to WebSocket.
  Future<void> _fetchFromFunnelcake({bool forceRefresh = false}) async {
    try {
      final analyticsService = ref.read(analyticsApiServiceProvider);

      // Quick check - skip if API not configured
      if (!analyticsService.isAvailable) {
        Log.debug(
          '🏷️ HashtagFeedScreen: Funnelcake not configured, skipping',
          category: LogCategory.video,
        );
        return;
      }

      // Use a 5-second timeout to fail fast
      final videos = await analyticsService
          .getVideosByHashtag(
            hashtag: widget.hashtag,
            limit: 100,
            forceRefresh: forceRefresh,
          )
          .timeout(const Duration(seconds: 5));

      if (!mounted) return;

      Log.info(
        '🏷️ HashtagFeedScreen: Got ${videos.length} videos from Funnelcake for #${widget.hashtag}',
        category: LogCategory.video,
      );

      // Update immediately - don't wait for WebSocket
      setState(() {
        _popularVideos = videos;
        // Mark as ready to show content if we have videos
        if (videos.isNotEmpty) {
          _subscriptionAttempted = true;
        }
      });
    } catch (e) {
      Log.debug(
        '🏷️ HashtagFeedScreen: Funnelcake skipped (${e.runtimeType})',
        category: LogCategory.video,
      );
    }
  }

  /// Subscribe to hashtag via WebSocket for real-time updates.
  Future<void> _subscribeViaWebSocket(HashtagService hashtagService) async {
    try {
      await hashtagService.subscribeToHashtagVideos([widget.hashtag]);
      if (!mounted) return;
      Log.debug(
        '🏷️ HashtagFeedScreen: WebSocket subscription complete for #${widget.hashtag}',
        category: LogCategory.video,
      );
    } catch (e) {
      Log.error(
        '🏷️ HashtagFeedScreen: WebSocket subscription failed: $e',
        category: LogCategory.video,
      );
    }
  }

  /// Combine and sort videos from Funnelcake and WebSocket sources.
  /// Funnelcake videos are shown first (already sorted by popularity).
  /// WebSocket-only videos are appended and sorted by local metrics.
  List<VideoEvent> _combineAndSortVideos(List<VideoEvent> webSocketVideos) {
    // If no Funnelcake data, just sort WebSocket videos locally
    if (_popularVideos == null || _popularVideos!.isEmpty) {
      webSocketVideos.sort(VideoEvent.compareByLoopsThenTime);
      return webSocketVideos;
    }

    // Create set of IDs we already have from Funnelcake
    final funnelcakeIds = <String>{};
    for (final v in _popularVideos!) {
      if (v.id.isNotEmpty) funnelcakeIds.add(v.id);
      if (v.vineId != null && v.vineId!.isNotEmpty) {
        funnelcakeIds.add(v.vineId!);
      }
    }

    // Find WebSocket videos NOT in Funnelcake results (new/real-time videos)
    final additionalVideos = <VideoEvent>[];
    for (final video in webSocketVideos) {
      final isInFunnelcake =
          funnelcakeIds.contains(video.id) ||
          (video.vineId != null && funnelcakeIds.contains(video.vineId));
      if (!isInFunnelcake) {
        additionalVideos.add(video);
      }
    }

    // Sort additional videos by local popularity
    additionalVideos.sort(VideoEvent.compareByLoopsThenTime);

    // Return Funnelcake videos (already sorted by API) + additional WebSocket videos
    return [..._popularVideos!, ...additionalVideos];
  }

  @override
  Widget build(BuildContext context) {
    final body = Builder(
      builder: (context) {
        Log.debug(
          '🏷️ Building HashtagFeedScreen for #${widget.hashtag}',
          category: LogCategory.video,
        );
        final videoService = ref.watch(videoEventServiceProvider);
        final hashtagService = ref.watch(hashtagServiceProvider);

        // Combine Funnelcake videos (fast, pre-sorted) with WebSocket videos
        final webSocketVideos = List<VideoEvent>.from(
          hashtagService.getVideosByHashtags([widget.hashtag]),
        );
        final videos = _combineAndSortVideos(webSocketVideos);

        Log.debug(
          '🏷️ Found ${videos.length} videos for #${widget.hashtag} '
          '(Funnelcake: ${_popularVideos?.length ?? 0}, WebSocket: ${webSocketVideos.length})',
          category: LogCategory.video,
        );

        // Use per-subscription loading state for hashtag feed
        final isLoadingHashtag = videoService.isLoadingForSubscription(
          SubscriptionType.hashtag,
        );

        // Show loading if:
        // 1. We haven't attempted subscription yet (initial state), OR
        // 2. Subscription is actively loading
        final shouldShowLoading = !_subscriptionAttempted || isLoadingHashtag;

        if (shouldShowLoading && videos.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: VineTheme.vineGreen),
                const SizedBox(height: 24),
                Text(
                  'Loading videos about #${widget.hashtag}...',
                  style: const TextStyle(
                    color: VineTheme.primaryText,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This may take a few moments',
                  style: TextStyle(
                    color: VineTheme.secondaryText,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        if (videos.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.tag, size: 64, color: VineTheme.secondaryText),
                const SizedBox(height: 16),
                Text(
                  'No videos found for #${widget.hashtag}',
                  style: const TextStyle(
                    color: VineTheme.primaryText,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Be the first to post a video with this hashtag!',
                  style: TextStyle(
                    color: VineTheme.secondaryText,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        // Use grid view when embedded (in explore), full-screen list when standalone
        if (widget.embedded) {
          return ComposableVideoGrid(
            videos: videos,
            useMasonryLayout: true,
            onVideoTap:
                widget.onVideoTap ??
                (videos, index) {
                  // Default behavior: navigate to hashtag feed mode using GoRouter
                  context.go(
                    HashtagScreenRouter.pathForTag(
                      widget.hashtag,
                      index: index,
                    ),
                  );
                },
            onRefresh: () => _loadHashtagVideos(forceRefresh: true),
          );
        }

        // Standalone mode: full-screen scrollable list
        final isLoadingMore = isLoadingHashtag;

        return RefreshIndicator(
          semanticsLabel: 'searching for more videos',
          color: VineTheme.onPrimary,
          backgroundColor: VineTheme.vineGreen,
          onRefresh: () => _loadHashtagVideos(forceRefresh: true),
          child: ListView.builder(
            // Add 1 for loading indicator if still loading
            itemCount: videos.length + (isLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              // Show loading indicator as last item
              if (index == videos.length) {
                return Container(
                  height: MediaQuery.of(context).size.height,
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(
                        color: VineTheme.vineGreen,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Getting more videos about #${widget.hashtag}...',
                        style: const TextStyle(
                          color: VineTheme.primaryText,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Please wait while we fetch from relays',
                        style: TextStyle(
                          color: VineTheme.secondaryText,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                );
              }

              final video = videos[index];
              return GestureDetector(
                onTap: () {
                  // Navigate to hashtag feed mode using GoRouter
                  context.go(
                    HashtagScreenRouter.pathForTag(
                      widget.hashtag,
                      index: index,
                    ),
                  );
                },
                child: SizedBox(
                  height: MediaQuery.of(context).size.height,
                  width: double.infinity,
                  child: VideoFeedItem(
                    video: video,
                    index: index,
                    contextTitle: '#${widget.hashtag}',
                    forceShowOverlay: true,
                  ),
                ),
              );
            },
          ),
        );
      },
    );

    // If embedded, return body only; otherwise wrap with Scaffold
    if (widget.embedded) {
      return body;
    }

    return Scaffold(
      backgroundColor: VineTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: VineTheme.vineGreen,
        elevation: 0,
        title: Text(
          '#${widget.hashtag}',
          style: const TextStyle(
            color: VineTheme.whiteText,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: VineTheme.whiteText),
          onPressed: context.pop,
        ),
      ),
      body: body,
    );
  }
}
