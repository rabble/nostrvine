// ABOUTME: Riverpod providers for likes feature using LikesRepository
// ABOUTME: Provides reactive state management for like/unlike operations

import 'dart:async';

import 'package:likes_repository/likes_repository.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/state/likes_state.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'likes_providers.g.dart';

/// Main likes state notifier
///
/// Manages the reactive state for likes feature, providing:
/// - Like/unlike operations
/// - Sync with relays on startup
/// - Reactive stream of liked event IDs
/// - Like count queries
///
/// Usage:
/// ```dart
/// // Watch likes state
/// final likesState = ref.watch(likesProvider);
///
/// // Check if event is liked
/// final isLiked = likesState.isLiked(eventId);
///
/// // Toggle like
/// await ref.read(likesProvider.notifier).toggleLike(
///   eventId: eventId,
///   authorPubkey: authorPubkey,
/// );
/// ```
@Riverpod(keepAlive: true)
class LikesNotifier extends _$LikesNotifier {
  StreamSubscription<Set<String>>? _likedIdsSubscription;
  Completer<void>? _initializationCompleter;

  @override
  LikesState build() {
    // Watch the repository - it handles auth checking internally
    // When auth changes, repository changes, which triggers rebuild
    final repository = ref.watch(likesRepositoryProvider);

    ref.onDispose(_cleanup);

    if (repository == null) {
      // Not authenticated - return empty state
      return LikesState.initial;
    }

    // Authenticated - schedule initialization after build() completes
    Future.microtask(() => _initialize(repository));

    return LikesState.initial;
  }

  /// Initialize the likes state
  ///
  /// Loads from local storage first, then syncs with relays.
  Future<void> _initialize(LikesRepository repository) async {
    // Prevent concurrent initialization
    if (_initializationCompleter != null &&
        !_initializationCompleter!.isCompleted) {
      return;
    }

    // Skip if already initialized
    if (state.isInitialized) {
      return;
    }

    _initializationCompleter = Completer<void>();

    state = state.copyWith(isSyncing: true, error: null);

    // Load from local storage immediately
    try {
      await _updateStateFromRepository(repository);
    } catch (e) {
      Log.error(
        'LikesNotifier: Failed to load from storage: $e',
        name: 'LikesNotifier',
        category: LogCategory.system,
      );
    }

    // Subscribe to reactive updates for live changes
    _subscribeToLikedIds(repository);

    // Sync with relays (may fetch newer data)
    try {
      await repository.syncUserReactions();
      await _updateStateFromRepository(repository, markInitialized: true);

      Log.info(
        'LikesNotifier: Initialized with ${state.likedEventIds.length} likes',
        name: 'LikesNotifier',
        category: LogCategory.system,
      );
    } on SyncFailedException catch (e) {
      Log.error(
        'LikesNotifier: Sync failed - $e',
        name: 'LikesNotifier',
        category: LogCategory.system,
      );
      // Still mark as initialized since we have local data
      state = state.copyWith(
        isInitialized: true,
        isSyncing: false,
        error: e.message,
      );
    } catch (e) {
      Log.error(
        'LikesNotifier: Initialization failed - $e',
        name: 'LikesNotifier',
        category: LogCategory.system,
      );
      state = state.copyWith(
        isInitialized: true,
        isSyncing: false,
        error: e.toString(),
      );
    } finally {
      _initializationCompleter?.complete();
    }
  }

  /// Updates state with current data from repository
  Future<void> _updateStateFromRepository(
    LikesRepository repository, {
    bool markInitialized = false,
  }) async {
    final likedIds = await repository.getLikedEventIds();

    // Build eventIdToReactionId map
    final eventIdToReactionId = <String, String>{};
    for (final eventId in likedIds) {
      final record = await repository.getLikeRecord(eventId);
      if (record != null) {
        eventIdToReactionId[eventId] = record.reactionEventId;
      }
    }

    state = state.copyWith(
      likedEventIds: likedIds,
      eventIdToReactionId: eventIdToReactionId,
      isInitialized: markInitialized ? true : state.isInitialized,
      isSyncing: markInitialized ? false : state.isSyncing,
    );
  }

  /// Subscribe to reactive liked IDs stream from repository
  void _subscribeToLikedIds(LikesRepository repository) {
    _likedIdsSubscription?.cancel();
    _likedIdsSubscription = repository.watchLikedEventIds().listen(
      (likedIds) {
        state = state.copyWith(likedEventIds: likedIds);
      },
      onError: (Object error) {
        Log.error(
          'LikesNotifier: Stream error - $error',
          name: 'LikesNotifier',
          category: LogCategory.system,
        );
      },
    );
  }

  /// Wait for initialization to complete (if in progress)
  Future<void> _waitForInitialization() async {
    if (_initializationCompleter != null &&
        !_initializationCompleter!.isCompleted) {
      await _initializationCompleter!.future;
    }
  }

  /// Cleanup resources
  void _cleanup() {
    _likedIdsSubscription?.cancel();
    _likedIdsSubscription = null;
  }

