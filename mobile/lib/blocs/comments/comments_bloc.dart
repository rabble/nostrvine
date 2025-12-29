// ABOUTME: BLoC for managing comments on videos with threaded replies
// ABOUTME: Handles loading, posting, and input state for comments

import 'package:comments_repository/comments_repository.dart' as repo;
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/utils/unified_logger.dart';

part 'comments_event.dart';
part 'comments_state.dart';

/// BLoC for managing comments on a video.
///
/// Handles:
/// - Loading comments from Nostr relays via CommentsRepository
/// - Building hierarchical comment trees
/// - Managing input state for main comment and replies
/// - Posting new comments with optimistic updates
class CommentsBloc extends Bloc<CommentsEvent, CommentsState> {
  CommentsBloc({
    required repo.CommentsRepository commentsRepository,
    required AuthService authService,
    required String rootEventId,
    required String rootAuthorPubkey,
  }) : _commentsRepository = commentsRepository,
       _authService = authService,
       super(
         CommentsState(
           rootEventId: rootEventId,
           rootAuthorPubkey: rootAuthorPubkey,
         ),
       ) {
    on<CommentsLoadRequested>(_onLoadRequested);
    on<CommentTextChanged>(_onTextChanged);
    on<CommentReplyToggled>(_onReplyToggled);
    on<CommentSubmitted>(_onSubmitted);
    on<CommentErrorCleared>(_onErrorCleared);
  }

  final repo.CommentsRepository _commentsRepository;
  final AuthService _authService;

  /// Handle request to load comments
  Future<void> _onLoadRequested(
    CommentsLoadRequested event,
    Emitter<CommentsState> emit,
  ) async {
    if (state.status == CommentsStatus.loading) return;

    emit(state.copyWith(status: CommentsStatus.loading, clearError: true));

    try {
      final thread = await _commentsRepository.loadComments(
        rootEventId: state.rootEventId,
      );

      final topLevelComments = _convertNodes(thread.topLevelComments);

      emit(
        state.copyWith(
          status: CommentsStatus.success,
          topLevelComments: topLevelComments,
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
          error: 'Failed to load comments',
        ),
      );
    }
  }

  /// Handle text change for main input or reply
  void _onTextChanged(CommentTextChanged event, Emitter<CommentsState> emit) {
    if (event.commentId == null) {
      // Main input
      emit(state.copyWith(mainInputText: event.text, clearError: true));
    } else {
      // Reply input
      final updatedReplies = Map<String, String>.from(state.replyInputTexts);
      updatedReplies[event.commentId!] = event.text;
      emit(state.copyWith(replyInputTexts: updatedReplies, clearError: true));
    }
  }

  /// Handle reply toggle
  void _onReplyToggled(CommentReplyToggled event, Emitter<CommentsState> emit) {
    if (state.activeReplyCommentId == event.commentId) {
      // Close reply
      emit(state.copyWith(clearActiveReply: true));
    } else {
      // Open reply, initialize text if needed
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

  /// Handle comment submission (main or reply)
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
      emit(state.copyWith(error: 'Please sign in to comment'));
      return;
    }

    emit(state.copyWith(isPosting: true, clearError: true));

    try {
      await _postComment(
        content: text,
        replyToEventId: event.parentCommentId,
        replyToAuthorPubkey: event.parentAuthorPubkey,
        emit: emit,
      );

      // Clear input on success
      if (isReply) {
        final updatedReplies = Map<String, String>.from(state.replyInputTexts);
        updatedReplies[event.parentCommentId!] = '';
        emit(
          state.copyWith(
            replyInputTexts: updatedReplies,
            isPosting: false,
            clearActiveReply: true,
          ),
        );
      } else {
        emit(state.copyWith(mainInputText: '', isPosting: false));
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
          error: isReply ? 'Failed to post reply' : 'Failed to post comment',
        ),
      );
    }
  }

  /// Handle error clear
  void _onErrorCleared(CommentErrorCleared event, Emitter<CommentsState> emit) {
    emit(state.copyWith(clearError: true));
  }

  /// Post a comment with optimistic update
  Future<void> _postComment({
    required String content,
    required String? replyToEventId,
    required String? replyToAuthorPubkey,
    required Emitter<CommentsState> emit,
  }) async {
    final currentUserPubkey = _authService.currentPublicKeyHex;
    if (currentUserPubkey == null) {
      throw Exception('User public key not found');
    }

    // Create optimistic comment for immediate UI feedback
    final optimisticComment = repo.Comment(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      content: content,
      authorPubkey: currentUserPubkey,
      createdAt: DateTime.now(),
      rootEventId: state.rootEventId,
      replyToEventId: replyToEventId,
      rootAuthorPubkey: state.rootAuthorPubkey,
      replyToAuthorPubkey: replyToAuthorPubkey,
    );

    // Add optimistic comment to tree
    final updatedComments = _addOptimisticComment(
      state.topLevelComments,
      optimisticComment,
      replyToEventId,
    );

    emit(
      state.copyWith(
        topLevelComments: updatedComments,
        totalCommentCount: state.totalCommentCount + 1,
      ),
    );

    // Post the actual comment via repository
    await _commentsRepository.postComment(
      content: content,
      rootEventId: state.rootEventId,
      rootEventAuthorPubkey: state.rootAuthorPubkey,
      replyToEventId: replyToEventId,
      replyToAuthorPubkey: replyToAuthorPubkey,
    );
  }

  /// Convert repository CommentNodes to app CommentNodes
  List<CommentNode> _convertNodes(List<repo.CommentNode> repoNodes) {
    return repoNodes.map((repoNode) {
      return CommentNode(
        comment: repoNode.comment,
        replies: _convertNodes(repoNode.replies),
      );
    }).toList();
  }

  /// Add optimistic comment to tree
  List<CommentNode> _addOptimisticComment(
    List<CommentNode> nodes,
    repo.Comment comment,
    String? replyToEventId,
  ) {
    if (replyToEventId == null) {
      // Top-level comment - add at beginning (newest first)
      return [CommentNode(comment: comment), ...nodes];
    }

    // Find the parent and add as a reply
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
          replies: _addOptimisticComment(node.replies, comment, replyToEventId),
        );
      }
      return node;
    }).toList();
  }
}
