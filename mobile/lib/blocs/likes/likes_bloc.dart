// ABOUTME: BLoC for managing user likes (Kind 7 reactions) on Nostr events
// ABOUTME: Handles syncing, liking, unliking, and tracking like state

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
/// - Liking and unliking events
/// - Tracking like operations in progress
/// - Providing ordered liked event IDs for display
class LikesBloc extends Bloc<LikesEvent, LikesState> {
  LikesBloc({required LikesRepository likesRepository})
    : _likesRepository = likesRepository,
      super(const LikesState()) {
    on<LikesSyncRequested>(_onSyncRequested);
    on<LikesToggleRequested>(_onToggleRequested);
    on<LikesLikeRequested>(_onLikeRequested);
    on<LikesUnlikeRequested>(_onUnlikeRequested);
    on<LikesErrorCleared>(_onErrorCleared);
  }

  final LikesRepository _likesRepository;

  /// Handle request to sync likes from storage and relays
  Future<void> _onSyncRequested(
    LikesSyncRequested event,
    Emitter<LikesState> emit,
  ) async {
    if (state.status == LikesStatus.syncing) return;

    emit(state.copyWith(status: LikesStatus.syncing, clearError: true));

    try {
      // Sync with relays (also loads from local storage)
      await _likesRepository.syncUserReactions();

      // Get ordered list and derive the Set from it
      final orderedIds = await _likesRepository.getOrderedLikedEventIds();
      final likedIds = orderedIds.toSet();

      // Build eventIdToReactionId map
      final eventIdToReactionId = <String, String>{};
      for (final eventId in orderedIds) {
        final record = await _likesRepository.getLikeRecord(eventId);
        if (record != null) {
          eventIdToReactionId[eventId] = record.reactionEventId;
        }
      }

      emit(
        state.copyWith(
          status: LikesStatus.success,
          likedEventIds: likedIds,
          orderedLikedEventIds: orderedIds,
          eventIdToReactionId: eventIdToReactionId,
        ),
      );

      Log.info(
        'LikesBloc: Synced ${likedIds.length} likes',
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
        state.copyWith(status: LikesStatus.failure, error: LikesError.syncFailed),
      );
    } catch (e) {
      Log.error(
        'LikesBloc: Error syncing likes - $e',
        name: 'LikesBloc',
        category: LogCategory.system,
      );
      emit(
        state.copyWith(status: LikesStatus.failure, error: LikesError.syncFailed),
      );
    }
  }

  /// Handle toggle like request
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
        final record = await _likesRepository.getLikeRecord(eventId);
        emit(
          state.copyWith(
            likedEventIds: {...state.likedEventIds, eventId},
            // Prepend to ordered list (most recent first)
            orderedLikedEventIds: [eventId, ...state.orderedLikedEventIds],
            eventIdToReactionId: record != null
                ? {...state.eventIdToReactionId, eventId: record.reactionEventId}
                : state.eventIdToReactionId,
            operationsInProgress: _removeFromSet(
              state.operationsInProgress,
              eventId,
            ),
          ),
        );
      } else {
        emit(
          state.copyWith(
            likedEventIds: _removeFromSet(state.likedEventIds, eventId),
            orderedLikedEventIds: state.orderedLikedEventIds
                .where((id) => id != eventId)
                .toList(),
            eventIdToReactionId: _removeFromMap(
              state.eventIdToReactionId,
              eventId,
            ),
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

  /// Handle like request (only likes, does not toggle)
  Future<void> _onLikeRequested(
    LikesLikeRequested event,
    Emitter<LikesState> emit,
  ) async {
    final eventId = event.eventId;

    // Prevent duplicate operations
    if (state.isOperationInProgress(eventId)) return;

    // Already liked - do nothing
    if (state.isLiked(eventId)) return;

    emit(
      state.copyWith(
        operationsInProgress: {...state.operationsInProgress, eventId},
        clearError: true,
      ),
    );

    try {
      final reactionEventId = await _likesRepository.likeEvent(
        eventId: eventId,
        authorPubkey: event.authorPubkey,
      );

      emit(
        state.copyWith(
          likedEventIds: {...state.likedEventIds, eventId},
          orderedLikedEventIds: [eventId, ...state.orderedLikedEventIds],
          eventIdToReactionId: {
            ...state.eventIdToReactionId,
            eventId: reactionEventId,
          },
          operationsInProgress: _removeFromSet(
            state.operationsInProgress,
            eventId,
          ),
        ),
      );
    } on AlreadyLikedException {
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
    }
  }

  /// Handle unlike request (only unlikes, does not toggle)
  Future<void> _onUnlikeRequested(
    LikesUnlikeRequested event,
    Emitter<LikesState> emit,
  ) async {
    final eventId = event.eventId;

    // Prevent duplicate operations
    if (state.isOperationInProgress(eventId)) return;

    // Not liked - do nothing
    if (!state.isLiked(eventId)) return;

    emit(
      state.copyWith(
        operationsInProgress: {...state.operationsInProgress, eventId},
        clearError: true,
      ),
    );

    try {
      await _likesRepository.unlikeEvent(eventId);

      emit(
        state.copyWith(
          likedEventIds: _removeFromSet(state.likedEventIds, eventId),
          orderedLikedEventIds: state.orderedLikedEventIds
              .where((id) => id != eventId)
              .toList(),
          eventIdToReactionId: _removeFromMap(
            state.eventIdToReactionId,
            eventId,
          ),
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

  /// Handle error cleared event
  void _onErrorCleared(LikesErrorCleared event, Emitter<LikesState> emit) {
    emit(state.copyWith(clearError: true));
  }

  /// Helper to remove an item from a Set immutably
  Set<String> _removeFromSet(Set<String> set, String item) {
    return {...set}..remove(item);
  }

  /// Helper to remove an item from a Map immutably
  Map<String, String> _removeFromMap(Map<String, String> map, String key) {
    return {...map}..remove(key);
  }
}
