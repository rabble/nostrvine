// ABOUTME: BLoC for managing interactions on a single video
// ABOUTME: Handles like status, like count, and comment count per video item

import 'dart:async';

import 'package:comments_repository/comments_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:likes_repository/likes_repository.dart';
import 'package:openvine/utils/unified_logger.dart';

part 'video_interactions_event.dart';
part 'video_interactions_state.dart';

/// BLoC for managing interactions on a single video.
///
/// This bloc is created per-VideoFeedItem and manages:
/// - Like status (from LikesRepository)
/// - Like count (from relays via LikesRepository)
/// - Comment count (from relays via CommentsRepository)
///
/// The bloc subscribes to the repository's liked IDs stream to stay
/// in sync when likes change from other sources (e.g., liked videos grid).
class VideoInteractionsBloc
    extends Bloc<VideoInteractionsEvent, VideoInteractionsState> {
  VideoInteractionsBloc({
    required String eventId,
    required String authorPubkey,
    required LikesRepository likesRepository,
    required CommentsRepository commentsRepository,
  }) : _eventId = eventId,
       _authorPubkey = authorPubkey,
       _likesRepository = likesRepository,
       _commentsRepository = commentsRepository,
       super(const VideoInteractionsState()) {
    on<VideoInteractionsFetchRequested>(_onFetchRequested);
    on<VideoInteractionsLikeToggled>(_onLikeToggled);
    on<VideoInteractionsLikeStatusChanged>(_onLikeStatusChanged);

    // Subscribe to liked IDs stream to stay in sync
    _likedIdsSubscription = _likesRepository.watchLikedEventIds().listen(
      _onLikedIdsChanged,
    );
  }

  final String _eventId;
  final String _authorPubkey;
  final LikesRepository _likesRepository;
  final CommentsRepository _commentsRepository;
  StreamSubscription<Set<String>>? _likedIdsSubscription;

  /// Handle changes to the global liked IDs set.
  void _onLikedIdsChanged(Set<String> likedIds) {
    final isLiked = likedIds.contains(_eventId);
    if (isLiked != state.isLiked) {
      add(VideoInteractionsLikeStatusChanged(isLiked: isLiked));
    }
  }

  /// Handle request to fetch initial state.
  Future<void> _onFetchRequested(
    VideoInteractionsFetchRequested event,
    Emitter<VideoInteractionsState> emit,
  ) async {
    // Don't re-fetch if already loaded
    if (state.status == VideoInteractionsStatus.success) return;
    if (state.status == VideoInteractionsStatus.loading) return;

    emit(state.copyWith(status: VideoInteractionsStatus.loading));

    try {
      // Check if liked (fast - from local cache)
      final isLiked = await _likesRepository.isLiked(_eventId);

      // Fetch counts in parallel
      final results = await Future.wait([
        _likesRepository.getLikeCount(_eventId),
        _commentsRepository.getCommentsCount(_eventId),
      ]);

      final likeCount = results[0];
      final commentCount = results[1];

      emit(
        state.copyWith(
          status: VideoInteractionsStatus.success,
          isLiked: isLiked,
          likeCount: likeCount,
          commentCount: commentCount,
          clearError: true,
        ),
      );
    } catch (e) {
      Log.error(
        'VideoInteractionsBloc: Failed to fetch for $_eventId - $e',
        name: 'VideoInteractionsBloc',
        category: LogCategory.system,
      );

      // Still mark as success if we have partial data
      // The UI can handle null counts gracefully
      emit(
        state.copyWith(
          status: VideoInteractionsStatus.success,
          error: VideoInteractionsError.fetchFailed,
        ),
      );
    }
  }

  /// Handle like toggle request.
  Future<void> _onLikeToggled(
    VideoInteractionsLikeToggled event,
    Emitter<VideoInteractionsState> emit,
  ) async {
    // Prevent double-taps
    if (state.isLikeInProgress) return;

    emit(state.copyWith(isLikeInProgress: true, clearError: true));

    try {
      final isNowLiked = await _likesRepository.toggleLike(
        eventId: _eventId,
        authorPubkey: _authorPubkey,
      );

      // Update local state with new like status and adjusted count
      final currentCount = state.likeCount ?? 0;
      final newCount = isNowLiked ? currentCount + 1 : currentCount - 1;

      emit(
        state.copyWith(
          isLiked: isNowLiked,
          likeCount: newCount < 0 ? 0 : newCount,
          isLikeInProgress: false,
        ),
      );
    } on AlreadyLikedException {
      // Already liked - just update state to reflect reality
      emit(state.copyWith(isLiked: true, isLikeInProgress: false));
    } on NotLikedException {
      // Not liked - just update state to reflect reality
      emit(state.copyWith(isLiked: false, isLikeInProgress: false));
    } catch (e) {
      Log.error(
        'VideoInteractionsBloc: Like toggle failed for $_eventId - $e',
        name: 'VideoInteractionsBloc',
        category: LogCategory.system,
      );

      emit(
        state.copyWith(
          isLikeInProgress: false,
          error: VideoInteractionsError.likeFailed,
        ),
      );
    }
  }

  /// Handle external like status change notification.
  void _onLikeStatusChanged(
    VideoInteractionsLikeStatusChanged event,
    Emitter<VideoInteractionsState> emit,
  ) {
    if (state.isLiked == event.isLiked) return;

    // Update like status and adjust count
    final currentCount = state.likeCount ?? 0;
    final newCount = event.isLiked ? currentCount + 1 : currentCount - 1;

    emit(
      state.copyWith(
        isLiked: event.isLiked,
        likeCount: newCount < 0 ? 0 : newCount,
      ),
    );
  }

  @override
  Future<void> close() {
    _likedIdsSubscription?.cancel();
    return super.close();
  }
}
