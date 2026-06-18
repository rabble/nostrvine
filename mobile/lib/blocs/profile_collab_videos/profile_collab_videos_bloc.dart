// ABOUTME: BLoC for managing profile collab videos grid
// ABOUTME: Fetches Funnelcake-confirmed collaborator videos for a profile

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:cache_sync/cache_sync.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/blocs/profile_shared/profile_video_cursor_snapshot.dart';
import 'package:openvine/extensions/video_event_extensions.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:videos_repository/videos_repository.dart';

part 'profile_collab_videos_event.dart';
part 'profile_collab_videos_state.dart';

/// Number of videos to load per page for pagination.
const _pageSize = 18;

/// BLoC for managing profile collab videos.
///
/// Fetches videos from Funnelcake's confirmed collaborator edge endpoint
/// (`GET /api/users/{pubkey}/collabs`). Raw relay p-tags are not confirmation:
/// they can represent pending invites or generic mentions, so the profile
/// collabs tab trusts the repository's confirmed read path instead of
/// re-confirming from event tags.
class ProfileCollabVideosBloc
    extends Bloc<ProfileCollabVideosEvent, ProfileCollabVideosState> {
  ProfileCollabVideosBloc({
    required VideosRepository videosRepository,
    required String targetUserPubkey,
  }) : _videosRepository = videosRepository,
       _targetUserPubkey = targetUserPubkey,
       super(const ProfileCollabVideosState()) {
    on<ProfileCollabVideosFetchRequested>(
      _onFetchRequested,
      transformer: droppable(),
    );
    on<ProfileCollabVideosLoadMoreRequested>(_onLoadMoreRequested);
  }

  final VideosRepository _videosRepository;
  final String _targetUserPubkey;

  /// Cache key for this profile's collab-videos snapshot.
  String get _cacheKey => '$_targetUserPubkey:profile_collab_videos';

  /// Handle fetch request using stale-while-revalidate backed by [CacheSync].
  ///
  /// On reopen the persisted snapshot is served immediately; revalidation then
  /// re-fetches just the first page and prepends any genuinely-new collab
  /// videos — it never re-fetches the whole loaded feed.
  Future<void> _onFetchRequested(
    ProfileCollabVideosFetchRequested event,
    Emitter<ProfileCollabVideosState> emit,
  ) async {
    if (state.videos.isNotEmpty && !state.isRefreshing) {
      emit(state.copyWith(isRefreshing: true));
    }

    final cached = await _readCachedSnapshot();
    if (isClosed) return;
    if (cached != null && cached.videos.isNotEmpty) {
      emit(
        state.copyWith(
          status: ProfileCollabVideosStatus.success,
          videos: cached.videos,
          hasMoreContent: cached.hasMoreContent,
          paginationCursor: cached.paginationCursor,
          isRefreshing: true,
        ),
      );
    }

    try {
      if (state.videos.isEmpty) {
        await _coldLoad(emit);
      } else {
        await _warmRevalidate(emit);
      }
    } catch (e, stackTrace) {
      Log.error(
        'ProfileCollabVideosBloc: Failed to fetch collab videos - $e',
        name: 'ProfileCollabVideosBloc',
        category: LogCategory.video,
      );
      addError(e, stackTrace);
      if (isClosed) return;
      if (state.videos.isNotEmpty) {
        emit(state.copyWith(isRefreshing: false));
        return;
      }
      emit(state.copyWith(status: ProfileCollabVideosStatus.failure));
    }
  }

  /// Cold path: nothing cached. Fetch the first page from the collabs feed.
  Future<void> _coldLoad(Emitter<ProfileCollabVideosState> emit) async {
    emit(state.copyWith(status: ProfileCollabVideosStatus.loading));

    final videos = await _videosRepository.getCollabVideos(
      taggedPubkey: _targetUserPubkey,
      limit: _pageSize,
    );
    if (isClosed) return;

    final collabVideos = videos
        .where((v) => v.isSupportedOnCurrentPlatform)
        .toList();
    final cursor = collabVideos.isNotEmpty ? collabVideos.last.createdAt : null;
    final hasMore = videos.length >= _pageSize;

    emit(
      state.copyWith(
        status: ProfileCollabVideosStatus.success,
        videos: collabVideos,
        hasMoreContent: hasMore,
        paginationCursor: cursor,
        clearCursor: cursor == null,
        isRefreshing: false,
      ),
    );
    await _persistSnapshot(
      ProfileVideoCursorSnapshot(
        videos: collabVideos,
        paginationCursor: cursor,
        hasMoreContent: hasMore,
      ),
    );
  }

  /// Warm path: cached videos are already on screen. Re-fetch just the first
  /// page and prepend any genuinely-new collab videos. No bulk re-fetch.
  Future<void> _warmRevalidate(Emitter<ProfileCollabVideosState> emit) async {
    final firstPage = await _videosRepository.getCollabVideos(
      taggedPubkey: _targetUserPubkey,
      limit: _pageSize,
    );
    if (isClosed) return;

    // getCollabVideos is the authoritative confirmed-collab endpoint, so the
    // fresh first page replaces the cached head — this picks up reorders and
    // drops videos no longer confirmed. Cached videos beyond the first page
    // (not re-fetched) are kept, deduped against the fresh page.
    final fresh = firstPage
        .where((v) => v.isSupportedOnCurrentPlatform)
        .toList();
    final freshIds = fresh.map((v) => v.id).toSet();
    final tail = firstPage.length >= _pageSize
        ? state.videos
              .skip(_tailStartAfterFreshOverlap(fresh))
              .where((v) => !freshIds.contains(v.id))
              .toList()
        : <VideoEvent>[];
    final allVideos = [...fresh, ...tail];
    // A short fresh page means the feed ends there; the cached tail (if any)
    // is no longer confirmed.
    final hasMore = firstPage.length >= _pageSize && state.hasMoreContent;

    final unchanged = listEquals(
      allVideos.map((v) => v.id).toList(),
      state.videos.map((v) => v.id).toList(),
    );
    if (unchanged && hasMore == state.hasMoreContent) {
      emit(state.copyWith(isRefreshing: false));
      return;
    }

    emit(
      state.copyWith(
        status: ProfileCollabVideosStatus.success,
        videos: allVideos,
        hasMoreContent: hasMore,
        isRefreshing: false,
      ),
    );
    await _persistSnapshot(
      ProfileVideoCursorSnapshot(
        videos: allVideos,
        paginationCursor: state.paginationCursor,
        hasMoreContent: hasMore,
      ),
    );
  }

  int _tailStartAfterFreshOverlap(List<VideoEvent> fresh) {
    if (fresh.isEmpty) return 0;

    final freshIds = fresh.map((v) => v.id).toSet();
    for (var i = state.videos.length - 1; i >= 0; i--) {
      if (freshIds.contains(state.videos[i].id)) {
        return i + 1;
      }
    }

    return fresh.length.clamp(0, state.videos.length);
  }

  Future<ProfileVideoCursorSnapshot?> _readCachedSnapshot() async {
    try {
      return await CacheSync.read<ProfileVideoCursorSnapshot>(
        key: _cacheKey,
        fromJson: ProfileVideoCursorSnapshot.fromJson,
      );
    } on Object catch (e) {
      Log.warning(
        'ProfileCollabVideosBloc: Failed to read cached snapshot - $e',
        name: 'ProfileCollabVideosBloc',
        category: LogCategory.video,
      );
      return null;
    }
  }

  Future<void> _persistSnapshot(ProfileVideoCursorSnapshot snapshot) async {
    try {
      await CacheSync.write<ProfileVideoCursorSnapshot>(
        key: _cacheKey,
        value: ProfileVideoCursorSnapshot.capped(
          videos: snapshot.videos,
          paginationCursor: snapshot.paginationCursor,
          hasMoreContent: snapshot.hasMoreContent,
        ),
        toJson: (s) => s.toJson(),
      );
    } on Object catch (e) {
      Log.warning(
        'ProfileCollabVideosBloc: Failed to persist snapshot - $e',
        name: 'ProfileCollabVideosBloc',
        category: LogCategory.video,
      );
    }
  }

  /// Handle load more request - fetches the next page of collab videos.
  Future<void> _onLoadMoreRequested(
    ProfileCollabVideosLoadMoreRequested event,
    Emitter<ProfileCollabVideosState> emit,
  ) async {
    // Skip if not in success state, already loading, or no more content
    if (state.status != ProfileCollabVideosStatus.success ||
        state.isLoadingMore ||
        !state.hasMoreContent) {
      return;
    }

    Log.info(
      'ProfileCollabVideosBloc: Loading more collab videos '
      '(current: ${state.videos.length})',
      name: 'ProfileCollabVideosBloc',
      category: LogCategory.video,
    );

    emit(state.copyWith(isLoadingMore: true));

    try {
      final videos = await _videosRepository.getCollabVideos(
        taggedPubkey: _targetUserPubkey,
        limit: _pageSize,
        until: state.paginationCursor,
      );

      final newCollabVideos = videos
          .where((v) => v.isSupportedOnCurrentPlatform)
          .toList();

      // Deduplicate against existing videos
      final existingIds = state.videos.map((v) => v.id).toSet();
      final uniqueNewVideos = newCollabVideos
          .where((v) => !existingIds.contains(v.id))
          .toList();

      // Update pagination cursor
      final cursor = uniqueNewVideos.isNotEmpty
          ? uniqueNewVideos.last.createdAt
          : state.paginationCursor;

      final allVideos = [...state.videos, ...uniqueNewVideos];

      Log.info(
        'ProfileCollabVideosBloc: Loaded ${uniqueNewVideos.length} more '
        'collab videos (total: ${allVideos.length})',
        name: 'ProfileCollabVideosBloc',
        category: LogCategory.video,
      );

      final hasMore = videos.length >= _pageSize;
      emit(
        state.copyWith(
          videos: allVideos,
          isLoadingMore: false,
          hasMoreContent: hasMore,
          paginationCursor: cursor,
        ),
      );
      await _persistSnapshot(
        ProfileVideoCursorSnapshot(
          videos: allVideos,
          paginationCursor: cursor,
          hasMoreContent: hasMore,
        ),
      );
    } catch (e) {
      Log.error(
        'ProfileCollabVideosBloc: Failed to load more collab videos - $e',
        name: 'ProfileCollabVideosBloc',
        category: LogCategory.video,
      );
      emit(state.copyWith(isLoadingMore: false));
    }
  }
}
