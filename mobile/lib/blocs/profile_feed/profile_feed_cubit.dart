// ABOUTME: Bloc backing a single author's profile/video feed.
// ABOUTME: Composes REST via videos_repository.getAuthorFeed and subscribes to
// ABOUTME: VideoEventService for the realtime/optimistic half (the repo is
// ABOUTME: Flutter/VES-free). Replaces the legacy profile_feed_provider.

import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:models/models.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:videos_repository/videos_repository.dart';

part 'profile_feed_event.dart';
part 'profile_feed_state.dart';

/// Enriches REST-sourced videos with their full Nostr tag set. Injected so the
/// cubit stays decoupled from `NostrClient` / the enrichment util and testable.
typedef EnrichVideos =
    Future<List<VideoEvent>> Function(List<VideoEvent> videos);

/// Bloc backing a single author's profile feed.
///
/// Cold load + pagination come from `videos_repository.getAuthorFeed` (REST-
/// source composition); the relay/realtime half (snapshot, optimistic add,
/// tombstones, live updates) is owned here over [VideoEventService]. Filtering
/// is applied on **every** emit so a block/unblock reflects without a re-fetch
/// (#4782).
///
/// It extends [Bloc] (not [Cubit]) only so `droppable()` can guard pagination.
class ProfileFeedCubit extends Bloc<ProfileFeedEvent, ProfileFeedState> {
  ProfileFeedCubit({
    required String authorPubkey,
    required VideosRepository videosRepository,
    required VideoEventService videoEventService,
    required ContentBlocklistRepository blocklistRepository,
    required EnrichVideos enrichVideos,
  }) : _authorPubkey = authorPubkey,
       _videosRepository = videosRepository,
       _videoEventService = videoEventService,
       _blocklistRepository = blocklistRepository,
       _enrichVideos = enrichVideos,
       super(const ProfileFeedState()) {
    on<ProfileFeedStarted>(_onStarted, transformer: sequential());
    on<ProfileFeedLoadMoreRequested>(_onLoadMore, transformer: droppable());
    on<ProfileFeedRefreshRequested>(_onRefresh, transformer: restartable());
    on<ProfileFeedFiltersChanged>(_onFiltersChanged, transformer: sequential());
    on<ProfileFeedRelaySnapshotChanged>(
      _onRelaySnapshot,
      transformer: sequential(),
    );
    on<ProfileFeedNewVideoReceived>(_onNewVideo, transformer: sequential());
    on<ProfileFeedVideoUpdated>(_onVideoUpdated, transformer: restartable());
    on<ProfileFeedInitialLoadTimedOut>(
      _onInitialLoadTimedOut,
      transformer: sequential(),
    );
    on<ProfileFeedEnrichmentReady>(
      _onEnrichmentReady,
      transformer: sequential(),
    );

    _registerRealtimeListeners();
    add(const ProfileFeedStarted());
  }

  /// Hard ceiling on how long [ProfileFeedState.isInitialLoad] stays true if no
  /// source settles, so the loading spinner can't strand (#4164).
  @visibleForTesting
  static Duration initialLoadHardTimeout = const Duration(seconds: 10);

  final String _authorPubkey;
  final VideosRepository _videosRepository;
  final VideoEventService _videoEventService;
  final ContentBlocklistRepository _blocklistRepository;
  final EnrichVideos _enrichVideos;

  /// Accumulated **unfiltered** source list (REST + relay). Not UI state — it's
  /// the source [ProfileFeedFiltersChanged] re-filters in place without a
  /// re-fetch. Same source-cache category as the injected dependencies.
  List<VideoEvent> _unfilteredVideos = const [];

  /// Backfill cache for engagement counts, used on the Nostr-fallback loadMore
  /// branch where there is no REST hydration.
  final Map<String, _VideoMetadataCache> _metadataCache = {};

