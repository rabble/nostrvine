// ABOUTME: Repository for managing user likes (Kind 7 reactions).
// ABOUTME: Coordinates between NostrClient for relay operations and
// ABOUTME: LikesLocalStorage for persistence. Handles Kind 7 reactions
// ABOUTME: and Kind 5 deletions for likes/unlikes.
// ABOUTME: Supports offline queuing via callback injection.

import 'dart:async';
import 'dart:math';

import 'package:likes_repository/src/exceptions.dart';
import 'package:likes_repository/src/likes_local_storage.dart';
import 'package:likes_repository/src/models/like_record.dart';
import 'package:likes_repository/src/models/likes_sync_result.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:rxdart/rxdart.dart';

/// Default limit for fetching user reactions from relays.
const _defaultReactionFetchLimit = 500;

/// NIP-25 reaction content for a like.
const _likeContent = '+';

/// Callback to check if the device is currently online
typedef IsOnlineCallback = bool Function();

/// Callback to queue an action for offline sync
typedef QueueOfflineActionCallback =
    Future<void> Function({
      required bool isLike,
      required String eventId,
      required String authorPubkey,
      String? addressableId,
      int? targetKind,
    });

/// Repository for managing user likes (Kind 7 reactions) on Nostr events.
///
/// This repository provides a unified interface for:
/// - Liking events (publishing Kind 7 reaction events)
/// - Unliking events (publishing Kind 5 deletion events)
/// - Querying like status and counts
/// - Syncing user's reactions from relays
/// - Persisting like records locally
///
/// The repository abstracts away the complexity of:
/// - Managing the mapping between target event IDs and reaction event IDs
/// - Coordinating between Nostr relays and local storage
/// - Handling optimistic updates and error recovery
///
/// This implementation:
/// - Uses `NostrClient` to publish reactions and deletions to relays
/// - Uses `LikesLocalStorage` to persist like records locally
/// - Maintains an in-memory cache for fast lookups
/// - Provides reactive streams for UI updates
/// - Handles authentication state changes automatically
class LikesRepository {
  /// Creates a new likes repository.
  ///
  /// Parameters:
  /// - [nostrClient]: Client for Nostr relay communication
  /// - [localStorage]: Optional local storage for persistence
  /// - [authStateStream]: Optional stream of authentication state
  /// (true=authenticated)
  /// - [isAuthenticated]: Initial authentication state
  /// - [isOnline]: Optional callback to check connectivity status
  /// - [queueOfflineAction]: Optional callback to queue actions when offline
  LikesRepository({
    required NostrClient nostrClient,
    LikesLocalStorage? localStorage,
    Stream<bool>? authStateStream,
    bool isAuthenticated = false,
    IsOnlineCallback? isOnline,
    QueueOfflineActionCallback? queueOfflineAction,
  }) : _nostrClient = nostrClient,
       _localStorage = localStorage,
       _isAuthenticated = isAuthenticated,
       _isOnline = isOnline,
       _queueOfflineAction = queueOfflineAction {
    // Listen to auth state changes if stream provided
    if (authStateStream != null) {
      _authSubscription = authStateStream.listen(_handleAuthChange);
    }
  }

  final NostrClient _nostrClient;
  final LikesLocalStorage? _localStorage;
  StreamSubscription<bool>? _authSubscription;

  /// Callback to check if the device is online
  final IsOnlineCallback? _isOnline;

  /// Callback to queue actions for offline sync
  final QueueOfflineActionCallback? _queueOfflineAction;

  /// Whether the user is currently authenticated.
  bool _isAuthenticated;

  /// In-memory cache of like records keyed by target event ID.
  final Map<String, LikeRecord> _likeRecords = {};

  /// Reactive stream controller for liked event IDs.
  final _likedIdsController = BehaviorSubject<Set<String>>.seeded({});

  /// Whether the repository has been initialized with data from storage.
  bool _isInitialized = false;

  /// Emits the current set of liked event IDs.
  void _emitLikedIds() {
    _likedIdsController.add(_likeRecords.keys.toSet());
  }

  /// Stream of liked event IDs (reactive).
  ///
  /// Emits a new set whenever the user's likes change.
  /// This is useful for UI components that need to reactively update.
  Stream<Set<String>> watchLikedEventIds() {
    // If we have local storage, delegate to its reactive stream
    if (_localStorage != null) {
      return _localStorage.watchLikedEventIds();
    }
    return _likedIdsController.stream;
  }

