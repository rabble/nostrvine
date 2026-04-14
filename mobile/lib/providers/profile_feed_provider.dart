// ABOUTME: Profile feed provider with REST/Nostr pagination support per user
// ABOUTME: Manages video lists for individual user profiles with loadMore() capability
// ABOUTME: Tries REST API first for better performance, falls back to Nostr subscription

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/profile_feed_session_cache.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/state/video_feed_state.dart';
import 'package:openvine/utils/video_nostr_enrichment.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:unified_logger/unified_logger.dart';

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
  /// Timeout for funnelcake REST API calls to prevent indefinite loading.
  static const _restApiTimeout = Duration(seconds: 10);

  // REST API mode state
  bool _usingRestApi = false;
  int? _nextOffset; // Offset for REST API pagination
  int? _totalVideoCount; // Total count from X-Total-Count header
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

    _registerRetainedRealtimeListeners(videoEventService);

    if (retainedState != null && retainedState.videos.isNotEmpty) {
      _usingRestApi = funnelcakeAvailable;
      _nextOffset = estimateNextRestOffset(retainedState);
      _totalVideoCount = retainedState.totalVideoCount;
      unawaited(Future(() => refresh(retainedState: retainedState)));
      return retainedState.copyWith(
        isRefreshing: true,
        isInitialLoad: false,
        error: null,
      );
    }

    authorVideos = _relayVideosSnapshot(videoEventService);

    unawaited(
      Future(() async {
        await _refreshFromNostrSource(videoEventService);
        if (funnelcakeAvailable) {
          await _refreshFromRestApi(clientOverride: funnelcakeClient);
        }
      }),
    );

    // Check if provider is still mounted after async gap
    if (!ref.mounted) {
      return const VideoFeedState(videos: [], hasMoreContent: false);
    }

    Log.info(
      'ProfileFeed: Initial load complete - ${authorVideos.length} videos for user=$userId (REST API: $_usingRestApi)',
      name: 'ProfileFeedProvider',
      category: LogCategory.video,
    );

    final initialState = VideoFeedState(
      videos: authorVideos,
      hasMoreContent:
          authorVideos.length >= AppConstants.hasMoreContentThreshold,
      isInitialLoad: authorVideos.isEmpty,
      lastUpdated: DateTime.now(),
      totalVideoCount: _totalVideoCount,
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
    unawaited(refresh());
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

    final updatedVideos = _mergeVideoLists(currentState.videos, [newVideo]);
    if (_sameVideoSequence(currentState.videos, updatedVideos)) {
      return;
    }

    Log.info(
      'ProfileFeed: Optimistically added new video ${newVideo.id} to state (total: ${updatedVideos.length})',
      name: 'ProfileFeedProvider',
      category: LogCategory.video,
    );

    _emitState(
      currentState.copyWith(
        videos: updatedVideos,
        hasMoreContent: currentState.hasMoreContent,
        isInitialLoad: false,
        lastUpdated: DateTime.now(),
      ),
    );
  }

  /// Fix #2: Refresh from REST API when in REST API mode
  Future<void> _refreshFromRestApi({
    FunnelcakeApiClient? clientOverride,
  }) async {
    try {
      final client = clientOverride ?? ref.read(funnelcakeApiClientProvider);
      if (client == null) return;
      final result = await client
          .getVideosByAuthor(pubkey: userId)
          .timeout(_restApiTimeout);
      final apiVideos = result.videos.map((v) => v.toVideoEvent()).toList();

      if (!ref.mounted) return;

      _totalVideoCount = result.totalCount;
      _nextOffset = apiVideos.length;

      if (apiVideos.isNotEmpty) {
        final relayVideos = _relayVideosSnapshot(
          ref.read(videoEventServiceProvider),
        );
        final authorVideos = _mergeVideoLists(
          relayVideos,
          apiVideos.where((v) => !v.isRepost).toList(),
        );
        _cacheVideoMetadata(authorVideos);

        final filteredVideos = ref
            .read(videoEventServiceProvider)
            .filterVideoList(authorVideos);

        _usingRestApi = true;
        _mergeSourceVideos(
          filteredVideos,
          hasMoreContent: apiVideos.length >= AppConstants.paginationBatchSize,
          totalVideoCount: _totalVideoCount,
          isRefreshing: false,
          isInitialLoad: false,
          mergeWithCurrent: false,
        );

        // Enrich with full Nostr event data in the background.
        enrichVideosInBackground(
          authorVideos,
          nostrService: ref.read(nostrServiceProvider),
          onEnriched: (enriched) {
            if (!ref.mounted) return;
            final enrichedVideos = ref
                .read(videoEventServiceProvider)
                .filterVideoList(enriched);
            _mergeSourceVideos(
              enrichedVideos,
              hasMoreContent:
                  apiVideos.length >= AppConstants.paginationBatchSize,
              totalVideoCount: _totalVideoCount,
              isRefreshing: false,
              isInitialLoad: false,
              mergeWithCurrent: false,
            );
          },
          callerName: 'ProfileFeedProvider',
        );

        Log.info(
          'ProfileFeed: Refreshed ${filteredVideos.length} videos from REST API for user=$userId',
          name: 'ProfileFeedProvider',
          category: LogCategory.video,
        );
      } else {
        _usingRestApi = true;
        _mergeSourceVideos(
          const <VideoEvent>[],
          hasMoreContent: false,
          totalVideoCount: _totalVideoCount,
          isRefreshing: false,
          isInitialLoad: false,
          mergeWithCurrent: false,
        );

        Log.info(
          'ProfileFeed: REST API returned empty for user=$userId',
          name: 'ProfileFeedProvider',
          category: LogCategory.video,
        );
      }
    } catch (e) {
      Log.warning(
        'ProfileFeed: REST API refresh failed ($e)',
        name: 'ProfileFeedProvider',
        category: LogCategory.video,
      );
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

        final result = await client
            .getVideosByAuthor(
              pubkey: userId,
              offset: offset,
            )
            .timeout(_restApiTimeout);
        final apiVideos = result.videos.map((v) => v.toVideoEvent()).toList();

        if (!ref.mounted) return;
        _totalVideoCount = result.totalCount ?? _totalVideoCount;
        _nextOffset = offset + apiVideos.length;

        if (apiVideos.isNotEmpty) {
          var newVideos = apiVideos.where((v) => !v.isRepost).toList();

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
            final allVideos = _mergeVideoLists(currentState.videos, newVideos);
            Log.info(
              'ProfileFeed: Loaded ${newVideos.length} new videos from REST API for user=$userId (total: ${allVideos.length})',
              name: 'ProfileFeedProvider',
              category: LogCategory.video,
            );

            _emitState(
              currentState.copyWith(
                videos: allVideos,
                hasMoreContent:
                    apiVideos.length >= AppConstants.paginationBatchSize,
                isLoadingMore: false,
                lastUpdated: DateTime.now(),
                totalVideoCount: _totalVideoCount,
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
    final videoEventService = ref.read(videoEventServiceProvider);
    final refreshFutures = <Future<void>>[
      _refreshFromNostrSource(videoEventService),
      if (funnelcakeAvailable) _refreshFromRestApi(),
    ];

    await Future.wait(refreshFutures);
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
      final currentVideos = _relayVideosSnapshot(videoEventService);

      final currentState = state.asData?.value;
      if (currentState == null) {
        return;
      }

      final updatedVideos = _mergeVideoLists(
        currentState.videos,
        currentVideos,
      );
      if (_sameVideoSequence(currentState.videos, updatedVideos)) {
        return;
      }

      _emitState(
        currentState.copyWith(
          videos: updatedVideos,
          hasMoreContent: currentState.totalVideoCount != null
              ? currentState.hasMoreContent
              : updatedVideos.length >= AppConstants.hasMoreContentThreshold,
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

  Future<void> _refreshFromNostrSource(
    VideoEventService videoEventService,
  ) async {
    try {
      await videoEventService.subscribeToUserVideos(userId);
      if (!ref.mounted) return;

      final relayVideos = _relayVideosSnapshot(videoEventService);
      final currentState = state.asData?.value;
      _mergeSourceVideos(
        relayVideos,
        hasMoreContent: currentState?.totalVideoCount != null
            ? currentState!.hasMoreContent
            : relayVideos.length >= AppConstants.hasMoreContentThreshold,
        totalVideoCount: currentState?.totalVideoCount,
        isRefreshing: false,
        isInitialLoad: false,
      );
    } catch (error, stackTrace) {
      Log.error(
        'ProfileFeed: Background Nostr subscribe failed for user=$userId: $error',
        name: 'ProfileFeedProvider',
        category: LogCategory.video,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  List<VideoEvent> _relayVideosSnapshot(VideoEventService videoEventService) {
    var videos = videoEventService
        .authorVideos(userId)
        .where((v) => !v.isRepost)
        .toList();
    videos = _applyMetadataCache(videos);
    return videoEventService.filterVideoList(videos);
  }

  void _mergeSourceVideos(
    List<VideoEvent> incoming, {
    required bool hasMoreContent,
    required bool isRefreshing,
    required bool isInitialLoad,
    int? totalVideoCount,
    bool mergeWithCurrent = true,
  }) {
    final currentState = state.asData?.value;
    final currentVideos = mergeWithCurrent
        ? currentState?.videos ?? const <VideoEvent>[]
        : const <VideoEvent>[];
    final mergedVideos = _mergeVideoLists(currentVideos, incoming);

    final nextState =
        (currentState ??
                const VideoFeedState(
                  videos: <VideoEvent>[],
                  hasMoreContent: false,
                ))
            .copyWith(
              videos: mergedVideos,
              hasMoreContent: hasMoreContent,
              isLoadingMore: false,
              isRefreshing: isRefreshing,
              isInitialLoad: isInitialLoad,
              lastUpdated: DateTime.now(),
              totalVideoCount: totalVideoCount ?? currentState?.totalVideoCount,
              error: null,
            );

    if (currentState != null &&
        _sameVideoSequence(currentState.videos, nextState.videos) &&
        currentState.hasMoreContent == nextState.hasMoreContent &&
        currentState.totalVideoCount == nextState.totalVideoCount &&
        currentState.isRefreshing == nextState.isRefreshing &&
        currentState.isInitialLoad == nextState.isInitialLoad) {
      return;
    }

    _emitState(nextState);
  }

  List<VideoEvent> _mergeVideoLists(
    List<VideoEvent> current,
    List<VideoEvent> incoming,
  ) {
    final byKey = <String, VideoEvent>{};

    for (final video in current) {
      byKey[_canonicalVideoKey(video)] = video;
    }

    for (final video in incoming) {
      final key = _canonicalVideoKey(video);
      final existing = byKey[key];
      byKey[key] = existing == null ? video : _mergeVideo(existing, video);
    }

    final merged = byKey.values.toList();
    merged.sort(_compareVideos);
    return merged;
  }

  VideoEvent _mergeVideo(VideoEvent existing, VideoEvent incoming) {
    final incomingIsNewer =
        incoming.createdAt > existing.createdAt ||
        (incoming.createdAt == existing.createdAt &&
            incoming.id.compareTo(existing.id) < 0);
    final primary = incomingIsNewer ? incoming : existing;
    final secondary = incomingIsNewer ? existing : incoming;

    final primaryHasPublishedAt =
        primary.publishedAt != null && primary.publishedAt!.isNotEmpty;
    final secondaryHasPublishedAt =
        secondary.publishedAt != null && secondary.publishedAt!.isNotEmpty;
    final preserveOriginalTimestamp =
        !primaryHasPublishedAt && !secondaryHasPublishedAt;

    return primary.copyWith(
      createdAt: preserveOriginalTimestamp
          ? math.min(primary.createdAt, secondary.createdAt)
          : primary.createdAt,
      timestamp: preserveOriginalTimestamp
          ? (primary.timestamp.isBefore(secondary.timestamp)
                ? primary.timestamp
                : secondary.timestamp)
          : primary.timestamp,
      publishedAt: primaryHasPublishedAt
          ? primary.publishedAt
          : secondary.publishedAt,
      rawTags: primary.rawTags.isNotEmpty ? primary.rawTags : secondary.rawTags,
      contentWarningLabels: primary.contentWarningLabels.isNotEmpty
          ? primary.contentWarningLabels
          : secondary.contentWarningLabels,
      title: primary.title ?? secondary.title,
      videoUrl: primary.videoUrl ?? secondary.videoUrl,
      thumbnailUrl: primary.thumbnailUrl ?? secondary.thumbnailUrl,
      duration: primary.duration ?? secondary.duration,
      dimensions: primary.dimensions ?? secondary.dimensions,
      mimeType: primary.mimeType ?? secondary.mimeType,
      sha256: primary.sha256 ?? secondary.sha256,
      fileSize: primary.fileSize ?? secondary.fileSize,
      hashtags: primary.hashtags.isNotEmpty
          ? primary.hashtags
          : secondary.hashtags,
      vineId: primary.vineId ?? secondary.vineId,
      group: primary.group ?? secondary.group,
      altText: primary.altText ?? secondary.altText,
      blurhash: primary.blurhash ?? secondary.blurhash,
      originalLoops: primary.originalLoops ?? secondary.originalLoops,
      originalLikes: primary.originalLikes ?? secondary.originalLikes,
      originalComments: primary.originalComments ?? secondary.originalComments,
      originalReposts: primary.originalReposts ?? secondary.originalReposts,
      audioEventId: primary.audioEventId ?? secondary.audioEventId,
      audioEventRelay: primary.audioEventRelay ?? secondary.audioEventRelay,
      collaboratorPubkeys: primary.collaboratorPubkeys.isNotEmpty
          ? primary.collaboratorPubkeys
          : secondary.collaboratorPubkeys,
      inspiredByVideo: primary.inspiredByVideo ?? secondary.inspiredByVideo,
      textTrackRef: primary.textTrackRef ?? secondary.textTrackRef,
      textTrackContent: primary.textTrackContent ?? secondary.textTrackContent,
      nostrEventTags: primary.nostrEventTags.isNotEmpty
          ? primary.nostrEventTags
          : secondary.nostrEventTags,
      authorName: primary.authorName ?? secondary.authorName,
      authorAvatar: primary.authorAvatar ?? secondary.authorAvatar,
      nostrLikeCount: primary.nostrLikeCount ?? secondary.nostrLikeCount,
    );
  }

  String _canonicalVideoKey(VideoEvent video) {
    return '${video.pubkey}:${video.stableId}'.toLowerCase();
  }

  int _compareVideos(VideoEvent a, VideoEvent b) {
    final timestampComparison = _publishedSortKey(
      b,
    ).compareTo(_publishedSortKey(a));
    if (timestampComparison != 0) return timestampComparison;
    return a.id.compareTo(b.id);
  }

  int _publishedSortKey(VideoEvent video) {
    final publishedAt = video.publishedAt;
    if (publishedAt != null && publishedAt.isNotEmpty) {
      final parsed = int.tryParse(publishedAt);
      if (parsed != null) return parsed;
    }
    return video.createdAt;
  }

  bool _sameVideoSequence(List<VideoEvent> left, List<VideoEvent> right) {
    if (left.length != right.length) return false;
    for (var i = 0; i < left.length; i++) {
      if (left[i].id != right[i].id) return false;
    }
    return true;
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
