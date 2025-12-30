// ABOUTME: Events for the ProfileLikedVideosBloc
// ABOUTME: Defines actions for loading and refreshing liked videos

part of 'profile_liked_videos_bloc.dart';

/// Base class for all profile liked videos events
sealed class ProfileLikedVideosEvent {
  const ProfileLikedVideosEvent();
}

/// Request to load liked videos for the given event IDs
///
/// [likedEventIds] should be ordered by recency (most recently liked first).
final class ProfileLikedVideosLoadRequested extends ProfileLikedVideosEvent {
  const ProfileLikedVideosLoadRequested({required this.likedEventIds});

  /// The ordered list of liked event IDs to fetch videos for
  final List<String> likedEventIds;
}

/// Request to refresh liked videos (re-fetch from cache and relays)
final class ProfileLikedVideosRefreshRequested extends ProfileLikedVideosEvent {
  const ProfileLikedVideosRefreshRequested();
}