  /// Get the current set of liked event IDs.
  ///
  /// This is a one-shot query that returns the current state.
  Future<Set<String>> getLikedEventIds() async {
    await _ensureInitialized();
    return _likeRecords.keys.toSet();
  }

  /// Get liked event IDs ordered by recency (most recently liked first).
  ///
  /// Returns a list of event IDs sorted by the `createdAt` timestamp
  /// of the like reaction, with the most recent likes first.
  Future<List<String>> getOrderedLikedEventIds() async {
    await _ensureInitialized();

    // Sort records by createdAt descending (most recent first)
    final sortedRecords = _likeRecords.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return sortedRecords.map((r) => r.targetEventId).toList();
  }

  /// Check if a specific event is liked.
  ///
  /// Returns `true` if the user has liked the event, `false` otherwise.
  Future<bool> isLiked(String eventId) async {
    await _ensureInitialized();
    return _likeRecords.containsKey(eventId);
  }

  /// Like an event.
  ///
  /// Creates and publishes a Kind 7 reaction event with content '+'.
  /// The reaction event is broadcast to Nostr relays and the mapping
  /// is stored locally for later retrieval.
  ///
  /// If the device is offline and offline queuing is enabled, the action
  /// is queued for later sync and the UI should be updated optimistically.
  ///
  /// Parameters:
  /// - [eventId]: The event ID to like (required)
  /// - [authorPubkey]: The pubkey of the event author (required)
  /// - [addressableId]: Optional addressable ID for Kind 30000+ events
  ///   (format: "kind:pubkey:d-tag"). When provided, adds an 'a' tag for
  ///   better discoverability of likes on addressable events like videos.
  /// - [targetKind]: Optional kind of the event being liked (e.g., 34236)
  ///
  /// Returns the reaction event ID (needed for unlikes), or a placeholder
  /// ID if the action was queued for offline sync.
  ///
  /// Throws `LikeFailedException` if the operation fails.
  /// Throws `AlreadyLikedException` if the event is already liked.
  Future<String> likeEvent({
    required String eventId,
    required String authorPubkey,
    String? addressableId,
    int? targetKind,
  }) async {
    await _ensureInitialized();

    // Check if already liked
    if (_likeRecords.containsKey(eventId)) {
      throw AlreadyLikedException(eventId);
    }

    // Check if offline and queue if needed
    if (_isOnline != null && !_isOnline() && _queueOfflineAction != null) {
      await _queueOfflineAction(
        isLike: true,
        eventId: eventId,
        authorPubkey: authorPubkey,
        addressableId: addressableId,
        targetKind: targetKind,
      );

      // Create optimistic local record with placeholder ID
      final placeholderId = 'pending_like_$eventId';
      final record = LikeRecord(
        targetEventId: eventId,
        reactionEventId: placeholderId,
        createdAt: DateTime.now(),
      );

      _likeRecords[eventId] = record;
      await _localStorage?.saveLikeRecord(record);
      _emitLikedIds();

      return placeholderId;
    }

    // Publish Kind 7 reaction event via NostrClient
    final reactionEvent = await _nostrClient.sendLike(
      eventId,
      content: _likeContent,
      addressableId: addressableId,
      targetAuthorPubkey: authorPubkey,
      targetKind: targetKind,
    );

    if (reactionEvent == null) {
      throw const LikeFailedException('Failed to publish like reaction');
    }

    // Create and store the like record
    final record = LikeRecord(
      targetEventId: eventId,
      reactionEventId: reactionEvent.id,
      createdAt: DateTime.now(),
    );

    _likeRecords[eventId] = record;
    await _localStorage?.saveLikeRecord(record);
    _emitLikedIds();

    return reactionEvent.id;
  }

