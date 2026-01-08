// ABOUTME: Events for OthersFollowersBloc
// ABOUTME: Defines actions for loading and follow operations

part of 'others_followers_bloc.dart';

/// Base class for all others followers list events
sealed class OthersFollowersEvent {
  const OthersFollowersEvent();
}

/// Request to load another user's followers list.
final class OthersFollowersListLoadRequested extends OthersFollowersEvent {
  const OthersFollowersListLoadRequested(this.targetPubkey);

  /// The public key of the user whose followers list to load
  final String targetPubkey;
}

/// Optimistically increment follower count when current user follows.
final class OthersFollowersIncrementRequested extends OthersFollowersEvent {
  const OthersFollowersIncrementRequested(this.followerPubkey);

  /// The public key of the new follower (current user)
  final String followerPubkey;
}

/// Optimistically decrement follower count when current user unfollows.
final class OthersFollowersDecrementRequested extends OthersFollowersEvent {
  const OthersFollowersDecrementRequested(this.followerPubkey);

  /// The public key of the follower to remove (current user)
  final String followerPubkey;
}
