// ABOUTME: Profile feed provider with cursor pagination support per user
// ABOUTME: Manages video lists for individual user profiles with loadMore() capability
// ABOUTME: Tries REST API first for better performance, falls back to Nostr subscription

import 'dart:async';

import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/state/video_feed_state.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'profile_feed_provider.g.dart';

/// Profile feed provider - shows videos for a specific user with pagination
///
/// This is a family provider, so each userId gets its own provider instance
/// with independent cursor tracking.
///
/// Strategy: Try Funnelcake REST API first for better performance,
/// fall back to Nostr subscription if unavailable.
///
/// Usage:
/// ```dart
/// final feed = ref.watch(profileFeedProvider(userId));
/// await ref.read(profileFeedProvider(userId).notifier).loadMore();
/// ```
@Riverpod(keepAlive: true) // Keep alive to prevent reload on tab switches
class ProfileFeed extends _$ProfileFeed {
  // REST API mode state
  bool _usingRestApi = false;
  int? _nextCursor; // Cursor for REST API pagination

  // Cache of video metadata from REST API (preserves loops, likes, etc.)
  // Key: video ID, Value: metadata fields
  final Map<String, _VideoMetadataCache> _metadataCache = {};

  @override
  Future<VideoFeedState> build(String userId) async {
    // Reset cursor state at start of build to ensure clean state
    _usingRestApi = false;
    _nextCursor = null;

    Log.info(
      'ProfileFeed: BUILD START for user=$userId',
      name: 'ProfileFeedProvider',
      category: LogCategory.video,
    );

    // Get video event service for Nostr fallback
    final videoEventService = ref.watch(videoEventServiceProvider);
    List<VideoEvent> authorVideos = [];

    // Try REST API first if available (use centralized availability check)
    final funnelcakeAvailable =
        ref.watch(funnelcakeAvailableProvider).asData?.value ?? false;
    final analyticsService = ref.read(analyticsApiServiceProvider);
    if (funnelcakeAvailable) {
      Log.info(
        'ProfileFeed: Trying Funnelcake REST API first for user=$userId',
        name: 'ProfileFeedProvider',
        category: LogCategory.video,
      );

      try {
        final apiVideos = await analyticsService.getVideosByAuthor(
          pubkey: userId,
          limit: 100,
        );

        if (apiVideos.isNotEmpty) {
          _usingRestApi = true;
          // Filter out reposts and store cursor
          authorVideos = apiVideos.where((v) => !v.isRepost).toList();
          _nextCursor = _getOldestTimestamp(apiVideos);

          // Cache metadata for later merging with Nostr data
          _cacheVideoMetadata(authorVideos);

          Log.info(
            '✅ ProfileFeed: Got ${authorVideos.length} videos from REST API for user=$userId, cursor: $_nextCursor',
            name: 'ProfileFeedProvider',
            category: LogCategory.video,
          );
        } else {
          Log.warning(
            'ProfileFeed: REST API returned empty for user=$userId, falling back to Nostr',
            name: 'ProfileFeedProvider',
            category: LogCategory.video,
          );
          _usingRestApi = false;
        }
      } catch (e) {
        Log.warning(
          'ProfileFeed: REST API failed ($e), falling back to Nostr',
          name: 'ProfileFeedProvider',
          category: LogCategory.video,
        );
        _usingRestApi = false;
      }
    }

    // Fall back to Nostr subscription if REST API not used
    if (!_usingRestApi) {
      // Subscribe to this user's videos
      await videoEventService.subscribeToUserVideos(userId, limit: 100);

      // Wait for initial batch of videos to arrive from relay
      final completer = Completer<void>();
      int stableCount = 0;
      Timer? stabilityTimer;

      void checkStability() {
        final currentCount = videoEventService.authorVideos(userId).length;
        if (currentCount != stableCount) {
          // Count changed, reset stability timer
          stableCount = currentCount;
          stabilityTimer?.cancel();
          stabilityTimer = Timer(const Duration(milliseconds: 300), () {
            // Count stable for 300ms, we're done
            if (!completer.isCompleted) {
              completer.complete();
            }
          });
        }
      }

      videoEventService.addListener(checkStability);

      // Also set a maximum wait time
      Timer(const Duration(seconds: 3), () {
        if (!completer.isCompleted) {
          completer.complete();
        }
      });

      // Trigger initial check
      checkStability();

      await completer.future;

      // Clean up
      videoEventService.removeListener(checkStability);
      stabilityTimer?.cancel();

      // Get videos for this author, filtering out reposts (originals only)
      authorVideos = videoEventService
          .authorVideos(userId)
          .where((v) => !v.isRepost)
          .toList();

      // Apply cached metadata to preserve engagement stats from previous REST API calls
      authorVideos = _applyMetadataCache(authorVideos);

      Log.info(
        'ProfileFeed: Got ${authorVideos.length} videos from Nostr for user=$userId',
        name: 'ProfileFeedProvider',
        category: LogCategory.video,
      );
    }

    // Check if provider is still mounted after async gap
    if (!ref.mounted) {
      return VideoFeedState(
        videos: [],
        hasMoreContent: false,
        isLoadingMore: false,
      );
    }

    // Register for video update callbacks to auto-refresh when this user's video is updated
    final unregisterUpdate = videoEventService.addVideoUpdateListener((
      updated,
    ) {
      if (updated.pubkey == userId && ref.mounted) {
        refreshFromService();
      }
    });

    // Register for NEW video callbacks to auto-refresh when this user posts a new video
    final unregisterNew = videoEventService.addNewVideoListener((
      newVideo,
      authorPubkey,
    ) {
      if (authorPubkey == userId && ref.mounted) {
        // CRITICAL FIX: Optimistically add the new video to state immediately
        // instead of re-fetching from REST API which may have stale data.
        // This fixes the "video disappears after upload" bug where Funnelcake
        // hasn't indexed the new video yet but the user expects to see it.
        _addNewVideoToState(newVideo);
      }
    });

    // Clean up callbacks when provider is disposed
    ref.onDispose(() {
      unregisterUpdate();
      unregisterNew();
    });

    Log.info(
      'ProfileFeed: Initial load complete - ${authorVideos.length} videos for user=$userId (REST API: $_usingRestApi)',
      name: 'ProfileFeedProvider',
      category: LogCategory.video,
    );

    return VideoFeedState(
      videos: authorVideos,
      hasMoreContent:
          authorVideos.length >= AppConstants.hasMoreContentThreshold,
      isLoadingMore: false,
      lastUpdated: DateTime.now(),
    );
  }

