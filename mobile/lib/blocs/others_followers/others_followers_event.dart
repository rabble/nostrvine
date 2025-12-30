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

/// Request to toggle follow status for a follower.
final class OthersFollowersToggleFollowRequested extends OthersFollowersEvent {
  const OthersFollowersToggleFollowRequested(this.pubkey);

  /// The public key of the follower to follow/unfollow
  final String pubkey;
}
