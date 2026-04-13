// ABOUTME: BLoC for loading a user's comments across all videos.
// ABOUTME: Splits results into video replies and text comments for UI display.
// ABOUTME: Supports lazy loading and cursor-based pagination.

import 'package:bloc/bloc.dart';
import 'package:comments_repository/comments_repository.dart';
import 'package:equatable/equatable.dart';

part 'profile_comments_event.dart';
part 'profile_comments_state.dart';

/// Number of comments to load per page.
const _pageSize = 50;

/// BLoC that loads and paginates a user's comments (text + video replies).
class ProfileCommentsBloc
    extends Bloc<ProfileCommentsEvent, ProfileCommentsState> {
  /// Creates a new profile comments BLoC.
  ///
  /// Parameters:
  /// - [commentsRepository]: Repository for querying comments
  /// - [targetUserPubkey]: Hex public key of the user whose comments
  ///   to load
  ProfileCommentsBloc({
    required CommentsRepository commentsRepository,
    required String targetUserPubkey,
  }) : _commentsRepository = commentsRepository,
       _targetUserPubkey = targetUserPubkey,
       super(const ProfileCommentsState()) {
    on<ProfileCommentsSyncRequested>(_onSyncRequested);
    on<ProfileCommentsLoadMoreRequested>(_onLoadMoreRequested);
  }

  final CommentsRepository _commentsRepository;
  final String _targetUserPubkey;

  Future<void> _onSyncRequested(
    ProfileCommentsSyncRequested event,
    Emitter<ProfileCommentsState> emit,
  ) async {
    if (state.status == ProfileCommentsStatus.loading) return;

    emit(state.copyWith(status: ProfileCommentsStatus.loading));

    try {
      final comments = await _commentsRepository.loadCommentsByAuthor(
        authorPubkey: _targetUserPubkey,
      );

      final videoReplies = comments.where((c) => c.hasVideo).toList();
      final textComments = comments.where((c) => !c.hasVideo).toList();

      final cursor = comments.isNotEmpty ? comments.last.createdAt : null;

      emit(
        state.copyWith(
          status: ProfileCommentsStatus.success,
          videoReplies: videoReplies,
          textComments: textComments,
          hasMoreContent: comments.length >= _pageSize,
          paginationCursor: cursor,
        ),
      );
    } catch (e, stackTrace) {
      addError(e, stackTrace);
      emit(state.copyWith(status: ProfileCommentsStatus.failure));
    }
  }

  Future<void> _onLoadMoreRequested(
    ProfileCommentsLoadMoreRequested event,
    Emitter<ProfileCommentsState> emit,
  ) async {
    if (state.status != ProfileCommentsStatus.success ||
        state.isLoadingMore ||
        !state.hasMoreContent) {
      return;
    }

    emit(state.copyWith(isLoadingMore: true));

    try {
      // Subtract 1 second to avoid re-fetching the last comment
      // (Nostr `until` filter is inclusive)
      final before = state.paginationCursor?.subtract(
        const Duration(seconds: 1),
      );

      final comments = await _commentsRepository.loadCommentsByAuthor(
        authorPubkey: _targetUserPubkey,
        before: before,
      );

      final newVideoReplies = comments.where((c) => c.hasVideo).toList();
      final newTextComments = comments.where((c) => !c.hasVideo).toList();

      // Deduplicate against existing comments
      final existingIds = {
        ...state.videoReplies.map((c) => c.id),
        ...state.textComments.map((c) => c.id),
      };
      final uniqueVideoReplies = newVideoReplies
          .where((c) => !existingIds.contains(c.id))
          .toList();
      final uniqueTextComments = newTextComments
          .where((c) => !existingIds.contains(c.id))
          .toList();

      final cursor = comments.isNotEmpty
          ? comments.last.createdAt
          : state.paginationCursor;

      emit(
        state.copyWith(
          videoReplies: [...state.videoReplies, ...uniqueVideoReplies],
          textComments: [...state.textComments, ...uniqueTextComments],
          isLoadingMore: false,
          hasMoreContent: comments.length >= _pageSize,
          paginationCursor: cursor,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isLoadingMore: false));
    }
  }
}