  /// Get oldest timestamp from videos for cursor pagination
  int? _getOldestTimestamp(List<VideoEvent> videos) {
    if (videos.isEmpty) return null;
    return videos.map((v) => v.createdAt).reduce((a, b) => a < b ? a : b);
  }

  /// Refresh state - uses REST API when available, otherwise Nostr with metadata preservation
  /// Call this after a video is updated to sync the provider's state
  void refreshFromService() {
    // Fix #1: If using REST API, refresh from REST API instead of Nostr
    if (_usingRestApi) {
      _refreshFromRestApi();
      return;
    }

    // Nostr mode: get videos from service
    final videoEventService = ref.read(videoEventServiceProvider);
    // Filter out reposts (originals only)
    var updatedVideos = videoEventService
        .authorVideos(userId)
        .where((v) => !v.isRepost)
        .toList();

    // Fix #3: Apply cached metadata to preserve engagement stats
    updatedVideos = _applyMetadataCache(updatedVideos);

    state = AsyncData(
      VideoFeedState(
        videos: updatedVideos,
        hasMoreContent:
            updatedVideos.length >= AppConstants.hasMoreContentThreshold,
        isLoadingMore: false,
        lastUpdated: DateTime.now(),
      ),
    );
  }

  /// Optimistically add a newly published video to the profile feed state.
  /// This is called when the user publishes a new video to ensure instant feedback
  /// without waiting for Funnelcake REST API to index the event.
  void _addNewVideoToState(VideoEvent newVideo) {
    // Skip reposts - profile feed shows only original videos
    if (newVideo.isRepost) {
      Log.debug(
        'ProfileFeed: Skipping repost in optimistic update',
        name: 'ProfileFeedProvider',
        category: LogCategory.video,
      );
      return;
    }

    final currentState = state.asData?.value;
    if (currentState == null) {
      Log.warning(
        'ProfileFeed: Cannot add video to state - state is null',
        name: 'ProfileFeedProvider',
        category: LogCategory.video,
      );
      return;
    }

    // Check for duplicates (case-insensitive for Nostr IDs)
    final existingIds = currentState.videos
        .map((v) => v.id.toLowerCase())
        .toSet();
    if (existingIds.contains(newVideo.id.toLowerCase())) {
      Log.debug(
        'ProfileFeed: Video ${newVideo.id} already in state, skipping optimistic add',
        name: 'ProfileFeedProvider',
        category: LogCategory.video,
      );
      return;
    }

    // Add new video to the front of the list (most recent first)
    final updatedVideos = <VideoEvent>[newVideo, ...currentState.videos];

    Log.info(
      'ProfileFeed: Optimistically added new video ${newVideo.id} to state (total: ${updatedVideos.length})',
      name: 'ProfileFeedProvider',
      category: LogCategory.video,
    );

    state = AsyncData(
      VideoFeedState(
        videos: updatedVideos,
        hasMoreContent: currentState.hasMoreContent,
        isLoadingMore: false,
        lastUpdated: DateTime.now(),
      ),
    );
  }

