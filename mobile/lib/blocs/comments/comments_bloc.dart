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
/// - Organizing comments chronologically
/// - Managing input state for main comment and replies
/// - Posting new comments
class CommentsBloc extends Bloc<CommentsEvent, CommentsState> {
  CommentsBloc({
    required CommentsRepository commentsRepository,
    required AuthService authService,
    required String rootEventId,
    required int rootEventKind,
    required String rootAuthorPubkey,
    int? initialTotalCount,
  }) : _commentsRepository = commentsRepository,
       _authService = authService,
       _initialTotalCount = initialTotalCount,
       super(
         CommentsState(
           rootEventId: rootEventId,
           rootEventKind: rootEventKind,
           rootAuthorPubkey: rootAuthorPubkey,
         ),
       ) {
    on<CommentsLoadRequested>(_onLoadRequested);
    on<CommentsLoadMoreRequested>(_onLoadMoreRequested);
    on<CommentTextChanged>(_onTextChanged);
    on<CommentReplyToggled>(_onReplyToggled);
    on<CommentSubmitted>(_onSubmitted);
    on<CommentErrorCleared>(_onErrorCleared);
    on<CommentDeleteRequested>(_onDeleteRequested);
  }

  /// Page size for comment loading.
  static const _pageSize = 50;

  /// Optional initial total count from video metadata or interactions state.
  /// Used to accurately determine hasMoreContent instead of page size heuristic.
  final int? _initialTotalCount;

  final CommentsRepository _commentsRepository;
  final AuthService _authService;

  Future<void> _onLoadRequested(
    CommentsLoadRequested event,
    Emitter<CommentsState> emit,
  ) async {
    if (state.status == CommentsStatus.loading) return;

    emit(state.copyWith(status: CommentsStatus.loading));

    try {
      final thread = await _commentsRepository.loadComments(
        rootEventId: state.rootEventId,
        rootEventKind: state.rootEventKind,
        limit: _pageSize,
      );

      // Determine if there are more comments to load:
      // 1. If we have a known total count, compare loaded count to it
      // 2. Otherwise, use page size heuristic (if we got a full page, there might be more)
      final hasMore = _initialTotalCount != null
          ? thread.comments.length < _initialTotalCount
          : thread.comments.length >= _pageSize;

      emit(
        state.copyWith(
          status: CommentsStatus.success,
          comments: thread.comments,
          hasMoreContent: hasMore,
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

  Future<void> _onLoadMoreRequested(
    CommentsLoadMoreRequested event,
    Emitter<CommentsState> emit,
  ) async {
    // Skip if not in success state, already loading more, or no more content
    if (state.status != CommentsStatus.success ||
        state.isLoadingMore ||
        !state.hasMoreContent ||
        state.comments.isEmpty) {
      return;
    }

    emit(state.copyWith(isLoadingMore: true));

    try {
      // Get the oldest comment's timestamp as cursor
      // Nostr `until` filter is inclusive, so subtract 1 second to avoid
      // getting the same comment again
      final oldestComment = state.comments.last;
      final cursor = oldestComment.createdAt.subtract(
        const Duration(seconds: 1),
      );

      Log.info(
        'Loading more comments before ${oldestComment.createdAt}',
        name: 'CommentsBloc',
        category: LogCategory.ui,
      );

      final thread = await _commentsRepository.loadComments(
        rootEventId: state.rootEventId,
        rootEventKind: state.rootEventKind,
        limit: _pageSize,
        before: cursor,
      );

      // Append new comments to existing list
      final allComments = [...state.comments, ...thread.comments];

      // Determine if there are more comments to load:
      // 1. If we have a known total count, compare loaded count to it
      // 2. Otherwise, use page size heuristic (if we got a full page, there might be more)
      final hasMore = _initialTotalCount != null
          ? allComments.length < _initialTotalCount
          : thread.comments.length >= _pageSize;

      emit(
        state.copyWith(
          comments: allComments,
          isLoadingMore: false,
          hasMoreContent: hasMore,
        ),
      );

      Log.info(
        'Loaded ${thread.comments.length} more comments '
        '(total: ${allComments.length}, hasMore: $hasMore)',
        name: 'CommentsBloc',
        category: LogCategory.ui,
      );
    } catch (e) {
      Log.error(
        'Error loading more comments: $e',
        name: 'CommentsBloc',
        category: LogCategory.ui,
      );
      emit(state.copyWith(isLoadingMore: false));
    }
  }

  void _onTextChanged(CommentTextChanged event, Emitter<CommentsState> emit) {
    if (event.commentId == null) {
      emit(state.copyWith(mainInputText: event.text));
    } else {
      emit(state.copyWith(replyInputText: event.text));
    }
  }

  void _onReplyToggled(CommentReplyToggled event, Emitter<CommentsState> emit) {
    if (state.activeReplyCommentId == event.commentId) {
      emit(state.clearActiveReply());
    } else {
      emit(
        state.copyWith(
          activeReplyCommentId: event.commentId,
          replyInputText: '',
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
        ? state.replyInputText.trim()
        : state.mainInputText.trim();

    if (text.isEmpty) return;

    if (!_authService.isAuthenticated) {
      emit(state.copyWith(error: CommentsError.notAuthenticated));
      return;
    }

    emit(state.copyWith(isPosting: true));

    try {
      final postedComment = await _commentsRepository.postComment(
        content: text,
        rootEventId: state.rootEventId,
        rootEventKind: state.rootEventKind,
        rootEventAuthorPubkey: state.rootAuthorPubkey,
        replyToEventId: event.parentCommentId,
        replyToAuthorPubkey: event.parentAuthorPubkey,
      );

      final updatedComments = _addCommentToList(state.comments, postedComment);

      if (isReply) {
        emit(
          state.clearActiveReply(comments: updatedComments, isPosting: false),
        );
      } else {
        emit(
          state.copyWith(
            comments: updatedComments,
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
    emit(state.copyWith());
  }

  /// Adds a new comment to the flat list.
  ///
  /// Comments are prepended to maintain chronological order (newest first).
  List<Comment> _addCommentToList(List<Comment> comments, Comment newComment) {
    // Add to beginning (newest first)
    return [newComment, ...comments];
  }

  Future<void> _onDeleteRequested(
    CommentDeleteRequested event,
    Emitter<CommentsState> emit,
  ) async {
    if (!_authService.isAuthenticated) {
      emit(state.copyWith(error: CommentsError.notAuthenticated));
      return;
    }

    try {
      await _commentsRepository.deleteComment(commentId: event.commentId);

      // Remove the comment from the flat list
      final updatedComments = state.comments
          .where((c) => c.id != event.commentId)
          .toList();

      emit(state.copyWith(comments: updatedComments));
    } catch (e) {
      Log.error(
        'Error deleting comment: $e',
        name: 'CommentsBloc',
        category: LogCategory.ui,
      );

      emit(state.copyWith(error: CommentsError.deleteCommentFailed));
    }
  }
}
