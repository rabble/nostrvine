// ABOUTME: Events for the ProfileCollabVideosBloc
// ABOUTME: Defines actions for fetching and paginating collab videos

part of 'profile_collab_videos_bloc.dart';

/// Base class for all profile collab videos events.
sealed class ProfileCollabVideosEvent {
  const ProfileCollabVideosEvent();
}

/// Request to fetch collab videos for the target user.
///
/// This triggers the repository's Funnelcake-confirmed collaborator read path.
final class ProfileCollabVideosFetchRequested extends ProfileCollabVideosEvent {
  const ProfileCollabVideosFetchRequested({this.completer});

  /// Optional completion signal for UI refresh affordances, completed once the
  /// handler is fully done — snapshot write included. See
  /// [completeProfileTabSync].
  final Completer<void>? completer;
}

/// Request to load more collab videos (pagination).
///
/// Uses [until] cursor from the last video's createdAt timestamp.
/// Only effective after initial fetch has completed.
final class ProfileCollabVideosLoadMoreRequested
    extends ProfileCollabVideosEvent {
  const ProfileCollabVideosLoadMoreRequested();
}

/// Internal: drop a video after the deletion bus reports it removed.
final class ProfileCollabVideosVideoRemoved extends ProfileCollabVideosEvent {
  const ProfileCollabVideosVideoRemoved(this.videoId);

  final String videoId;
}
