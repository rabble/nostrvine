part of 'comment_composer_bloc.dart';

/// Base class for all composer events.
sealed class CommentComposerEvent {
  const CommentComposerEvent();
}

/// Update text for main input or a reply.
///
/// If [commentId] is null, updates the main input text.
/// If [commentId] is provided, updates the reply text for that comment.
final class CommentTextChanged extends CommentComposerEvent {
  const CommentTextChanged(this.text, {this.commentId});

  /// The new text content.
  final String text;

  /// Comment ID if this is a reply, null for main input.
  final String? commentId;
}

/// Toggle reply mode for a comment (show/hide reply input).
final class CommentReplyToggled extends CommentComposerEvent {
  const CommentReplyToggled(this.commentId);

  final String commentId;
}

/// Submit a comment (main or reply).
///
/// If [parentCommentId] is null, submits a new top-level comment.
/// If [parentCommentId] is provided, submits a reply to that comment.
final class CommentSubmitted extends CommentComposerEvent {
  const CommentSubmitted({this.parentCommentId, this.parentAuthorPubkey});

  /// Parent comment ID if this is a reply, null for top-level comment.
  final String? parentCommentId;

  /// Parent comment author's pubkey (for Nostr threading).
  final String? parentAuthorPubkey;
}

/// Clear any error message.
final class CommentComposerErrorCleared extends CommentComposerEvent {
  const CommentComposerErrorCleared();
}

/// Enter edit mode for a comment (pre-populates input).
///
/// Carries the original threading info ([originalReplyToEventId] /
/// [originalReplyToAuthorPubkey]) so the edit submit can preserve them
/// without re-reading the canonical store from [CommentsListBloc].
final class CommentEditModeEntered extends CommentComposerEvent {
  const CommentEditModeEntered({
    required this.commentId,
    required this.originalContent,
    required this.originalComment,
    this.originalReplyToEventId,
    this.originalReplyToAuthorPubkey,
  });

  /// The ID of the comment being edited.
  final String commentId;

  /// The original content to pre-populate in the input.
  final String originalContent;

  /// Snapshot of the original canonical comment for rollback-repost if the
  /// delete half of an edit succeeds but the replacement publish fails.
  final Comment originalComment;

  /// Original `replyToEventId` from the comment being edited (preserves
  /// threading for the re-post that replaces it).
  final String? originalReplyToEventId;

  /// Original `replyToAuthorPubkey` from the comment being edited.
  final String? originalReplyToAuthorPubkey;
}

/// Cancel edit mode.
final class CommentEditModeCancelled extends CommentComposerEvent {
  const CommentEditModeCancelled();
}

/// Submit edited comment (delete old + post new).
final class CommentEditSubmitted extends CommentComposerEvent {
  const CommentEditSubmitted();
}

/// Search for mention suggestions based on a query string.
final class MentionSearchRequested extends CommentComposerEvent {
  const MentionSearchRequested(this.query);

  /// The partial query after '@'.
  final String query;
}

/// Register a mention mapping (displayName -> full hex pubkey) for resolution
/// on submit.
final class MentionRegistered extends CommentComposerEvent {
  const MentionRegistered({
    required this.displayName,
    required this.pubkey,
    this.start,
    this.end,
  });

  /// The display name shown in the text field (e.g. "Alice").
  final String displayName;

  /// The full hex pubkey to resolve on submit.
  final String pubkey;

  /// Start offset of the selected visible mention token in the current input.
  final int? start;

  /// Exclusive end offset of the selected visible mention token.
  final int? end;
}

/// Clear mention suggestions (when @ is removed or input dismissed).
final class MentionSuggestionsCleared extends CommentComposerEvent {
  const MentionSuggestionsCleared();
}

/// Acknowledge that the UI has bridged the current [ComposerOutbox] item to
/// [CommentsListBloc]. Clears [CommentComposerState.outbox] back to null.
final class ComposerOutboxConsumed extends CommentComposerEvent {
  const ComposerOutboxConsumed();
}
