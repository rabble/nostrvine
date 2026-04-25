// ABOUTME: BLoC for managing profile collab videos grid
// ABOUTME: Fetches Funnelcake-confirmed collaborator videos for a profile

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart' hide LogCategory;
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
    on<ProfileCollabVideosFetchRequested>(_onFetchRequested);
    on<ProfileCollabVideosLoadMoreRequested>(_onLoadMoreRequested);
  }

  final VideosRepository _videosRepository;
  final String _targetUserPubkey;

  /// Handle fetch request - loads collab videos for the target user.
  Future<void> _onFetchRequested(
    ProfileCollabVideosFetchRequested event,
    Emitter<ProfileCollabVideosState> emit,
  ) async {
    // Don't re-fetch if already loading
    if (state.status == ProfileCollabVideosStatus.loading) return;

    Log.info(
      'ProfileCollabVideosBloc: Fetching collab videos for '
      '$_targetUserPubkey',
      name: 'ProfileCollabVideosBloc',
      category: LogCategory.video,
    );

    emit(state.copyWith(status: ProfileCollabVideosStatus.loading));

    try {
      final videos = await _videosRepository.getCollabVideos(
        taggedPubkey: _targetUserPubkey,
        limit: _pageSize,
      );

      final collabVideos = videos
          .where((v) => v.isSupportedOnCurrentPlatform)
          .toList();

      // Determine pagination cursor from last video's createdAt
      final cursor = collabVideos.isNotEmpty
          ? collabVideos.last.createdAt
          : null;

      Log.info(
        'ProfileCollabVideosBloc: Loaded ${collabVideos.length} collab '
        'videos (from ${videos.length} total results)',
        name: 'ProfileCollabVideosBloc',
        category: LogCategory.video,
      );

      emit(
        state.copyWith(
          status: ProfileCollabVideosStatus.success,
          videos: collabVideos,
          hasMoreContent: videos.length >= _pageSize,
          paginationCursor: cursor,
        ),
      );
    } catch (e, stackTrace) {
      Log.error(
        'ProfileCollabVideosBloc: Failed to fetch collab videos - $e',
        name: 'ProfileCollabVideosBloc',
        category: LogCategory.video,
      );
      addError(e, stackTrace);
      emit(state.copyWith(status: ProfileCollabVideosStatus.failure));
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

      emit(
        state.copyWith(
          videos: allVideos,
          isLoadingMore: false,
          hasMoreContent: videos.length >= _pageSize,
          paginationCursor: cursor,
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
