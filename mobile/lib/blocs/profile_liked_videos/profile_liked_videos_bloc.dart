// ABOUTME: BLoC for managing profile liked videos grid
// ABOUTME: Coordinates between LikesRepository (for IDs) and VideosRepository
// ABOUTME: (for video data)

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:likes_repository/likes_repository.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/extensions/video_event_extensions.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:videos_repository/videos_repository.dart';

part 'profile_liked_videos_event.dart';
part 'profile_liked_videos_state.dart';

/// Number of videos to load per page for pagination.
const _pageSize = 18;

/// BLoC for managing profile liked videos.
///
/// Coordinates between:
/// - [LikesRepository]: Provides liked event IDs (sync for own, fetch for other)
/// - [VideosRepository]: Fetches actual video data by IDs
///
/// Handles:
/// - Syncing liked event IDs from LikesRepository
/// - Loading video data for liked event IDs via VideosRepository
/// - Filtering: excludes unsupported video formats
/// - Listening for like changes to update the list
/// - Pagination: loads videos in batches of [_pageSize]
class ProfileLikedVideosBloc
    extends Bloc<ProfileLikedVideosEvent, ProfileLikedVideosState> {
  ProfileLikedVideosBloc({
    required LikesRepository likesRepository,
    required VideosRepository videosRepository,
    required String currentUserPubkey,
    String? targetUserPubkey,
  }) : _likesRepository = likesRepository,
       _videosRepository = videosRepository,
       _currentUserPubkey = currentUserPubkey,
       _targetUserPubkey = targetUserPubkey,
       super(const ProfileLikedVideosState()) {
    on<ProfileLikedVideosSyncRequested>(_onSyncRequested);
    on<ProfileLikedVideosSubscriptionRequested>(_onSubscriptionRequested);
    on<ProfileLikedVideosLoadMoreRequested>(_onLoadMoreRequested);
  }

  final LikesRepository _likesRepository;
  final VideosRepository _videosRepository;
  final String _currentUserPubkey;

  /// The pubkey of the user whose likes to display.
  /// If null or same as current user, uses LikesRepository sync.
  /// If different, fetches likes directly from Nostr relays.
  final String? _targetUserPubkey;

  /// Whether we're viewing another user's profile (not our own).
  bool get _isOtherUserProfile =>
      _targetUserPubkey != null && _targetUserPubkey != _currentUserPubkey;

  /// Handle sync request - syncs liked IDs from repository then loads videos.
  Future<void> _onSyncRequested(
    ProfileLikedVideosSyncRequested event,
    Emitter<ProfileLikedVideosState> emit,
  ) async {
    // Don't re-sync if already syncing
    if (state.status == ProfileLikedVideosStatus.syncing) return;

    Log.info(
      'ProfileLikedVideosBloc: Starting sync for '
      '${_isOtherUserProfile ? "other user" : "own profile"}',
      name: 'ProfileLikedVideosBloc',
      category: LogCategory.video,
    );

    emit(state.copyWith(status: ProfileLikedVideosStatus.syncing));

    try {
      // Get liked event IDs - either from repository (own) or relays (other)
      final likedEventIds = _isOtherUserProfile
          ? await _likesRepository.fetchUserLikes(_targetUserPubkey!)
          : (await _likesRepository.syncUserReactions()).orderedEventIds;

      Log.info(
        'ProfileLikedVideosBloc: Synced ${likedEventIds.length} liked IDs',
        name: 'ProfileLikedVideosBloc',
        category: LogCategory.video,
      );

      if (likedEventIds.isEmpty) {
        emit(
          state.copyWith(
            status: ProfileLikedVideosStatus.success,
            videos: [],
            likedEventIds: [],
            hasMoreContent: false,
            clearError: true,
          ),
        );
        return;
      }

      emit(
        state.copyWith(
          status: ProfileLikedVideosStatus.loading,
          likedEventIds: likedEventIds,
        ),
      );

      // Fetch video data for the first page of liked IDs
      final firstPageIds = likedEventIds.take(_pageSize).toList();
      final videos = await _fetchVideos(firstPageIds);

      Log.info(
        'ProfileLikedVideosBloc: Loaded ${videos.length} videos '
        '(first page of ${likedEventIds.length} total)',
        name: 'ProfileLikedVideosBloc',
        category: LogCategory.video,
      );

      emit(
        state.copyWith(
          status: ProfileLikedVideosStatus.success,
          videos: videos,
          hasMoreContent: likedEventIds.length > _pageSize,
          clearError: true,
        ),
      );
    } on SyncFailedException catch (e) {
      Log.error(
        'ProfileLikedVideosBloc: Sync failed - ${e.message}',
        name: 'ProfileLikedVideosBloc',
        category: LogCategory.video,
      );
      emit(
        state.copyWith(
          status: ProfileLikedVideosStatus.failure,
          error: ProfileLikedVideosError.syncFailed,
        ),
      );
    } on FetchLikesFailedException catch (e) {
      Log.error(
        'ProfileLikedVideosBloc: Fetch likes failed - ${e.message}',
        name: 'ProfileLikedVideosBloc',
        category: LogCategory.video,
      );
      emit(
        state.copyWith(
          status: ProfileLikedVideosStatus.failure,
          error: ProfileLikedVideosError.syncFailed,
        ),
      );
    } catch (e) {
      Log.error(
        'ProfileLikedVideosBloc: Failed to load videos - $e',
        name: 'ProfileLikedVideosBloc',
        category: LogCategory.video,
      );
      emit(
        state.copyWith(
          status: ProfileLikedVideosStatus.failure,
          error: ProfileLikedVideosError.loadFailed,
        ),
      );
    }
  }

  /// Subscribe to liked IDs changes and update the video list reactively.
  ///
  /// Uses emit.forEach to listen to the repository stream and emit state
  /// changes when liked IDs change (videos added or removed).
  ///
  /// Note: This only works for the current user's own profile, as the
  /// LikesRepository only tracks the authenticated user's likes.
  /// For other users' profiles, this subscription has no effect.
  Future<void> _onSubscriptionRequested(
    ProfileLikedVideosSubscriptionRequested event,
    Emitter<ProfileLikedVideosState> emit,
  ) async {
    // Only subscribe for own profile - the repository only tracks current
    // user's likes, so watching it for other users would show wrong data.
    if (_isOtherUserProfile) return;

    await emit.forEach<Set<String>>(
      _likesRepository.watchLikedEventIds(),
      onData: (likedIdsSet) {
        final newIds = likedIdsSet.toList();

        // Skip if IDs haven't changed
        if (listEquals(newIds, state.likedEventIds)) return state;

        // Skip if we haven't done initial sync yet
        if (state.status == ProfileLikedVideosStatus.initial ||
            state.status == ProfileLikedVideosStatus.syncing) {
          return state;
        }

        Log.info(
          'ProfileLikedVideosBloc: Liked IDs changed, updating list',
          name: 'ProfileLikedVideosBloc',
          category: LogCategory.video,
        );

        // If a video was unliked, remove it from the list immediately
        if (newIds.length < state.likedEventIds.length) {
          final removedIds = state.likedEventIds
              .where((id) => !newIds.contains(id))
              .toSet();
          final updatedVideos = state.videos
              .where((v) => !removedIds.contains(v.id))
              .toList();

          return state.copyWith(likedEventIds: newIds, videos: updatedVideos);
        }

        // If a video was liked, we need to fetch it asynchronously
        // For now, just update the IDs - the video will be fetched on next sync
        if (newIds.length > state.likedEventIds.length) {
          return state.copyWith(likedEventIds: newIds);
        }

        return state;
      },
    );
  }

  /// Handle load more request - fetches the next page of videos.
  ///
  /// Uses [state.videos.length] to determine the offset and fetches
  /// the next [_pageSize] videos from [state.likedEventIds].
  Future<void> _onLoadMoreRequested(
    ProfileLikedVideosLoadMoreRequested event,
    Emitter<ProfileLikedVideosState> emit,
  ) async {
    // Skip if not in success state, already loading, or no more content
    if (state.status != ProfileLikedVideosStatus.success ||
        state.isLoadingMore ||
        !state.hasMoreContent) {
      return;
    }

    final currentCount = state.videos.length;
    final totalCount = state.likedEventIds.length;

    // No more to load
    if (currentCount >= totalCount) {
      emit(state.copyWith(hasMoreContent: false));
      return;
    }

    Log.info(
      'ProfileLikedVideosBloc: Loading more videos '
      '(current: $currentCount, total: $totalCount)',
      name: 'ProfileLikedVideosBloc',
      category: LogCategory.video,
    );

    emit(state.copyWith(isLoadingMore: true));

    try {
      // Get the next page of IDs
      final nextPageIds = state.likedEventIds
          .skip(currentCount)
          .take(_pageSize)
          .toList();

      // Fetch videos for the next page
      final newVideos = await _fetchVideos(nextPageIds);

      Log.info(
        'ProfileLikedVideosBloc: Loaded ${newVideos.length} more videos',
        name: 'ProfileLikedVideosBloc',
        category: LogCategory.video,
      );

      // Append to existing videos
      final allVideos = [...state.videos, ...newVideos];
      final hasMore = allVideos.length < totalCount;

      emit(
        state.copyWith(
          videos: allVideos,
          isLoadingMore: false,
          hasMoreContent: hasMore,
        ),
      );
    } catch (e) {
      Log.error(
        'ProfileLikedVideosBloc: Failed to load more videos - $e',
        name: 'ProfileLikedVideosBloc',
        category: LogCategory.video,
      );
      emit(state.copyWith(isLoadingMore: false));
    }
  }

  /// Fetch videos for the given event IDs via VideosRepository.
  ///
  /// The repository handles:
  /// - Fetching from Nostr relays
  /// - Filtering out invalid/expired videos
  /// - Preserving order based on input IDs
  Future<List<VideoEvent>> _fetchVideos(List<String> eventIds) async {
    final videos = await _videosRepository.getVideosByIds(eventIds);

    // Filter out unsupported videos (WebM on iOS/macOS)
    return videos.where((v) => v.isSupportedOnCurrentPlatform).toList();
  }
}
