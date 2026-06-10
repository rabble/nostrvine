// ABOUTME: BLoC for unified video feed with mode switching
// ABOUTME: Manages For You, Following, and New (latest) feeds
// ABOUTME: Uses VideosRepository for data fetching with cursor-based pagination

import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/blocs/video_feed/home_feed_cache.dart';
import 'package:openvine/services/feed_performance_tracker.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:videos_repository/videos_repository.dart';

part 'video_feed_event.dart';
part 'video_feed_state.dart';

/// Default interval between auto-refreshes of the home feed.
const _defaultAutoRefreshMinInterval = Duration(minutes: 10);

/// Legacy SharedPreferences key for persisting the selected feed mode.
///
/// New authenticated sessions use a pubkey-scoped key so switching accounts
/// cannot carry a previous account's Following/list selection into a newly
/// imported key with a different social graph.
const _legacyFeedModeKey = 'selected_feed_mode';

/// BLoC for managing the unified video feed.
///
/// Handles:
/// - Multiple feed modes (forYou, following, latest)
/// - Pagination via cursor-based loading
/// - Following list changes for home feed
/// - Pull-to-refresh functionality
class VideoFeedBloc extends Bloc<VideoFeedEvent, VideoFeedBlocState> {
  VideoFeedBloc({
    required VideosRepository videosRepository,
    required FollowRepository followRepository,
    required CuratedListRepository curatedListRepository,
    ProfileRepository? profileRepository,
    ContentBlocklistRepository? contentBlocklistRepository,
    String? userPubkey,
    SharedPreferences? sharedPreferences,
    bool serveCachedHomeFeed = true,
    Duration autoRefreshMinInterval = _defaultAutoRefreshMinInterval,
    FeedPerformanceTracker? feedTracker,
    HomeFeedCache? homeFeedCache,
  }) : _videosRepository = videosRepository,
       _followRepository = followRepository,
       _curatedListRepository = curatedListRepository,
       _profileRepository = profileRepository,
       _blocklistRepository = contentBlocklistRepository,
       _userPubkey = userPubkey,
       _sharedPreferences = sharedPreferences,
       _serveCachedHomeFeed = serveCachedHomeFeed,
       _autoRefreshMinInterval = autoRefreshMinInterval,
       _feedTracker = feedTracker,
       _homeFeedCache = homeFeedCache ?? const HomeFeedCache(),
       super(const VideoFeedBlocState()) {
    on<VideoFeedStarted>(_onStarted);
    on<VideoFeedModeChanged>(_onModeChanged);
    on<VideoFeedSourceChanged>(_onSourceChanged);
    on<VideoFeedLoadMoreRequested>(
      _onLoadMoreRequested,
      transformer: droppable(),
    );
    on<VideoFeedRefreshRequested>(_onRefreshRequested);
    on<VideoFeedAutoRefreshRequested>(_onAutoRefreshRequested);
    on<VideoFeedFollowingListChanged>(_onFollowingListChanged);
    on<VideoFeedCuratedListsChanged>(_onCuratedListsChanged);
    on<VideoFeedBlocklistChanged>(_onBlocklistChanged);
  }

  final VideosRepository _videosRepository;
  final FollowRepository _followRepository;
  final CuratedListRepository _curatedListRepository;
  final ProfileRepository? _profileRepository;
  final ContentBlocklistRepository? _blocklistRepository;
  final String? _userPubkey;
  final SharedPreferences? _sharedPreferences;
  final bool _serveCachedHomeFeed;
  final Duration _autoRefreshMinInterval;
  final FeedPerformanceTracker? _feedTracker;
  final HomeFeedCache _homeFeedCache;
  StreamSubscription<List<String>>? _followingSubscription;
  StreamSubscription<List<CuratedList>>? _curatedListsSubscription;

  /// Whether the cache has already been served for this BLoC instance.
  ///
  /// Prevents serving stale cached data on subsequent loads (e.g.,
  /// follow list changes or mode switches).
  bool _cacheServed = false;

