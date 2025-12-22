// ABOUTME: Freezed state model for comment input UI
// ABOUTME: Manages text input, reply mode, and posting status for CommentsScreen

import 'package:freezed_annotation/freezed_annotation.dart';

part 'comment_input_state.freezed.dart';

/// State model for comment input UI
///
/// Tracks the current text content for main comment and replies,
/// which comment is being replied to, and posting operation states.
@freezed
sealed class CommentInputState with _$CommentInputState {
  const factory CommentInputState({
    /// Text content of the main comment input
    @Default('') String mainInputText,

    /// Map of comment ID -> reply text for each active reply
    @Default({}) Map<String, String> replyInputTexts,

    /// ID of the comment currently being replied to (shows reply input)
    String? activeReplyCommentId,

    /// Whether the main comment is currently being posted
    @Default(false) bool isMainPosting,

    /// Set of comment IDs with replies currently being posted
    @Default({}) Set<String> postingReplyIds,

    /// Last error that occurred, cleared on next action
    String? error,
  }) = _CommentInputState;

  const CommentInputState._();

  /// Initial state
  static const CommentInputState initial = CommentInputState();

  /// Check if a specific reply is being posted
  bool isReplyPosting(String commentId) => postingReplyIds.contains(commentId);

  /// Check if any posting operation is in progress
  bool get isAnyPosting => isMainPosting || postingReplyIds.isNotEmpty;

  /// Get the reply text for a specific comment
  String getReplyText(String commentId) => replyInputTexts[commentId] ?? '';
}