  /// Fix #2: Refresh from REST API when in REST API mode
  Future<void> _refreshFromRestApi() async {
    try {
      final analyticsService = ref.read(analyticsApiServiceProvider);
      final apiVideos = await analyticsService.getVideosByAuthor(
        pubkey: userId,
        limit: 100,
      );

      if (!ref.mounted) return;

      if (apiVideos.isNotEmpty) {
        // Filter out reposts
        final authorVideos = apiVideos.where((v) => !v.isRepost).toList();

        // Update metadata cache with fresh data
        _cacheVideoMetadata(authorVideos);

        state = AsyncData(
          VideoFeedState(
            videos: authorVideos,
            hasMoreContent:
                apiVideos.length >= AppConstants.hasMoreContentThreshold,
            isLoadingMore: false,
            lastUpdated: DateTime.now(),
          ),
        );

        Log.info(
          'ProfileFeed: Refreshed ${authorVideos.length} videos from REST API for user=$userId',
          name: 'ProfileFeedProvider',
          category: LogCategory.video,
        );
      } else {
        // REST API returned empty, fall back to Nostr with metadata cache
        Log.warning(
          'ProfileFeed: REST API refresh returned empty, using Nostr with cached metadata',
          name: 'ProfileFeedProvider',
          category: LogCategory.video,
        );
        _usingRestApi = false;
        refreshFromService(); // Will now use Nostr path with metadata cache
      }
    } catch (e) {
      Log.warning(
        'ProfileFeed: REST API refresh failed ($e), using Nostr with cached metadata',
        name: 'ProfileFeedProvider',
        category: LogCategory.video,
      );
      // Fall back to Nostr with metadata cache on error
      _usingRestApi = false;
      refreshFromService();
    }
  }

