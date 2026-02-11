// ABOUTME: Home feed provider that shows videos only from people you follow
// ABOUTME: Filters video events by the user's following list for a personalized feed
// ABOUTME: Tries REST API first for better performance, falls back to Nostr subscription

import 'dart:async';

import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/extensions/video_event_extensions.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/services/video_filter_builder.dart';
import 'package:openvine/state/video_feed_state.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'home_feed_provider.g.dart';

/// Auto-refresh interval for home feed (10 minutes in production, overridable in tests)
@Riverpod(keepAlive: true)
Duration homeFeedPollInterval(Ref ref) => const Duration(minutes: 10);

/// Home feed provider - shows videos only from people you follow
///
/// Rebuilds occur when:
/// - Contact list changes (follow/unfollow)
/// - Poll interval elapses (default 10 minutes, injectable via homeFeedPollIntervalProvider)
/// - User pulls to refresh
///
/// Timer lifecycle:
/// - Starts when provider is first watched
/// - Pauses when all listeners detach (ref.onCancel)
/// - Resumes when a new listener attaches (ref.onResume)
/// - Cancels on dispose
@Riverpod(keepAlive: false) // Auto-dispose when no listeners
class HomeFeed extends _$HomeFeed {
  Timer? _profileFetchTimer;
  Timer? _autoRefreshTimer;
  static int _buildCounter = 0;
  static DateTime? _lastBuildTime;

  // REST API mode state
  bool _usingRestApi = false;
  bool _restApiSucceededOnce = false; // Survives rebuilds - prefer REST API
  int? _nextCursor; // Cursor for REST API pagination
  bool _hasMoreFromApi = true;