  /// Execute a like action directly (for use by sync service).
  ///
  /// This method bypasses offline queuing and directly publishes to relays.
  /// Used by PendingActionService to execute queued actions.
  Future<String> executeLikeAction({
    required String eventId,
    required String authorPubkey,
    String? addressableId,
    int? targetKind,
  }) async {
    // Publish Kind 7 reaction event via NostrClient
    final reactionEvent = await _nostrClient.sendLike(
      eventId,
      content: _likeContent,
      addressableId: addressableId,
      targetAuthorPubkey: authorPubkey,
      targetKind: targetKind,
    );

    if (reactionEvent == null) {
      throw const LikeFailedException('Failed to publish like reaction');
    }

    // Update local record with real event ID if we have a placeholder
    final existingRecord = _likeRecords[eventId];
    if (existingRecord != null &&
        existingRecord.reactionEventId.startsWith('pending_')) {
      final record = LikeRecord(
        targetEventId: eventId,
        reactionEventId: reactionEvent.id,
        createdAt: existingRecord.createdAt,
      );
      _likeRecords[eventId] = record;
      await _localStorage?.saveLikeRecord(record);
    }

    return reactionEvent.id;
  }

  /// Unlike an event.
  ///
  /// Creates and publishes a Kind 5 deletion event referencing the
  /// original reaction event. Removes the like record from local storage.
  ///
  /// If the device is offline and offline queuing is enabled, the action
  /// is queued for later sync and the UI should be updated optimistically.
  ///
  /// Throws `UnlikeFailedException` if the operation fails.
  /// Throws `NotLikedException` if the event is not currently liked.
  Future<void> unlikeEvent(String eventId) async {
    await _ensureInitialized();

    // Try in-memory cache first, then fall back to database
    // This handles the case where the cache hasn't been populated yet
    var record = _likeRecords[eventId];
    if (record == null && _localStorage != null) {
      record = await _localStorage.getLikeRecord(eventId);
    }

    if (record == null) {
      throw NotLikedException(eventId);
    }

    // Check if offline and queue if needed
    if (_isOnline != null && !_isOnline() && _queueOfflineAction != null) {
      await _queueOfflineAction(
        isLike: false,
        eventId: eventId,
        authorPubkey: '', // Not needed for unlike
      );

      // Remove from cache and storage optimistically
      _likeRecords.remove(eventId);
      await _localStorage?.deleteLikeRecord(eventId);
      _emitLikedIds();

      return;
    }

    // Skip publishing deletion if this was a pending like that never synced
    if (!record.reactionEventId.startsWith('pending_')) {
      // Publish Kind 5 deletion event via NostrClient
      final deletionEvent = await _nostrClient.deleteEvent(
        record.reactionEventId,
      );

      if (deletionEvent == null) {
        throw const UnlikeFailedException('Failed to publish unlike deletion');
      }
    }

    // Remove from cache and storage
    _likeRecords.remove(eventId);
    await _localStorage?.deleteLikeRecord(eventId);
    _emitLikedIds();
  }

  /// Execute an unlike action directly (for use by sync service).
  ///
  /// This method bypasses offline queuing and directly publishes to relays.
  /// Used by PendingActionService to execute queued actions.
  Future<void> executeUnlikeAction(String eventId) async {
    // Try to get the record - it may not exist if the like was also offline
    var record = _likeRecords[eventId];
    if (record == null && _localStorage != null) {
      record = await _localStorage.getLikeRecord(eventId);
    }

    // If no record exists, the like was never synced either, so we're done
    if (record == null) {
      return;
    }

    // Skip publishing if this was a pending like
    if (record.reactionEventId.startsWith('pending_')) {
      // Just clean up local storage
      _likeRecords.remove(eventId);
      await _localStorage?.deleteLikeRecord(eventId);
      _emitLikedIds();
      return;
    }

    // Publish Kind 5 deletion event via NostrClient
    final deletionEvent = await _nostrClient.deleteEvent(
      record.reactionEventId,
    );

    if (deletionEvent == null) {
      throw const UnlikeFailedException('Failed to publish unlike deletion');
    }

    // Remove from cache and storage
    _likeRecords.remove(eventId);
    await _localStorage?.deleteLikeRecord(eventId);
    _emitLikedIds();
  }

