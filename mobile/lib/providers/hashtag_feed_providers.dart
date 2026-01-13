// ABOUTME: Route-aware hashtag feed provider with pagination support
// ABOUTME: Uses Funnelcake REST API for popular sorting, WebSocket for fallback

import 'dart:async';

import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/router/page_context_provider.dart';
import 'package:openvine/router/route_utils.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/state/video_feed_state.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'hashtag_feed_providers.g.dart';

/// Hashtag feed provider - shows videos with a specific hashtag
///
/// Rebuilds when:
/// - Route changes (different hashtag)
/// - User pulls to refresh
/// - VideoEventService updates with new hashtag videos
@Riverpod(keepAlive: false) // Auto-dispose when no listeners
class HashtagFeed extends _$HashtagFeed {
  static int _buildCounter = 0;
  Timer? _rebuildDebounceTimer;

  /// Cached popular videos from REST API for ordering
  List<VideoEvent>? _popularVideos;

  @override
  Future<VideoFeedState> build() async {
    _buildCounter++;
    final buildId = _buildCounter;

    // Get hashtag from route context
    final ctx = ref.watch(pageContextProvider).asData?.value;
    if (ctx == null || ctx.type != RouteType.hashtag) {
      return VideoFeedState(
        videos: const [],
        hasMoreContent: false,
        isLoadingMore: false,
      );
    }

    final raw = (ctx.hashtag ?? '').trim();
    final tag = raw.toLowerCase(); // normalize
    if (tag.isEmpty) {
      return VideoFeedState(
        videos: const [],
        hasMoreContent: false,
        isLoadingMore: false,
      );
    }

    Log.info(
      'HashtagFeed: Loading #$tag (build #$buildId)',
      name: 'HashtagFeedProvider',
      category: LogCategory.video,
    );

    // Try to get popular video ordering from Funnelcake REST API
    // This provides engagement-based sorting when available
    final analyticsService = ref.read(analyticsApiServiceProvider);
    if (analyticsService.isAvailable) {
      try {
        _popularVideos = await analyticsService.getVideosByHashtag(
          hashtag: tag,
          limit: 100,
        );
        Log.info(
          'HashtagFeed: Got ${_popularVideos?.length ?? 0} popular videos from REST API',
          name: 'HashtagFeedProvider',
          category: LogCategory.video,
        );
      } catch (e) {
        Log.warning(
          'HashtagFeed: REST API failed, falling back to WebSocket: $e',
          name: 'HashtagFeedProvider',
          category: LogCategory.video,
        );
        _popularVideos = null;
      }
    } else {
      Log.debug(
        'HashtagFeed: No Funnelcake API available, using WebSocket only',
        name: 'HashtagFeedProvider',
        category: LogCategory.video,
      );
    }

    // Get video event service and subscribe to hashtag via WebSocket
    // This fetches actual video events (REST API only provides IDs)
    final videoEventService = ref.watch(videoEventServiceProvider);
    await videoEventService.subscribeToHashtagVideos([tag], limit: 100);

    // Set up continuous listening for video updates
    // Track last known count to avoid rebuilding on unrelated changes
    int lastKnownCount = videoEventService.hashtagVideos(tag).length;

    void onVideosChanged() {
      // Only update if THIS hashtag's videos changed
      final currentCount = videoEventService.hashtagVideos(tag).length;
      if (currentCount != lastKnownCount) {
        lastKnownCount = currentCount;
        // Debounce updates to avoid excessive rebuilds
        _rebuildDebounceTimer?.cancel();
        _rebuildDebounceTimer = Timer(const Duration(milliseconds: 500), () {
          if (ref.mounted) {
            // Update state directly instead of invalidating to prevent rebuild loop
            final videos = _sortVideosByPopularity(
              List<VideoEvent>.from(videoEventService.hashtagVideos(tag)),
            );

            state = AsyncData(
              VideoFeedState(
                videos: videos,
                hasMoreContent: videos.length >= 10,
                isLoadingMore: false,
                error: null,
                lastUpdated: DateTime.now(),
              ),
            );
          }
        });
      }
    }

    videoEventService.addListener(onVideosChanged);

    // Clean up listener on dispose
    ref.onDispose(() {
      videoEventService.removeListener(onVideosChanged);
      _rebuildDebounceTimer?.cancel();
    });

    // Wait for initial batch of videos to arrive

    final completer = Completer<void>();
    int stableCount = 0;
    Timer? stabilityTimer;

    void checkStability() {
      final currentCount = videoEventService.hashtagVideos(tag).length;
      if (currentCount != stableCount) {
        stableCount = currentCount;
        stabilityTimer?.cancel();
        stabilityTimer = Timer(const Duration(milliseconds: 300), () {
          if (!completer.isCompleted) {
            completer.complete();
          }
        });
      }
    }

    videoEventService.addListener(checkStability);

    // Maximum wait time
    Timer(const Duration(seconds: 3), () {
      if (!completer.isCompleted) {
        Log.warning(
          '🏷️⏰ HashtagFeed: Timeout reached (3s) with $stableCount videos',
          name: 'HashtagFeedProvider',
          category: LogCategory.video,
        );
        completer.complete();
      }
    });

    checkStability();
    await completer.future;

    // Cleanup stability listener (but keep the continuous listener)
    videoEventService.removeListener(checkStability);
    stabilityTimer?.cancel();

    if (!ref.mounted) {
      return VideoFeedState(
        videos: const [],
        hasMoreContent: false,
        isLoadingMore: false,
      );
    }

    // Get videos for this hashtag and sort by popularity
    // Uses REST API order if available, otherwise falls back to local sorting
    final videos = _sortVideosByPopularity(
      List<VideoEvent>.from(videoEventService.hashtagVideos(tag)),
    );

    Log.info(
      'HashtagFeed: Loaded ${videos.length} videos for #$tag '
      '(REST order: ${_popularVideos != null})',
      name: 'HashtagFeedProvider',
      category: LogCategory.video,
    );

    return VideoFeedState(
      videos: videos,
      hasMoreContent: videos.length >= 10,
      isLoadingMore: false,
      error: null,
      lastUpdated: DateTime.now(),
    );
  }