  @override
  Future<VideoFeedState> build() async {
    // Reset per-build state but preserve REST API preference
    // _restApiSucceededOnce survives rebuilds so we keep using REST API
    _usingRestApi = false;
    _nextCursor = null;
    _hasMoreFromApi = true;

    // Note: isNostrReadyProvider listener removed intentionally.
    // REST API is the primary path and doesn't need Nostr to be ready.
    // Follow list reactivity is handled by followRepository.followingStream.

    // Prevent auto-dispose during async operations
    final keepAliveLink = ref.keepAlive();

    _buildCounter++;
    final buildId = _buildCounter;
    final now = DateTime.now();
    final timeSinceLastBuild = _lastBuildTime != null
        ? now.difference(_lastBuildTime!).inMilliseconds
        : null;

    Log.info(
      '🏠 HomeFeed: BUILD #$buildId START at ${now.millisecondsSinceEpoch}ms'
      '${timeSinceLastBuild != null ? ' (${timeSinceLastBuild}ms since last build)' : ''}',
      name: 'HomeFeedProvider',
      category: LogCategory.video,
    );

    if (timeSinceLastBuild != null && timeSinceLastBuild < 2000) {
      Log.warning(
        '⚠️  HomeFeed: RAPID REBUILD DETECTED! Only ${timeSinceLastBuild}ms since last build. '
        'This may indicate a provider dependency issue.',
        name: 'HomeFeedProvider',
        category: LogCategory.video,
      );
    }

    _lastBuildTime = now;

    // Get injectable poll interval (overridable in tests)
    final pollInterval = ref.read(homeFeedPollIntervalProvider);

    // Timer lifecycle management
    void startAutoRefresh() {
      _autoRefreshTimer?.cancel();
      _autoRefreshTimer = Timer(pollInterval, () {
        Log.info(
          '🏠 HomeFeed: Auto-refresh triggered after ${pollInterval.inMinutes} minutes',
          name: 'HomeFeedProvider',
          category: LogCategory.video,
        );
        if (ref.mounted) {
          ref.invalidateSelf();
        }
      });
    }

    void stopAutoRefresh() {
      _autoRefreshTimer?.cancel();
      _autoRefreshTimer = null;
    }

    // Start timer when provider is first watched or resumed
    ref.onResume(() {
      Log.debug(
        '🏠 HomeFeed: Resuming auto-refresh timer',
        name: 'HomeFeedProvider',
        category: LogCategory.video,
      );
      startAutoRefresh();
    });

    // Pause timer when all listeners detach
    ref.onCancel(() {
      Log.debug(
        '🏠 HomeFeed: Pausing auto-refresh timer (no listeners)',
        name: 'HomeFeedProvider',
        category: LogCategory.video,
      );
      stopAutoRefresh();
    });

    // Clean up timers on dispose
    ref.onDispose(() {
      Log.info(
        '🏠 HomeFeed: BUILD #$buildId DISPOSED',
        name: 'HomeFeedProvider',
        category: LogCategory.video,
      );
      stopAutoRefresh();
      _profileFetchTimer?.cancel();
    });

    // Start timer immediately for first build
    startAutoRefresh();

    // Get current user pubkey for REST API (available after auth, before Nostr ready)
    final authService = ref.read(authServiceProvider);
    final currentUserPubkey = authService.currentPublicKeyHex;

    // Will hold videos from either REST API or Nostr
    List<VideoEvent> followingVideosFromSource = [];

    // Emit initial loading state so UI shows loading indicator instead of empty state
    state = const AsyncData(
      VideoFeedState(videos: [], hasMoreContent: false, isInitialLoad: true),
    );

    // === PRIMARY PATH: Try REST API first ===
    // REST API only needs pubkey + analyticsApiService (independent of Nostr/followRepository)
    // Try optimistically without waiting for funnelcakeAvailableProvider to resolve
    final analyticsService = ref.read(analyticsApiServiceProvider);
    if (currentUserPubkey != null) {
      Log.info(
        '🏠 HomeFeed: Trying Funnelcake REST API first (pubkey available)',
        name: 'HomeFeedProvider',
        category: LogCategory.video,
      );

      try {
        final feedResult = await analyticsService.getHomeFeed(
          pubkey: currentUserPubkey,
          limit: 100,
          sort: 'recent',
        );

        if (feedResult.videos.isNotEmpty) {
          _usingRestApi = true;
          _restApiSucceededOnce = true;
          _nextCursor = feedResult.nextCursor;
          _hasMoreFromApi = feedResult.hasMore;
          followingVideosFromSource = feedResult.videos;

          Log.info(
            '✅ HomeFeed: Got ${feedResult.videos.length} videos from REST API, '
            'hasMore: ${feedResult.hasMore}, cursor: ${feedResult.nextCursor}',
            name: 'HomeFeedProvider',
            category: LogCategory.video,
          );
        } else {
          Log.warning(
            '🏠 HomeFeed: REST API returned empty, falling back to Nostr',
            name: 'HomeFeedProvider',
            category: LogCategory.video,
          );
          _usingRestApi = false;
        }
      } catch (e, stackTrace) {
        Log.error(
          '🏠 HomeFeed: REST API failed ($e), falling back to Nostr',
          name: 'HomeFeedProvider',
          category: LogCategory.video,
          error: e,
          stackTrace: stackTrace,
        );
        _usingRestApi = false;
      }
    }

    // === NOSTR FALLBACK PATH ===
    // Only attempt Nostr subscription if REST API didn't provide videos
    // FollowRepository requires NostrClient to be ready with keys

    // Read following list from FollowRepository (source of truth for BLoC-based follow actions)
    // FollowRepository is null until NostrClient is ready with keys
    final followRepository = ref.watch(followRepositoryProvider);

    // If REST API succeeded, we still set up followRepository listeners for
    // follow/unfollow reactivity, but don't block on it
    if (followRepository != null) {
      // Listen to followingStream and refresh when following list changes
      // Skip the initial replay from BehaviorSubject using skip(1)
      final followingSubscription = followRepository.followingStream
          .skip(1) // Skip initial replay, only react to NEW emissions
          .listen((newFollowingList) {
            Log.info(
              '🏠 HomeFeed: Stream received new following list '
              '(${newFollowingList.length} users), '
              'restApiPreferred=$_restApiSucceededOnce',
              name: 'HomeFeedProvider',
              category: LogCategory.video,
            );
            if (ref.mounted) {
              if (_restApiSucceededOnce) {
                // REST API worked before - re-fetch from REST API
                // instead of invalidating (which resets _usingRestApi)
                _refreshFromRestApi();
              } else {
                ref.invalidateSelf();
              }
            }
          });

      // Clean up stream subscription on dispose
      ref.onDispose(() {
        followingSubscription.cancel();
      });
    } else if (!_usingRestApi) {
      Log.info(
        '🏠 HomeFeed: Waiting for FollowRepository (NostrClient not ready) '
        'and REST API unavailable - keeping provider alive for rebuild',
        name: 'HomeFeedProvider',
        category: LogCategory.video,
      );
      stopAutoRefresh();
      return const VideoFeedState(
        videos: [],
        hasMoreContent: false,
        isInitialLoad: true,
      );
    }

    // Read (not watch) curatedListsState to check if subscribed lists are still loading
    // Watching would cause cascade rebuilds through userProfileService chain
    final curatedListsState = ref.read(curatedListsStateProvider);
    final isCuratedListsLoading = curatedListsState.isLoading;

    // Watch subscribedListVideoCache - provider will rebuild when cache changes
    // We listen to the cache's ChangeNotifier to invalidate when list videos change
    final subscribedListCacheForListener = ref.watch(
      subscribedListVideoCacheProvider,
    );
    if (subscribedListCacheForListener != null) {
      void onCacheChanged() {
        Log.debug(
          '🏠 HomeFeed: SubscribedListVideoCache updated, refreshing from service',
          name: 'HomeFeedProvider',
          category: LogCategory.video,
        );
        if (ref.mounted) {
          refreshFromService();
        }
      }

      subscribedListCacheForListener.addListener(onCacheChanged);
      ref.onDispose(() {
        subscribedListCacheForListener.removeListener(onCacheChanged);
      });
    }

    // Get following pubkeys (may be empty if followRepository not ready yet)
    final followingPubkeys = followRepository?.followingPubkeys ?? [];

    // Even if not following anyone, we might have videos from subscribed lists
    // Need to wait for CuratedListService to initialize before declaring empty
    // hasSubscribedLists is true if cache is ready OR still loading
    final hasSubscribedLists =
        subscribedListCacheForListener != null || isCuratedListsLoading;

    Log.info(
      '🏠 HomeFeed: BUILD #$buildId - User is following ${followingPubkeys.length} people, '
      'curatedListsLoading=$isCuratedListsLoading, cache=${subscribedListCacheForListener != null ? "ready" : "null"}, '
      'usingRestApi=$_usingRestApi',
      name: 'HomeFeedProvider',
      category: LogCategory.video,
    );

    if (!_usingRestApi && followingPubkeys.isEmpty && !hasSubscribedLists) {
      // Return empty state only if REST API didn't provide videos AND
      // not following anyone AND curated lists are done loading
      // AND there's still no cache (meaning user has no subscribed lists)
      keepAliveLink.close();
      return VideoFeedState(
        videos: [],
        hasMoreContent: false,
        isLoadingMore: false,
        error: null,
        lastUpdated: DateTime.now(),
      );
    }

    // Get video event service for subscriptions and cache management
    final videoEventService = ref.watch(videoEventServiceProvider);

    // Fall back to Nostr subscription if REST API not used
    if (!_usingRestApi && followingPubkeys.isNotEmpty) {
      // Subscribe to home feed videos from followed authors using dedicated subscription type
      // NostrService now handles deduplication automatically
      // Request server-side sorting by created_at (newest first) if relay supports it
      // Use force: true to ensure new subscription even if params seem similar
      Log.info(
        '🏠 HomeFeed: Using Nostr subscription with ${followingPubkeys.length} authors',
        name: 'HomeFeedProvider',
        category: LogCategory.video,
      );

      await videoEventService.subscribeToHomeFeed(
        followingPubkeys,
        limit: 100,
        sortBy:
            VideoSortField.createdAt, // Newest videos first (timeline order)
        force: true,
      );
      Log.info(
        '🏠 HomeFeed: After subscribe, cache has ${videoEventService.homeFeedVideos.length} videos',
        name: 'HomeFeedProvider',
        category: LogCategory.video,
      );

      // Wait for initial batch of videos to arrive from relay
      // Videos arrive in rapid succession, so we wait for the count to stabilize
      final completer = Completer<void>();
      int stableCount = -1; // Start at -1 so first check always triggers timer
      Timer? stabilityTimer;

      void checkStability() {
        final currentCount = videoEventService.homeFeedVideos.length;
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

      Log.info(
        '🏠 HomeFeed: After stability wait, cache has ${videoEventService.homeFeedVideos.length} videos',
        name: 'HomeFeedProvider',
        category: LogCategory.video,
      );

      // Get videos from Nostr service
      followingVideosFromSource = List<VideoEvent>.from(
        videoEventService.homeFeedVideos,
      );
    } else if (!_usingRestApi) {
      // Not following anyone - need subscribed list cache to show any content
      Log.info(
        '🏠 HomeFeed: Not following anyone, waiting for subscribed list cache',
        name: 'HomeFeedProvider',
        category: LogCategory.video,
      );

      // If cache is null because CuratedListService is still loading,
      // return loading state - provider will rebuild when cache becomes ready
      if (subscribedListCacheForListener == null) {
        if (isCuratedListsLoading) {
          Log.info(
            '🏠 HomeFeed: Cache not ready yet (curated lists still loading), returning loading state',
            name: 'HomeFeedProvider',
            category: LogCategory.video,
          );
          keepAliveLink.close();
          return const VideoFeedState(
            videos: [],
            hasMoreContent: false,
            isInitialLoad: true,
          );
        }
        // If not loading and still null, user has no subscribed lists
        Log.info(
          '🏠 HomeFeed: No subscribed lists found',
          name: 'HomeFeedProvider',
          category: LogCategory.video,
        );
        keepAliveLink.close();
        return VideoFeedState(
          videos: [],
          hasMoreContent: false,
          isLoadingMore: false,
          error: null,
          lastUpdated: DateTime.now(),
        );
      }

      // Cache is ready - wait for it to have videos (up to 2 seconds)
      final completer = Completer<void>();
      Timer? checkTimer;

      void checkCache() {
        final videos = subscribedListCacheForListener.getVideos();
        if (videos.isNotEmpty) {
          checkTimer?.cancel();
          if (!completer.isCompleted) {
            completer.complete();
          }
        }
      }

      // Check periodically
      checkTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
        checkCache();
      });

      // Listen for cache updates
      void onCacheUpdate() {
        checkCache();
      }

      subscribedListCacheForListener.addListener(onCacheUpdate);

      // Clean up listener when done
      completer.future.then((_) {
        subscribedListCacheForListener.removeListener(onCacheUpdate);
      });

      // Maximum wait time of 2 seconds (first video notifies immediately now)
      Timer(const Duration(seconds: 2), () {
        checkTimer?.cancel();
        if (!completer.isCompleted) {
          completer.complete();
        }
      });

      // Check immediately
      checkCache();

      await completer.future;
      checkTimer.cancel();

      Log.info(
        '🏠 HomeFeed: Done waiting for subscribed list cache, has ${subscribedListCacheForListener.getVideos().length} videos',
        name: 'HomeFeedProvider',
        category: LogCategory.video,
      );
    }