  /// True while a cold-load fetch is in flight (timer-coupled lifecycle
  /// bookkeeping; the observable result is [ProfileFeedState.isInitialLoad]).
  bool _initialLoadPending = false;
  Timer? _initialLoadTimer;

  VoidCallback? _removeChangeListener;
  VoidCallback? _unregisterUpdate;
  VoidCallback? _unregisterNew;

  // ---------------------------------------------------------------------------
  // Realtime wiring
  // ---------------------------------------------------------------------------

  void _registerRealtimeListeners() {
    void onChanged() {
      if (!isClosed) add(const ProfileFeedRelaySnapshotChanged());
    }

    _videoEventService.addListener(onChanged);
    _removeChangeListener = () => _videoEventService.removeListener(onChanged);

    _unregisterUpdate = _videoEventService.addVideoUpdateListener((updated) {
      if (updated.pubkey == _authorPubkey && !isClosed) {
        add(const ProfileFeedVideoUpdated());
      }
    });

    _unregisterNew = _videoEventService.addNewVideoListener((
      newVideo,
      authorPubkey,
    ) {
      if (authorPubkey == _authorPubkey && !isClosed) {
        add(ProfileFeedNewVideoReceived(newVideo));
      }
    });
  }

  Future<void> _subscribe() async {
    try {
      await _videoEventService.subscribeToUserVideos(_authorPubkey);
    } on Object {
      // Non-fatal: the realtime listeners and REST still populate the feed.
    }
  }

  // ---------------------------------------------------------------------------
  // Cold load + refresh
  // ---------------------------------------------------------------------------

  Future<void> _onStarted(
    ProfileFeedStarted event,
    Emitter<ProfileFeedState> emit,
  ) async {
    emit(state.copyWith(status: ProfileFeedStatus.loading));

    final relaySeed = _relayVideosSnapshot();
    if (relaySeed.isEmpty) {
      _beginInitialLoadTracking();
    }
    _unfilteredVideos = relaySeed;
    unawaited(_subscribe());

    emit(
      state.copyWith(
        status: ProfileFeedStatus.ready,
        videos: _applyFeedFilters(relaySeed),
        hasMoreContent:
            relaySeed.length >= AppConstants.hasMoreContentThreshold,
        isInitialLoad: relaySeed.isEmpty,
        isFetchingTotalCount: true,
        lastUpdated: DateTime.now(),
      ),
    );

    final result = await _loadFromRest(
      emit,
      relaySeed: relaySeed,
      mergeWithCurrent: false,
      skipCache: false,
    );

    if (!isClosed && result?.isFromCache == true) {
      await _doRefresh(emit, backfillInitialPage: true);
    } else if (!isClosed && result != null) {
      await _backfillInitialRestPage(emit);
    }
  }

  Future<void> _onRefresh(
    ProfileFeedRefreshRequested event,
    Emitter<ProfileFeedState> emit,
  ) => _doRefresh(emit);

  Future<void> _onVideoUpdated(
    ProfileFeedVideoUpdated event,
    Emitter<ProfileFeedState> emit,
  ) => _doRefresh(emit);

  Future<void> _doRefresh(
    Emitter<ProfileFeedState> emit, {
    bool backfillInitialPage = false,
  }) async {
    emit(
      state.copyWith(
        isRefreshing: true,
        isInitialLoad: false,
        isFetchingTotalCount: true,
      ),
    );
    final relaySeed = _relayVideosSnapshot();
    unawaited(_subscribe());
    await _loadFromRest(
      emit,
      relaySeed: relaySeed,
      mergeWithCurrent: false,
      skipCache: true,
    );
    if (backfillInitialPage && !isClosed) {
      await _backfillInitialRestPage(emit);
    }
  }