  /// Sort videos by popularity, using REST API order if available
  /// Falls back to local loop count + timestamp sorting
  List<VideoEvent> _sortVideosByPopularity(List<VideoEvent> videos) {
    if (_popularVideos == null || _popularVideos!.isEmpty) {
      // No REST API data - use local sorting by loops then time
      videos.sort(VideoEvent.compareByLoopsThenTime);
      return videos;
    }

    // Create a map of video ID to position in REST API results
    final orderMap = <String, int>{};
    for (var i = 0; i < _popularVideos!.length; i++) {
      final v = _popularVideos![i];
      if (v.id.isNotEmpty) orderMap[v.id] = i;
      if (v.vineId != null && v.vineId!.isNotEmpty) orderMap[v.vineId!] = i;
    }

    // Separate videos into those in REST results and those only from WebSocket
    final inRestApi = <VideoEvent>[];
    final notInRestApi = <VideoEvent>[];

    for (final video in videos) {
      // Check both vineId and id for matching
      if (orderMap.containsKey(video.vineId) ||
          orderMap.containsKey(video.id)) {
        inRestApi.add(video);
      } else {
        notInRestApi.add(video);
      }
    }

    // Sort videos in REST API by their API order
    inRestApi.sort((a, b) {
      final aOrder = orderMap[a.vineId] ?? orderMap[a.id] ?? 999999;
      final bOrder = orderMap[b.vineId] ?? orderMap[b.id] ?? 999999;
      return aOrder.compareTo(bOrder);
    });

    // Sort videos not in REST API by local popularity
    notInRestApi.sort(VideoEvent.compareByLoopsThenTime);

    // Return REST API videos first (in order), then others
    return [...inRestApi, ...notInRestApi];
  }

  /// Load more historical videos with this hashtag
  Future<void> loadMore() async {
    final currentState = await future;

    if (!ref.mounted) return;

    if (currentState.isLoadingMore) {
      return;
    }

    // Update state to show loading
    state = AsyncData(currentState.copyWith(isLoadingMore: true));

    try {
      final videoEventService = ref.read(videoEventServiceProvider);

      final eventCountBefore = videoEventService.getEventCount(
        SubscriptionType.hashtag,
      );

      // Load more events for hashtag subscription
      await videoEventService.loadMoreEvents(
        SubscriptionType.hashtag,
        limit: 50,
      );

      if (!ref.mounted) return;

      final eventCountAfter = videoEventService.getEventCount(
        SubscriptionType.hashtag,
      );
      final newEventsLoaded = eventCountAfter - eventCountBefore;

      // Reset loading state
      final newState = await future;
      if (!ref.mounted) return;
      state = AsyncData(
        newState.copyWith(
          isLoadingMore: false,
          hasMoreContent: newEventsLoaded > 0,
        ),
      );
    } catch (e) {
      Log.error(
        'HashtagFeed: Error loading more: $e',
        name: 'HashtagFeedProvider',
        category: LogCategory.video,
      );

      if (!ref.mounted) return;
      final currentState = await future;
      if (!ref.mounted) return;
      state = AsyncData(
        currentState.copyWith(isLoadingMore: false, error: e.toString()),
      );
    }
  }

  /// Refresh the hashtag feed
  Future<void> refresh() async {
    // Get hashtag from route context
    final ctx = ref.read(pageContextProvider).asData?.value;
    final raw = (ctx?.hashtag ?? '').trim();
    final tag = raw.toLowerCase();

    if (tag.isNotEmpty) {
      // Get video event service and force a fresh subscription
      final videoEventService = ref.read(videoEventServiceProvider);

      // Force new subscription to get fresh data from relay
      await videoEventService.subscribeToHashtagVideos(
        [tag],
        limit: 100,
        force: true, // Force refresh bypasses duplicate detection
      );
    }

    ref.invalidateSelf();
  }
}