    // Check if provider is still mounted after async gap
    if (!ref.mounted) {
      keepAliveLink.close();
      return VideoFeedState(
        videos: [],
        hasMoreContent: false,
        isLoadingMore: false,
        error: null,
        lastUpdated: null,
      );
    }

    // Use videos from REST API or Nostr based on mode
    var followingVideos = _usingRestApi
        ? followingVideosFromSource
        : List<VideoEvent>.from(videoEventService.homeFeedVideos);

    // Client-side filter to ensure only videos from currently followed users are shown
    // This handles the case where Nostr cache contains videos from recently unfollowed users
    // Only apply when using Nostr mode AND followingPubkeys is available
    // REST API already filters server-side, so skip for REST API mode
    if (!_usingRestApi && followingPubkeys.isNotEmpty) {
      final followingSet = followingPubkeys.toSet();
      final beforeClientFilter = followingVideos.length;
      followingVideos = followingVideos
          .where((v) => followingSet.contains(v.pubkey))
          .toList();
      if (beforeClientFilter != followingVideos.length) {
        Log.info(
          '🏠 HomeFeed: Client-side filtered ${beforeClientFilter - followingVideos.length} videos from unfollowed users',
          name: 'HomeFeedProvider',
          category: LogCategory.video,
        );
      }
    }

