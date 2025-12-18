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

  @override
  LikesState build() {
    // Listen to auth state changes
    ref.listen(authServiceProvider, (previous, current) {
      final previousAuth = previous?.isAuthenticated ?? false;
      final currentAuth = current.isAuthenticated;

      if (!previousAuth && currentAuth) {
        // User logged in - initialize
        _initialize();
      } else if (previousAuth && !currentAuth) {
        // User logged out - clear state
        _clearState();
      }
    }, fireImmediately: true);

    ref.onDispose(_cleanup);

    return LikesState.initial;
  }

  /// Initialize the likes state
  ///
  /// Called when user authenticates. Syncs with local storage and relays.
  Future<void> _initialize() async {
    final repository = ref.read(likesRepositoryProvider);
    if (repository == null) {
      Log.warning(
        'LikesNotifier: Cannot initialize - repository not available',
        name: 'LikesNotifier',
        category: LogCategory.system,
      );
      return;
    }

    state = state.copyWith(isSyncing: true, error: null);

    try {
      // Sync user's reactions from relays
      await repository.syncUserReactions();

      // Get initial liked IDs
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
        isInitialized: true,
        isSyncing: false,
      );

      // Subscribe to reactive updates
      _subscribeTeLikedIds(repository);

      Log.info(
        'LikesNotifier: Initialized with ${likedIds.length} liked events',
        name: 'LikesNotifier',
        category: LogCategory.system,
      );
    } on SyncFailedException catch (e) {
      Log.error(
        'LikesNotifier: Sync failed - $e',
        name: 'LikesNotifier',
        category: LogCategory.system,
      );
      state = state.copyWith(isSyncing: false, error: e.message);
    } catch (e) {
      Log.error(
        'LikesNotifier: Initialization failed - $e',
        name: 'LikesNotifier',
        category: LogCategory.system,
      );
      state = state.copyWith(isSyncing: false, error: e.toString());
    }
  }

  /// Subscribe to reactive liked IDs stream from repository
  void _subscribeTeLikedIds(LikesRepository repository) {
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

  /// Clear state when user logs out
  Future<void> _clearState() async {
    _likedIdsSubscription?.cancel();
    _likedIdsSubscription = null;

    final repository = ref.read(likesRepositoryProvider);
    if (repository != null) {
      await repository.clearCache();
    }

    state = LikesState.initial;

    Log.info(
      'LikesNotifier: State cleared on logout',
      name: 'LikesNotifier',
      category: LogCategory.system,
    );
  }

  /// Cleanup resources
  void _cleanup() {
    _likedIdsSubscription?.cancel();
    _likedIdsSubscription = null;
  }

  /// Toggle like status for an event
  ///
  /// If the event is not liked, likes it.
  /// If the event is liked, unlikes it.
  ///
  /// Returns true if the event is now liked, false if unliked.
  /// Throws if the operation fails.
  Future<bool> toggleLike({
    required String eventId,
    required String authorPubkey,
  }) async {
    final repository = ref.read(likesRepositoryProvider);
    if (repository == null) {
      throw const NotAuthenticatedException();
    }

    // Prevent duplicate operations
    if (state.isOperationInProgress(eventId)) {
      Log.debug(
        'LikesNotifier: Operation already in progress for $eventId',
        name: 'LikesNotifier',
        category: LogCategory.system,
      );
      return state.isLiked(eventId);
    }

    // Mark operation as in progress
    state = state.copyWith(
      operationsInProgress: {...state.operationsInProgress, eventId},
      error: null,
    );

    try {
      final isNowLiked = await repository.toggleLike(
        eventId: eventId,
        authorPubkey: authorPubkey,
      );

      // Update local state optimistically
      // The reactive stream will also update, but this ensures immediate UI feedback
      if (isNowLiked) {
        final record = await repository.getLikeRecord(eventId);
        state = state.copyWith(
          likedEventIds: {...state.likedEventIds, eventId},
          eventIdToReactionId: record != null
              ? {...state.eventIdToReactionId, eventId: record.reactionEventId}
              : state.eventIdToReactionId,
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

      Log.debug(
        'LikesNotifier: Toggled like for $eventId -> $isNowLiked',
        name: 'LikesNotifier',
        category: LogCategory.system,
      );

      return isNowLiked;
    } on AlreadyLikedException {
      // Already liked - just return current state
      return true;
    } on NotLikedException {
      // Not liked - just return current state
      return false;
    } on LikeFailedException catch (e) {
      Log.error(
        'LikesNotifier: Like failed - ${e.message}',
        name: 'LikesNotifier',
        category: LogCategory.system,
      );
      state = state.copyWith(error: e.message);
      rethrow;
    } on UnlikeFailedException catch (e) {
      Log.error(
        'LikesNotifier: Unlike failed - ${e.message}',
        name: 'LikesNotifier',
        category: LogCategory.system,
      );
      state = state.copyWith(error: e.message);
      rethrow;
    } finally {
      // Remove from in-progress set
      final newInProgress = {...state.operationsInProgress}..remove(eventId);
      state = state.copyWith(operationsInProgress: newInProgress);
    }
  }

  /// Like an event
  ///
  /// Throws [AlreadyLikedException] if already liked.
  /// Throws [LikeFailedException] if the operation fails.
  Future<void> like({
    required String eventId,
    required String authorPubkey,
  }) async {
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

      Log.info(
        'LikesNotifier: Liked event $eventId',
        name: 'LikesNotifier',
        category: LogCategory.system,
      );
    } finally {
      final newInProgress = {...state.operationsInProgress}..remove(eventId);
      state = state.copyWith(operationsInProgress: newInProgress);
    }
  }

  /// Unlike an event
  ///
  /// Throws [NotLikedException] if not currently liked.
  /// Throws [UnlikeFailedException] if the operation fails.
  Future<void> unlike(String eventId) async {
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

      Log.info(
        'LikesNotifier: Unliked event $eventId',
        name: 'LikesNotifier',
        category: LogCategory.system,
      );
    } finally {
      final newInProgress = {...state.operationsInProgress}..remove(eventId);
      state = state.copyWith(operationsInProgress: newInProgress);
    }
  }

  /// Get the like count for an event from relays
  ///
  /// Queries relays for the count and caches the result.
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

  /// Check if an event is liked
  ///
  /// Synchronous check using cached state.
  bool isLiked(String eventId) => state.isLiked(eventId);

  /// Force refresh likes from relays
  Future<void> refresh() async {
    await _initialize();
  }
}

/// Convenience provider to check if a specific event is liked
///
/// Usage:
/// ```dart
/// final isLiked = ref.watch(isEventLikedProvider(eventId));
/// ```
@riverpod
bool isEventLiked(Ref ref, String eventId) {
  final likesState = ref.watch(likesProvider);
  return likesState.isLiked(eventId);
}

/// Convenience provider to check if a like operation is in progress
///
/// Usage:
/// ```dart
/// final isLoading = ref.watch(isLikeInProgressProvider(eventId));
/// ```
@riverpod
bool isLikeInProgress(Ref ref, String eventId) {
  final likesState = ref.watch(likesProvider);
  return likesState.isOperationInProgress(eventId);
}

/// Provider to get the cached like count for an event
///
/// Usage:
/// ```dart
/// final likeCount = ref.watch(likeCountProvider(eventId));
/// ```
@riverpod
int likeCount(Ref ref, String eventId) {
  final likesState = ref.watch(likesProvider);
  return likesState.getLikeCount(eventId);
}
