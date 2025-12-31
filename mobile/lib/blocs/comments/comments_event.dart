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

/// Update text for main input or a reply
///
/// If [commentId] is null, updates the main input text.
/// If [commentId] is provided, updates the reply text for that comment.
final class CommentTextChanged extends CommentsEvent {
  const CommentTextChanged(this.text, {this.commentId});

  /// The new text content
  final String text;

  /// Comment ID if this is a reply, null for main input
  final String? commentId;
}

/// Toggle reply mode for a comment (show/hide reply input)
final class CommentReplyToggled extends CommentsEvent {
  const CommentReplyToggled(this.commentId);

  final String commentId;
}

/// Submit a comment (main or reply)
///
/// If [parentCommentId] is null, submits a new top-level comment.
/// If [parentCommentId] is provided, submits a reply to that comment.
final class CommentSubmitted extends CommentsEvent {
  const CommentSubmitted({this.parentCommentId, this.parentAuthorPubkey});

  /// Parent comment ID if this is a reply, null for top-level comment
  final String? parentCommentId;

  /// Parent comment author's pubkey (for Nostr threading)
  final String? parentAuthorPubkey;
}

/// Clear any error message
final class CommentErrorCleared extends CommentsEvent {
  const CommentErrorCleared();
}

/// Request to delete a comment
final class CommentDeleteRequested extends CommentsEvent {
  const CommentDeleteRequested(this.commentId);

  /// The ID of the comment to delete
  final String commentId;
}
