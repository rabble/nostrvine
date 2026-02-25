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

/// Request to toggle repost status.
///
/// Will repost if not reposted, unrepost if already reposted.
class VideoInteractionsRepostToggled extends VideoInteractionsEvent {
  const VideoInteractionsRepostToggled();
}

/// Request to start listening for liked IDs changes from the repository.
///
/// This should be dispatched once when the video feed item is initialized.
/// Uses emit.forEach internally to reactively update state when likes change.
class VideoInteractionsSubscriptionRequested extends VideoInteractionsEvent {
  const VideoInteractionsSubscriptionRequested();
}

/// Updates the comment count from an authoritative source.
///
/// Dispatched when the comments sheet is dismissed, carrying the actual
/// loaded comment count from [CommentsBloc] so the feed sidebar stays
/// in sync without an extra relay round-trip.
class VideoInteractionsCommentCountUpdated extends VideoInteractionsEvent {
  const VideoInteractionsCommentCountUpdated(this.commentCount);

  /// The updated total comment count.
  final int commentCount;

  @override
  List<Object?> get props => [commentCount];
}