  /// Tracks when the last successful load completed, used by
  /// [_onAutoRefreshRequested] to skip refreshes when data is fresh.
  DateTime? _lastRefreshedAt;

  /// Whether [source] should be served from and written to the cross-restart
  /// [HomeFeedCache] (SharedPreferences).
  ///
  /// Only the chronological `following` feed is cached. Its ordering is
  /// inherently stable, so replaying the last response on cold start is a
  /// harmless startup optimization.
  ///
  /// The `forYou` feed is deliberately excluded: it is a recommendation feed
  /// that should reflect fresh server state on every cold start. Persisting
  /// and replaying its exact contents/order made the feed look identical on
  /// every app reopen within the cache window (see issue #3861).
  bool _usesHomeFeedCache(VideoFeedSource source) =>
      source.type == VideoFeedSourceType.following;

  /// Handle feed started event.
  ///
  /// Fires [_loadVideos] immediately without waiting for the follow list to
  /// initialize. When `userPubkey` is available, the Funnelcake API is
  /// attempted first (fast path).
  ///
  /// After the initial load, subscribes to [FollowRepository.followingStream]
  /// and ignores only the first replay when it exactly matches the follow
  /// list already used for that load. This avoids a redundant second API
  /// call on startup while still allowing late [FollowRepository.initialize]
  /// completions to trigger a corrective refresh or "no follows" CTA.
  ///
  /// Also subscribes to [CuratedListRepository.subscribedListsStream]
  /// (skipping the first replay) so curated list changes refresh the feed.
  ///
  /// If a feed mode was previously saved to SharedPreferences, that mode is
  /// restored. Otherwise [event.mode] is used.
  Future<void> _onStarted(
    VideoFeedStarted event,
    Emitter<VideoFeedBlocState> emit,
  ) async {
    final source = _restoreSource(event.mode);
    if (_sharedPreferences?.getString(_feedModePreferenceKey) !=
        source.persistenceValue) {
      await _persistSourcePreference(source);
    }

    final subscribedLists = _curatedListRepository.getSubscribedLists();

    emit(
      state.copyWith(
        status: VideoFeedStatus.loading,
        source: source,
        subscribedLists: subscribedLists,
      ),
    );

    _feedTracker?.startFeedLoad(source.mode.name);

    final initialFollowingPubkeys = List<String>.unmodifiable(
      _followRepository.followingPubkeys,
    );

    await _loadVideos(source, emit);
    if (emit.isDone) return;

    // After the initial load, check for the "no follows" CTA. Needed for
    // BLoC re-creation (e.g. navigating back to home) when the follow repo
    // is already initialized — .skip(1) would skip the only replay.
    if (source.type == VideoFeedSourceType.following) {
      final currentFollowing = _followRepository.followingPubkeys;
      if (currentFollowing.isEmpty && state.videos.isEmpty) {
        emit(
          state.copyWith(
            status: VideoFeedStatus.success,
            videos: [],
            hasMore: false,
            error: VideoFeedError.noFollowedUsers,
            videoListSources: const {},
            listOnlyVideoIds: const {},
          ),
        );
      }
    }

    if (emit.isDone) return;

    await _followingSubscription?.cancel();
    await _curatedListsSubscription?.cancel();

    // Subscribe to following list changes.
    //
    // The first replay can mean one of two things:
    // - the initial load already used this exact follow list and a refresh
    //   would be redundant
    // - initialize() completed after the first load and this replay is the
    //   corrective signal that the feed should refresh or show the CTA
    //
    // Distinguish those cases by comparing the first replay with the list
    // used for the initial fetch instead of relying on isInitialized.
    var isFirstFollowingEmission = true;
    _followingSubscription = _followRepository.followingStream.listen((
      pubkeys,
    ) {
      if (isFirstFollowingEmission) {
        isFirstFollowingEmission = false;
        if (_listsEqual(pubkeys, initialFollowingPubkeys)) {
          return;
        }
      }

      _addIfOpen(VideoFeedFollowingListChanged(pubkeys));
    });

    // Subscribe to curated list changes.
    _curatedListsSubscription = _curatedListRepository.subscribedListsStream
        .skip(1)
        .listen((lists) {
          _addIfOpen(VideoFeedCuratedListsChanged(lists));
        });
  }