    Log.info(
      '🏠 HomeFeed: ${followingVideos.length} videos from following (REST API: $_usingRestApi)',
      name: 'HomeFeedProvider',
      category: LogCategory.video,
    );

    // Track IDs of videos from followed users for deduplication
    final followingVideoIds = followingVideos.map((v) => v.id).toSet();

    // Merge videos from subscribed curated lists
    final subscribedListCache = ref.read(subscribedListVideoCacheProvider);
    final subscribedVideos = subscribedListCache?.getVideos() ?? [];

    // Track which videos are ONLY from subscribed lists (not from follows)
    // and map each video to its source list(s)
    final listOnlyVideoIds = <String>{};
    final videoListSources = <String, Set<String>>{};

    for (final video in subscribedVideos) {
      final listIds = subscribedListCache?.getListsForVideo(video.id) ?? {};
      if (listIds.isNotEmpty) {
        videoListSources[video.id] = listIds;

        if (!followingVideoIds.contains(video.id)) {
          // Video is ONLY in feed because of subscribed list, not from follows
          listOnlyVideoIds.add(video.id);
          followingVideos.add(video);
        }
      }
    }

    if (listOnlyVideoIds.isNotEmpty) {
      Log.info(
        '🏠 HomeFeed: Merged ${listOnlyVideoIds.length} videos from subscribed lists',
        name: 'HomeFeedProvider',
        category: LogCategory.video,
      );
    }

