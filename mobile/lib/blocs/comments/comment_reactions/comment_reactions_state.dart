part of 'comment_reactions_bloc.dart';

/// l10n-friendly reactions-side errors.
///
/// The UI maps these to localized strings via [BlocListener].
enum ReactionsError {
  /// User must sign in to vote / report / block / delete.
  notAuthenticated,

  /// Failed to toggle vote on a comment.
  voteFailed,

  /// Failed to toggle an emoji reaction on a comment.
  reactionFailed,

  /// Failed to report a comment.
  reportFailed,

  /// Failed to block a user.
  blockFailed,

  /// Failed to delete a comment.
  deleteCommentFailed,
}

/// One-shot signal from [CommentReactionsBloc] to UI: dispatch the
/// corresponding event onto [CommentsListBloc] then ack via
/// [ReactionsOutboxConsumed].
sealed class ReactionsOutbox extends Equatable {
  const ReactionsOutbox();

  @override
  bool? get stringify => true;
}

/// Remove a single comment from the canonical store (post-delete cleanup).
final class ReactionsOutboxRemoveComment extends ReactionsOutbox {
  const ReactionsOutboxRemoveComment(this.commentId);

  final String commentId;

  @override
  List<Object?> get props => [commentId];
}

/// Remove every comment authored by [authorPubkey] (post-block cleanup).
final class ReactionsOutboxRemoveByAuthor extends ReactionsOutbox {
  const ReactionsOutboxRemoveByAuthor(this.authorPubkey);

  final String authorPubkey;

  @override
  List<Object?> get props => [authorPubkey];
}

/// State for [CommentReactionsBloc].
final class CommentReactionsState extends Equatable {
  const CommentReactionsState({
    this.commentUpvoteCounts = const {},
    this.commentDownvoteCounts = const {},
    this.upvotedCommentIds = const {},
    this.downvotedCommentIds = const {},
    this.commentEmojiReactionCounts = const {},
    this.ownReactionEmojiByCommentId = const {},
    this.pendingReactionCommentIds = const {},
    this.error,
    this.outbox,
  });

  /// Upvote counts per comment ID.
  final Map<String, int> commentUpvoteCounts;

  /// Downvote counts per comment ID.
  final Map<String, int> commentDownvoteCounts;

  /// Set of comment IDs the current user has upvoted.
  final Set<String> upvotedCommentIds;

  /// Set of comment IDs the current user has downvoted.
  final Set<String> downvotedCommentIds;

  /// Emoji reaction counts per comment ID (`comment id -> emoji -> count`).
  ///
  /// Inner maps are replaced wholesale per comment (never mutated), so
  /// selectors can rely on identity to skip rebuilds of untouched rows.
  final Map<String, Map<String, int>> commentEmojiReactionCounts;

  /// The current user's own emoji reaction per comment ID (cap-at-one).
  ///
  /// Absent key = no own reaction on that comment.
  final Map<String, String> ownReactionEmojiByCommentId;

  /// Comment IDs with an emoji reaction publish currently in flight.
  ///
  /// A second toggle on a pending comment is suppressed so kind-7/kind-5
  /// publishes for the cap-at-one supersede flow cannot interleave, while
  /// toggles on other comments proceed independently. Fetch merges keep a
  /// pending comment's optimistic values: the fetch sampled the relay
  /// before the in-flight publish landed.
  final Set<String> pendingReactionCommentIds;

  /// Error type for l10n-friendly error handling.
  final ReactionsError? error;

  /// One-shot signal for the UI to bridge into [CommentsListBloc].
  final ReactionsOutbox? outbox;

  CommentReactionsState copyWith({
    Map<String, int>? commentUpvoteCounts,
    Map<String, int>? commentDownvoteCounts,
    Set<String>? upvotedCommentIds,
    Set<String>? downvotedCommentIds,
    Map<String, Map<String, int>>? commentEmojiReactionCounts,
    Map<String, String>? ownReactionEmojiByCommentId,
    Set<String>? pendingReactionCommentIds,
    ReactionsError? error,
    ReactionsOutbox? outbox,
    bool clearError = false,
    bool clearOutbox = false,
  }) {
    return CommentReactionsState(
      commentUpvoteCounts: commentUpvoteCounts ?? this.commentUpvoteCounts,
      commentDownvoteCounts:
          commentDownvoteCounts ?? this.commentDownvoteCounts,
      upvotedCommentIds: upvotedCommentIds ?? this.upvotedCommentIds,
      downvotedCommentIds: downvotedCommentIds ?? this.downvotedCommentIds,
      commentEmojiReactionCounts:
          commentEmojiReactionCounts ?? this.commentEmojiReactionCounts,
      ownReactionEmojiByCommentId:
          ownReactionEmojiByCommentId ?? this.ownReactionEmojiByCommentId,
      pendingReactionCommentIds:
          pendingReactionCommentIds ?? this.pendingReactionCommentIds,
      error: clearError ? null : (error ?? this.error),
      outbox: clearOutbox ? null : (outbox ?? this.outbox),
    );
  }

  @override
  List<Object?> get props => [
    commentUpvoteCounts,
    commentDownvoteCounts,
    upvotedCommentIds,
    downvotedCommentIds,
    commentEmojiReactionCounts,
    ownReactionEmojiByCommentId,
    pendingReactionCommentIds,
    error,
    outbox,
  ];
}
