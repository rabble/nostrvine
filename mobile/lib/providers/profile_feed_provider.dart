// ABOUTME: Profile feed provider with REST/Nostr pagination support per user
// ABOUTME: Manages video lists for individual user profiles with loadMore() capability
// ABOUTME: Tries REST API first for better performance, falls back to Nostr subscription

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/profile_feed_session_cache.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/state/video_feed_state.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/utils/video_nostr_enrichment.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'profile_feed_provider.g.dart';

/// Profile feed provider - shows videos for a specific user with pagination
///
/// This is a family provider, so each userId gets its own provider instance
/// with independent pagination tracking.
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
  int? _nextOffset; // Offset for REST API pagination
  // Cache of video metadata from REST API (preserves loops, likes, etc.)
  // Key: video ID, Value: metadata fields
  final Map<String, _VideoMetadataCache> _metadataCache = {};

  /// Guard against concurrent refresh() calls.
  bool _isRefreshing = false;

  /// Guard against duplicate listener registration from retained-state path.
  bool _listenersRegistered = false;

  @override
  Future<VideoFeedState> build(String userId) async {
    // Reset REST pagination state at start of build to ensure clean state.
    _usingRestApi = false;
    _nextOffset = null;
    _listenersRegistered = false;
    int? restPageCount;

    // Watch content filter version — rebuilds when preferences change.
    ref.watch(contentFilterVersionProvider);
    ref.watch(divineHostFilterVersionProvider);

    Log.info(
      'ProfileFeed: BUILD START for user=$userId',
      name: 'ProfileFeedProvider',
      category: LogCategory.video,
    );

    // Get video event service for Nostr fallback
    final videoEventService = ref.watch(videoEventServiceProvider);
    List<VideoEvent> authorVideos = [];

    // Try REST API first if available (use centralized availability check)
    // Use ref.read() instead of ref.watch() to prevent cascade rebuilds
    // when funnelcake availability resolves. ProfileFeed is keepAlive, so
    // cascade rebuilds create new instances and lose state.
    final funnelcakeAsync = ref.read(funnelcakeAvailableProvider);
    final funnelcakeAvailable = funnelcakeAsync.asData?.value ?? false;
    final funnelcakeClient = ref.read(funnelcakeApiClientProvider);
    final sessionCache = ref.read(profileFeedSessionCacheProvider);
    final retainedState = sessionCache.read(userId);

    if (retainedState != null && retainedState.videos.isNotEmpty) {
      _usingRestApi = funnelcakeAvailable;
      _nextOffset = estimateNextRestOffset(retainedState);
      _registerRetainedRealtimeListeners(videoEventService);
      Future.microtask(() => refresh(retainedState: retainedState));
      return retainedState.copyWith(
        isRefreshing: true,
        isInitialLoad: false,
        error: null,
      );
    }

    if (funnelcakeAvailable) {
      Log.info(
        'ProfileFeed: Trying Funnelcake REST API first for user=$userId',
        name: 'ProfileFeedProvider',
        category: LogCategory.video,
      );

      try {
        final stats = await funnelcakeClient.getVideosByAuthor(pubkey: userId);
        final apiVideos = stats.map((v) => v.toVideoEvent()).toList();
        restPageCount = apiVideos.length;

        if (apiVideos.isNotEmpty) {
          _usingRestApi = true;
          // Filter out reposts and store the next REST page offset.
          final tempAuthorVideos = apiVideos.where((v) => !v.isRepost).toList();
          _nextOffset = apiVideos.length;

          // Cache metadata for later merging with Nostr data
          _cacheVideoMetadata(tempAuthorVideos);

          // Enrich with full Nostr event data in the background so we
          // don't block the initial render waiting on relay round-trips
          // (up to 5s timeout). Badges appear once enrichment completes.
          authorVideos = enrichVideosInBackground(
            tempAuthorVideos,
            nostrService: ref.read(nostrServiceProvider),
            onEnriched: (enriched) {
              if (!ref.mounted) return;
              final currentState = state.asData?.value;
              if (currentState == null) return;
              final enrichedMap = <String, VideoEvent>{
                for (final v in enriched) v.id: v,
              };
              final updated = currentState.videos
                  .map((v) => enrichedMap[v.id] ?? v)
                  .toList();
              state = AsyncData(currentState.copyWith(videos: updated));
            },
            callerName: 'ProfileFeedProvider',
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
      // Start the Nostr subscription in the background so the provider can
      // return retained, cached, or empty state immediately.
      unawaited(
        videoEventService.subscribeToUserVideos(userId).catchError((
          Object error,
          StackTrace stackTrace,
        ) {
          Log.error(
            'ProfileFeed: Background Nostr subscribe failed for user=$userId: $error',
            name: 'ProfileFeedProvider',
            category: LogCategory.video,
            error: error,
            stackTrace: stackTrace,
          );
        }),
      );

      // Return immediately with whatever videos are available.
      // Progressive updates arrive via the video update/new video listeners
      // registered below.
      authorVideos = videoEventService
          .authorVideos(userId)
          .where((v) => !v.isRepost)
          .toList();

      // Apply cached metadata to preserve engagement stats from previous REST API calls
      authorVideos = _applyMetadataCache(authorVideos);

      // Set up continuous listener for progressive updates from Nostr
      void onNostrVideosChanged() {
        if (!ref.mounted) return;
        final currentVideos = videoEventService
            .authorVideos(userId)
            .where((v) => !v.isRepost)
            .toList();

        // Only update if count actually changed
        final currentState = state.asData?.value;
        if (currentState != null &&
            currentVideos.length != currentState.videos.length) {
          var updatedVideos = _applyMetadataCache(currentVideos);
          updatedVideos = videoEventService.filterVideoList(updatedVideos);

          state = AsyncData(
            VideoFeedState(
              videos: updatedVideos,
              hasMoreContent:
                  updatedVideos.length >= AppConstants.hasMoreContentThreshold,
              lastUpdated: DateTime.now(),
            ),
          );
        }
      }

      videoEventService.addListener(onNostrVideosChanged);
      ref.onDispose(() {
        videoEventService.removeListener(onNostrVideosChanged);
      });
    }

    // Check if provider is still mounted after async gap
    if (!ref.mounted) {
      return const VideoFeedState(videos: [], hasMoreContent: false);
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

    // Apply content filter preferences
    authorVideos = videoEventService.filterVideoList(authorVideos);

    Log.info(
      'ProfileFeed: Initial load complete - ${authorVideos.length} videos for user=$userId (REST API: $_usingRestApi)',
      name: 'ProfileFeedProvider',
      category: LogCategory.video,
    );

    final initialState = VideoFeedState(
      videos: authorVideos,
      hasMoreContent: _usingRestApi
          ? (restPageCount ?? 0) >= AppConstants.paginationBatchSize
          : authorVideos.length >= AppConstants.hasMoreContentThreshold,
      isInitialLoad: authorVideos.isEmpty && !_usingRestApi,
      lastUpdated: DateTime.now(),
    );
    _cacheSnapshot(initialState);
    return initialState;
  }

  /// Staleness threshold — data older than this triggers a background refresh.
  @visibleForTesting
  static Duration staleTtl = const Duration(seconds: 30);

  /// Refresh in the background if cached data is stale.
  /// Returns immediately — UI keeps showing cached data, updates when done.
  void refreshIfStale() {
    final current = state.asData?.value;
    if (current == null) return; // Still loading, don't interfere
    final lastUpdated = current.lastUpdated;
    if (lastUpdated != null &&
        DateTime.now().difference(lastUpdated) < staleTtl) {
      return; // Data is fresh
    }
    refresh();
  }

  @visibleForTesting
  static int estimateNextRestOffset(VideoFeedState currentState) {
    final visibleCount = currentState.videos.length;
    if (!currentState.hasMoreContent) {
      return visibleCount;
    }

    const batchSize = AppConstants.paginationBatchSize;
    return math.max(
      batchSize,
      ((visibleCount + batchSize - 1) ~/ batchSize) * batchSize,
    );
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

    // Apply content filter preferences
    updatedVideos = videoEventService.filterVideoList(updatedVideos);

    state = AsyncData(
      VideoFeedState(
        videos: updatedVideos,
        hasMoreContent:
            updatedVideos.length >= AppConstants.hasMoreContentThreshold,
        lastUpdated: DateTime.now(),
      ),
    );
  }

  List<VideoEvent> _mergeStableTimestampsFromCurrentState(
    List<VideoEvent> incoming,
  ) {
    final currentVideos = state.asData?.value.videos;
    if (currentVideos == null || currentVideos.isEmpty) return incoming;

    // Build lookup keys because REST API responses can be inconsistent
    // about addressable identifiers (`d` tag / stableId).
    //
    // Known inconsistency:
    // - Missing d-tags: Many relays don't include 'd' tags on NIP-71 addressable events
    String? stableKey(VideoEvent v) {
      final stableId = v.stableId;
      if (stableId.isEmpty) return null;
      return '${v.pubkey}:$stableId'.toLowerCase();
    }

    final existingByKey = <String, VideoEvent>{};
    for (final v in currentVideos) {
      final key = stableKey(v);
      if (key != null) existingByKey[key] = v;
    }

    return incoming.map((video) {
      final existing = stableKey(video) != null
          ? existingByKey[stableKey(video)!]
          : null;
      if (existing == null) return video;

      // Funnelcake may return the latest replaceable event's created_at (edit time)
      // and may omit published_at. Preserve existing timestamps when published_at
      // isn't present to avoid resetting relative time to "now" after refresh.
      final hasPublishedAt =
          video.publishedAt != null && video.publishedAt!.isNotEmpty;
      if (hasPublishedAt) return video;

      return video.copyWith(
        createdAt: existing.createdAt,
        timestamp: existing.timestamp,
        publishedAt: existing.publishedAt,
      );
    }).toList();
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

    // Also deduplicate replaceable/addressable videos by stable identity.
    // Editing metadata republishes a new event id for the same (pubkey, d-tag),
    // so id-based dedupe is insufficient and would create a duplicate entry.
    final newStableKey = '${newVideo.pubkey}:${newVideo.stableId}'
        .toLowerCase();
    final existingStableKeys = currentState.videos
        .map((v) => '${v.pubkey}:${v.stableId}'.toLowerCase())
        .toSet();
    if (existingStableKeys.contains(newStableKey)) {
      Log.debug(
        'ProfileFeed: Video ${newVideo.id} matches existing stableId=${newVideo.stableId}, skipping optimistic add',
        name: 'ProfileFeedProvider',
        category: LogCategory.video,
      );
      return;
    }

    // Add new video and maintain newest-first sort order.
    // Simple prepend is insufficient because during initial Nostr subscription
    // events arrive newest-first, so prepending each one reverses the order.
    final updatedVideos = <VideoEvent>[newVideo, ...currentState.videos]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    Log.info(
      'ProfileFeed: Optimistically added new video ${newVideo.id} to state (total: ${updatedVideos.length})',
      name: 'ProfileFeedProvider',
      category: LogCategory.video,
    );

    state = AsyncData(
      VideoFeedState(
        videos: updatedVideos,
        hasMoreContent: currentState.hasMoreContent,
        lastUpdated: DateTime.now(),
      ),
    );
  }

  /// Fix #2: Refresh from REST API when in REST API mode
  Future<void> _refreshFromRestApi() async {
    try {
      final client = ref.read(funnelcakeApiClientProvider);
      final stats = await client.getVideosByAuthor(pubkey: userId);
      final apiVideos = stats.map((v) => v.toVideoEvent()).toList();

      if (!ref.mounted) return;

      if (apiVideos.isNotEmpty) {
        // Filter out reposts
        var authorVideos = apiVideos.where((v) => !v.isRepost).toList();
        authorVideos = _mergeStableTimestampsFromCurrentState(authorVideos);
        _nextOffset = apiVideos.length;

        // Update metadata cache with fresh data
        _cacheVideoMetadata(authorVideos);

        // Enrich with full Nostr event data (rawTags, dimensions, etc.)
        authorVideos = await enrichVideosWithNostrTags(
          authorVideos,
          nostrService: ref.read(nostrServiceProvider),
          callerName: 'ProfileFeedProvider',
        );

        // Apply content filter preferences
        final videoEventService = ref.read(videoEventServiceProvider);
        authorVideos = videoEventService.filterVideoList(authorVideos);

        state = AsyncData(
          VideoFeedState(
            videos: authorVideos,
            hasMoreContent:
                apiVideos.length >= AppConstants.paginationBatchSize,
            lastUpdated: DateTime.now(),
          ),
        );

        Log.info(
          'ProfileFeed: Refreshed ${authorVideos.length} videos from REST API for user=$userId',
          name: 'ProfileFeedProvider',
          category: LogCategory.video,
        );
      } else {
        // REST API returned empty — this is valid (e.g. all videos deleted)
        _nextOffset = 0;
        state = AsyncData(
          VideoFeedState(
            videos: [],
            hasMoreContent: false,
            lastUpdated: DateTime.now(),
          ),
        );

        Log.info(
          'ProfileFeed: REST API returned empty for user=$userId',
          name: 'ProfileFeedProvider',
          category: LogCategory.video,
        );
      }
    } catch (e) {
      Log.warning(
        'ProfileFeed: REST API refresh failed ($e), using Nostr with cached metadata',
        name: 'ProfileFeedProvider',
        category: LogCategory.video,
      );
      // Fall back to Nostr with metadata cache on error
      _usingRestApi = false;
      _nextOffset = null;
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
      // If using REST API, load more using offset-based pagination.
      if (_usingRestApi) {
        final client = ref.read(funnelcakeApiClientProvider);
        final offset = _nextOffset ?? estimateNextRestOffset(currentState);
        Log.info(
          'ProfileFeed: Loading more from REST API with offset: $offset for user=$userId',
          name: 'ProfileFeedProvider',
          category: LogCategory.video,
        );

        final stats = await client.getVideosByAuthor(
          pubkey: userId,
          offset: offset,
        );
        final apiVideos = stats.map((v) => v.toVideoEvent()).toList();

        if (!ref.mounted) return;
        _nextOffset = offset + apiVideos.length;

        if (apiVideos.isNotEmpty) {
          // Deduplicate and merge (case-insensitive for Nostr IDs)
          final existingIds = currentState.videos
              .map((v) => v.id.toLowerCase())
              .toSet();
          var newVideos = apiVideos
              .where((v) => !existingIds.contains(v.id.toLowerCase()))
              .where((v) => !v.isRepost)
              .toList();

          // Cache metadata from new videos
          _cacheVideoMetadata(newVideos);

          // Enrich with full Nostr event data (rawTags, dimensions, etc.)
          newVideos = await enrichVideosWithNostrTags(
            newVideos,
            nostrService: ref.read(nostrServiceProvider),
            callerName: 'ProfileFeedProvider',
          );

          // Apply content filter preferences
          final videoEventService = ref.read(videoEventServiceProvider);
          newVideos = videoEventService.filterVideoList(newVideos);

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
      await videoEventService.queryHistoricalUserVideos(userId, until: until);

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

      // Apply content filter preferences
      updatedVideos = videoEventService.filterVideoList(updatedVideos);

      // Update state with new videos
      if (!ref.mounted) return;
      state = AsyncData(
        VideoFeedState(
          videos: updatedVideos,
          hasMoreContent: newEventsLoaded > 0,
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
  Future<void> refresh({VideoFeedState? retainedState}) async {
    if (_isRefreshing) return;
    _isRefreshing = true;

    try {
      await _refreshInner(retainedState: retainedState);
    } finally {
      _isRefreshing = false;
    }
  }

  Future<void> _refreshInner({VideoFeedState? retainedState}) async {
    Log.info(
      'ProfileFeed: Refreshing feed for user=$userId',
      name: 'ProfileFeedProvider',
      category: LogCategory.video,
    );

    final currentState = retainedState ?? state.asData?.value;
    if (currentState != null && ref.mounted) {
      state = AsyncData(
        currentState.copyWith(
          isRefreshing: true,
          isInitialLoad: false,
          error: null,
        ),
      );
    }

    final funnelcakeAvailable =
        ref.read(funnelcakeAvailableProvider).asData?.value ?? false;

    if (funnelcakeAvailable) {
      try {
        final client = ref.read(funnelcakeApiClientProvider);
        final stats = await client.getVideosByAuthor(pubkey: userId);
        final apiVideos = stats.map((v) => v.toVideoEvent()).toList();

        if (!ref.mounted) return;

        if (apiVideos.isNotEmpty) {
          // Reset offset-based pagination
          _usingRestApi = true;
          _nextOffset = apiVideos.length;

          // Filter out reposts
          var authorVideos = apiVideos.where((v) => !v.isRepost).toList();
          authorVideos = _mergeStableTimestampsFromCurrentState(authorVideos);

          // Cache metadata for future Nostr fallbacks
          _cacheVideoMetadata(authorVideos);

          // Enrich with full Nostr event data (rawTags, dimensions, etc.)
          authorVideos = await enrichVideosWithNostrTags(
            authorVideos,
            nostrService: ref.read(nostrServiceProvider),
            callerName: 'ProfileFeedProvider',
          );

          // Apply content filter preferences
          final videoEventService = ref.read(videoEventServiceProvider);
          authorVideos = videoEventService.filterVideoList(authorVideos);

          _emitState(
            VideoFeedState(
              videos: authorVideos,
              hasMoreContent:
                  apiVideos.length >= AppConstants.paginationBatchSize,
              lastUpdated: DateTime.now(),
            ),
          );

          Log.info(
            'ProfileFeed: Refreshed ${authorVideos.length} videos from REST API for user=$userId',
            name: 'ProfileFeedProvider',
            category: LogCategory.video,
          );
          return;
        } else {
          // REST API returned empty — valid (e.g. all videos deleted)
          _nextOffset = 0;
          state = AsyncData(
            VideoFeedState(
              videos: [],
              hasMoreContent: false,
              lastUpdated: DateTime.now(),
            ),
          );

          Log.info(
            'ProfileFeed: REST API refresh returned empty for user=$userId',
            name: 'ProfileFeedProvider',
            category: LogCategory.video,
          );
          return;
        }
      } catch (e) {
        Log.warning(
          'ProfileFeed: REST API refresh failed ($e), falling back to Nostr refresh',
          name: 'ProfileFeedProvider',
          category: LogCategory.video,
        );
      }
    }

    // Reset REST pagination state before Nostr refresh (but keep metadata cache!)
    _usingRestApi = false;
    _nextOffset = null;

    final videoEventService = ref.read(videoEventServiceProvider);
    await videoEventService.subscribeToUserVideos(userId);

    if (!ref.mounted) return;

    var updatedVideos = videoEventService
        .authorVideos(userId)
        .where((v) => !v.isRepost)
        .toList();
    updatedVideos = _applyMetadataCache(updatedVideos);
    updatedVideos = videoEventService.filterVideoList(updatedVideos);

    _emitState(
      VideoFeedState(
        videos: updatedVideos,
        hasMoreContent:
            updatedVideos.length >= AppConstants.hasMoreContentThreshold,
        lastUpdated: DateTime.now(),
      ),
    );
  }

  /// Cache metadata from REST API videos for later merging with Nostr data
  void _cacheVideoMetadata(List<VideoEvent> videos) {
    for (final video in videos) {
      if (video.originalLoops != null ||
          video.originalLikes != null ||
          video.originalComments != null ||
          video.originalReposts != null) {
        _metadataCache[video.id.toLowerCase()] = _VideoMetadataCache(
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
      final cached = _metadataCache[video.id.toLowerCase()];
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

  void _registerRetainedRealtimeListeners(VideoEventService videoEventService) {
    if (_listenersRegistered) return;
    _listenersRegistered = true;

    void onNostrVideosChanged() {
      if (!ref.mounted) return;
      final currentVideos = videoEventService
          .authorVideos(userId)
          .where((v) => !v.isRepost)
          .toList();

      final currentState = state.asData?.value;
      if (currentState == null ||
          currentVideos.length == currentState.videos.length) {
        return;
      }

      var updatedVideos = _applyMetadataCache(currentVideos);
      updatedVideos = videoEventService.filterVideoList(updatedVideos);
      _emitState(
        currentState.copyWith(
          videos: updatedVideos,
          hasMoreContent:
              updatedVideos.length >= AppConstants.hasMoreContentThreshold,
          isRefreshing: false,
          isInitialLoad: false,
          lastUpdated: DateTime.now(),
        ),
      );
    }

    videoEventService.addListener(onNostrVideosChanged);
    ref.onDispose(() {
      videoEventService.removeListener(onNostrVideosChanged);
    });

    final unregisterUpdate = videoEventService.addVideoUpdateListener((
      updated,
    ) {
      if (updated.pubkey == userId && ref.mounted) {
        refresh();
      }
    });

    final unregisterNew = videoEventService.addNewVideoListener((
      newVideo,
      authorPubkey,
    ) {
      if (authorPubkey == userId && ref.mounted) {
        _addNewVideoToState(newVideo);
      }
    });

    ref.onDispose(() {
      unregisterUpdate();
      unregisterNew();
    });
  }

  void _emitState(VideoFeedState nextState) {
    if (!ref.mounted) return;
    state = AsyncData(nextState);
    _cacheSnapshot(nextState);
  }

  void _cacheSnapshot(VideoFeedState stateSnapshot) {
    ref
        .read(profileFeedSessionCacheProvider)
        .write(
          userId,
          stateSnapshot.copyWith(
            isLoadingMore: false,
            isRefreshing: false,
            isInitialLoad: false,
            error: null,
          ),
        );
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
