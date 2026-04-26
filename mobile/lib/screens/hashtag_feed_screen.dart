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
import 'package:openvine/services/view_event_publisher.dart';
import 'package:openvine/widgets/composable_video_grid.dart';
import 'package:rxdart/rxdart.dart';
import 'package:unified_logger/unified_logger.dart';

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

  /// Load the fast initial hashtag results first, then detach realtime updates.
  /// This keeps the first paint honest: no empty-state flash before the
  /// initial source has answered, while the websocket subscription still starts
  /// in the background.
  Future<void> _loadHashtagVideos() async {
    if (!mounted) return;

    Log.info(
      '🏷️ HashtagFeedScreen: Loading #${widget.hashtag}',
      category: LogCategory.video,
    );

    final hashtagService = ref.read(hashtagServiceProvider);

    // Wait for the fast initial source before leaving the loading gate.
    // The websocket can continue in the background once the first pass has
    // answered.
    await _fetchFromFunnelcake();
    if (!mounted) return;

    unawaited(_subscribeViaWebSocket(hashtagService));

    setState(() => _subscriptionAttempted = true);
  }

  /// Fetch videos from Funnelcake REST API and update state immediately.
  /// Fetches trending AND classic videos in parallel, then interleaves 50/50.
  Future<void> _fetchFromFunnelcake() async {
    try {
      final client = ref.read(funnelcakeApiClientProvider);

      // Quick check - skip if API not configured
      if (!client.isAvailable) {
        Log.debug(
          '🏷️ HashtagFeedScreen: Funnelcake not configured, skipping',
          category: LogCategory.video,
        );
        return;
      }

      // Fetch trending AND classic videos in parallel
      final results = await Future.wait([
        client.getVideosByHashtag(hashtag: widget.hashtag),
        client.getClassicVideosByHashtag(hashtag: widget.hashtag),
      ]).timeout(const Duration(seconds: 5));

      if (!mounted) return;

      final trendingStats = results[0];
      final classicStats = results[1];
      final trendingVideos = trendingStats.toVideoEvents();
      final classicVideos = classicStats.toVideoEvents();

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
        removedIdsStream: ref.read(videoEventServiceProvider).removedVideoIds,
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

        // Show a full-screen loader only before the initial startup attempt.
        // Once background loading has started, render empty or cached state
        // instead of blocking on relay subscription setup.
        final shouldShowLoading = !_subscriptionAttempted;

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

        return ComposableVideoGrid(
          videos: videos,
          useMasonryLayout: true,
          onVideoTap:
              widget.onVideoTap ??
              (videoList, index) {
                _navigateToFullscreenFeed(context, videoList, index);
              },
          onRefresh: _loadHashtagVideos,
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
      ),
      body: body,
    );
  }
}
