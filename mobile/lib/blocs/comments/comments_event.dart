// ABOUTME: Events for the CommentsBloc
// ABOUTME: Defines actions for loading comments, posting, and UI interactions

part of 'comments_bloc.dart';

/// Base class for all comments events
sealed class CommentsEvent {
  const CommentsEvent();
}

/// Request to load (or refresh) comments for a video
final class CommentsLoadRequested extends CommentsEvent {
  const CommentsLoadRequested();
}

/// Request to post a new comment
final class CommentPostRequested extends CommentsEvent {
  const CommentPostRequested({
    required this.content,
    this.replyToEventId,
    this.replyToAuthorPubkey,
  });

  /// The comment text content
  final String content;

  /// If replying to another comment, its event ID
  final String? replyToEventId;

  /// If replying to another comment, its author pubkey
  final String? replyToAuthorPubkey;
}

/// Request to toggle expansion state of a comment thread
final class CommentExpansionToggled extends CommentsEvent {
  const CommentExpansionToggled(this.commentId);

  /// The comment ID to toggle expansion for
  final String commentId;
}

/// Internal event when a new comment arrives from the stream
final class _CommentReceived extends CommentsEvent {
  const _CommentReceived(this.comment);

  final Comment comment;
}

/// Internal event when comment stream completes or times out
final class _CommentsStreamCompleted extends CommentsEvent {
  const _CommentsStreamCompleted();
}

/// Internal event when comment stream errors
final class _CommentsStreamError extends CommentsEvent {
  const _CommentsStreamError(this.error);

  final Object error;
}
