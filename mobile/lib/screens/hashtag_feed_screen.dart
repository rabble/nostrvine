// ABOUTME: Screen displaying videos filtered by a specific hashtag
// ABOUTME: Allows users to explore all videos with a particular hashtag

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/services/hashtag_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/services/view_event_publisher.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/composable_video_grid.dart';
import 'package:openvine/widgets/video_feed_item/video_feed_item.dart';
import 'package:rxdart/rxdart.dart';

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

  /// Stream controller for pushing video list updates to the fullscreen feed.
  late final StreamController<List<VideoEvent>> _videosStreamController;

  @override
  void initState() {
    super.initState();
    _videosStreamController = StreamController<List<VideoEvent>>.broadcast();
    // Subscribe to videos with this hashtag
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return; // Safety check: don't use ref if widget is disposed

      _loadHashtagVideos();
    });
  }

  @override
  void dispose() {
    _videosStreamController.close();
    super.dispose();
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
  /// Fetches trending AND classic videos in parallel, then interleaves 50/50.
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

      // Fetch trending AND classic videos in parallel
      final results = await Future.wait([
        analyticsService.getVideosByHashtag(
          hashtag: widget.hashtag,
          forceRefresh: forceRefresh,
        ),
        analyticsService.getClassicVideosByHashtag(hashtag: widget.hashtag),
      ]).timeout(const Duration(seconds: 5));

      if (!mounted) return;

      final trendingVideos = results[0];
      final classicVideos = results[1];

      Log.info(
        '🏷️ HashtagFeedScreen: Got ${trendingVideos.length} trending + '
        '${classicVideos.length} classic videos from Funnelcake '
        'for #${widget.hashtag}',
        category: LogCategory.video,
      );

      // Interleave 50/50 for a balanced feed
      final interleaved = _interleaveVideos(trendingVideos, classicVideos);

      // Update immediately - don't wait for WebSocket
      setState(() {
        _popularVideos = interleaved;
        // Mark as ready to show content if we have videos
        if (interleaved.isNotEmpty) {
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

  /// Interleave trending and classic videos 1:1 for a balanced feed.
  /// Deduplicates first so a video appearing in both lists isn't shown twice.
  /// If one list runs out, appends the remainder of the other.
  List<VideoEvent> _interleaveVideos(
    List<VideoEvent> trending,
    List<VideoEvent> classics,
  ) {
    // Build set of trending IDs for deduplication
    final trendingIds = <String>{};
    for (final v in trending) {
      if (v.id.isNotEmpty) trendingIds.add(v.id.toLowerCase());
      if (v.vineId != null && v.vineId!.isNotEmpty) {
        trendingIds.add(v.vineId!.toLowerCase());
      }
    }

    // Remove classics that already appear in trending
    final uniqueClassics = <VideoEvent>[];
    for (final video in classics) {
      final isDuplicate =
          trendingIds.contains(video.id.toLowerCase()) ||
          (video.vineId != null &&
              trendingIds.contains(video.vineId!.toLowerCase()));
      if (!isDuplicate) {
        uniqueClassics.add(video);
      }
    }

    Log.debug(
      '🏷️ Interleaving: ${trending.length} trending + '
      '${uniqueClassics.length} unique classics '
      '(${classics.length - uniqueClassics.length} duplicates removed)',
      category: LogCategory.video,
    );

    // Interleave 1:1
    final result = <VideoEvent>[];
    final maxLen = trending.length > uniqueClassics.length
        ? trending.length
        : uniqueClassics.length;

    for (var i = 0; i < maxLen; i++) {
      if (i < trending.length) result.add(trending[i]);
      if (i < uniqueClassics.length) result.add(uniqueClassics[i]);
    }

    return result;
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

    final funnelcakeIds = <String>{};
    for (final v in _popularVideos!) {
      if (v.id.isNotEmpty) funnelcakeIds.add(v.id.toLowerCase());
      if (v.vineId != null && v.vineId!.isNotEmpty) {
        funnelcakeIds.add(v.vineId!.toLowerCase());
      }
    }

    // Find WebSocket videos NOT in Funnelcake results (new/real-time videos)
    // Use case-insensitive comparison to prevent duplicates
    final additionalVideos = <VideoEvent>[];
    for (final video in webSocketVideos) {
      final isInFunnelcake =
          funnelcakeIds.contains(video.id.toLowerCase()) ||
          (video.vineId != null &&
              funnelcakeIds.contains(video.vineId!.toLowerCase()));
      if (!isInFunnelcake) {
        additionalVideos.add(video);
      }
    }

    // Sort additional videos by local popularity
    additionalVideos.sort(VideoEvent.compareByLoopsThenTime);

    // Return Funnelcake videos (already sorted by API) + additional WebSocket videos
    return [..._popularVideos!, ...additionalVideos];
  }

  /// Navigate to fullscreen video feed, passing the grid's video list directly.
  /// This ensures the feed shows the same order as the grid (fixes #1751).
  void _navigateToFullscreenFeed(
    BuildContext context,
    List<VideoEvent> videoList,
    int index,
  ) {
    Log.info(
      '🏷️ HashtagFeedScreen TAP: gridIndex=$index, '
      'videoId=${videoList[index].id}',
      category: LogCategory.video,
    );
    context.push(
      PooledFullscreenVideoFeedScreen.path,
      extra: PooledFullscreenVideoFeedArgs(
        videosStream: _videosStreamController.stream.startWith(videoList),
        initialIndex: index,
        contextTitle: '#${widget.hashtag}',
        trafficSource: ViewTrafficSource.search,
        sourceDetail: widget.hashtag,
      ),
    );
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

        // Push updated video list to stream so any open fullscreen feed
        // receives the latest ordering (keeps grid and feed in sync).
        if (videos.isNotEmpty) {
          _videosStreamController.add(videos);
        }

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
                (videoList, index) {
                  _navigateToFullscreenFeed(context, videoList, index);
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
                  _navigateToFullscreenFeed(context, videos, index);
                },
                child: SizedBox(
                  height: MediaQuery.of(context).size.height,
                  width: double.infinity,
                  child: VideoFeedItem(
                    video: video,
                    index: index,
                    contextTitle: '#${widget.hashtag}',
                    forceShowOverlay: true,
                    trafficSource: ViewTrafficSource.search,
                    sourceDetail: widget.hashtag,
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
      appBar: DiVineAppBar(
        title: '#${widget.hashtag}',
        showBackButton: true,
        onBackPressed: context.pop,
        backgroundColor: VineTheme.vineGreen,
      ),
      body: body,
    );
  }
}
