// ABOUTME: BLoC for managing comments on videos with threaded replies
// ABOUTME: Handles loading, posting, and input state for comments

import 'package:comments_repository/comments_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/utils/unified_logger.dart';

part 'comments_event.dart';
part 'comments_state.dart';

/// BLoC for managing comments on a video.
///
/// Handles:
/// - Loading comments from Nostr relays
/// - Building hierarchical comment trees
/// - Managing input state for main comment and replies
/// - Posting new comments
class CommentsBloc extends Bloc<CommentsEvent, CommentsState> {
  CommentsBloc({
    required CommentsRepository commentsRepository,
    required AuthService authService,
    required String rootEventId,
    required int rootEventKind,
    required String rootAuthorPubkey,
  }) : _commentsRepository = commentsRepository,
       _authService = authService,
       super(
         CommentsState(
           rootEventId: rootEventId,
           rootEventKind: rootEventKind,
           rootAuthorPubkey: rootAuthorPubkey,
         ),
       ) {
    on<CommentsLoadRequested>(_onLoadRequested);
    on<CommentTextChanged>(_onTextChanged);
    on<CommentReplyToggled>(_onReplyToggled);
    on<CommentSubmitted>(_onSubmitted);
    on<CommentErrorCleared>(_onErrorCleared);
  }

  final CommentsRepository _commentsRepository;
  final AuthService _authService;

  Future<void> _onLoadRequested(
    CommentsLoadRequested event,
    Emitter<CommentsState> emit,
  ) async {
    if (state.status == CommentsStatus.loading) return;

    emit(state.copyWith(status: CommentsStatus.loading, clearError: true));

    try {
      final thread = await _commentsRepository.loadComments(
        rootEventId: state.rootEventId,
        rootEventKind: state.rootEventKind,
      );

      emit(
        state.copyWith(
          status: CommentsStatus.success,
          topLevelComments: thread.topLevelComments,
          totalCommentCount: thread.totalCount,
        ),
      );
    } catch (e) {
      Log.error(
        'Error loading comments: $e',
        name: 'CommentsBloc',
        category: LogCategory.ui,
      );
      emit(
        state.copyWith(
          status: CommentsStatus.failure,
          error: CommentsError.loadFailed,
        ),
      );
    }
  }

  void _onTextChanged(CommentTextChanged event, Emitter<CommentsState> emit) {
    if (event.commentId == null) {
      emit(state.copyWith(mainInputText: event.text, clearError: true));
    } else {
      final updatedReplies = Map<String, String>.from(state.replyInputTexts);
      updatedReplies[event.commentId!] = event.text;
      emit(state.copyWith(replyInputTexts: updatedReplies, clearError: true));
    }
  }

  void _onReplyToggled(CommentReplyToggled event, Emitter<CommentsState> emit) {
    if (state.activeReplyCommentId == event.commentId) {
      emit(state.copyWith(clearActiveReply: true));
    } else {
      final updatedReplies = Map<String, String>.from(state.replyInputTexts);
      updatedReplies.putIfAbsent(event.commentId, () => '');
      emit(
        state.copyWith(
          activeReplyCommentId: event.commentId,
          replyInputTexts: updatedReplies,
        ),
      );
    }
  }

  Future<void> _onSubmitted(
    CommentSubmitted event,
    Emitter<CommentsState> emit,
  ) async {
    final isReply = event.parentCommentId != null;
    final text = isReply
        ? state.getReplyText(event.parentCommentId!).trim()
        : state.mainInputText.trim();

    if (text.isEmpty) return;

    if (!_authService.isAuthenticated) {
      emit(state.copyWith(error: CommentsError.notAuthenticated));
      return;
    }

    emit(state.copyWith(isPosting: true, clearError: true));

    try {
      final postedComment = await _commentsRepository.postComment(
        content: text,
        rootEventId: state.rootEventId,
        rootEventKind: state.rootEventKind,
        rootEventAuthorPubkey: state.rootAuthorPubkey,
        replyToEventId: event.parentCommentId,
        replyToAuthorPubkey: event.parentAuthorPubkey,
      );

      final updatedComments = _addCommentToTree(
        state.topLevelComments,
        postedComment,
        event.parentCommentId,
      );

      if (isReply) {
        final updatedReplies = Map<String, String>.from(state.replyInputTexts);
        updatedReplies[event.parentCommentId!] = '';
        emit(
          state.copyWith(
            topLevelComments: updatedComments,
            totalCommentCount: state.totalCommentCount + 1,
            replyInputTexts: updatedReplies,
            isPosting: false,
            clearActiveReply: true,
          ),
        );
      } else {
        emit(
          state.copyWith(
            topLevelComments: updatedComments,
            totalCommentCount: state.totalCommentCount + 1,
            mainInputText: '',
            isPosting: false,
          ),
        );
      }
    } catch (e) {
      Log.error(
        'Error posting comment: $e',
        name: 'CommentsBloc',
        category: LogCategory.ui,
      );

      emit(
        state.copyWith(
          isPosting: false,
          error: isReply
              ? CommentsError.postReplyFailed
              : CommentsError.postCommentFailed,
        ),
      );
    }
  }

  void _onErrorCleared(CommentErrorCleared event, Emitter<CommentsState> emit) {
    emit(state.copyWith(clearError: true));
  }

  /// Adds comment to tree. Top-level comments go first (newest first order).
  List<CommentNode> _addCommentToTree(
    List<CommentNode> nodes,
    Comment comment,
    String? replyToEventId,
  ) {
    if (replyToEventId == null) {
      return [CommentNode(comment: comment), ...nodes];
    }

    return nodes.map((node) {
      if (node.comment.id == replyToEventId) {
        return node.copyWith(
          replies: [
            ...node.replies,
            CommentNode(comment: comment),
          ],
        );
      } else if (node.replies.isNotEmpty) {
        return node.copyWith(
          replies: _addCommentToTree(node.replies, comment, replyToEventId),
        );
      }
      return node;
    }).toList();
  }
}
