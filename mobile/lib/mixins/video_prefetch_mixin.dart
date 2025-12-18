// ABOUTME: Reusable video prefetch mixin for PageView-based video feeds
// ABOUTME: Handles both file caching and controller pre-initialization for instant playback

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/individual_video_providers.dart';
import 'package:openvine/services/video_cache_manager.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Mixin that provides video prefetching logic for PageView-based feeds
///
/// Automatically prefetches videos before and after the current index
/// to enable instant playback when user scrolls.
///
/// Usage:
/// ```dart
/// class _MyFeedState extends State<MyFeed> with VideoPrefetchMixin {
///   @override
///   VideoCacheManager get videoCacheManager => openVineVideoCache;
///
///   PageView.builder(
///     onPageChanged: (index) {
///       checkForPrefetch(
///         currentIndex: index,
///         videos: myVideos,
///       );
///     },
///   );
/// }
/// ```
mixin VideoPrefetchMixin {
  DateTime? _lastPrefetchCall;

  /// Tracks video IDs that we've pre-initialized controllers for.
  /// Maps videoId -> videoUrl to enable disposal without full video data.
  final Map<String, String> _preInitializedControllers = {};

  /// Override this to provide the cache manager instance
  /// Default uses the global singleton
  VideoCacheManager get videoCacheManager => openVineVideoCache;

  /// Override this to customize throttle duration (useful for testing)
  int get prefetchThrottleSeconds => 2;

  /// Check if videos should be prefetched and trigger prefetch if appropriate
  ///
  /// - [currentIndex]: Current video index in the feed
  /// - [videos]: Full list of videos in the feed
  void checkForPrefetch({
    required int currentIndex,
    required List<VideoEvent> videos,
  }) {
    // Skip if no videos
    if (videos.isEmpty) {
      return;
    }

    // Skip prefetch on web platform - file caching not supported
    if (kIsWeb) {
      return;
    }

    // Throttle prefetch calls to avoid excessive network activity
    final now = DateTime.now();
    if (_lastPrefetchCall != null &&
        now.difference(_lastPrefetchCall!).inSeconds <
            prefetchThrottleSeconds) {
      Log.debug(
        'Prefetch: Skipping - too soon since last call (index=$currentIndex)',
        name: 'VideoPrefetchMixin',
        category: LogCategory.video,
      );
      return;
    }

    _lastPrefetchCall = now;

    // Calculate prefetch range using app constants
    final startIndex = (currentIndex - AppConstants.preloadBefore).clamp(
      0,
      videos.length - 1,
    );
    final endIndex = (currentIndex + AppConstants.preloadAfter + 1).clamp(
      0,
      videos.length,
    );

    final videosToPreFetch = <VideoEvent>[];
    for (int i = startIndex; i < endIndex; i++) {
      // Skip current video and videos without URLs
      if (i != currentIndex && i >= 0 && i < videos.length) {
        final video = videos[i];
        if (video.videoUrl != null && video.videoUrl!.isNotEmpty) {
          videosToPreFetch.add(video);
        }
      }
    }

    if (videosToPreFetch.isEmpty) {
      return;
    }

    final videoUrls = videosToPreFetch.map((v) => v.videoUrl!).toList();
    final videoIds = videosToPreFetch.map((v) => v.id).toList();

    Log.info(
      '🎬 Prefetching ${videosToPreFetch.length} videos around index $currentIndex '
      '(before=${AppConstants.preloadBefore}, after=${AppConstants.preloadAfter})',
      name: 'VideoPrefetchMixin',
      category: LogCategory.video,
    );

    // Fire and forget - don't block on prefetch
    try {
      videoCacheManager.preCache(videoUrls, videoIds).catchError((error) {
        Log.error(
          '❌ Error prefetching videos: $error',
          name: 'VideoPrefetchMixin',
          category: LogCategory.video,
        );
      });
    } catch (error) {
      Log.error(
        '❌ Error prefetching videos: $error',
        name: 'VideoPrefetchMixin',
        category: LogCategory.video,
      );
    }
  }

  /// Reset prefetch throttle (useful after feed refresh or context change)
  void resetPrefetch() {
    _lastPrefetchCall = null;
    Log.debug(
      'Prefetch: Reset throttle',
      name: 'VideoPrefetchMixin',
      category: LogCategory.video,
    );
  }

  /// Pre-initialize video controllers for adjacent videos
  ///
  /// Triggers controller creation and initialization for videos before/after
  /// the current position. By the time user swipes, the controller should
  /// already be initialized for instant playback.
  ///
  /// This complements [checkForPrefetch] which caches video files to disk.
  /// Controller initialization happens in memory and includes codec setup.
  ///
  /// - [ref]: WidgetRef for reading the controller provider
  /// - [currentIndex]: Current video index in the feed
  /// - [videos]: Full list of videos in the feed
  /// - [preInitBefore]: Number of videos to pre-init before current (default: 1)
  /// - [preInitAfter]: Number of videos to pre-init after current (default: 2)
  void preInitializeControllers({
    required WidgetRef ref,
    required int currentIndex,
    required List<VideoEvent> videos,
    int preInitBefore = 1,
    int preInitAfter = 2,
  }) {
    if (videos.isEmpty) return;

    final startIndex = (currentIndex - preInitBefore).clamp(0, videos.length);
    final endIndex = (currentIndex + preInitAfter + 1).clamp(0, videos.length);

    for (int i = startIndex; i < endIndex; i++) {
      // Skip current video (it's already being initialized by its widget)
      if (i == currentIndex) continue;
      if (i < 0 || i >= videos.length) continue;

      final video = videos[i];
      if (video.videoUrl == null || video.videoUrl!.isEmpty) continue;

      // Trigger controller creation by reading the provider
      // This is fire-and-forget - we just want to start initialization
      final params = VideoControllerParams(
        videoId: video.id,
        videoUrl: video.videoUrl!,
        videoEvent: video,
      );

      // Reading the provider triggers controller creation + initialize()
      // The controller will stay alive due to keepAlive() + 5-min cache
      ref.read(individualVideoControllerProvider(params));

      // Track this controller for potential disposal later
      _preInitializedControllers[video.id] = video.videoUrl!;
    }
  }

  /// Dispose video controllers that are far outside the current viewing range.
  ///
  /// This prevents memory buildup when scrolling through many videos.
  /// Controllers within the keep range are preserved for smooth scrolling.
  /// Controllers outside this range are invalidated to free memory.
  ///
  /// The keep range is intentionally larger than the pre-init range to avoid
  /// disposing controllers that might be needed soon.
  ///
  /// - [ref]: WidgetRef for invalidating controller providers
  /// - [currentIndex]: Current video index in the feed
  /// - [videos]: Full list of videos in the feed
  /// - [keepBefore]: Videos to keep before current (default: 5)
  /// - [keepAfter]: Videos to keep after current (default: 6)
  void disposeControllersOutsideRange({
    required WidgetRef ref,
    required int currentIndex,
    required List<VideoEvent> videos,
    int keepBefore = 5,
    int keepAfter = 6,
  }) {
    if (videos.isEmpty || _preInitializedControllers.isEmpty) {
      return;
    }

    // Build set of video IDs that should be kept alive
    final keepStart = (currentIndex - keepBefore).clamp(0, videos.length);
    final keepEnd = (currentIndex + keepAfter + 1).clamp(0, videos.length);

    final idsToKeep = <String>{};
    for (int i = keepStart; i < keepEnd; i++) {
      idsToKeep.add(videos[i].id);
    }

    // Find IDs to dispose (pre-initialized but now outside keep range)
    final idsToDispose = <String>[];
    for (final videoId in _preInitializedControllers.keys) {
      if (!idsToKeep.contains(videoId)) {
        idsToDispose.add(videoId);
      }
    }

    if (idsToDispose.isEmpty) {
      return;
    }

    Log.debug(
      '🧹 Disposing ${idsToDispose.length} controllers outside range '
      '(keeping indices $keepStart-${keepEnd - 1} around index $currentIndex)',
      name: 'VideoPrefetchMixin',
      category: LogCategory.video,
    );

    // Invalidate providers for videos outside the range
    for (final videoId in idsToDispose) {
      final videoUrl = _preInitializedControllers[videoId];
      if (videoUrl == null) continue;

      // Find the video event in the list for the params
      VideoEvent? videoEvent;
      for (final v in videos) {
        if (v.id == videoId) {
          videoEvent = v;
          break;
        }
      }

      final params = VideoControllerParams(
        videoId: videoId,
        videoUrl: videoUrl,
        videoEvent: videoEvent,
      );

      // Invalidate triggers disposal via Riverpod's autoDispose
      ref.invalidate(individualVideoControllerProvider(params));

      // Remove from tracking
      _preInitializedControllers.remove(videoId);
    }
  }

  /// Clear all tracked controllers (useful when feed changes completely)
  void clearTrackedControllers() {
    _preInitializedControllers.clear();
    Log.debug(
      '🧹 Cleared all tracked controllers',
      name: 'VideoPrefetchMixin',
      category: LogCategory.video,
    );
  }
}
