// ABOUTME: Events for VideoInteractionsBloc
// ABOUTME: Handles like toggle, count fetching for a single video

part of 'video_interactions_bloc.dart';

/// Base class for video interactions events.
sealed class VideoInteractionsEvent extends Equatable {
  const VideoInteractionsEvent();

  @override
  List<Object?> get props => [];
}

/// Request to fetch initial state (like status and counts).
///
/// Dispatched when the video feed item becomes visible/active.
class VideoInteractionsFetchRequested extends VideoInteractionsEvent {
  const VideoInteractionsFetchRequested();
}

/// Request to toggle like status.
///
/// Will like if not liked, unlike if already liked.
class VideoInteractionsLikeToggled extends VideoInteractionsEvent {
  const VideoInteractionsLikeToggled();
}

/// Notification that the global liked status changed.
///
/// Used to sync state when liked status changes from elsewhere
/// (e.g., liked from another screen or synced from relay).
class VideoInteractionsLikeStatusChanged extends VideoInteractionsEvent {
  const VideoInteractionsLikeStatusChanged({required this.isLiked});

  final bool isLiked;

  @override
  List<Object?> get props => [isLiked];
}
