// ABOUTME: Events for the LikesBloc
// ABOUTME: Defines actions for syncing likes, toggling like status, and errors

part of 'likes_bloc.dart';

/// Base class for all likes events
sealed class LikesEvent {
  const LikesEvent();
}

/// Request to sync likes from relays and local storage
final class LikesSyncRequested extends LikesEvent {
  const LikesSyncRequested();
}

/// Toggle like status for an event (like or unlike)
final class LikesToggleRequested extends LikesEvent {
  const LikesToggleRequested({
    required this.eventId,
    required this.authorPubkey,
  });

  /// The event ID to like/unlike
  final String eventId;

  /// The author's pubkey of the event
  final String authorPubkey;
}

/// Clear any error message
final class LikesErrorCleared extends LikesEvent {
  const LikesErrorCleared();
}
