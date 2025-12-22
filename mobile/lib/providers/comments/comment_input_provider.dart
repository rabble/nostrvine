// ABOUTME: Riverpod provider for managing comment input UI state
// ABOUTME: Handles text input, reply toggling, and posting orchestration

import 'package:openvine/providers/comments/comments_provider.dart';
import 'package:openvine/state/comment_input_state.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'comment_input_provider.g.dart';

/// Provider for managing comment input state for a specific video
///
/// Parameterized by (rootEventId, rootAuthorPubkey) to match CommentsNotifier.
/// Manages:
/// - Main comment text input
/// - Reply text inputs (per comment ID)
/// - Active reply state (which comment is being replied to)
/// - Posting states (main and per-reply)
///
/// Usage:
/// ```dart
/// // Watch input state
/// final inputState = ref.watch(commentInputProvider(videoId, authorPubkey));
///
/// // Update main text
/// ref.read(commentInputProvider(videoId, authorPubkey).notifier)
///     .updateMainText(newText);
///
/// // Post comment
/// await ref.read(commentInputProvider(videoId, authorPubkey).notifier)
///     .postMainComment();
/// ```
@riverpod
class CommentInputNotifier extends _$CommentInputNotifier {
  late String _rootEventId;
  late String _rootAuthorPubkey;

  @override
  CommentInputState build(String rootEventId, String rootAuthorPubkey) {
    _rootEventId = rootEventId;
    _rootAuthorPubkey = rootAuthorPubkey;
    return CommentInputState.initial;
  }

  /// Update main input text
  void updateMainText(String text) {
    state = state.copyWith(mainInputText: text, error: null);
  }

  /// Update reply text for a specific comment
  void updateReplyText(String commentId, String text) {
    final updatedReplies = Map<String, String>.from(state.replyInputTexts);
    updatedReplies[commentId] = text;
    state = state.copyWith(replyInputTexts: updatedReplies, error: null);
  }

  /// Toggle reply mode for a comment
  void toggleReply(String commentId) {
    if (state.activeReplyCommentId == commentId) {
      // Close reply
      state = state.copyWith(activeReplyCommentId: null);
    } else {
      // Open reply, initialize text if needed
      final updatedReplies = Map<String, String>.from(state.replyInputTexts);
      updatedReplies.putIfAbsent(commentId, () => '');
      state = state.copyWith(
        activeReplyCommentId: commentId,
        replyInputTexts: updatedReplies,
      );
    }
  }

  /// Post main comment
  Future<void> postMainComment() async {
    final text = state.mainInputText.trim();
    if (text.isEmpty) return;

    state = state.copyWith(isMainPosting: true, error: null);

    try {
      final commentsNotifier = ref.read(
        commentsProvider(_rootEventId, _rootAuthorPubkey).notifier,
      );

      await commentsNotifier.postComment(content: text);

      // Check if still mounted after async operation
      if (!ref.exists(commentInputProvider(_rootEventId, _rootAuthorPubkey))) {
        return;
      }

      // Clear input on success
      state = state.copyWith(mainInputText: '', isMainPosting: false);

      Log.debug(
        'CommentInputNotifier: Posted main comment successfully',
        name: 'CommentInputNotifier',
        category: LogCategory.ui,
      );
    } catch (e) {
      Log.error(
        'CommentInputNotifier: Failed to post comment: $e',
        name: 'CommentInputNotifier',
        category: LogCategory.ui,
      );
      state = state.copyWith(
        isMainPosting: false,
        error: 'Failed to post comment',
      );
    }
  }

  /// Post reply to a specific comment
  Future<void> postReply(
    String parentCommentId,
    String? parentAuthorPubkey,
  ) async {
    final text = state.getReplyText(parentCommentId).trim();
    if (text.isEmpty) return;

    // Add to posting set
    final newPostingIds = {...state.postingReplyIds, parentCommentId};
    state = state.copyWith(postingReplyIds: newPostingIds, error: null);

    try {
      final commentsNotifier = ref.read(
        commentsProvider(_rootEventId, _rootAuthorPubkey).notifier,
      );

      await commentsNotifier.postComment(
        content: text,
        replyToEventId: parentCommentId,
        replyToAuthorPubkey: parentAuthorPubkey,
      );

      // Check if still mounted after async operation
      if (!ref.exists(commentInputProvider(_rootEventId, _rootAuthorPubkey))) {
        return;
      }

      // Clear reply input and close reply mode on success
      final updatedReplies = Map<String, String>.from(state.replyInputTexts);
      updatedReplies[parentCommentId] = '';
      final updatedPostingIds = {...state.postingReplyIds}
        ..remove(parentCommentId);

      state = state.copyWith(
        replyInputTexts: updatedReplies,
        postingReplyIds: updatedPostingIds,
        activeReplyCommentId: null, // Close reply input
      );

      Log.debug(
        'CommentInputNotifier: Posted reply successfully',
        name: 'CommentInputNotifier',
        category: LogCategory.ui,
      );
    } catch (e) {
      Log.error(
        'CommentInputNotifier: Failed to post reply: $e',
        name: 'CommentInputNotifier',
        category: LogCategory.ui,
      );
      final updatedPostingIds = {...state.postingReplyIds}
        ..remove(parentCommentId);
      state = state.copyWith(
        postingReplyIds: updatedPostingIds,
        error: 'Failed to post reply',
      );
    }
  }

  /// Clear any error
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Reset all input state
  void reset() {
    state = CommentInputState.initial;
  }
}