  void _addIfOpen(VideoFeedEvent event) {
    if (isClosed) return;
    add(event);
  }

  @override
  Future<void> close() async {
    await _followingSubscription?.cancel();
    await _curatedListsSubscription?.cancel();
    _followingSubscription = null;
    _curatedListsSubscription = null;
    return super.close();
  }

  VideoFeedSource _restoreSource(FeedMode fallbackMode) {
    final saved = _savedSourcePreference();
    if (saved == null) {
      return VideoFeedSource.fromMode(fallbackMode);
    }

    return _sourceFromPersistedValue(saved) ?? const VideoFeedSource.forYou();
  }

  String get _feedModePreferenceKey => _userPubkey == null
      ? _legacyFeedModeKey
      : '${_legacyFeedModeKey}_$_userPubkey';

  String? _savedSourcePreference() {
    final prefs = _sharedPreferences;
    if (prefs == null) return null;

    final scoped = prefs.getString(_feedModePreferenceKey);
    if (scoped != null) return scoped;

    // Only unauthenticated/test callers should keep reading the legacy global
    // key directly. Authenticated sessions migrate it conservatively below.
    if (_userPubkey == null) {
      return prefs.getString(_legacyFeedModeKey);
    }

    final legacy = prefs.getString(_legacyFeedModeKey);
    if (legacy == null) return null;

    final migratedSource = _sourceFromPersistedValue(legacy);
    if (migratedSource == null) return null;

    // The bug fixed here: a newly imported key could inherit another account's
    // Following mode and land on an empty feed. Only migrate Following when
    // the current account already has a non-empty following list.
    if (migratedSource.type == VideoFeedSourceType.following &&
        _followRepository.followingPubkeys.isEmpty) {
      return null;
    }

    // A legacy list preference cannot be proven to belong to the authenticated
    // account because the curated-list bridge can briefly hold stale data
    // across account switches. Only restore list selections from scoped keys.
    if (migratedSource.type == VideoFeedSourceType.subscribedList) {
      return null;
    }

    unawaited(_persistSourcePreference(migratedSource));
    return migratedSource.persistenceValue;
  }

  VideoFeedSource? _sourceFromPersistedValue(String saved) {
    if (saved.startsWith('list:')) {
      final listId = saved.substring('list:'.length);
      final list = _curatedListRepository.getListById(listId);
      if (list != null) {
        return VideoFeedSource.subscribedList(
          listId: list.id,
          listName: list.name,
        );
      }
      return null;
    }

    if (saved == FeedMode.following.name) {
      return const VideoFeedSource.following();
    }

    if (saved == FeedMode.latest.name) {
      return const VideoFeedSource.newVideos();
    }

    if (saved == FeedMode.forYou.name) {
      return const VideoFeedSource.forYou();
    }

    return null;
  }

  Future<void> _persistSourcePreference(VideoFeedSource source) async {
    final prefs = _sharedPreferences;
    if (prefs == null) return;

    await prefs.setString(_feedModePreferenceKey, source.persistenceValue);
    if (_userPubkey != null) {
      await prefs.remove(_legacyFeedModeKey);
    }
  }

  /// Handle mode changed event.
  Future<void> _onModeChanged(
    VideoFeedModeChanged event,
    Emitter<VideoFeedBlocState> emit,
  ) async {
    await _selectSource(VideoFeedSource.fromMode(event.mode), emit);
  }

  /// Handle source changed event.
  Future<void> _onSourceChanged(
    VideoFeedSourceChanged event,
    Emitter<VideoFeedBlocState> emit,
  ) async {
    await _selectSource(event.source, emit);
  }

