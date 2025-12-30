// ABOUTME: BLoC for managing user likes (Kind 7 reactions) on Nostr events
// ABOUTME: Handles syncing, toggling likes, and tracking operations in progress

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:likes_repository/likes_repository.dart';
import 'package:openvine/utils/unified_logger.dart';

part 'likes_event.dart';
part 'likes_state.dart';

/// BLoC for managing the current user's likes.
///
/// Handles:
/// - Syncing likes from local storage and Nostr relays
/// - Toggling like status on events
/// - Tracking like operations in progress for UI feedback
class LikesBloc extends Bloc<LikesEvent, LikesState> {
  LikesBloc({required LikesRepository likesRepository})
    : _likesRepository = likesRepository,
      super(const LikesState()) {
    on<LikesSyncRequested>(_onSyncRequested);
    on<LikesToggleRequested>(_onToggleRequested);
    on<LikesErrorCleared>(_onErrorCleared);
  }

  final LikesRepository _likesRepository;

  /// Handle request to sync likes from storage and relays.
  Future<void> _onSyncRequested(
    LikesSyncRequested event,
    Emitter<LikesState> emit,
  ) async {
    if (state.status == LikesStatus.syncing) return;

    emit(state.copyWith(status: LikesStatus.syncing, clearError: true));

    try {
      final result = await _likesRepository.syncUserReactions();

      emit(
        state.copyWith(
          status: LikesStatus.success,
          likedEventIds: result.orderedEventIds,
        ),
      );

      Log.info(
        'LikesBloc: Synced ${result.count} likes',
        name: 'LikesBloc',
        category: LogCategory.system,
      );
    } on SyncFailedException catch (e) {
      Log.error(
        'LikesBloc: Sync failed - ${e.message}',
        name: 'LikesBloc',
        category: LogCategory.system,
      );
      emit(
        state.copyWith(
          status: LikesStatus.failure,
          error: LikesError.syncFailed,
        ),
      );
    }
  }

  /// Handle toggle like request.
  Future<void> _onToggleRequested(
    LikesToggleRequested event,
    Emitter<LikesState> emit,
  ) async {
    final eventId = event.eventId;

    // Prevent duplicate operations
    if (state.isOperationInProgress(eventId)) return;

    emit(
      state.copyWith(
        operationsInProgress: {...state.operationsInProgress, eventId},
        clearError: true,
      ),
    );

    try {
      final isNowLiked = await _likesRepository.toggleLike(
        eventId: eventId,
        authorPubkey: event.authorPubkey,
      );

      if (isNowLiked) {
        // Prepend to list (most recent first)
        emit(
          state.copyWith(
            likedEventIds: [eventId, ...state.likedEventIds],
            operationsInProgress: _removeFromSet(
              state.operationsInProgress,
              eventId,
            ),
          ),
        );
      } else {
        // Remove from list
        emit(
          state.copyWith(
            likedEventIds: state.likedEventIds
                .where((id) => id != eventId)
                .toList(),
            operationsInProgress: _removeFromSet(
              state.operationsInProgress,
              eventId,
            ),
          ),
        );
      }
    } on AlreadyLikedException {
      emit(
        state.copyWith(
          operationsInProgress: _removeFromSet(
            state.operationsInProgress,
            eventId,
          ),
        ),
      );
    } on NotLikedException {
      emit(
        state.copyWith(
          operationsInProgress: _removeFromSet(
            state.operationsInProgress,
            eventId,
          ),
        ),
      );
    } on LikeFailedException catch (e) {
      Log.error(
        'LikesBloc: Like failed - ${e.message}',
        name: 'LikesBloc',
        category: LogCategory.system,
      );
      emit(
        state.copyWith(
          operationsInProgress: _removeFromSet(
            state.operationsInProgress,
            eventId,
          ),
          error: LikesError.likeFailed,
        ),
      );
    } on UnlikeFailedException catch (e) {
      Log.error(
        'LikesBloc: Unlike failed - ${e.message}',
        name: 'LikesBloc',
        category: LogCategory.system,
      );
      emit(
        state.copyWith(
          operationsInProgress: _removeFromSet(
            state.operationsInProgress,
            eventId,
          ),
          error: LikesError.unlikeFailed,
        ),
      );
    }
  }

  /// Handle error cleared event.
  void _onErrorCleared(LikesErrorCleared event, Emitter<LikesState> emit) {
    emit(state.copyWith(clearError: true));
  }

  /// Helper to remove an item from a Set immutably.
  Set<String> _removeFromSet(Set<String> set, String item) {
    return {...set}..remove(item);
  }
}