    // Filter out WebM videos on iOS/macOS (not supported by AVPlayer)
    final beforeFilter = followingVideos.length;
    followingVideos = followingVideos
        .where((v) => v.isSupportedOnCurrentPlatform)
        .toList();
    if (beforeFilter != followingVideos.length) {
      Log.info(
        '🏠 HomeFeed: Filtered out ${beforeFilter - followingVideos.length} unsupported videos (WebM on iOS/macOS)',
        name: 'HomeFeedProvider',
        category: LogCategory.video,
      );
    }

    // DEBUG: Dump all events with cdn.divine.video thumbnails
    videoEventService.debugDumpCdnDivineVideoThumbnails();

    // Sort by creation time (newest first) with stable secondary sort by ID
    // This prevents videos with identical timestamps from jumping around
    followingVideos.sort((a, b) {
      final timeCompare = b.createdAt.compareTo(a.createdAt);
      if (timeCompare != 0) return timeCompare;
      // Secondary sort by ID for stable ordering when timestamps match
      return a.id.compareTo(b.id);
    });

    Log.info(
      '🏠 HomeFeed: Sorted ${followingVideos.length} videos by creation time (newest first)',
      name: 'HomeFeedProvider',
      category: LogCategory.video,
    );

    // Auto-fetch profiles for new videos and wait for completion
    await _scheduleBatchProfileFetch(followingVideos);

    // Check if provider is still mounted after async gap
    if (!ref.mounted) {
      keepAliveLink.close();
      return VideoFeedState(
        videos: [],
        hasMoreContent: false,
        isLoadingMore: false,
        error: null,
        lastUpdated: null,
      );
    }

    // Keep showing loading if we have no videos but might still be getting them from lists
    // This prevents showing "empty" while subscribed list cache is still syncing
    final stillLoadingLists = followingVideos.isEmpty && hasSubscribedLists;

    // Determine if there's more content:
    // - REST API mode: use the API's hasMore response
    // - Nostr mode: use threshold heuristic
    final hasMoreContent = _usingRestApi
        ? _hasMoreFromApi
        : followingVideos.length >= AppConstants.hasMoreContentThreshold;

    final feedState = VideoFeedState(
      videos: followingVideos,
      hasMoreContent: hasMoreContent,
      isLoadingMore: false,
      isInitialLoad: stillLoadingLists,
      error: null,
      lastUpdated: DateTime.now(),
      videoListSources: videoListSources,
      listOnlyVideoIds: listOnlyVideoIds,
    );

    // Register for video update callbacks to auto-refresh when any video is updated
    final unregisterVideoUpdate = videoEventService.addVideoUpdateListener((
      updated,
    ) {
      if (ref.mounted) {
        refreshFromService();
      }
    });

    // Clean up callback when provider is disposed
    ref.onDispose(unregisterVideoUpdate);

    final buildDuration = DateTime.now().difference(now).inMilliseconds;

    Log.info(
      '✅ HomeFeed: BUILD #$buildId COMPLETE - ${followingVideos.length} videos from following in ${buildDuration}ms',
      name: 'HomeFeedProvider',
      category: LogCategory.video,
    );

    // Close keepAlive link to allow auto-dispose after build completes
    keepAliveLink.close();

