// ABOUTME: Cubit for managing comment input UI state
// ABOUTME: Handles text input, reply toggling, and posting orchestration

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/comments/comments_bloc.dart';
import 'package:openvine/utils/unified_logger.dart';

part 'comment_input_state.dart';

/// Cubit for managing comment input UI state.
///
/// Manages:
/// - Main comment text input
/// - Reply text inputs (per comment ID)
/// - Active reply state (which comment is being replied to)
/// - Posting states (main and per-reply)
///
/// Works in coordination with [CommentsBloc] for posting comments.
class CommentInputCubit extends Cubit<CommentInputState> {
  CommentInputCubit({required CommentsBloc commentsBloc})
    : _commentsBloc = commentsBloc,
      super(CommentInputState.initial);

  final CommentsBloc _commentsBloc;

  /// Update main input text
  void updateMainText(String text) {
    emit(state.copyWith(mainInputText: text, clearError: true));
  }

  /// Update reply text for a specific comment
  void updateReplyText(String commentId, String text) {
    final updatedReplies = Map<String, String>.from(state.replyInputTexts);
    updatedReplies[commentId] = text;
    emit(state.copyWith(replyInputTexts: updatedReplies, clearError: true));
  }

  /// Toggle reply mode for a comment
  void toggleReply(String commentId) {
    if (state.activeReplyCommentId == commentId) {
      // Close reply
      emit(state.copyWith(clearActiveReply: true));
    } else {
      // Open reply, initialize text if needed
      final updatedReplies = Map<String, String>.from(state.replyInputTexts);
      updatedReplies.putIfAbsent(commentId, () => '');
      emit(
        state.copyWith(
          activeReplyCommentId: commentId,
          replyInputTexts: updatedReplies,
        ),
      );
    }
  }

  /// Post main comment
  Future<void> postMainComment() async {
    final text = state.mainInputText.trim();
    if (text.isEmpty) return;

    emit(state.copyWith(isMainPosting: true, clearError: true));

    try {
      _commentsBloc.add(CommentPostRequested(content: text));

      // Clear input on success
      emit(state.copyWith(mainInputText: '', isMainPosting: false));

      Log.debug(
        'CommentInputCubit: Posted main comment successfully',
        name: 'CommentInputCubit',
        category: LogCategory.ui,
      );
    } catch (e) {
      Log.error(
        'CommentInputCubit: Failed to post comment: $e',
        name: 'CommentInputCubit',
        category: LogCategory.ui,
      );
      emit(
        state.copyWith(isMainPosting: false, error: 'Failed to post comment'),
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
    emit(state.copyWith(postingReplyIds: newPostingIds, clearError: true));

    try {
      _commentsBloc.add(
        CommentPostRequested(
          content: text,
          replyToEventId: parentCommentId,
          replyToAuthorPubkey: parentAuthorPubkey,
        ),
      );

      // Clear reply input and close reply mode on success
      final updatedReplies = Map<String, String>.from(state.replyInputTexts);
      updatedReplies[parentCommentId] = '';
      final updatedPostingIds = {...state.postingReplyIds}
        ..remove(parentCommentId);

      emit(
        state.copyWith(
          replyInputTexts: updatedReplies,
          postingReplyIds: updatedPostingIds,
          clearActiveReply: true,
        ),
      );

      Log.debug(
        'CommentInputCubit: Posted reply successfully',
        name: 'CommentInputCubit',
        category: LogCategory.ui,
      );
    } catch (e) {
      Log.error(
        'CommentInputCubit: Failed to post reply: $e',
        name: 'CommentInputCubit',
        category: LogCategory.ui,
      );
      final updatedPostingIds = {...state.postingReplyIds}
        ..remove(parentCommentId);
      emit(
        state.copyWith(
          postingReplyIds: updatedPostingIds,
          error: 'Failed to post reply',
        ),
      );
    }
  }

  /// Clear any error
  void clearError() {
    emit(state.copyWith(clearError: true));
  }

  /// Reset all input state
  void reset() {
    emit(CommentInputState.initial);
  }
}
