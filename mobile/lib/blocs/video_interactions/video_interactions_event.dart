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

/// Request to start listening for liked IDs changes from the repository.
///
/// This should be dispatched once when the video feed item is initialized.
/// Uses emit.forEach internally to reactively update state when likes change.
class VideoInteractionsSubscriptionRequested extends VideoInteractionsEvent {
  const VideoInteractionsSubscriptionRequested();
}
