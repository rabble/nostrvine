// ABOUTME: BLoC for managing profile saved (bookmarked) videos grid
// ABOUTME: Coordinates between BookmarkService (NIP-51 kind 10003) and VideosRepository
// ABOUTME: (cache-aware relay fetch with SQLite local storage). Own profile only.

import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart' hide LogCategory;
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
  }) : _bookmarkServiceFuture = bookmarkService,
       _videosRepository = videosRepository,
       super(const ProfileSavedVideosState()) {
    on<ProfileSavedVideosSyncRequested>(_onSyncRequested);
    on<ProfileSavedVideosLoadMoreRequested>(_onLoadMoreRequested);
  }

  /// Resolved lazily on the first sync — [bookmarkServiceProvider] is an
  /// async provider so the service isn't immediately available at widget
  /// build time.
  final Future<BookmarkService> _bookmarkServiceFuture;
  final VideosRepository _videosRepository;

  /// Handle sync request — loads bookmark IDs from [BookmarkService] (which
  /// already keeps a SharedPreferences-cached list populated on startup and
  /// reconciles with the relay on initialize) and fetches the first page of
  /// videos through [VideosRepository].
  Future<void> _onSyncRequested(
    ProfileSavedVideosSyncRequested event,
    Emitter<ProfileSavedVideosState> emit,
  ) async {
    if (state.status == ProfileSavedVideosStatus.syncing) return;

    emit(state.copyWith(status: ProfileSavedVideosStatus.syncing));

    try {
      final bookmarkService = await _bookmarkServiceFuture;

      // BookmarkService.globalBookmarks is a List<BookmarkItem>; keep only
      // event-type entries (type 'e') — hashtag/url/article bookmarks are
      // not videos.
      final savedEventIds = bookmarkService.globalBookmarks
          .where((item) => item.type == 'e')
          .map((item) => item.id)
          .toList();

      Log.info(
        'ProfileSavedVideosBloc: Got ${savedEventIds.length} saved event IDs',
        name: 'ProfileSavedVideosBloc',
        category: LogCategory.video,
      );

      if (savedEventIds.isEmpty) {
        emit(
          state.copyWith(
            status: ProfileSavedVideosStatus.success,
            videos: [],
            savedEventIds: [],
            hasMoreContent: false,
            nextPageOffset: 0,
            clearError: true,
          ),
        );
        return;
      }

      emit(
        state.copyWith(
          status: ProfileSavedVideosStatus.loading,
          savedEventIds: savedEventIds,
        ),
      );

      final firstPageIds = savedEventIds.take(_pageSize).toList();
      final videos = await _fetchVideos(firstPageIds, cacheResults: true);

      Log.info(
        'ProfileSavedVideosBloc: Loaded ${videos.length} videos '
        '(first page of ${savedEventIds.length} total)',
        name: 'ProfileSavedVideosBloc',
        category: LogCategory.video,
      );

      emit(
        state.copyWith(
          status: ProfileSavedVideosStatus.success,
          videos: videos,
          hasMoreContent: savedEventIds.length > firstPageIds.length,
          nextPageOffset: firstPageIds.length,
          clearError: true,
        ),
      );
    } catch (e, stackTrace) {
      Log.error(
        'ProfileSavedVideosBloc: Failed to load saved videos - $e',
        name: 'ProfileSavedVideosBloc',
        category: LogCategory.video,
      );
      addError(e, stackTrace);
      emit(
        state.copyWith(
          status: ProfileSavedVideosStatus.failure,
          error: ProfileSavedVideosError.loadFailed,
        ),
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
      final newVideos = await _fetchVideos(nextPageIds);

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
