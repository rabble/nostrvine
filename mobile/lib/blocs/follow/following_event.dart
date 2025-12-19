// ABOUTME: Events for the FollowingBloc
// ABOUTME: Defines actions for loading and refreshing the following list

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
