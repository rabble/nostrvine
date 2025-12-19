// ABOUTME: Riverpod providers for likes feature using LikesRepository
// ABOUTME: Provides reactive state management for like/unlike operations

import 'dart:async';

import 'package:likes_repository/likes_repository.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/auth_service.dart';
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
    // Listen to auth state changes (like SocialNotifier pattern)
    // This is more reliable than listening to repository because auth state
    // transitions are explicit enums, not null-checks on repository instances
    ref.listen(authServiceProvider, (previous, current) {
      final previousState = previous?.authState;
      final currentState = current.authState;

      Log.debug(
        'LikesNotifier: Auth state: '
        '${previousState?.name ?? 'null'} → ${currentState.name}',
        name: 'LikesNotifier',
        category: LogCategory.system,
      );

      if (currentState == AuthState.authenticated) {
        // Schedule initialization for after build() completes
        // This is necessary because fireImmediately triggers during build(),
        // before state is available
        Future.microtask(_initializeIfNeeded);
      } else if (previousState == AuthState.authenticated &&
          currentState != AuthState.authenticated) {
        // User logged out
        _clearState();
      }
    }, fireImmediately: true);

    ref.onDispose(_cleanup);

    return LikesState.initial;
  }

  /// Initialize if not already initialized
  void _initializeIfNeeded() {
    if (!state.isInitialized) {
      Log.info(
        'LikesNotifier: Starting initialization',
        name: 'LikesNotifier',
        category: LogCategory.system,
      );
      _initialize();
    }
  }

  /// Initialize the likes state
  ///
  /// Called when user authenticates. Syncs with local storage and relays.
  Future<void> _initialize() async {
    // Prevent concurrent initialization - if already in progress, skip
    if (_initializationCompleter != null &&
        !_initializationCompleter!.isCompleted) {
      return;
    }

    // Create a new completer for this initialization
    _initializationCompleter = Completer<void>();

    final repository = ref.read(likesRepositoryProvider);
    if (repository == null) {
      Log.warning(
        'LikesNotifier: Cannot initialize - repository not available '
        '(auth may still be initializing)',
        name: 'LikesNotifier',
        category: LogCategory.system,
      );
      _initializationCompleter?.complete();
      return;
    }

    state = state.copyWith(isSyncing: true, error: null);

    // CRITICAL: Load state from local storage IMMEDIATELY before any async ops
    // This ensures UI shows correct liked state right away on app restart
    try {
      await _updateStateFromRepository(repository);
      Log.info(
        'LikesNotifier: Initial load complete - ${state.likedEventIds.length} '
        'likes loaded from storage',
        name: 'LikesNotifier',
        category: LogCategory.system,
      );
    } catch (e, stackTrace) {
      Log.error(
        'LikesNotifier: Failed to load from storage: $e\n$stackTrace',
        name: 'LikesNotifier',
        category: LogCategory.system,
      );
    }

    // Subscribe to reactive updates for live changes
    _subscribeToLikedIds(repository);

    try {
      // Sync user's reactions from relays (may fetch newer data)
      await repository.syncUserReactions();

      // Update state again with any new data from relays
      await _updateStateFromRepository(repository, markInitialized: true);

      Log.info(
        'LikesNotifier: Initialized with ${state.likedEventIds.length} '
        'liked events',
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
      // Still mark as initialized since we have local data
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
  ///
  /// Loads liked IDs and reaction ID mappings from the repository's cache
  /// (which is backed by local storage).
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

    Log.debug(
      'LikesNotifier: Loaded ${likedIds.length} likes from storage',
      name: 'LikesNotifier',
      category: LogCategory.system,
    );
  }

  /// Wait for initialization to complete (if in progress)
  Future<void> _waitForInitialization() async {
    if (_initializationCompleter != null &&
        !_initializationCompleter!.isCompleted) {
      Log.debug(
        'LikesNotifier: Waiting for initialization to complete...',
        name: 'LikesNotifier',
        category: LogCategory.system,
      );
      await _initializationCompleter!.future;
    }
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
    Log.debug(
      'toggleLike called for $eventId (initialized: ${state.isInitialized})',
      name: 'LikesNotifier',
      category: LogCategory.system,
    );

    // Wait for any pending initialization to complete
    await _waitForInitialization();

    final repository = ref.read(likesRepositoryProvider);
    if (repository == null) {
      Log.error(
        'toggleLike failed: repository is null (user not authenticated)',
        name: 'LikesNotifier',
        category: LogCategory.system,
      );
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
    // Wait for any pending initialization to complete
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
    // Wait for any pending initialization to complete
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