  /// Toggle like status for an event
  ///
  /// Returns true if the event is now liked, false if unliked.
  Future<bool> toggleLike({
    required String eventId,
    required String authorPubkey,
  }) async {
    await _waitForInitialization();

    final repository = ref.read(likesRepositoryProvider);
    if (repository == null) {
      throw const NotAuthenticatedException();
    }

    // Prevent duplicate operations
    if (state.isOperationInProgress(eventId)) {
      return state.isLiked(eventId);
    }

    state = state.copyWith(
      operationsInProgress: {...state.operationsInProgress, eventId},
      error: null,
    );

    try {
      final isNowLiked = await repository.toggleLike(
        eventId: eventId,
        authorPubkey: authorPubkey,
      );

      // Update local state
      if (isNowLiked) {
        final record = await repository.getLikeRecord(eventId);
        final newLikedIds = {...state.likedEventIds, eventId};
        Log.info(
          '❤️ [toggleLike] Adding $eventId to liked set. New count: ${newLikedIds.length}',
          name: 'LikesNotifier',
          category: LogCategory.system,
        );
        state = state.copyWith(
          likedEventIds: newLikedIds,
          eventIdToReactionId: record != null
              ? {...state.eventIdToReactionId, eventId: record.reactionEventId}
              : state.eventIdToReactionId,
        );
        Log.info(
          '❤️ [toggleLike] State updated. likedEventIds now has ${state.likedEventIds.length} items, contains $eventId: ${state.likedEventIds.contains(eventId)}',
          name: 'LikesNotifier',
          category: LogCategory.system,
        );
      } else {
        final newLikedIds = {...state.likedEventIds}..remove(eventId);
        final newEventIdToReactionId = {...state.eventIdToReactionId}
          ..remove(eventId);
        state = state.copyWith(
          likedEventIds: newLikedIds,
          eventIdToReactionId: newEventIdToReactionId,
        );
      }

      return isNowLiked;
    } on AlreadyLikedException {
      return true;
    } on NotLikedException {
      return false;
    } on LikeFailedException catch (e) {
      state = state.copyWith(error: e.message);
      rethrow;
    } on UnlikeFailedException catch (e) {
      state = state.copyWith(error: e.message);
      rethrow;
    } finally {
      final newInProgress = {...state.operationsInProgress}..remove(eventId);
      state = state.copyWith(operationsInProgress: newInProgress);
    }
  }

  /// Like an event
  Future<void> like({
    required String eventId,
    required String authorPubkey,
  }) async {
    await _waitForInitialization();

    final repository = ref.read(likesRepositoryProvider);
    if (repository == null) {
      throw const NotAuthenticatedException();
    }

    if (state.isOperationInProgress(eventId)) {
      return;
    }

    state = state.copyWith(
      operationsInProgress: {...state.operationsInProgress, eventId},
      error: null,
    );

    try {
      final reactionEventId = await repository.likeEvent(
        eventId: eventId,
        authorPubkey: authorPubkey,
      );

      state = state.copyWith(
        likedEventIds: {...state.likedEventIds, eventId},
        eventIdToReactionId: {
          ...state.eventIdToReactionId,
          eventId: reactionEventId,
        },
      );
    } finally {
      final newInProgress = {...state.operationsInProgress}..remove(eventId);
      state = state.copyWith(operationsInProgress: newInProgress);
    }
  }

  /// Unlike an event
  Future<void> unlike(String eventId) async {
    await _waitForInitialization();

    final repository = ref.read(likesRepositoryProvider);
    if (repository == null) {
      throw const NotAuthenticatedException();
    }

    if (state.isOperationInProgress(eventId)) {
      return;
    }

    state = state.copyWith(
      operationsInProgress: {...state.operationsInProgress, eventId},
      error: null,
    );

    try {
      await repository.unlikeEvent(eventId);

      final newLikedIds = {...state.likedEventIds}..remove(eventId);
      final newEventIdToReactionId = {...state.eventIdToReactionId}
        ..remove(eventId);

      state = state.copyWith(
        likedEventIds: newLikedIds,
        eventIdToReactionId: newEventIdToReactionId,
      );
    } finally {
      final newInProgress = {...state.operationsInProgress}..remove(eventId);
      state = state.copyWith(operationsInProgress: newInProgress);
    }
  }

  /// Get the like count for an event from relays
  Future<int> fetchLikeCount(String eventId) async {
    final repository = ref.read(likesRepositoryProvider);
    if (repository == null) {
      return 0;
    }

    try {
      final count = await repository.getLikeCount(eventId);
      state = state.copyWith(likeCounts: {...state.likeCounts, eventId: count});
      return count;
    } catch (e) {
      Log.error(
        'LikesNotifier: Failed to fetch like count - $e',
        name: 'LikesNotifier',
        category: LogCategory.system,
      );
      return state.getLikeCount(eventId);
    }
  }

  /// Check if an event is liked (synchronous)
  bool isLiked(String eventId) => state.isLiked(eventId);

  /// Force refresh likes from relays
  Future<void> refresh() async {
    final repository = ref.read(likesRepositoryProvider);
    if (repository != null) {
      await _initialize(repository);
    }
  }
}

/// Convenience provider to check if a specific event is liked
@riverpod
bool isEventLiked(Ref ref, String eventId) {
  final likesState = ref.watch(likesProvider);
  final isLiked = likesState.isLiked(eventId);
  Log.debug(
    '❤️ [isEventLiked] eventId=$eventId, isLiked=$isLiked, likedCount=${likesState.likedEventIds.length}',
    name: 'LikesProviders',
    category: LogCategory.system,
  );
  return isLiked;
}

/// Convenience provider to check if a like operation is in progress
@riverpod
bool isLikeInProgress(Ref ref, String eventId) {
  final likesState = ref.watch(likesProvider);
  return likesState.isOperationInProgress(eventId);
}

/// Provider to get the cached like count for an event
@riverpod
int likeCount(Ref ref, String eventId) {
  final likesState = ref.watch(likesProvider);
  return likesState.getLikeCount(eventId);
}
