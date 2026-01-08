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

/// Request to start listening for liked IDs changes from the repository.
///
/// This should be dispatched once when the screen/widget is initialized.
/// Uses emit.forEach internally to reactively update state when likes change.
final class ProfileLikedVideosSubscriptionRequested
    extends ProfileLikedVideosEvent {
  const ProfileLikedVideosSubscriptionRequested();
}
