// ABOUTME: Events for OthersFollowingBloc
// ABOUTME: Defines action to load another user's following list

part of 'others_following_bloc.dart';

/// Base class for all others following list events
sealed class OthersFollowingEvent {
  const OthersFollowingEvent();
}

/// Request to load another user's following list.
final class OthersFollowingListLoadRequested extends OthersFollowingEvent {
  const OthersFollowingListLoadRequested(this.targetPubkey);

  /// The public key of the user whose following list to load
  final String targetPubkey;
}