  Future<void> _selectSource(
    VideoFeedSource source,
    Emitter<VideoFeedBlocState> emit,
  ) async {
    // Skip if already on this source.
    if (state.source == source && state.status == VideoFeedStatus.success) {
      return;
    }

    await _persistSourcePreference(source);

    emit(
      state.copyWith(
        status: VideoFeedStatus.loading,
        source: source,
        videos: [],
        hasMore: true,
        clearError: true,
      ),
    );

    await _loadVideos(source, emit);
  }

  bool _listsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;

    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }

    return true;
  }

  /// Handle load more request (pagination).
  Future<void> _onLoadMoreRequested(
    VideoFeedLoadMoreRequested event,
    Emitter<VideoFeedBlocState> emit,
  ) async {
    // Skip if not in success state, already loading more, or no more content
    if (state.status != VideoFeedStatus.success ||
        state.isLoadingMore ||
        !state.hasMore ||
        state.videos.isEmpty) {
      return;
    }

    if (state.source.type == VideoFeedSourceType.forYou &&
        state.paginationCursor == null) {
      emit(state.copyWith(hasMore: false));
      return;
    }

    emit(state.copyWith(isLoadingMore: true));

    try {
      // Find the oldest createdAt among all loaded videos for the cursor.
      // For popular feed (sorted by engagement), state.videos.last is the
      // lowest-engagement video, not the oldest — using its createdAt would
      // skip older popular videos.
      final oldestCreatedAt = state.videos
          .map((v) => v.createdAt)
          .reduce((a, b) => a < b ? a : b);
      final until = oldestCreatedAt - 1;

      final result = await _fetchVideosForSource(
        state.source,
        until: state.source.type == VideoFeedSourceType.forYou ? null : until,
        paginationCursor: state.source.type == VideoFeedSourceType.forYou
            ? state.paginationCursor
            : null,
      );

      // Filter out videos without valid URLs
      final validNewVideos = result.videos
          .where((v) => v.videoUrl != null)
          .toList();

      // Deduplicate by event ID. Funnelcake and Nostr can return
      // overlapping videos when Funnelcake runs out and we fall through
      // to Nostr. Without dedup, feed-level player dedup can cause a
      // count mismatch that breaks the pagination trigger.
      final seenIds = <String>{};
      final updatedVideos = <VideoEvent>[];
      for (final video in [...state.videos, ...validNewVideos]) {
        if (seenIds.add(video.id)) {
          updatedVideos.add(video);
        }
      }

      // For You pages arrive in server-ranked recommendation order;
      // re-sorting by createdAt would shuffle new videos around the
      // current play index and resurface already-seen ones.
      if (state.source.type != VideoFeedSourceType.forYou) {
        updatedVideos.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }

      // Merge attribution metadata from pagination with existing state.
      final mergedSources = Map.of(state.videoListSources);
      for (final entry in result.videoListSources.entries) {
        mergedSources
            .putIfAbsent(entry.key, () => <String>{})
            .addAll(entry.value);
      }

      final mergedListOnly = {...state.listOnlyVideoIds}
        ..addAll(result.listOnlyVideoIds);

      emit(
        state.copyWith(
          videos: updatedVideos,
          // Only stop pagination when the server returns nothing.
          // Fewer than _pageSize can happen due to server-side filtering.
          hasMore: _hasMoreForSource(
            state.source,
            result,
            fallbackHasMore: result.videos.isNotEmpty,
          ),
          isLoadingMore: false,
          videoListSources: mergedSources,
          listOnlyVideoIds: mergedListOnly,
          paginationCursor: result.paginationCursor,
          clearPaginationCursor: result.paginationCursor == null,
        ),
      );

      // Batch-fetch profiles for new creators only.
      await _fetchCreatorProfiles(validNewVideos, emit);
    } catch (e) {
      Log.error(
        'VideoFeedBloc: Failed to load more videos - $e',
        name: 'VideoFeedBloc',
        category: LogCategory.video,
      );
      emit(state.copyWith(isLoadingMore: false));
    }
  }

  /// Handle refresh request.
  Future<void> _onRefreshRequested(
    VideoFeedRefreshRequested event,
    Emitter<VideoFeedBlocState> emit,
  ) async {
    emit(
      state.copyWith(
        status: VideoFeedStatus.loading,
        videos: [],
        hasMore: true,
        clearError: true,
      ),
    );

    await _loadVideos(state.source, emit, skipCache: true);
  }

  /// Handle auto-refresh request (dispatched by UI on app resume).
  ///
  /// Only refreshes when:
  /// - The current feed mode is [FeedMode.following]
  /// - The data is stale (last refresh was longer ago than
  ///   [_autoRefreshMinInterval])
  Future<void> _onAutoRefreshRequested(
    VideoFeedAutoRefreshRequested event,
    Emitter<VideoFeedBlocState> emit,
  ) async {
    if (state.source.type != VideoFeedSourceType.following) return;

    final lastRefresh = _lastRefreshedAt;
    if (lastRefresh != null &&
        DateTime.now().difference(lastRefresh) < _autoRefreshMinInterval) {
      return;
    }

    emit(
      state.copyWith(
        status: VideoFeedStatus.loading,
        videos: [],
        hasMore: true,
        clearError: true,
      ),
    );

    await _loadVideos(state.source, emit, skipCache: true);
  }

  /// Handle following list changes from [FollowRepository].
  ///
  /// Only receives runtime changes (the initial BehaviorSubject replay is
  /// skipped). Performs a silent refresh — keeps current videos visible and
  /// replaces when done.
  ///
  /// - **Empty list** → show `noFollowedUsers` CTA immediately.
  /// - **Non-empty list** → silent refresh via [_loadVideos]. Old content
  ///   stays visible briefly, then replaced with updated feed (no loading
  ///   flash).
  Future<void> _onFollowingListChanged(
    VideoFeedFollowingListChanged event,
    Emitter<VideoFeedBlocState> emit,
  ) async {
    if (state.source.type != VideoFeedSourceType.following) return;
    if (state.status == VideoFeedStatus.loading) return;

    // Empty follow list → show "follow someone" CTA.
    if (event.followingPubkeys.isEmpty) {
      emit(
        state.copyWith(
          status: VideoFeedStatus.success,
          videos: [],
          hasMore: false,
          error: VideoFeedError.noFollowedUsers,
          videoListSources: const {},
          listOnlyVideoIds: const {},
        ),
      );
      return;
    }

    // Silent refresh — keep current videos visible, replace when done.
    await _loadVideos(state.source, emit, skipCache: true);
  }

  /// Handle curated list subscription changes from [CuratedListRepository].
  ///
  /// Only refreshes when the current mode is [FeedMode.following] and the
  /// feed has already been loaded (avoids double-loading on startup).
  Future<void> _onCuratedListsChanged(
    VideoFeedCuratedListsChanged event,
    Emitter<VideoFeedBlocState> emit,
  ) async {
    final subscribedLists = event.subscribedLists;
    if (state.status == VideoFeedStatus.loading) {
      if (subscribedLists.isNotEmpty) {
        emit(state.copyWith(subscribedLists: subscribedLists));
      }
      return;
    }

    if (!state.isSubscribedListSelected) {
      emit(state.copyWith(subscribedLists: subscribedLists));
      return;
    }

    // Mirror _restoreSource: if the currently selected subscribed list is no
    // longer in the subscription set (user unsubscribed, list was deleted),
    // fall back to forYou instead of reloading an empty list source.
    final selectedId = state.source.listId;
    final stillSubscribed = subscribedLists.any((l) => l.id == selectedId);
    final nextSource = stillSubscribed
        ? state.source
        : const VideoFeedSource.forYou();

    if (!stillSubscribed) {
      await _persistSourcePreference(nextSource);
    }

    emit(
      state.copyWith(
        status: VideoFeedStatus.loading,
        source: nextSource,
        videos: [],
        hasMore: true,
        clearError: true,
        subscribedLists: subscribedLists,
      ),
    );

    await _loadVideos(nextSource, emit, skipCache: true);
  }

  /// Handle blocklist changes.
  ///
  /// When [event.blockedPubkey] is provided, removes that user's videos
  /// from the current state instantly (no network call). When null,
  /// filters the current videos against the full blocklist in-memory.
  void _onBlocklistChanged(
    VideoFeedBlocklistChanged event,
    Emitter<VideoFeedBlocState> emit,
  ) {
    final pubkey = event.blockedPubkey;
    if (pubkey != null) {
      final filtered = state.videos.where((v) => v.pubkey != pubkey).toList();
      if (filtered.length != state.videos.length) {
        emit(state.copyWith(videos: filtered));
      }
      return;
    }

    // General blocklist change — filter current videos in-memory.
    final service = _blocklistRepository;
    if (service == null) return;

    final filtered = service.filterContent<VideoEvent>(
      state.videos,
      (v) => v.pubkey,
    );
    if (filtered.length != state.videos.length) {
      emit(state.copyWith(videos: filtered));
    }
  }

  /// Load videos for the specified mode.
  ///
  /// For the home feed on cold start, serves cached data instantly while
  /// fresh data loads in the background. The cache is only served once
  /// per BLoC instance to avoid showing stale data on subsequent loads.
  ///
  /// For the home feed, does NOT wait for the follow list to initialize.
  /// Instead, the follow-list stream subscription (set up in [_onStarted])
  /// drives recovery: when the follow list arrives via
  /// [VideoFeedFollowingListChanged], the handler decides whether to show
  /// the `noFollowedUsers` CTA or refresh the feed.
  Future<void> _loadVideos(
    VideoFeedSource source,
    Emitter<VideoFeedBlocState> emit, {
    bool skipCache = false,
  }) async {
    // Serve cached home feed on first load for instant startup.
    if (_serveCachedHomeFeed &&
        !_cacheServed &&
        _usesHomeFeedCache(source) &&
        _sharedPreferences != null) {
      _cacheServed = true;
      final cached = _homeFeedCache.read(_sharedPreferences);
      if (cached != null) {
        final filtered = _videosRepository.applyContentPreferences(
          cached.videos,
        );
        final cachedValid = filtered.where((v) => v.videoUrl != null).toList();
        if (cachedValid.isNotEmpty) {
          _feedTracker?.markFirstVideosReceived(
            source.mode.name,
            cachedValid.length,
          );
          emit(
            state.copyWith(
              status: VideoFeedStatus.success,
              videos: cachedValid,
              hasMore: true,
              clearPaginationCursor: true,
              clearError: true,
            ),
          );
          _feedTracker?.markFeedDisplayed(source.mode.name, cachedValid.length);
          // Continue to fetch fresh data below — the emit will update
          // the UI when the network result arrives.
        }
      }
    }

    try {
      final result = await _fetchVideosForSource(source, skipCache: skipCache);

      // Filter out videos without valid URLs
      final validVideos = result.videos
          .where((v) => v.videoUrl != null)
          .toList();

      _lastRefreshedAt = DateTime.now();

      _feedTracker?.markFirstVideosReceived(
        source.mode.name,
        validVideos.length,
      );

      emit(
        state.copyWith(
          status: VideoFeedStatus.success,
          videos: validVideos,
          // Only stop pagination when no results at all.
          // Fewer than _pageSize can happen due to server-side filtering.
          hasMore: _hasMoreForSource(
            source,
            result,
            fallbackHasMore:
                source.type != VideoFeedSourceType.subscribedList &&
                validVideos.isNotEmpty,
          ),
          clearError: true,
          videoListSources: result.videoListSources,
          listOnlyVideoIds: result.listOnlyVideoIds,
          paginationCursor: result.paginationCursor,
          clearPaginationCursor: result.paginationCursor == null,
        ),
      );

      _feedTracker?.markFeedDisplayed(source.mode.name, validVideos.length);

      // Batch-fetch creator profiles to warm the Drift cache.
      await _fetchCreatorProfiles(validVideos, emit);

      // Cache the raw response for next cold start (fire-and-forget).
      if (_usesHomeFeedCache(source) &&
          _sharedPreferences != null &&
          result.rawResponseBody != null) {
        unawaited(
          _homeFeedCache.write(_sharedPreferences, result.rawResponseBody!),
        );
      }
    } catch (e) {
      Log.error(
        'VideoFeedBloc: Failed to load videos - $e',
        name: 'VideoFeedBloc',
        category: LogCategory.video,
      );

      _feedTracker?.trackFeedError(
        source.mode.name,
        errorType: 'load_failed',
        errorMessage: e.toString(),
      );

      // Only show failure if we don't have cached data already displayed.
      if (state.status != VideoFeedStatus.success || state.videos.isEmpty) {
        emit(
          state.copyWith(
            status: VideoFeedStatus.failure,
            error: VideoFeedError.loadFailed,
          ),
        );
      }
    }
  }

  bool _hasMoreForSource(
    VideoFeedSource source,
    HomeFeedResult result, {
    required bool fallbackHasMore,
  }) {
    final upstreamHasMore = result.hasMore ?? fallbackHasMore;
    if (source.type != VideoFeedSourceType.forYou) {
      return upstreamHasMore;
    }

    return upstreamHasMore && result.paginationCursor != null;
  }

  /// Fetch videos for a specific mode from the repository.
  ///
  /// Returns [HomeFeedResult] for all modes. For home/forYou, includes
  /// curated list attribution metadata. For other modes, returns a
  /// result with empty attribution.
  ///
  /// When [skipCache] is `false` (default), the repository may return
  /// a previously cached result from the [InMemoryFeedCache] without
  /// a network round-trip. Pass `true` for refresh and auto-refresh
  /// flows that must hit the network.
  Future<HomeFeedResult> _fetchVideosForSource(
    VideoFeedSource source, {
    int? until,
    String? paginationCursor,
    bool skipCache = false,
  }) => switch (source.type) {
    VideoFeedSourceType.forYou =>
      paginationCursor == null
          ? _videosRepository.getRecommendedVideos(
              userPubkey: _userPubkey,
              until: until,
              skipCache: skipCache,
            )
          : _videosRepository.getRecommendedVideos(
              userPubkey: _userPubkey,
              cursor: paginationCursor,
              skipCache: skipCache,
            ),
    VideoFeedSourceType.following => _videosRepository.getHomeFeedVideos(
      authors: _followRepository.followingPubkeys,
      userPubkey: _userPubkey,
      until: until,
      skipCache: skipCache,
    ),
    VideoFeedSourceType.subscribedList =>
      _videosRepository
          .getVideosForList(
            _curatedListRepository.getOrderedVideoIds(source.listId!),
          )
          .then((videos) => HomeFeedResult(videos: videos)),
    VideoFeedSourceType.newVideos =>
      _videosRepository
          .getNewVideos(until: until, skipCache: skipCache)
          .then((videos) => HomeFeedResult(videos: videos)),
  };

  /// Batch-fetch creator profiles for the given videos.
  ///
  /// Only fetches profiles for pubkeys not already in
  /// [state.creatorProfiles]. Does not block video display — called
  /// after videos are already emitted.
  Future<void> _fetchCreatorProfiles(
    List<VideoEvent> videos,
    Emitter<VideoFeedBlocState> emit,
  ) async {
    if (_profileRepository == null || videos.isEmpty) return;

    final newPubkeys = videos
        .map((v) => v.pubkey)
        .toSet()
        .difference(state.creatorProfiles.keys.toSet())
        .toList();

    if (newPubkeys.isEmpty) return;

    try {
      final profiles = await _profileRepository.fetchBatchProfiles(
        pubkeys: newPubkeys,
      );

      if (profiles.isNotEmpty) {
        emit(
          state.copyWith(
            creatorProfiles: {...state.creatorProfiles, ...profiles},
          ),
        );
      }
    } catch (e) {
      Log.error(
        'VideoFeedBloc: Failed to batch-fetch creator profiles - $e',
        name: 'VideoFeedBloc',
        category: LogCategory.video,
      );
    }
  }
}
