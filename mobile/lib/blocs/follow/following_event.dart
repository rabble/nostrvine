// ABOUTME: Events for the FollowingBloc
// ABOUTME: Defines actions for loading, refreshing, and follow/unfollow operations

part of 'following_bloc.dart';

/// Base class for all following list events
sealed class FollowingEvent {
  const FollowingEvent();
}

/// Request to load the following list for a specific user
final class FollowingListLoadRequested extends FollowingEvent {
  const FollowingListLoadRequested(this.pubkey);

  /// The public key of the user whose following list to load
  final String pubkey;
}

/// Request to refresh the following list
final class FollowingListRefreshRequested extends FollowingEvent {
  const FollowingListRefreshRequested(this.pubkey);

  /// The public key of the user whose following list to refresh
  final String pubkey;
}

/// Request to follow a user
final class FollowRequested extends FollowingEvent {
  const FollowRequested(this.pubkey);

  /// The public key of the user to follow
  final String pubkey;
}

/// Request to unfollow a user
final class UnfollowRequested extends FollowingEvent {
  const UnfollowRequested(this.pubkey);

  /// The public key of the user to unfollow
  final String pubkey;
}
