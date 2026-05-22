part of 'comment_reactions_bloc.dart';

/// Base class for all reactions events.
sealed class CommentReactionsEvent {
  const CommentReactionsEvent();
}

/// Clear any error message.
final class CommentReactionsErrorCleared extends CommentReactionsEvent {
  const CommentReactionsErrorCleared();
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
/// A single event for both upvotes and downvotes so that one `droppable()`
/// handler serializes all votes — same-comment rapid up→down (or down→up)
/// within publish-RTT can no longer run two handlers concurrently and produce
/// interleaved kind-7 / kind-5 publishes on the relay.
final class CommentVoteToggled extends CommentReactionsEvent {
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

/// Request to batch-fetch vote counts for a set of comments.
///
/// Dispatched by the UI (via a [BlocListener] on [CommentsListBloc]) whenever
/// the loaded-comment set changes so the reactions cubit can populate counts
/// for the visible list.
final class CommentVoteCountsFetchRequested extends CommentReactionsEvent {
  const CommentVoteCountsFetchRequested(this.commentIds);

  /// The set of comment IDs to fetch vote counts for.
  final List<String> commentIds;
}

/// Report a comment (publishes Kind 1984 / NIP-56).
final class CommentReportRequested extends CommentReactionsEvent {
  const CommentReportRequested({
    required this.commentId,
    required this.authorPubkey,
    required this.reason,
    this.details = '',
  });

  /// The ID of the comment to report.
  final String commentId;

  /// The pubkey of the comment author.
  final String authorPubkey;

  /// The reason for the report.
  final ContentFilterReason reason;

  /// Optional additional details.
  final String details;
}

/// Block a user from comments (updates Kind 10000 mute list / NIP-51).
///
/// After the persist + relay broadcast succeeds, the reactions bloc emits a
/// [ReactionsOutboxRemoveByAuthor] signal that the UI bridges to
/// [CommentsListBloc] for store cleanup.
final class CommentBlockUserRequested extends CommentReactionsEvent {
  const CommentBlockUserRequested(this.authorPubkey);

  /// The pubkey of the user to block.
  final String authorPubkey;
}

/// Request to delete a comment.
///
/// After the relay broadcast succeeds, the reactions bloc emits a
/// [ReactionsOutboxRemoveComment] signal that the UI bridges to
/// [CommentsListBloc] for store cleanup.
final class CommentDeleteRequested extends CommentReactionsEvent {
  const CommentDeleteRequested(this.commentId);

  /// The ID of the comment to delete.
  final String commentId;
}

/// Acknowledge that the UI has bridged the current [ReactionsOutbox] item to
/// [CommentsListBloc]. Clears [CommentReactionsState.outbox] back to null.
final class ReactionsOutboxConsumed extends CommentReactionsEvent {
  const ReactionsOutboxConsumed();
}
