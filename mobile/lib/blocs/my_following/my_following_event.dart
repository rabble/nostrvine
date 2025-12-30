// ABOUTME: Events for MyFollowingBloc
// ABOUTME: Defines actions for loading and follow/unfollow operations

part of 'my_following_bloc.dart';

/// Base class for all my following list events
sealed class MyFollowingEvent {
  const MyFollowingEvent();
}

/// Request to start listening to following list updates.
final class MyFollowingListLoadRequested extends MyFollowingEvent {
  const MyFollowingListLoadRequested();
}

/// Request to toggle follow status for a user.
/// The bloc will determine whether to follow or unfollow based on current state.
final class MyFollowingToggleRequested extends MyFollowingEvent {
  const MyFollowingToggleRequested(this.pubkey);

  /// The public key of the user to follow/unfollow
  final String pubkey;
}
