// ABOUTME: BLoC for managing interactions on a single video
// ABOUTME: Handles like/repost status and counts per video item

import 'dart:async';

import 'package:comments_repository/comments_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:likes_repository/likes_repository.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:reposts_repository/reposts_repository.dart';

part 'video_interactions_event.dart';
part 'video_interactions_state.dart';

/// BLoC for managing interactions on a single video.
///
/// This bloc is created per-VideoFeedItem and manages:
/// - Like status (from LikesRepository)
/// - Like count (from relays via LikesRepository)
/// - Repost status (from RepostsRepository)
/// - Repost count (from video metadata)
/// - Comment count (from relays via CommentsRepository)
///
/// The bloc subscribes to the repository's liked/reposted IDs streams to stay
/// in sync when interactions change from other sources (e.g., profile grids).
class VideoInteractionsBloc
    extends Bloc<VideoInteractionsEvent, VideoInteractionsState> {
  VideoInteractionsBloc({
    required String eventId,
    required String authorPubkey,
    required LikesRepository likesRepository,
    required CommentsRepository commentsRepository,
    required RepostsRepository repostsRepository,
    String? addressableId,
  }) : _eventId = eventId,
       _authorPubkey = authorPubkey,
       _likesRepository = likesRepository,
       _commentsRepository = commentsRepository,
       _repostsRepository = repostsRepository,
       _addressableId = addressableId,
       super(const VideoInteractionsState()) {
    on<VideoInteractionsFetchRequested>(_onFetchRequested);
    on<VideoInteractionsLikeToggled>(_onLikeToggled);
    on<VideoInteractionsRepostToggled>(_onRepostToggled);
    on<VideoInteractionsSubscriptionRequested>(_onSubscriptionRequested);
  }

  final String _eventId;
  final String _authorPubkey;
  final LikesRepository _likesRepository;
  final CommentsRepository _commentsRepository;
  final RepostsRepository _repostsRepository;

  /// Addressable ID for repost operations (format: `kind:pubkey:d-tag`).
  /// Null if the video doesn't have a d-tag (non-addressable event).
  final String? _addressableId;

  /// Subscribe to liked/reposted IDs changes and update status reactively.
  Future<void> _onSubscriptionRequested(
    VideoInteractionsSubscriptionRequested event,
    Emitter<VideoInteractionsState> emit,
  ) {
    final subscriptions = [
      emit.forEach<Set<String>>(
        _likesRepository.watchLikedEventIds(),
        onData: (likedIds) {
          final isLiked = likedIds.contains(_eventId);
          if (isLiked == state.isLiked) return state;

          // Update like status and adjust count
          final currentCount = state.likeCount ?? 0;
          final newCount = isLiked ? currentCount + 1 : currentCount - 1;

          return state.copyWith(
            isLiked: isLiked,
            likeCount: newCount < 0 ? 0 : newCount,
          );
        },
      ),
      if (_addressableId != null)
        emit.forEach<Set<String>>(
          _repostsRepository.watchRepostedAddressableIds(),
          onData: (repostedIds) {
            final isReposted = repostedIds.contains(_addressableId);
            if (isReposted == state.isReposted) return state;

            return state.copyWith(isReposted: isReposted);
          },
        ),
    ];

    return subscriptions.wait;
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

      // Check if reposted (fast - from local cache) if addressable
      final isReposted = _addressableId != null
          ? await _repostsRepository.isReposted(_addressableId)
          : false;

      // Fetch counts in parallel
      // Query repost count by addressable ID when available (NIP-18 specifies
      // that generic reposts of addressable events use the `a` tag).
      // Fall back to event ID for non-addressable videos.
      final repostCountFuture = _addressableId != null
          ? _repostsRepository.getRepostCount(_addressableId)
          : _repostsRepository.getRepostCountByEventId(_eventId);

      final results = await Future.wait([
        _likesRepository.getLikeCount(_eventId),
        _commentsRepository.getCommentsCount(
          _eventId,
          rootAddressableId: _addressableId,
        ),
        repostCountFuture,
      ]);

      final likeCount = results[0];
      final commentCount = results[1];
      final repostCount = results[2];

      emit(
        state.copyWith(
          status: VideoInteractionsStatus.success,
          isLiked: isLiked,
          likeCount: likeCount,
          isReposted: isReposted,
          repostCount: repostCount,
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

  /// Handle repost toggle request.
  Future<void> _onRepostToggled(
    VideoInteractionsRepostToggled event,
    Emitter<VideoInteractionsState> emit,
  ) async {
    // Prevent double-taps
    if (state.isRepostInProgress) return;

    // Cannot repost non-addressable events (missing d-tag)
    if (_addressableId == null) {
      Log.warning(
        'VideoInteractionsBloc: Cannot repost - no addressable ID for '
        '$_eventId',
        name: 'VideoInteractionsBloc',
        category: LogCategory.system,
      );
      emit(state.copyWith(error: VideoInteractionsError.repostFailed));
      return;
    }

    emit(state.copyWith(isRepostInProgress: true, clearError: true));

    try {
      final isNowReposted = await _repostsRepository.toggleRepost(
        addressableId: _addressableId,
        originalAuthorPubkey: _authorPubkey,
        eventId: _eventId,
      );

      // Update local state with new repost status and adjusted count
      final currentCount = state.repostCount ?? 0;
      final newCount = isNowReposted ? currentCount + 1 : currentCount - 1;

      emit(
        state.copyWith(
          isReposted: isNowReposted,
          repostCount: newCount < 0 ? 0 : newCount,
          isRepostInProgress: false,
        ),
      );
    } on AlreadyRepostedException {
      // Already reposted - just update state to reflect reality
      emit(state.copyWith(isReposted: true, isRepostInProgress: false));
    } on NotRepostedException {
      // Not reposted - just update state to reflect reality
      emit(state.copyWith(isReposted: false, isRepostInProgress: false));
    } catch (e) {
      Log.error(
        'VideoInteractionsBloc: Repost toggle failed for $_eventId - $e',
        name: 'VideoInteractionsBloc',
        category: LogCategory.system,
      );

      emit(
        state.copyWith(
          isRepostInProgress: false,
          error: VideoInteractionsError.repostFailed,
        ),
      );
    }
  }
}