  /// Toggle like status for an event.
  ///
  /// If the event is not liked, likes it and returns `true`.
  /// If the event is liked, unlikes it and returns `false`.
  ///
  /// Parameters:
  /// - [eventId]: The event ID to toggle like on (required)
  /// - [authorPubkey]: The pubkey of the event author (required)
  /// - [addressableId]: Optional addressable ID for Kind 30000+ events
  ///   (format: "kind:pubkey:d-tag"). When provided, adds an 'a' tag for
  ///   better discoverability of likes on addressable events like videos.
  /// - [targetKind]: Optional kind of the event being liked (e.g., 34236)
  ///
  /// This is a convenience method that combines [isLiked], [likeEvent],
  /// and [unlikeEvent].
  Future<bool> toggleLike({
    required String eventId,
    required String authorPubkey,
    String? addressableId,
    int? targetKind,
  }) async {
    await _ensureInitialized();

    // Query the database directly as source of truth to avoid cache/db
    // inconsistency after app restart
    final isCurrentlyLiked =
        await _localStorage?.isLiked(eventId) ??
        _likeRecords.containsKey(eventId);

    if (isCurrentlyLiked) {
      await unlikeEvent(eventId);
      return false;
    } else {
      await likeEvent(
        eventId: eventId,
        authorPubkey: authorPubkey,
        addressableId: addressableId,
        targetKind: targetKind,
      );
      return true;
    }
  }

  /// Get the like count for an event.
  ///
  /// Queries relays for the count of Kind 7 reactions on the event.
  /// When [addressableId] is provided, queries by both 'e' and 'a' tags
  /// and returns the maximum count (since relays may index differently).
  ///
  /// Note: This counts all likes, not just the current user's.
  Future<int> getLikeCount(String eventId, {String? addressableId}) async {
    // Query relays for count of Kind 7 reactions on this event
    final filterByE = Filter(
      kinds: const [EventKind.reaction],
      e: [eventId],
    );

    // If addressable ID provided, query by both e and a tags
    if (addressableId != null && addressableId.isNotEmpty) {
      final filterByA = Filter(
        kinds: const [EventKind.reaction],
        a: [addressableId],
      );

      // Query both filters in parallel and return the maximum count
      // Some relays may index by e-tag, others by a-tag
      final results = await Future.wait([
        _nostrClient.countEvents([filterByE]),
        _nostrClient.countEvents([filterByA]),
      ]);

      return max(results[0].count, results[1].count);
    }

    final result = await _nostrClient.countEvents([filterByE]);
    return result.count;
  }

  /// Get like counts for multiple events in a single batched query.
  ///
  /// Queries relays for the count of Kind 7 reactions on each event.
  /// This is more efficient than calling [getLikeCount] multiple times
  /// as it sends a single request with multiple event IDs in the filter.
  ///
  /// Parameters:
  /// - [eventIds]: List of event IDs to get counts for
  /// - [addressableIds]: Optional map of event ID to addressable ID for
  ///   Kind 30000+ events. When provided, also queries by 'a' tag and
  ///   merges results (taking max count per event).
  ///
  /// Returns a map of event ID to like count. Events with zero likes
  /// are included with a count of 0.
  ///
  /// Note: This counts all likes, not just the current user's.
  Future<Map<String, int>> getLikeCounts(
    List<String> eventIds, {
    Map<String, String>? addressableIds,
  }) async {
    if (eventIds.isEmpty) return {};

    // Query relays for count of Kind 7 reactions on all events at once
    // Using a single filter with multiple event IDs in the 'e' array
    final filterByE = Filter(
      kinds: const [EventKind.reaction],
      e: eventIds,
    );

    // NIP-45 COUNT with multiple event IDs returns total count, not per-event
    // So we need to fall back to querying events and counting client-side
    final eventsByE = await _nostrClient.queryEvents([filterByE]);

    // Count reactions per target event from e-tag query
    final counts = <String, int>{};
    for (final eventId in eventIds) {
      counts[eventId] = 0;
    }

    for (final event in eventsByE) {
      // Find the 'e' tag that references the target event
      for (final tag in event.tags) {
        if (tag is List && tag.isNotEmpty && tag[0] == 'e' && tag.length > 1) {
          final targetId = tag[1] as String;
          if (counts.containsKey(targetId)) {
            counts[targetId] = counts[targetId]! + 1;
          }
        }
      }
    }

    // If addressable IDs provided, also query by a-tag and merge results
    if (addressableIds != null && addressableIds.isNotEmpty) {
      final aTagValues = addressableIds.values.toList();
      final filterByA = Filter(
        kinds: const [EventKind.reaction],
        a: aTagValues,
      );

      final eventsByA = await _nostrClient.queryEvents([filterByA]);

      // Create reverse lookup: addressableId -> eventId
      final aTagToEventId = <String, String>{};
      for (final entry in addressableIds.entries) {
        aTagToEventId[entry.value] = entry.key;
      }

      // Count reactions from a-tag query
      final countsFromA = <String, int>{};
      for (final eventId in eventIds) {
        countsFromA[eventId] = 0;
      }

      for (final event in eventsByA) {
        for (final tag in event.tags) {
          if (tag is List &&
              tag.isNotEmpty &&
              tag[0] == 'a' &&
              tag.length > 1) {
            final aTagValue = tag[1] as String;
            final eventId = aTagToEventId[aTagValue];
            if (eventId != null && countsFromA.containsKey(eventId)) {
              countsFromA[eventId] = countsFromA[eventId]! + 1;
            }
          }
        }
      }

      // Merge counts, taking maximum for each event
      for (final eventId in eventIds) {
        counts[eventId] = max(counts[eventId]!, countsFromA[eventId] ?? 0);
      }
    }

    return counts;
  }