  /// Load more historical events for this specific user
  Future<void> loadMore() async {
    final currentState = await future;

    // Check if provider is still mounted after async gap
    if (!ref.mounted) return;

    Log.info(
      'ProfileFeed: loadMore() called for user=$userId - isLoadingMore: ${currentState.isLoadingMore}, usingRestApi: $_usingRestApi',
      name: 'ProfileFeedProvider',
      category: LogCategory.video,
    );

    if (currentState.isLoadingMore) {
      Log.debug(
        'ProfileFeed: Already loading more, skipping',
        name: 'ProfileFeedProvider',
        category: LogCategory.video,
      );
      return;
    }

    if (!currentState.hasMoreContent) {
      Log.debug(
        'ProfileFeed: No more content available, skipping',
        name: 'ProfileFeedProvider',
        category: LogCategory.video,
      );
      return;
    }

    // Update state to show loading
    state = AsyncData(currentState.copyWith(isLoadingMore: true));

    try {
      // If using REST API, load more using cursor-based pagination
      if (_usingRestApi) {
        final analyticsService = ref.read(analyticsApiServiceProvider);
        Log.info(
          'ProfileFeed: Loading more from REST API with cursor: $_nextCursor for user=$userId',
          name: 'ProfileFeedProvider',
          category: LogCategory.video,
        );

        final apiVideos = await analyticsService.getVideosByAuthor(
          pubkey: userId,
          limit: 50,
          before: _nextCursor,
        );

        if (!ref.mounted) return;

        if (apiVideos.isNotEmpty) {
          // Deduplicate and merge (case-insensitive for Nostr IDs)
          final existingIds = currentState.videos
              .map((v) => v.id.toLowerCase())
              .toSet();
          final newVideos = apiVideos
              .where((v) => !existingIds.contains(v.id.toLowerCase()))
              .where((v) => !v.isRepost)
              .toList();

          // Update cursor for next pagination
          _nextCursor = _getOldestTimestamp(apiVideos);

          // Cache metadata from new videos
          _cacheVideoMetadata(newVideos);

          if (newVideos.isNotEmpty) {
            final allVideos = [...currentState.videos, ...newVideos];
            Log.info(
              'ProfileFeed: Loaded ${newVideos.length} new videos from REST API for user=$userId (total: ${allVideos.length})',
              name: 'ProfileFeedProvider',
              category: LogCategory.video,
            );

            state = AsyncData(
              VideoFeedState(
                videos: allVideos,
                hasMoreContent:
                    apiVideos.length >= AppConstants.paginationBatchSize,
                isLoadingMore: false,
                lastUpdated: DateTime.now(),
              ),
            );
          } else {
            Log.info(
              'ProfileFeed: All returned videos already in state for user=$userId',
              name: 'ProfileFeedProvider',
              category: LogCategory.video,
            );
            state = AsyncData(
              currentState.copyWith(
                hasMoreContent:
                    apiVideos.length >= AppConstants.paginationBatchSize,
                isLoadingMore: false,
              ),
            );
          }
        } else {
          Log.info(
            'ProfileFeed: No more videos available from REST API for user=$userId',
            name: 'ProfileFeedProvider',
            category: LogCategory.video,
          );
          state = AsyncData(
            currentState.copyWith(hasMoreContent: false, isLoadingMore: false),
          );
        }
        return;
      }

      // Nostr mode - load more from relay
      final videoEventService = ref.read(videoEventServiceProvider);

      // Find the oldest timestamp from current videos to use as cursor
      int? until;
      if (currentState.videos.isNotEmpty) {
        until = currentState.videos
            .map((v) => v.createdAt)
            .reduce((a, b) => a < b ? a : b);

        Log.debug(
          'ProfileFeed: Using Nostr cursor until=${DateTime.fromMillisecondsSinceEpoch(until * 1000)}',
          name: 'ProfileFeedProvider',
          category: LogCategory.video,
        );
      }

      final eventCountBefore = videoEventService.authorVideos(userId).length;

      // Query for older events from this specific user
      await videoEventService.queryHistoricalUserVideos(
        userId,
        until: until,
        limit: 50,
      );

      // Check if provider is still mounted after async gap
      if (!ref.mounted) return;

      final eventCountAfter = videoEventService.authorVideos(userId).length;
      final newEventsLoaded = eventCountAfter - eventCountBefore;

      Log.info(
        'ProfileFeed: Loaded $newEventsLoaded new events from Nostr for user=$userId (total: $eventCountAfter)',
        name: 'ProfileFeedProvider',
        category: LogCategory.video,
      );

      // Get updated videos, filtering out reposts (originals only)
      var updatedVideos = videoEventService
          .authorVideos(userId)
          .where((v) => !v.isRepost)
          .toList();

      // Apply cached metadata to preserve engagement stats
      updatedVideos = _applyMetadataCache(updatedVideos);

      // Update state with new videos
      if (!ref.mounted) return;
      state = AsyncData(
        VideoFeedState(
          videos: updatedVideos,
          hasMoreContent: newEventsLoaded > 0,
          isLoadingMore: false,
          lastUpdated: DateTime.now(),
        ),
      );
    } catch (e) {
      Log.error(
        'ProfileFeed: Error loading more: $e',
        name: 'ProfileFeedProvider',
        category: LogCategory.video,
      );

      if (!ref.mounted) return;
      state = AsyncData(
        currentState.copyWith(isLoadingMore: false, error: e.toString()),
      );
    }
  }

