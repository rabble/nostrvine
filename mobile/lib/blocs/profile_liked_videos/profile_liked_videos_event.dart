// ABOUTME: Events for the ProfileLikedVideosBloc
// ABOUTME: Defines actions for syncing and refreshing liked videos

part of 'profile_liked_videos_bloc.dart';

/// Base class for all profile liked videos events
sealed class ProfileLikedVideosEvent {
  const ProfileLikedVideosEvent();
}

/// Request to sync liked event IDs from repository and load videos.
///
/// This triggers:
/// 1. Sync of liked event IDs from LikesRepository
/// 2. Fetch of video data for those IDs from cache/relays
final class ProfileLikedVideosSyncRequested extends ProfileLikedVideosEvent {
  const ProfileLikedVideosSyncRequested();
}

/// Request to refresh liked videos (re-sync and reload)
final class ProfileLikedVideosRefreshRequested extends ProfileLikedVideosEvent {
  const ProfileLikedVideosRefreshRequested();
}

/// Internal event for when liked IDs change from the repository stream.
final class _ProfileLikedVideosIdsChanged extends ProfileLikedVideosEvent {
  const _ProfileLikedVideosIdsChanged(this.likedEventIds);

  final List<String> likedEventIds;
}