  /// Get a like record by target event ID.
  ///
  /// Returns the full [LikeRecord] including the reaction event ID,
  /// or `null` if the event is not liked.
  Future<LikeRecord?> getLikeRecord(String eventId) async {
    await _ensureInitialized();
    return _likeRecords[eventId];
  }

  /// Sync all user's reactions from relays.
  ///
  /// Fetches the user's Kind 7 events from relays and updates local storage.
  /// Also fetches Kind 5 deletion events to filter out unliked reactions.
  /// This should be called on startup to ensure local state matches relay
  /// state.
  ///
  /// Returns a [LikesSyncResult] containing all synced data needed by the UI.
  ///
  /// Throws `SyncFailedException` if syncing fails.
  Future<LikesSyncResult> syncUserReactions() async {
    // First, load from local storage (fast)
    if (_localStorage != null) {
      final records = await _localStorage.getAllLikeRecords();
      for (final record in records) {
        _likeRecords[record.targetEventId] = record;
      }
      _emitLikedIds();
    }

    // Fetch both reactions and deletions from relays (authoritative)
    final reactionsFilter = Filter(
      kinds: const [EventKind.reaction],
      authors: [_nostrClient.publicKey],
      limit: _defaultReactionFetchLimit,
    );

    final deletionsFilter = Filter(
      kinds: const [EventKind.eventDeletion],
      authors: [_nostrClient.publicKey],
      limit: _defaultReactionFetchLimit,
    );

    try {
      // Fetch reactions and deletions in parallel
      final results = await Future.wait([
        _nostrClient.queryEvents([reactionsFilter]),
        _nostrClient.queryEvents([deletionsFilter]),
      ]);

      final reactionEvents = results[0];
      final deletionEvents = results[1];

      // Build set of deleted reaction event IDs from Kind 5 events
      final deletedReactionIds = <String>{};
      for (final deletion in deletionEvents) {
        for (final tag in deletion.tags) {
          if (tag is List &&
              tag.isNotEmpty &&
              tag[0] == 'e' &&
              tag.length > 1) {
            deletedReactionIds.add(tag[1] as String);
          }
        }
      }

      final newRecords = <LikeRecord>[];
      final deletedTargetIds = <String>[];

      for (final event in reactionEvents) {
        // Skip reactions that have been deleted
        if (deletedReactionIds.contains(event.id)) {
          // If we have this in local storage, mark for deletion
          final targetId = _extractTargetEventId(event);
          if (targetId != null && _likeRecords.containsKey(targetId)) {
            deletedTargetIds.add(targetId);
          }
          continue;
        }

        final targetId = _extractTargetEventId(event);
        if (targetId != null && event.content == _likeContent) {
          final record = LikeRecord(
            targetEventId: targetId,
            reactionEventId: event.id,
            createdAt: DateTime.fromMillisecondsSinceEpoch(
              event.createdAt * 1000,
            ),
          );

          // Only update if we don't have this record or the new one is newer
          final existing = _likeRecords[targetId];
          if (existing == null ||
              record.createdAt.isAfter(existing.createdAt)) {
            _likeRecords[targetId] = record;
            newRecords.add(record);
          }
        }
      }

      // Remove deleted likes from cache and storage
      for (final targetId in deletedTargetIds) {
        _likeRecords.remove(targetId);
        await _localStorage?.deleteLikeRecord(targetId);
      }

      // Batch save new records to storage
      if (newRecords.isNotEmpty && _localStorage != null) {
        await _localStorage.saveLikeRecordsBatch(newRecords);
      }

      _emitLikedIds();
      _isInitialized = true;

      return _buildSyncResult();
    } catch (e) {
      // If relay sync fails but we have local data, don't throw
      if (_likeRecords.isNotEmpty) {
        _isInitialized = true;
        return _buildSyncResult();
      }
      throw SyncFailedException('Failed to sync user reactions: $e');
    }
  }

