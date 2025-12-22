// ABOUTME: Events for the FollowersBloc
// ABOUTME: Defines actions for loading, refreshing, and follow/unfollow operations

part of 'followers_bloc.dart';

/// Base class for all followers list events
sealed class FollowersEvent {
  const FollowersEvent();
}

/// Request to load (or refresh) the followers list for a specific user
final class FollowersListLoadRequested extends FollowersEvent {
  const FollowersListLoadRequested(this.pubkey);

  /// The public key of the user whose followers list to load
  final String pubkey;
}

/// Request to toggle follow status for a follower.
/// Used when the current user wants to follow back a follower.
final class FollowerToggleFollowRequested extends FollowersEvent {
  const FollowerToggleFollowRequested(this.pubkey);

  /// The public key of the follower to follow/unfollow
  final String pubkey;
}