    return feedState;
  }

  Future<void> _scheduleBatchProfileFetch(List<VideoEvent> videos) async {
    // Cancel any existing timer
    _profileFetchTimer?.cancel();

    // Check if provider is still mounted after async gap
    if (!ref.mounted) return;

    // Fetch profiles immediately - no delay needed as provider handles batching internally
    final profilesProvider = ref.read(userProfileProvider.notifier);

    final newPubkeys = videos
        .map((v) => v.pubkey)
        .where((pubkey) => !profilesProvider.hasProfile(pubkey))
        .toSet()
        .toList();

    if (newPubkeys.isNotEmpty) {
      Log.debug(
        'HomeFeed: Fetching ${newPubkeys.length} new profiles immediately and waiting for completion',
        name: 'HomeFeedProvider',
        category: LogCategory.video,
      );

      // Wait for profiles to be fetched before continuing
      await profilesProvider.fetchMultipleProfiles(newPubkeys);

      Log.debug(
        'HomeFeed: Profile fetching completed for ${newPubkeys.length} profiles',
        name: 'HomeFeedProvider',
        category: LogCategory.video,
      );
    } else {
      Log.debug(
        'HomeFeed: All ${videos.length} video profiles already cached',
        name: 'HomeFeedProvider',
        category: LogCategory.video,
      );
    }
  }

  /// Load more historical events from followed authors
  Future<void> loadMore() async {
    final currentState = await future;

    // Check if provider is still mounted after async gap
    if (!ref.mounted) return;

    Log.info(
      'HomeFeed: loadMore() called - isLoadingMore: ${currentState.isLoadingMore}, usingRestApi: $_usingRestApi',
      name: 'HomeFeedProvider',
      category: LogCategory.video,
    );

    if (currentState.isLoadingMore) {
      return;
    }

    // Update state to show loading
    state = AsyncData(currentState.copyWith(isLoadingMore: true));

    try {
      // If using REST API, load more using cursor-based pagination
      if (_usingRestApi) {
        if (!_hasMoreFromApi) {
          Log.info(
            'HomeFeed: No more content available from REST API',
            name: 'HomeFeedProvider',
            category: LogCategory.video,
          );
          if (!ref.mounted) return;
          state = AsyncData(
            currentState.copyWith(isLoadingMore: false, hasMoreContent: false),
          );
          return;
        }

        final authService = ref.read(authServiceProvider);
        final currentUserPubkey = authService.currentPublicKeyHex;
        if (currentUserPubkey == null) {
          if (!ref.mounted) return;
          state = AsyncData(
            currentState.copyWith(isLoadingMore: false, hasMoreContent: false),
          );
          return;
        }

        final analyticsService = ref.read(analyticsApiServiceProvider);
        Log.info(
          'HomeFeed: Loading more from REST API with cursor: $_nextCursor',
          name: 'HomeFeedProvider',
          category: LogCategory.video,
        );

        final feedResult = await analyticsService.getHomeFeed(
          pubkey: currentUserPubkey,
          limit: 50,
          sort: 'recent',
          before: _nextCursor,
        );

        if (!ref.mounted) return;

        if (feedResult.videos.isNotEmpty) {
          // Deduplicate and merge (case-insensitive for Nostr IDs)
          final existingIds = currentState.videos
              .map((v) => v.id.toLowerCase())
              .toSet();
          final newVideos = feedResult.videos
              .where((v) => !existingIds.contains(v.id.toLowerCase()))
              .where((v) => v.isSupportedOnCurrentPlatform)
              .toList();

          // Update cursor for next pagination
          _nextCursor = feedResult.nextCursor;
          _hasMoreFromApi = feedResult.hasMore;

          if (newVideos.isNotEmpty) {
            final allVideos = [...currentState.videos, ...newVideos];
            Log.info(
              'HomeFeed: Loaded ${newVideos.length} new videos from REST API (total: ${allVideos.length})',
              name: 'HomeFeedProvider',
              category: LogCategory.video,
            );

            state = AsyncData(
              currentState.copyWith(
                videos: allVideos,
                hasMoreContent: feedResult.hasMore,
                isLoadingMore: false,
              ),
            );
          } else {
            Log.info(
              'HomeFeed: All returned videos already in state',
              name: 'HomeFeedProvider',
              category: LogCategory.video,
            );
            state = AsyncData(
              currentState.copyWith(
                hasMoreContent: feedResult.hasMore,
                isLoadingMore: false,
              ),
            );
          }
        } else {
          _hasMoreFromApi = false;
          Log.info(
            'HomeFeed: No more videos available from REST API',
            name: 'HomeFeedProvider',
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
      final followRepository = ref.read(followRepositoryProvider);

      // FollowRepository not ready - can't load more
      if (followRepository == null) {
        if (!ref.mounted) return;
        state = AsyncData(currentState.copyWith(isLoadingMore: false));
        return;
      }
      final followingPubkeys = followRepository.followingPubkeys;

      if (followingPubkeys.isEmpty) {
        // No one to load more from
        if (!ref.mounted) return;
        state = AsyncData(
          currentState.copyWith(isLoadingMore: false, hasMoreContent: false),
        );
        return;
      }

      final eventCountBefore = videoEventService.getEventCount(
        SubscriptionType.homeFeed,
      );

      // Load more events for home feed subscription type
      await videoEventService.loadMoreEvents(
        SubscriptionType.homeFeed,
        limit: 50,
      );

      // Check if provider is still mounted after async gap
      if (!ref.mounted) return;

      final eventCountAfter = videoEventService.getEventCount(
        SubscriptionType.homeFeed,
      );
      final newEventsLoaded = eventCountAfter - eventCountBefore;

      Log.info(
        'HomeFeed: Loaded $newEventsLoaded new events from Nostr (total: $eventCountAfter)',
        name: 'HomeFeedProvider',
        category: LogCategory.video,
      );

      // Reset loading state - state will auto-update via dependencies
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
        'HomeFeed: Error loading more: $e',
        name: 'HomeFeedProvider',
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

  /// Re-fetch home feed from REST API without a full provider rebuild.
  /// Used when following list changes and REST API is the preferred path.
  Future<void> _refreshFromRestApi() async {
    final authService = ref.read(authServiceProvider);
    final currentUserPubkey = authService.currentPublicKeyHex;
    if (currentUserPubkey == null) return;

    Log.info(
      '🏠 HomeFeed: Re-fetching from REST API after follow list change',
      name: 'HomeFeedProvider',
      category: LogCategory.video,
    );

    try {
      final analyticsService = ref.read(analyticsApiServiceProvider);
      final feedResult = await analyticsService.getHomeFeed(
        pubkey: currentUserPubkey,
        limit: 100,
        sort: 'recent',
      );

      if (!ref.mounted) return;

      if (feedResult.videos.isNotEmpty) {
        _usingRestApi = true;
        _nextCursor = feedResult.nextCursor;
        _hasMoreFromApi = feedResult.hasMore;

        var videos = feedResult.videos
            .where((v) => v.isSupportedOnCurrentPlatform)
            .toList();

        // Merge subscribed list videos
        final subscribedListCache = ref.read(subscribedListVideoCacheProvider);
        final subscribedVideos = subscribedListCache?.getVideos() ?? [];
        final followingVideoIds = videos.map((v) => v.id).toSet();
        final listOnlyVideoIds = <String>{};
        final videoListSources = <String, Set<String>>{};

        for (final video in subscribedVideos) {
          final listIds = subscribedListCache?.getListsForVideo(video.id) ?? {};
          if (listIds.isNotEmpty) {
            videoListSources[video.id] = listIds;
            if (!followingVideoIds.contains(video.id)) {
              listOnlyVideoIds.add(video.id);
              videos.add(video);
            }
          }
        }

        // Sort by creation time (newest first)
        videos.sort((a, b) {
          final timeCompare = b.createdAt.compareTo(a.createdAt);
          if (timeCompare != 0) return timeCompare;
          return a.id.compareTo(b.id);
        });

        Log.info(
          '✅ HomeFeed: REST API refresh got ${videos.length} videos',
          name: 'HomeFeedProvider',
          category: LogCategory.video,
        );

        state = AsyncData(
          VideoFeedState(
            videos: videos,
            hasMoreContent: feedResult.hasMore,
            isLoadingMore: false,
            lastUpdated: DateTime.now(),
            videoListSources: videoListSources,
            listOnlyVideoIds: listOnlyVideoIds,
          ),
        );
      } else {
        Log.warning(
          '🏠 HomeFeed: REST API refresh returned empty, '
          'falling back to full rebuild',
          name: 'HomeFeedProvider',
          category: LogCategory.video,
        );
        _restApiSucceededOnce = false;
        ref.invalidateSelf();
      }
    } catch (e, stackTrace) {
      Log.error(
        '🏠 HomeFeed: REST API refresh failed: $e',
        name: 'HomeFeedProvider',
        category: LogCategory.video,
        error: e,
        stackTrace: stackTrace,
      );
      // Fall back to full rebuild which will try REST API then Nostr
      _restApiSucceededOnce = false;
      ref.invalidateSelf();
    }
  }

  /// Refresh state from VideoEventService without re-subscribing to relay
  /// Call this after a video is updated to sync the provider's state
  /// Only applies to Nostr mode - REST API mode re-fetches on refresh()
  void refreshFromService() {
    // Skip if using REST API - refreshFromService reads from Nostr cache
    // which is empty in REST API mode, causing videos to disappear
    if (_usingRestApi) return;

    final videoEventService = ref.read(videoEventServiceProvider);
    var updatedVideos = List<VideoEvent>.from(videoEventService.homeFeedVideos);

    // Track IDs of videos from followed users for deduplication
    final followingVideoIds = updatedVideos.map((v) => v.id).toSet();

    // Merge videos from subscribed curated lists
    final subscribedListCache = ref.read(subscribedListVideoCacheProvider);
    final subscribedVideos = subscribedListCache?.getVideos() ?? [];

    // Track which videos are ONLY from subscribed lists (not from follows)
    final listOnlyVideoIds = <String>{};
    final videoListSources = <String, Set<String>>{};

    for (final video in subscribedVideos) {
      final listIds = subscribedListCache?.getListsForVideo(video.id) ?? {};
      if (listIds.isNotEmpty) {
        videoListSources[video.id] = listIds;

        if (!followingVideoIds.contains(video.id)) {
          listOnlyVideoIds.add(video.id);
          updatedVideos.add(video);
        }
      }
    }

    // Apply same filtering as build()
    updatedVideos = updatedVideos
        .where((v) => v.isSupportedOnCurrentPlatform)
        .toList();

    // Sort by creation time (newest first)
    updatedVideos.sort((a, b) {
      final timeCompare = b.createdAt.compareTo(a.createdAt);
      if (timeCompare != 0) return timeCompare;
      return a.id.compareTo(b.id);
    });

    // Preserve hasMore from API mode, otherwise use threshold heuristic
    final hasMoreContent = _usingRestApi
        ? _hasMoreFromApi
        : updatedVideos.length >= AppConstants.hasMoreContentThreshold;

    state = AsyncData(
      VideoFeedState(
        videos: updatedVideos,
        hasMoreContent: hasMoreContent,
        isLoadingMore: false,
        lastUpdated: DateTime.now(),
        videoListSources: videoListSources,
        listOnlyVideoIds: listOnlyVideoIds,
      ),
    );
  }

  /// Refresh the home feed (pull-to-refresh)
  Future<void> refresh() async {
    Log.info(
      'HomeFeed: Refreshing home feed (restApiPreferred=$_restApiSucceededOnce)',
      name: 'HomeFeedProvider',
      category: LogCategory.video,
    );

    // If REST API is the preferred path, re-fetch from REST API directly
    if (_restApiSucceededOnce) {
      await _refreshFromRestApi();
      return;
    }

    // Nostr fallback path
    final videoEventService = ref.read(videoEventServiceProvider);
    final followRepository = ref.read(followRepositoryProvider);

    // Can't refresh if FollowRepository not ready
    if (followRepository == null) {
      Log.warning(
        'HomeFeed: Cannot refresh - FollowRepository not ready',
        name: 'HomeFeedProvider',
        category: LogCategory.video,
      );
      return;
    }
    final followingPubkeys = followRepository.followingPubkeys;

    if (followingPubkeys.isNotEmpty) {
      // Force new subscription to get fresh data from relay
      await videoEventService.subscribeToHomeFeed(
        followingPubkeys,
        limit: 100,
        sortBy: VideoSortField.createdAt,
        force: true, // Force refresh bypasses duplicate detection
      );
    }

    // Invalidate self to rebuild with fresh data
    ref.invalidateSelf();
  }
}

/// Provider to check if home feed is loading
@riverpod
bool homeFeedLoading(Ref ref) {
  final asyncState = ref.watch(homeFeedProvider);
  if (asyncState.isLoading) return true;

  final state = asyncState.hasValue ? asyncState.value : null;
  if (state == null) return false;

  return state.isLoadingMore;
}

/// Provider to get current home feed video count
@riverpod
int homeFeedCount(Ref ref) {
  final asyncState = ref.watch(homeFeedProvider);
  return asyncState.hasValue ? (asyncState.value?.videos.length ?? 0) : 0;
}

/// Provider to check if we have home feed videos
@riverpod
bool hasHomeFeedVideos(Ref ref) {
  final count = ref.watch(homeFeedCountProvider);
  return count > 0;
}