  /// Fetch liked event IDs for any user from relays.
  ///
  /// Unlike [syncUserReactions], this method:
  /// - Does NOT cache results locally (since it's not the current user's data)
  /// - Does NOT require authentication
  /// - Is intended for viewing other users' liked content
  ///
  /// Returns a list of event IDs that the specified user has liked,
  /// ordered by recency (most recent first).
  ///
  /// Parameters:
  /// - [pubkey]: The public key (hex) of the user whose likes to fetch
  ///
  /// Throws [FetchLikesFailedException] if the fetch fails.
  Future<List<String>> fetchUserLikes(String pubkey) async {
    final filter = Filter(
      kinds: const [EventKind.reaction],
      authors: [pubkey],
      limit: _defaultReactionFetchLimit,
    );

    try {
      final events = await _nostrClient.queryEvents([filter]);
      final likedEventIds = <String>[];
      final seenIds = <String>{};

      // Sort events by createdAt descending (most recent first)
      events.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      for (final event in events) {
        // Only process '+' reactions (likes)
        if (event.content != _likeContent) continue;

        final targetId = _extractTargetEventId(event);
        if (targetId != null && !seenIds.contains(targetId)) {
          seenIds.add(targetId);
          likedEventIds.add(targetId);
        }
      }

      return likedEventIds;
    } catch (e) {
      throw FetchLikesFailedException(
        'Failed to fetch likes for user $pubkey: $e',
      );
    }
  }

  /// Builds a [LikesSyncResult] from the current in-memory cache.
  LikesSyncResult _buildSyncResult() {
    // Sort records by createdAt descending (most recent first)
    final sortedRecords = _likeRecords.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final orderedEventIds = sortedRecords.map((r) => r.targetEventId).toList();
    final eventIdToReactionId = <String, String>{};
    for (final record in sortedRecords) {
      eventIdToReactionId[record.targetEventId] = record.reactionEventId;
    }

    return LikesSyncResult(
      orderedEventIds: orderedEventIds,
      eventIdToReactionId: eventIdToReactionId,
    );
  }

  /// Clear all local like data.
  ///
  /// Used when logging out or clearing user data.
  /// Does not affect data on relays.
  Future<void> clearCache() async {
    _likeRecords.clear();
    await _localStorage?.clearAll();
    _emitLikedIds();
    _isInitialized = false;
  }

  /// Dispose of resources.
  ///
  /// Should be called when the repository is no longer needed.
  void dispose() {
    unawaited(_authSubscription?.cancel());
    unawaited(_likedIdsController.close());
  }

  /// Handle authentication state changes.
  ///
  /// When user logs out, clears the cache.
  /// When user logs in, triggers a sync.
  void _handleAuthChange(bool isAuthenticated) {
    if (isAuthenticated == _isAuthenticated) return;

    _isAuthenticated = isAuthenticated;

    if (!isAuthenticated) {
      // User logged out - clear cache
      unawaited(clearCache());
    } else {
      // User logged in - sync will be triggered by BLoC
      // Just mark as not initialized so next operation triggers init
      _isInitialized = false;
    }
  }

  /// Ensures the repository is initialized with data from storage.
  Future<void> _ensureInitialized() async {
    if (_isInitialized) return;

    if (_localStorage != null) {
      final records = await _localStorage.getAllLikeRecords();
      for (final record in records) {
        _likeRecords[record.targetEventId] = record;
      }
      _emitLikedIds();
    }
    _isInitialized = true;
  }

  /// Extracts the target event ID from a reaction event's 'e' tag.
  ///
  /// According to NIP-25, the 'e' tag contains the event ID being reacted to.
  String? _extractTargetEventId(Event event) {
    for (final tag in event.tags) {
      if (tag is List && tag.isNotEmpty && tag[0] == 'e' && tag.length > 1) {
        return tag[1] as String;
      }
    }
    return null;
  }
}