  /// Refresh the profile feed for this user
  Future<void> refresh() async {
    Log.info(
      'ProfileFeed: Refreshing feed for user=$userId',
      name: 'ProfileFeedProvider',
      category: LogCategory.video,
    );

    // If using REST API, try to refresh from there first
    if (_usingRestApi) {
      try {
        final analyticsService = ref.read(analyticsApiServiceProvider);
        final apiVideos = await analyticsService.getVideosByAuthor(
          pubkey: userId,
          limit: 100,
        );

        if (!ref.mounted) return;

        if (apiVideos.isNotEmpty) {
          // Reset cursor for pagination
          _nextCursor = _getOldestTimestamp(apiVideos);

          // Filter out reposts
          final authorVideos = apiVideos.where((v) => !v.isRepost).toList();

          // Cache metadata for future Nostr fallbacks
          _cacheVideoMetadata(authorVideos);

          state = AsyncData(
            VideoFeedState(
              videos: authorVideos,
              hasMoreContent:
                  apiVideos.length >= AppConstants.paginationBatchSize,
              isLoadingMore: false,
              lastUpdated: DateTime.now(),
            ),
          );

          Log.info(
            'ProfileFeed: Refreshed ${authorVideos.length} videos from REST API for user=$userId',
            name: 'ProfileFeedProvider',
            category: LogCategory.video,
          );
          return;
        }
      } catch (e) {
        Log.warning(
          'ProfileFeed: REST API refresh failed ($e), falling back to invalidate',
          name: 'ProfileFeedProvider',
          category: LogCategory.video,
        );
      }
    }

    // Reset cursor state before invalidating (but keep metadata cache!)
    _usingRestApi = false;
    _nextCursor = null;

    // Invalidate to re-run build() which will try REST API then Nostr
    ref.invalidateSelf();
  }

  /// Cache metadata from REST API videos for later merging with Nostr data
  void _cacheVideoMetadata(List<VideoEvent> videos) {
    for (final video in videos) {
      if (video.originalLoops != null ||
          video.originalLikes != null ||
          video.originalComments != null ||
          video.originalReposts != null) {
        _metadataCache[video.id] = _VideoMetadataCache(
          originalLoops: video.originalLoops,
          originalLikes: video.originalLikes,
          originalComments: video.originalComments,
          originalReposts: video.originalReposts,
        );
      }
    }
  }

  /// Apply cached metadata to videos that may be missing it (from Nostr)
  List<VideoEvent> _applyMetadataCache(List<VideoEvent> videos) {
    return videos.map((video) {
      final cached = _metadataCache[video.id];
      if (cached == null) return video;

      // Only apply if video is missing metadata but cache has it
      if (video.originalLoops == null && cached.originalLoops != null ||
          video.originalLikes == null && cached.originalLikes != null ||
          video.originalComments == null && cached.originalComments != null ||
          video.originalReposts == null && cached.originalReposts != null) {
        return video.copyWith(
          originalLoops: video.originalLoops ?? cached.originalLoops,
          originalLikes: video.originalLikes ?? cached.originalLikes,
          originalComments: video.originalComments ?? cached.originalComments,
          originalReposts: video.originalReposts ?? cached.originalReposts,
        );
      }
      return video;
    }).toList();
  }
}

/// Cached video metadata from REST API
/// Used to preserve engagement stats when refreshing from Nostr
class _VideoMetadataCache {
  const _VideoMetadataCache({
    this.originalLoops,
    this.originalLikes,
    this.originalComments,
    this.originalReposts,
  });

  final int? originalLoops;
  final int? originalLikes;
  final int? originalComments;
  final int? originalReposts;
}