  Future<AuthorFeedResult?> _loadFromRest(
    Emitter<ProfileFeedState> emit, {
    required List<VideoEvent> relaySeed,
    required bool mergeWithCurrent,
    required bool skipCache,
  }) async {
    try {
      final result = await _videosRepository.getAuthorFeed(
        authorPubkey: _authorPubkey,
        relaySeed: relaySeed,
        skipCache: skipCache,
      );
      if (isClosed) return null;
      _applyRestPage(
        emit,
        pageVideos: result.videos,
        totalCount: result.totalCount,
        nextOffset: result.nextOffset,
        hasMore: result.hasMore,
        mergeWithCurrent: mergeWithCurrent,
      );
      _enrichInBackground();
      return result;
    } on Object catch (error, stackTrace) {
      if (isClosed) return null;
      addError(error, stackTrace);
      _completeInitialLoad();
      emit(
        state.copyWith(
          status: state.videos.isEmpty
              ? ProfileFeedStatus.failure
              : ProfileFeedStatus.ready,
          isRefreshing: false,
          isFetchingTotalCount: false,
        ),
      );
      return null;
    }
  }

  Future<void> _backfillInitialRestPage(Emitter<ProfileFeedState> emit) async {
    var targetCount = AppConstants.paginationBatchSize;
    final totalVideoCount = state.totalVideoCount;
    if (totalVideoCount != null && totalVideoCount < targetCount) {
      targetCount = totalVideoCount;
    }

    while (!isClosed &&
        state.hasMoreContent &&
        state.nextOffset != null &&
        state.videos.length < targetCount) {
      final offset = state.nextOffset;
      if (offset == null) return;

      final beforeCount = state.videos.length;
      final AuthorFeedResult result;
      try {
        result = await _videosRepository.getAuthorFeed(
          authorPubkey: _authorPubkey,
          offset: offset,
        );
        if (isClosed) return;
      } on Object catch (error, stackTrace) {
        if (isClosed) return;
        addError(error, stackTrace);
        emit(state.copyWith(hasLoadMoreError: true));
        return;
      }

      if (result.videos.isEmpty) {
        if (_isAdvancingRestPage(result, offset)) {
          _applyRestPage(
            emit,
            pageVideos: const [],
            totalCount: result.totalCount,
            nextOffset: result.nextOffset,
            hasMore: result.hasMore,
            mergeWithCurrent: true,
          );
          continue;
        }
        emit(state.copyWith(hasMoreContent: false));
        return;
      }

      final enriched = await _enrichVideos(result.videos);
      if (isClosed) return;
      _applyRestPage(
        emit,
        pageVideos: enriched,
        totalCount: result.totalCount,
        nextOffset: result.nextOffset,
        hasMore: result.hasMore,
        mergeWithCurrent: true,
      );

      if (state.videos.length <= beforeCount && state.nextOffset == offset) {
        return;
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Load more (REST offset page or Nostr-fallback page)
  // ---------------------------------------------------------------------------

  Future<void> _onLoadMore(
    ProfileFeedLoadMoreRequested event,
    Emitter<ProfileFeedState> emit,
  ) async {
    if (!state.hasMoreContent) return;
    emit(state.copyWith(isLoadingMore: true, hasLoadMoreError: false));

    try {
      if (state.nextOffset != null) {
        final offset = state.nextOffset;
        final result = await _videosRepository.getAuthorFeed(
          authorPubkey: _authorPubkey,
          offset: offset,
        );
        if (isClosed) return;
        if (result.videos.isEmpty) {
          if (_isAdvancingRestPage(result, offset)) {
            _applyRestPage(
              emit,
              pageVideos: const [],
              totalCount: result.totalCount,
              nextOffset: result.nextOffset,
              hasMore: result.hasMore,
              mergeWithCurrent: true,
            );
            return;
          }
          emit(state.copyWith(hasMoreContent: false, isLoadingMore: false));
          return;
        }
        final enriched = await _enrichVideos(result.videos);
        if (isClosed) return;
        _applyRestPage(
          emit,
          pageVideos: enriched,
          totalCount: result.totalCount,
          nextOffset: result.nextOffset,
          hasMore: result.hasMore,
          mergeWithCurrent: true,
        );
      } else {
        // Nostr-fallback pagination (REST unavailable).
        final until = state.videos.isEmpty
            ? null
            : state.videos
                  .map((v) => v.createdAt)
                  .reduce((a, b) => a < b ? a : b);
        final before = _videoEventService.authorVideos(_authorPubkey).length;
        await _videoEventService.queryHistoricalUserVideos(
          _authorPubkey,
          until: until,
        );
        if (isClosed) return;
        final after = _videoEventService.authorVideos(_authorPubkey).length;

        _unfilteredVideos = _applyMetadataCache(
          _videoEventService
              .authorVideos(_authorPubkey)
              .where((v) => !v.isRepost)
              .toList(),
        );
        // C5 fix: copyWith over the live state preserves totalVideoCount,
        // isInitialLoad, isFetchingTotalCount and nextOffset that the legacy
        // fresh-VideoFeedState() emit dropped.
        emit(
          state.copyWith(
            videos: _applyFeedFilters(_unfilteredVideos),
            hasMoreContent: (after - before) > 0,
            isLoadingMore: false,
            lastUpdated: DateTime.now(),
          ),
        );
      }
    } on Object catch (error, stackTrace) {
      if (isClosed) return;
      addError(error, stackTrace);
      emit(state.copyWith(isLoadingMore: false, hasLoadMoreError: true));
    }
  }

  bool _isAdvancingRestPage(AuthorFeedResult result, int? previousOffset) {
    final nextOffset = result.nextOffset;
    return result.hasMore == true &&
        nextOffset != null &&
        nextOffset != previousOffset;
  }

  void _applyRestPage(
    Emitter<ProfileFeedState> emit, {
    required List<VideoEvent> pageVideos,
    required int? totalCount,
    required int? nextOffset,
    required bool? hasMore,
    required bool mergeWithCurrent,
  }) {
    _completeInitialLoad();
    final merged = mergeWithCurrent
        ? mergeProfileFeedVideoLists(_unfilteredVideos, pageVideos)
        : pageVideos;
    _unfilteredVideos = _withoutTombstones(merged);
    _cacheVideoMetadata(_unfilteredVideos);
    final filtered = _applyFeedFilters(_unfilteredVideos);

    emit(
      state.copyWith(
        status: ProfileFeedStatus.ready,
        videos: filtered,
        hasMoreContent:
            hasMore ?? (pageVideos.length >= AppConstants.paginationBatchSize),
        totalVideoCount: totalCount ?? state.totalVideoCount,
        nextOffset: nextOffset,
        isLoadingMore: false,
        isRefreshing: false,
        isFetchingTotalCount: false,
        isInitialLoad: _shouldKeepInitialLoad(videosEmpty: filtered.isEmpty),
        lastUpdated: DateTime.now(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Background Nostr enrichment of the REST page (#3705)
  // ---------------------------------------------------------------------------

  void _enrichInBackground() {
    final snapshot = _unfilteredVideos;
    if (snapshot.isEmpty) return;
    final sourceKeys = {
      for (final v in snapshot) canonicalProfileFeedVideoKey(v),
    };
    unawaited(
      _enrichVideos(snapshot)
          .then((enriched) {
            if (isClosed || identical(enriched, snapshot)) return;
            add(
              ProfileFeedEnrichmentReady(
                enriched: enriched,
                sourceKeys: sourceKeys,
              ),
            );
          })
          .catchError((Object error, StackTrace stackTrace) {
            if (!isClosed) addError(error, stackTrace);
          }),
    );
  }

  void _onEnrichmentReady(
    ProfileFeedEnrichmentReady event,
    Emitter<ProfileFeedState> emit,
  ) {
    _unfilteredVideos = _mergeVideosReplacingCurrentKeys(
      current: _unfilteredVideos,
      sourceKeys: event.sourceKeys,
      incoming: event.enriched,
    );
    emit(
      state.copyWith(
        videos: _applyFeedFilters(_unfilteredVideos),
        lastUpdated: DateTime.now(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Realtime handlers
  // ---------------------------------------------------------------------------

  void _onRelaySnapshot(
    ProfileFeedRelaySnapshotChanged event,
    Emitter<ProfileFeedState> emit,
  ) {
    final snapshot = _relayVideosSnapshot();
    final merged = _withoutTombstones(
      mergeProfileFeedVideoLists(_unfilteredVideos, snapshot),
    );
    final filtered = _applyFeedFilters(merged);
    if (_sameVideoSequence(state.videos, filtered)) return;

    if (merged.isNotEmpty) _completeInitialLoad();
    _unfilteredVideos = merged;
    emit(
      state.copyWith(
        videos: filtered,
        hasMoreContent: state.totalVideoCount != null
            ? state.hasMoreContent
            : merged.length >= AppConstants.hasMoreContentThreshold,
        isRefreshing: false,
        isInitialLoad: _shouldKeepInitialLoad(videosEmpty: filtered.isEmpty),
        lastUpdated: DateTime.now(),
      ),
    );
  }

  void _onNewVideo(
    ProfileFeedNewVideoReceived event,
    Emitter<ProfileFeedState> emit,
  ) {
    if (event.video.isRepost) return;
    final merged = _withoutTombstones(
      mergeProfileFeedVideoLists(_unfilteredVideos, [event.video]),
    );
    final filtered = _applyFeedFilters(merged);
    if (_sameVideoSequence(state.videos, filtered)) return;

    _completeInitialLoad();
    _unfilteredVideos = merged;
    emit(
      state.copyWith(
        videos: filtered,
        isInitialLoad: false,
        lastUpdated: DateTime.now(),
      ),
    );
  }

  void _onFiltersChanged(
    ProfileFeedFiltersChanged event,
    Emitter<ProfileFeedState> emit,
  ) {
    // Re-filter in place over the cached source — no re-fetch, no re-key
    // (#4782). Equatable suppresses the emit when the filtered list is
    // unchanged.
    emit(state.copyWith(videos: _applyFeedFilters(_unfilteredVideos)));
  }

  // ---------------------------------------------------------------------------
  // Initial-load spinner machine (#4164)
  // ---------------------------------------------------------------------------

  void _onInitialLoadTimedOut(
    ProfileFeedInitialLoadTimedOut event,
    Emitter<ProfileFeedState> emit,
  ) {
    if (!_initialLoadPending) return;
    _initialLoadPending = false;
    _initialLoadTimer = null;
    if (state.isInitialLoad) {
      emit(state.copyWith(isInitialLoad: false));
    }
  }

  void _beginInitialLoadTracking() {
    _initialLoadPending = true;
    _initialLoadTimer?.cancel();
    _initialLoadTimer = Timer(initialLoadHardTimeout, () {
      if (!isClosed) add(const ProfileFeedInitialLoadTimedOut());
    });
  }

  void _completeInitialLoad() {
    _initialLoadPending = false;
    _initialLoadTimer?.cancel();
    _initialLoadTimer = null;
  }

  bool _shouldKeepInitialLoad({required bool videosEmpty}) =>
      _initialLoadPending && videosEmpty;

  // ---------------------------------------------------------------------------
  // Source helpers (ported from the provider)
  // ---------------------------------------------------------------------------

  List<VideoEvent> _relayVideosSnapshot() {
    var videos = _videoEventService
        .authorVideos(_authorPubkey)
        .where((v) => !v.isRepost)
        .toList();
    videos = _applyMetadataCache(videos);
    return _withoutTombstones(_videoEventService.filterVideoList(videos));
  }

  /// Blocked/muted-author filter on top of the content-preference filter, for
  /// the REST author endpoint (anonymous, applies no per-viewer block). Relay
  /// videos are already blocklist-filtered by [VideoEventService] at reception
  /// (#4782). Does NOT remove tombstones — those are handled in the merge paths.
  List<VideoEvent> _applyFeedFilters(List<VideoEvent> videos) {
    if (videos.isEmpty) return videos;
    final blockFiltered = videos
        .where((v) => !_blocklistRepository.shouldFilterFromFeeds(v.pubkey))
        .toList();
    return _videoEventService.filterVideoList(blockFiltered);
  }

  List<VideoEvent> _withoutTombstones(List<VideoEvent> videos) {
    if (videos.isEmpty) return videos;
    return videos
        .where((v) => !_videoEventService.isVideoLocallyDeleted(v.id))
        .toList();
  }

  void _cacheVideoMetadata(List<VideoEvent> videos) {
    for (final video in videos) {
      if (video.originalLoops != null ||
          video.rawTags['views'] != null ||
          video.originalLikes != null ||
          video.originalComments != null ||
          video.originalReposts != null ||
          video.nostrLikeCount != null) {
        _metadataCache[video.id.toLowerCase()] = _VideoMetadataCache(
          originalLoops: video.originalLoops,
          views: video.rawTags['views'],
          originalLikes: video.originalLikes,
          originalComments: video.originalComments,
          originalReposts: video.originalReposts,
          nostrLikeCount: video.nostrLikeCount,
        );
      }
    }
  }

  List<VideoEvent> _applyMetadataCache(List<VideoEvent> videos) {
    return videos.map((video) {
      final cached = _metadataCache[video.id.toLowerCase()];
      if (cached == null) return video;
      final currentViews = video.rawTags['views'];
      final shouldApply =
          (video.originalLoops == null && cached.originalLoops != null) ||
          (currentViews == null && cached.views != null) ||
          (video.originalLikes == null && cached.originalLikes != null) ||
          (video.originalComments == null && cached.originalComments != null) ||
          (video.originalReposts == null && cached.originalReposts != null) ||
          (video.nostrLikeCount == null && cached.nostrLikeCount != null);
      if (!shouldApply) return video;
      return video.copyWith(
        originalLoops: video.originalLoops ?? cached.originalLoops,
        rawTags: currentViews == null && cached.views != null
            ? {...video.rawTags, 'views': cached.views!}
            : video.rawTags,
        originalLikes: video.originalLikes ?? cached.originalLikes,
        originalComments: video.originalComments ?? cached.originalComments,
        originalReposts: video.originalReposts ?? cached.originalReposts,
        nostrLikeCount: video.nostrLikeCount ?? cached.nostrLikeCount,
      );
    }).toList();
  }

  /// Merges enriched copies over [sourceKeys] against the current list, filling
  /// missing fields without clobbering relay updates that arrived during the
  /// enrichment window (#3705).
  List<VideoEvent> _mergeVideosReplacingCurrentKeys({
    required List<VideoEvent> current,
    required Set<String> sourceKeys,
    required List<VideoEvent> incoming,
  }) {
    if (sourceKeys.isEmpty) {
      return _withoutTombstones(mergeProfileFeedVideoLists(current, incoming));
    }
    final currentByKey = {
      for (final video in current)
        if (sourceKeys.contains(canonicalProfileFeedVideoKey(video)))
          canonicalProfileFeedVideoKey(video): video,
    };
    final keepFromCurrent = current
        .where((v) => !sourceKeys.contains(canonicalProfileFeedVideoKey(v)))
        .toList();
    final mergedSource = incoming.map((video) {
      final currentVideo = currentByKey[canonicalProfileFeedVideoKey(video)];
      return currentVideo == null
          ? video
          : _mergeEnrichmentIntoCurrent(currentVideo, video);
    }).toList();
    return _withoutTombstones(
      mergeProfileFeedVideoLists(keepFromCurrent, mergedSource),
    );
  }

  VideoEvent _mergeEnrichmentIntoCurrent(
    VideoEvent current,
    VideoEvent enriched,
  ) {
    return current.copyWith(
      publishedAt:
          (current.publishedAt != null && current.publishedAt!.isNotEmpty)
          ? current.publishedAt
          : enriched.publishedAt,
      rawTags: mergeVideoRawTagsPrimaryWins(current.rawTags, enriched.rawTags),
      contentWarningLabels: current.contentWarningLabels.isNotEmpty
          ? current.contentWarningLabels
          : enriched.contentWarningLabels,
      title: current.title ?? enriched.title,
      videoUrl: current.videoUrl ?? enriched.videoUrl,
      thumbnailUrl: current.thumbnailUrl ?? enriched.thumbnailUrl,
      duration: current.duration ?? enriched.duration,
      dimensions: current.dimensions ?? enriched.dimensions,
      mimeType: current.mimeType ?? enriched.mimeType,
      sha256: current.sha256 ?? enriched.sha256,
      fileSize: current.fileSize ?? enriched.fileSize,
      hashtags: current.hashtags.isNotEmpty
          ? current.hashtags
          : enriched.hashtags,
      vineId: current.vineId ?? enriched.vineId,
      group: current.group ?? enriched.group,
      altText: current.altText ?? enriched.altText,
      blurhash: current.blurhash ?? enriched.blurhash,
      originalLoops: mergeNullableEngagementMax(
        current.originalLoops,
        enriched.originalLoops,
      ),
      originalLikes: mergeNullableEngagementMax(
        current.originalLikes,
        enriched.originalLikes,
      ),
      originalComments: mergeNullableEngagementMax(
        current.originalComments,
        enriched.originalComments,
      ),
      originalReposts: mergeNullableEngagementMax(
        current.originalReposts,
        enriched.originalReposts,
      ),
      audioEventId: current.audioEventId ?? enriched.audioEventId,
      audioEventRelay: current.audioEventRelay ?? enriched.audioEventRelay,
      collaboratorPubkeys: current.collaboratorPubkeys.isNotEmpty
          ? current.collaboratorPubkeys
          : enriched.collaboratorPubkeys,
      inspiredByVideo: current.inspiredByVideo ?? enriched.inspiredByVideo,
      textTrackRef: current.textTrackRef ?? enriched.textTrackRef,
      textTrackContent: current.textTrackContent ?? enriched.textTrackContent,
      nostrEventTags: current.nostrEventTags.isNotEmpty
          ? current.nostrEventTags
          : enriched.nostrEventTags,
      authorName: current.authorName ?? enriched.authorName,
      authorAvatar: current.authorAvatar ?? enriched.authorAvatar,
      nostrLikeCount: mergeNullableEngagementMax(
        current.nostrLikeCount,
        enriched.nostrLikeCount,
      ),
    );
  }

  bool _sameVideoSequence(List<VideoEvent> left, List<VideoEvent> right) {
    if (left.length != right.length) return false;
    for (var i = 0; i < left.length; i++) {
      final l = left[i];
      final r = right[i];
      if (l.id != r.id) return false;
      if (l.originalLoops != r.originalLoops) return false;
      if (l.rawTags['views'] != r.rawTags['views']) return false;
      if (l.originalLikes != r.originalLikes) return false;
      if (l.originalComments != r.originalComments) return false;
      if (l.originalReposts != r.originalReposts) return false;
      if (l.nostrLikeCount != r.nostrLikeCount) return false;
    }
    return true;
  }

  @override
  Future<void> close() {
    _removeChangeListener?.call();
    _unregisterUpdate?.call();
    _unregisterNew?.call();
    _initialLoadTimer?.cancel();
    return super.close();
  }
}

/// Cached engagement metadata used to backfill Nostr-only videos.
class _VideoMetadataCache {
  const _VideoMetadataCache({
    this.originalLoops,
    this.views,
    this.originalLikes,
    this.originalComments,
    this.originalReposts,
    this.nostrLikeCount,
  });

  final int? originalLoops;
  final String? views;
  final int? originalLikes;
  final int? originalComments;
  final int? originalReposts;
  final int? nostrLikeCount;
}
