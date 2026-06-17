// ABOUTME: BLoC for managing profile saved (bookmarked) videos grid
// ABOUTME: Coordinates between BookmarkService (NIP-51 kind 10003) and VideosRepository
// ABOUTME: (cache-aware relay fetch with SQLite local storage). Own profile only.

import 'dart:async';
import 'dart:math';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:cache_sync/cache_sync.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/blocs/profile_shared/profile_video_list_snapshot.dart';
import 'package:openvine/extensions/video_event_extensions.dart';
import 'package:openvine/services/bookmark_service.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:videos_repository/videos_repository.dart';

part 'profile_saved_videos_event.dart';
part 'profile_saved_videos_state.dart';

/// Number of videos to load per page for pagination.
const _pageSize = 18;

/// BLoC for managing profile saved (bookmarked) videos.
///
/// Coordinates between:
/// - [BookmarkService]: Provides NIP-51 global bookmarks (kind 10003) — only
///   items of type `'e'` (event bookmarks) are treated as saved videos.
/// - [VideosRepository]: Fetches video data with cache-first lookups via
///   SQLite local storage. Automatically checks cache before relay queries.
///
/// Bookmarks are a private user artifact, so this BLoC is only wired for the
/// current user's own profile.
class ProfileSavedVideosBloc
    extends Bloc<ProfileSavedVideosEvent, ProfileSavedVideosState> {
  ProfileSavedVideosBloc({
    required Future<BookmarkService> bookmarkService,
    required VideosRepository videosRepository,
    required String currentUserPubkey,
  }) : _bookmarkServiceFuture = bookmarkService,
       _videosRepository = videosRepository,
       _currentUserPubkey = currentUserPubkey,
       super(const ProfileSavedVideosState()) {
    on<ProfileSavedVideosSyncRequested>(
      _onSyncRequested,
      transformer: droppable(),
    );
    on<ProfileSavedVideosLoadMoreRequested>(_onLoadMoreRequested);
  }

  /// Resolved lazily on the first sync — [bookmarkServiceProvider] is an
  /// async provider so the service isn't immediately available at widget
  /// build time.
  final Future<BookmarkService> _bookmarkServiceFuture;
  final VideosRepository _videosRepository;
  final String _currentUserPubkey;

  /// Cache key for the saved-videos snapshot (bookmarks are private, so the
  /// key is scoped to the signed-in user for sign-out invalidation).
  String get _cacheKey => '$_currentUserPubkey:profile_saved_videos';

  /// Handle sync request using stale-while-revalidate backed by [CacheSync].
  ///
  /// On reopen the persisted snapshot is served immediately; revalidation then
  /// re-reads the (in-memory, SharedPreferences-cached) bookmark list and only
  /// reconciles it against the shown videos — no bulk re-fetch / re-serialize.
  Future<void> _onSyncRequested(
    ProfileSavedVideosSyncRequested event,
    Emitter<ProfileSavedVideosState> emit,
  ) async {
    if (state.videos.isNotEmpty && !state.isRefreshing) {
      emit(state.copyWith(isRefreshing: true));
    }

    final cached = await _readCachedSnapshot();
    if (isClosed) return;
    if (cached != null && cached.videos.isNotEmpty) {
      emit(
        state.copyWith(
          status: ProfileSavedVideosStatus.success,
          videos: cached.videos,
          savedEventIds: cached.itemIds,
          nextPageOffset: cached.nextPageOffset,
          hasMoreContent: cached.hasMoreContent,
          isRefreshing: true,
          clearError: true,
        ),
      );
    }

    try {
      final freshIds = await _resolveSavedIds();
      if (isClosed) return;

      if (state.videos.isEmpty) {
        await _coldLoad(freshIds, emit);
      } else {
        await _warmRevalidate(freshIds, emit);
      }
    } catch (e, stackTrace) {
      Log.error(
        'ProfileSavedVideosBloc: Failed to load saved videos - $e',
        name: 'ProfileSavedVideosBloc',
        category: LogCategory.video,
      );
      addError(e, stackTrace);
      if (isClosed) return;
      if (state.videos.isNotEmpty) {
        emit(state.copyWith(isRefreshing: false));
        return;
      }
      emit(
        state.copyWith(
          status: ProfileSavedVideosStatus.failure,
          isRefreshing: false,
          error: ProfileSavedVideosError.loadFailed,
        ),
      );
    }
  }

  /// Reads the event-type bookmark IDs from [BookmarkService]. The service
  /// keeps a SharedPreferences-cached list and reconciles with the relay on
  /// initialize, so this read is cheap (no relay round-trip).
  Future<List<String>> _resolveSavedIds() async {
    final bookmarkService = await _bookmarkServiceFuture;
    return bookmarkService.globalBookmarks
        .where((item) => item.type == 'e')
        .map((item) => item.id)
        .toList();
  }

  /// Cold path: nothing cached. Fetch the first page for [savedEventIds].
  Future<void> _coldLoad(
    List<String> savedEventIds,
    Emitter<ProfileSavedVideosState> emit,
  ) async {
    if (savedEventIds.isEmpty) {
      emit(
        state.copyWith(
          status: ProfileSavedVideosStatus.success,
          videos: [],
          savedEventIds: [],
          nextPageOffset: 0,
          hasMoreContent: false,
          isRefreshing: false,
          clearError: true,
        ),
      );
      await _persistSnapshot(_emptySnapshot);
      return;
    }

    final firstPageIds = savedEventIds.take(_pageSize).toList();
    final videos = await _fetchVideos(firstPageIds, cacheResults: true);
    if (isClosed) return;

    final snapshot = ProfileVideoListSnapshot(
      videos: videos,
      itemIds: savedEventIds,
      nextPageOffset: firstPageIds.length,
      hasMoreContent: savedEventIds.length > firstPageIds.length,
    );
    emit(
      state.copyWith(
        status: ProfileSavedVideosStatus.success,
        videos: videos,
        savedEventIds: savedEventIds,
        nextPageOffset: snapshot.nextPageOffset,
        hasMoreContent: snapshot.hasMoreContent,
        isRefreshing: false,
        clearError: true,
      ),
    );
    await _persistSnapshot(snapshot);
  }

  /// Warm path: cached videos are already on screen. Reconcile against the
  /// fresh bookmark list (drop unsaved, fetch newly-saved in the window).
  Future<void> _warmRevalidate(
    List<String> freshIds,
    Emitter<ProfileSavedVideosState> emit,
  ) async {
    if (listEquals(freshIds, state.savedEventIds)) {
      emit(state.copyWith(isRefreshing: false));
      return;
    }

    final reconciled = await _reconcile(freshIds);
    if (isClosed) return;
    emit(
      state.copyWith(
        status: ProfileSavedVideosStatus.success,
        videos: reconciled.videos,
        savedEventIds: freshIds,
        nextPageOffset: reconciled.nextPageOffset,
        hasMoreContent: reconciled.hasMoreContent,
        isRefreshing: false,
        clearError: true,
      ),
    );
    await _persistSnapshot(
      ProfileVideoListSnapshot(
        videos: reconciled.videos,
        itemIds: freshIds,
        nextPageOffset: reconciled.nextPageOffset,
        hasMoreContent: reconciled.hasMoreContent,
      ),
    );
  }

  /// Reconciles displayed videos against a fresh [freshIds] list: keeps saved
  /// videos still present, drops the rest, and fetches only the newly-saved
  /// IDs in the loaded window. Bounded so it never bulk-fetches.
  Future<({List<VideoEvent> videos, int nextPageOffset, bool hasMoreContent})>
  _reconcile(List<String> freshIds) async {
    final byId = {for (final video in state.videos) video.id: video};
    // Anchor on the previous top ID rather than a length delta, so a capped
    // persisted ID list can't balloon the reconcile window into a full
    // re-fetch on reopen (see ProfileLikedVideosBloc for the rationale).
    final newAtTop = _newItemsAtTop(freshIds);
    final windowSize =
        (max(state.nextPageOffset, state.videos.length) + newAtTop).clamp(
          0,
          freshIds.length,
        );
    final windowIds = freshIds.take(windowSize).toList();

    final missingIds = windowIds.where((id) => !byId.containsKey(id)).toList();
    if (missingIds.isNotEmpty) {
      for (final video in await _fetchVideos(missingIds, cacheResults: true)) {
        byId[video.id] = video;
      }
    }

    final videos = windowIds
        .map((id) => byId[id])
        .whereType<VideoEvent>()
        .toList();
    return (
      videos: videos,
      nextPageOffset: windowIds.length,
      hasMoreContent: windowIds.length < freshIds.length,
    );
  }

  /// Number of fresh IDs prepended above the previous top item, located by
  /// finding the old top ID in [freshIds]. Returns 0 when there is no prior
  /// list or the old top is gone, so a capped persisted list can never
  /// balloon the reconcile window into a full re-fetch.
  int _newItemsAtTop(List<String> freshIds) {
    if (state.savedEventIds.isEmpty) return 0;
    final index = freshIds.indexOf(state.savedEventIds.first);
    return index < 0 ? 0 : index;
  }

  static const ProfileVideoListSnapshot _emptySnapshot =
      ProfileVideoListSnapshot(
        videos: [],
        itemIds: [],
        nextPageOffset: 0,
        hasMoreContent: false,
      );

  Future<ProfileVideoListSnapshot?> _readCachedSnapshot() async {
    try {
      return await CacheSync.read<ProfileVideoListSnapshot>(
        key: _cacheKey,
        fromJson: ProfileVideoListSnapshot.fromJson,
      );
    } on Object catch (e) {
      Log.warning(
        'ProfileSavedVideosBloc: Failed to read cached snapshot - $e',
        name: 'ProfileSavedVideosBloc',
        category: LogCategory.video,
      );
      return null;
    }
  }

  Future<void> _persistSnapshot(ProfileVideoListSnapshot snapshot) async {
    try {
      await CacheSync.write<ProfileVideoListSnapshot>(
        key: _cacheKey,
        value: ProfileVideoListSnapshot.capped(
          videos: snapshot.videos,
          itemIds: snapshot.itemIds,
          nextPageOffset: snapshot.nextPageOffset,
          hasMoreContent: snapshot.hasMoreContent,
        ),
        toJson: (s) => s.toJson(),
      );
    } on Object catch (e) {
      Log.warning(
        'ProfileSavedVideosBloc: Failed to persist snapshot - $e',
        name: 'ProfileSavedVideosBloc',
        category: LogCategory.video,
      );
    }
  }

  /// Handle load more request — fetches the next page of videos.
  ///
  /// Uses [state.nextPageOffset] to track the position in
  /// [state.savedEventIds] and fetches the next [_pageSize] IDs. The offset
  /// advances by the number of IDs consumed, not the number of videos loaded
  /// (some IDs may not resolve to videos due to relay unavailability or
  /// format filtering).
  Future<void> _onLoadMoreRequested(
    ProfileSavedVideosLoadMoreRequested event,
    Emitter<ProfileSavedVideosState> emit,
  ) async {
    if (state.status != ProfileSavedVideosStatus.success ||
        state.isLoadingMore ||
        !state.hasMoreContent) {
      return;
    }

    final offset = state.nextPageOffset;
    final totalCount = state.savedEventIds.length;

    if (offset >= totalCount) {
      emit(state.copyWith(hasMoreContent: false));
      return;
    }

    Log.info(
      'ProfileSavedVideosBloc: Loading more videos '
      '(offset: $offset, total: $totalCount)',
      name: 'ProfileSavedVideosBloc',
      category: LogCategory.video,
    );

    emit(state.copyWith(isLoadingMore: true));

    try {
      final nextPageIds = state.savedEventIds
          .skip(offset)
          .take(_pageSize)
          .toList();
      final newVideos = await _fetchVideos(nextPageIds, cacheResults: true);

      Log.info(
        'ProfileSavedVideosBloc: Loaded ${newVideos.length} more videos',
        name: 'ProfileSavedVideosBloc',
        category: LogCategory.video,
      );

      final existingIds = state.videos.map((v) => v.id).toSet();
      final uniqueNewVideos = newVideos
          .where((v) => !existingIds.contains(v.id))
          .toList();

      final newOffset = offset + nextPageIds.length;
      final allVideos = [...state.videos, ...uniqueNewVideos];
      final hasMore = newOffset < totalCount;

      emit(
        state.copyWith(
          videos: allVideos,
          isLoadingMore: false,
          hasMoreContent: hasMore,
          nextPageOffset: newOffset,
        ),
      );
      await _persistSnapshot(
        ProfileVideoListSnapshot(
          videos: allVideos,
          itemIds: state.savedEventIds,
          nextPageOffset: newOffset,
          hasMoreContent: hasMore,
        ),
      );
    } catch (e, stackTrace) {
      Log.error(
        'ProfileSavedVideosBloc: Failed to load more videos - $e',
        name: 'ProfileSavedVideosBloc',
        category: LogCategory.video,
      );
      addError(e, stackTrace);
      emit(state.copyWith(isLoadingMore: false));
    }
  }

  /// Fetch videos for the given event IDs via [VideosRepository], which
  /// handles cache-first lookups (SQLite local storage → relay fallback).
  ///
  /// When [cacheResults] is true, videos fetched from relay are saved to
  /// local storage for future cache hits. Only use for first-page loads to
  /// avoid bloating the cache.
  ///
  /// Returns videos in the same order as [eventIds], excluding videos not
  /// found in cache or relay and videos whose format is unsupported on the
  /// current platform.
  Future<List<VideoEvent>> _fetchVideos(
    List<String> eventIds, {
    bool cacheResults = false,
  }) async {
    if (eventIds.isEmpty) return [];

    final videos = await _videosRepository.getVideosByIds(
      eventIds,
      cacheResults: cacheResults,
    );

    Log.debug(
      'ProfileSavedVideosBloc: Fetched ${videos.length}/${eventIds.length} '
      'videos (cacheResults: $cacheResults)',
      name: 'ProfileSavedVideosBloc',
      category: LogCategory.video,
    );

    return videos.where((v) => v.isSupportedOnCurrentPlatform).toList();
  }
}
