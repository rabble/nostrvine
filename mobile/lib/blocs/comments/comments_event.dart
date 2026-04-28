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

/// Request to load more (older) comments for pagination
final class CommentsLoadMoreRequested extends CommentsEvent {
  const CommentsLoadMoreRequested();
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

/// Enter edit mode for a comment (pre-populates input)
final class CommentEditModeEntered extends CommentsEvent {
  const CommentEditModeEntered({
    required this.commentId,
    required this.originalContent,
  });

  /// The ID of the comment being edited
  final String commentId;

  /// The original content to pre-populate in the input
  final String originalContent;
}

/// Cancel edit mode
final class CommentEditModeCancelled extends CommentsEvent {
  const CommentEditModeCancelled();
}

/// Submit edited comment (delete old + post new).
///
/// Uses [CommentsState.activeEditCommentId] to identify the comment being
/// edited, so no parameters are needed.
final class CommentEditSubmitted extends CommentsEvent {
  const CommentEditSubmitted();
}

/// Direction of a comment vote.
enum Vote {
  /// Upvote (kind-7 reaction with content "+").
  up,

  /// Downvote (kind-7 reaction with content "-").
  down,
}

/// Toggle a vote on a comment (optimistic update + relay publish).
///
/// A single event for both upvotes and downvotes so that one
/// `droppable()` handler serializes all votes — same-comment rapid
/// up→down (or down→up) within publish-RTT can no longer run two
/// handlers concurrently and produce interleaved kind-7 / kind-5
/// publishes on the relay.
final class CommentVoteToggled extends CommentsEvent {
  const CommentVoteToggled({
    required this.commentId,
    required this.authorPubkey,
    required this.vote,
  });

  /// The ID of the comment being voted on.
  final String commentId;

  /// The pubkey of the comment author.
  final String authorPubkey;

  /// Whether this is an upvote or a downvote tap.
  final Vote vote;
}

/// Request to batch-fetch vote counts for all loaded comments
final class CommentVoteCountsFetchRequested extends CommentsEvent {
  const CommentVoteCountsFetchRequested();
}

/// Change the sort order for comments
final class CommentsSortModeChanged extends CommentsEvent {
  const CommentsSortModeChanged(this.sortMode);

  final CommentsSortMode sortMode;
}

/// Report a comment (publishes Kind 1984 / NIP-56)
final class CommentReportRequested extends CommentsEvent {
  const CommentReportRequested({
    required this.commentId,
    required this.authorPubkey,
    required this.reason,
    this.details = '',
  });

  /// The ID of the comment to report
  final String commentId;

  /// The pubkey of the comment author
  final String authorPubkey;

  /// The reason for the report
  final ContentFilterReason reason;

  /// Optional additional details
  final String details;
}

/// Block a user from comments (updates Kind 10000 mute list / NIP-51)
final class CommentBlockUserRequested extends CommentsEvent {
  const CommentBlockUserRequested(this.authorPubkey);

  /// The pubkey of the user to block
  final String authorPubkey;
}

/// Search for mention suggestions based on a query string
final class MentionSearchRequested extends CommentsEvent {
  const MentionSearchRequested(this.query);

  /// The partial query after '@'
  final String query;
}

/// Register a mention mapping (displayName -> npub) for conversion on submit
final class MentionRegistered extends CommentsEvent {
  const MentionRegistered({required this.displayName, required this.npub});

  /// The display name shown in the text field (e.g. "Alice")
  final String displayName;

  /// The npub to convert to on submit (e.g. "npub1abc...")
  final String npub;
}

/// Clear mention suggestions (when @ is removed or input dismissed)
final class MentionSuggestionsCleared extends CommentsEvent {
  const MentionSuggestionsCleared();
}

/// A new comment was received from the real-time subscription
final class NewCommentReceived extends CommentsEvent {
  const NewCommentReceived(this.comment);

  /// The new comment received from the stream
  final Comment comment;
}

/// The initial relay backfill reached EOSE; subsequent events are live.
final class CommentsInitialBackfillCompleted extends CommentsEvent {
  const CommentsInitialBackfillCompleted();
}

/// User acknowledged the new comments (e.g., tapped the pill or scrolled to top)
final class NewCommentsAcknowledged extends CommentsEvent {
  const NewCommentsAcknowledged();
}
