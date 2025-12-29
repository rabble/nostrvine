// ABOUTME: Events for the FollowingBloc
// ABOUTME: Defines actions for loading and follow/unfollow operations

part of 'following_bloc.dart';

/// Base class for all following list events
sealed class FollowingEvent {
  const FollowingEvent();
}

/// Request to load (or refresh) the following list.
final class FollowingListLoadRequested extends FollowingEvent {
  const FollowingListLoadRequested();
}

/// Request to toggle follow status for a user.
/// The bloc will determine whether to follow or unfollow based on current state.
final class FollowToggleRequested extends FollowingEvent {
  const FollowToggleRequested(this.pubkey);

  /// The public key of the user to follow/unfollow
  final String pubkey;
}
