// ABOUTME: BLoC for managing interactions on a single video
// ABOUTME: Handles like/repost status and counts per video item

import 'dart:async';

import 'package:comments_repository/comments_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:likes_repository/likes_repository.dart';
import 'package:models/models.dart' show NIP71VideoKinds;
import 'package:reposts_repository/reposts_repository.dart';
import 'package:unified_logger/unified_logger.dart';

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
    int? initialLikeCount,
  }) : _eventId = eventId,
       _authorPubkey = authorPubkey,
       _likesRepository = likesRepository,
       _commentsRepository = commentsRepository,
       _repostsRepository = repostsRepository,
       _addressableId = addressableId,
       super(VideoInteractionsState(likeCount: initialLikeCount)) {
    on<VideoInteractionsFetchRequested>(_onFetchRequested);
    on<VideoInteractionsLikeToggled>(_onLikeToggled);
    on<VideoInteractionsRepostToggled>(_onRepostToggled);
    on<VideoInteractionsSubscriptionRequested>(_onSubscriptionRequested);
    on<VideoInteractionsCommentCountUpdated>(_onCommentCountUpdated);
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
      emit.forEach<List<String>>(
        _likesRepository.watchLikedEventIds(),
        onData: (likedIds) {
          final isLiked = likedIds.contains(_eventId);
          // Load-bearing: when [_onLikeToggled] has already emitted its
          // optimistic state, state.isLiked matches and we no-op here.
          // This guarantees a single bloc emit per tap and avoids the
          // double-count race that would otherwise happen if both
          // handlers adjusted likeCount.
          if (isLiked == state.isLiked) return state;

          // Sync like status only — count is owned by _onLikeToggled.
          // External sources (cross-device sync via the repo's reaction
          // subscription) can flip isLiked here, but likeCount is left
          // alone; cross-device count drift is tracked as a follow-up.
          return state.copyWith(isLiked: isLiked);
        },
      ),
      if (_addressableId != null)
        emit.forEach<Set<String>>(
          _repostsRepository.watchRepostedAddressableIds(),
          onData: (repostedIds) {
            final isReposted = repostedIds.contains(_addressableId);
            // Load-bearing for the same reason as the likes branch: the
            // repost toggle handler emits optimistically before awaiting,
            // and this early-return absorbs the follow-up stream tick.
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
      final isReposted =
          _addressableId != null &&
          await _repostsRepository.isReposted(_addressableId);

      // Fetch counts in parallel
      // Query repost count by addressable ID when available (NIP-18 specifies
      // that generic reposts of addressable events use the `a` tag).
      // Fall back to event ID for non-addressable videos.
      final repostCountFuture = _addressableId != null
          ? _repostsRepository.getRepostCount(_addressableId)
          : _repostsRepository.getRepostCountByEventId(_eventId);

      final likeCountFuture = state.likeCount != null
          ? Future.value(state.likeCount)
          : _likesRepository.getLikeCount(
              _eventId,
              addressableId: _addressableId,
            );

      final results = await Future.wait([
        likeCountFuture,
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
  ///
  /// Emits the optimistic state (flipped [isLiked] + adjusted [likeCount])
  /// BEFORE awaiting the repository, so the heart and counter flip in the
  /// same frame. The repository's stream tick fires during the await; the
  /// subscription handler at [_onSubscriptionRequested] no-ops because
  /// state.isLiked already matches, guaranteeing a single emit per tap.
  ///
  /// Exception paths revert both fields to the pre-tap baseline so the UI
  /// returns to its original state if the publish fails.
  Future<void> _onLikeToggled(
    VideoInteractionsLikeToggled event,
    Emitter<VideoInteractionsState> emit,
  ) async {
    final wasLiked = state.isLiked;
    final wasCount = state.likeCount;
    final optimisticLiked = !wasLiked;

    emit(
      state.copyWith(
        isLiked: optimisticLiked,
        // copyWith treats null as "no change", so when the count hasn't
        // been fetched yet we leave it null (don't synthesize a 0).
        likeCount: _adjustCount(wasCount, increment: optimisticLiked),
        clearError: true,
      ),
    );

    try {
      // Pass addressable ID and target kind for proper a-tag tagging
      final isNowLiked = await _likesRepository.toggleLike(
        eventId: _eventId,
        authorPubkey: _authorPubkey,
        addressableId: _addressableId,
        targetKind: _addressableId != null
            ? NIP71VideoKinds.addressableShortVideo
            : null,
      );

      if (isNowLiked != optimisticLiked) {
        // Out-of-band toggle (e.g. another device flipped it mid-tap).
        // Reconcile from the pre-tap baseline rather than current state.
        emit(
          state.copyWith(
            isLiked: isNowLiked,
            likeCount: _adjustCount(wasCount, increment: isNowLiked),
          ),
        );
      }
    } on AlreadyLikedException {
      // Reality says we were already liked — revert to pre-tap baseline
      // since no real transition occurred.
      emit(state.copyWith(isLiked: true, likeCount: wasCount));
    } on NotLikedException {
      emit(state.copyWith(isLiked: false, likeCount: wasCount));
    } catch (e) {
      Log.error(
        'VideoInteractionsBloc: Like toggle failed for $_eventId - $e',
        name: 'VideoInteractionsBloc',
        category: LogCategory.system,
      );

      emit(
        state.copyWith(
          isLiked: wasLiked,
          likeCount: wasCount,
          error: VideoInteractionsError.likeFailed,
        ),
      );
    }
  }

  /// Adjusts a possibly-null count by +1/-1 with a zero floor.
  ///
  /// Returns null when [count] is null so callers can pass the result to
  /// [VideoInteractionsState.copyWith] without overwriting an unset count.
  static int? _adjustCount(int? count, {required bool increment}) {
    if (count == null) return null;
    final raw = increment ? count + 1 : count - 1;
    return raw < 0 ? 0 : raw;
  }

  /// Handle repost toggle request.
  ///
  /// Mirrors [_onLikeToggled]: the repository now writes the optimistic
  /// record + ticks [RepostsRepository.watchRepostedAddressableIds] before
  /// the kind-16 publish, and this handler emits the optimistic state
  /// before awaiting, so the icon and counter flip in the same frame. The
  /// subscription handler's early-return absorbs the follow-up stream tick.
  Future<void> _onRepostToggled(
    VideoInteractionsRepostToggled event,
    Emitter<VideoInteractionsState> emit,
  ) async {
    // Cannot repost non-addressable events (missing d-tag).
    final addressableId = _addressableId;
    if (addressableId == null) {
      Log.warning(
        'VideoInteractionsBloc: Cannot repost - no addressable ID for '
        '$_eventId',
        name: 'VideoInteractionsBloc',
        category: LogCategory.system,
      );
      emit(state.copyWith(error: VideoInteractionsError.repostFailed));
      return;
    }

    final wasReposted = state.isReposted;
    final wasCount = state.repostCount;
    final optimisticReposted = !wasReposted;

    emit(
      state.copyWith(
        isReposted: optimisticReposted,
        repostCount: _adjustCount(wasCount, increment: optimisticReposted),
        clearError: true,
      ),
    );

    try {
      final isNowReposted = await _repostsRepository.toggleRepost(
        addressableId: addressableId,
        originalAuthorPubkey: _authorPubkey,
        eventId: _eventId,
      );

      if (isNowReposted != optimisticReposted) {
        // Out-of-band toggle. Reconcile from the pre-tap baseline.
        emit(
          state.copyWith(
            isReposted: isNowReposted,
            repostCount: _adjustCount(wasCount, increment: isNowReposted),
          ),
        );
      }
    } on AlreadyRepostedException {
      emit(state.copyWith(isReposted: true, repostCount: wasCount));
    } on NotRepostedException {
      emit(state.copyWith(isReposted: false, repostCount: wasCount));
    } catch (e) {
      Log.error(
        'VideoInteractionsBloc: Repost toggle failed for $_eventId - $e',
        name: 'VideoInteractionsBloc',
        category: LogCategory.system,
      );

      emit(
        state.copyWith(
          isReposted: wasReposted,
          repostCount: wasCount,
          error: VideoInteractionsError.repostFailed,
        ),
      );
    }
  }

  void _onCommentCountUpdated(
    VideoInteractionsCommentCountUpdated event,
    Emitter<VideoInteractionsState> emit,
  ) {
    // Only update the BLoC's own display state. Repository cache coherence is
    // handled automatically by CommentsRepository.loadComments(), which updates
    // _commentCountCache with the authoritative count on every full load.
    emit(state.copyWith(commentCount: event.commentCount));
  }
}
