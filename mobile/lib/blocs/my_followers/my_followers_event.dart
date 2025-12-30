// ABOUTME: Events for MyFollowersBloc
// ABOUTME: Defines actions for loading and follow-back operations

part of 'my_followers_bloc.dart';

/// Base class for all my followers list events
sealed class MyFollowersEvent {
  const MyFollowersEvent();
}

/// Request to load current user's followers list.
final class MyFollowersListLoadRequested extends MyFollowersEvent {
  const MyFollowersListLoadRequested();
}

/// Request to toggle follow status for a follower (follow back).
final class MyFollowersToggleFollowRequested extends MyFollowersEvent {
  const MyFollowersToggleFollowRequested(this.pubkey);

  /// The public key of the follower to follow/unfollow
  final String pubkey;
}
