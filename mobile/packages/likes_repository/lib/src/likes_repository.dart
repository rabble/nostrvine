// ABOUTME: Repository for managing user likes (Kind 7 reactions).
// ABOUTME: Coordinates between NostrClient for relay operations and
// ABOUTME: LikesLocalStorage for persistence. Handles Kind 7 reactions
// ABOUTME: and Kind 5 deletions for likes/unlikes.

import 'dart:async';

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

/// Kind 7 is the NIP-25 reaction event kind.
const _reactionKind = 7;

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
class LikesRepository {
  /// Creates a new likes repository.
  ///
  /// Parameters:
  /// - [nostrClient]: Client for Nostr relay communication
  /// - [localStorage]: Optional local storage for persistence
  LikesRepository({
    required NostrClient nostrClient,
    LikesLocalStorage? localStorage,
  }) : _nostrClient = nostrClient,
       _localStorage = localStorage;

  final NostrClient _nostrClient;
  final LikesLocalStorage? _localStorage;

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
  /// Returns the reaction event ID (needed for unlikes).
  ///
  /// Throws `LikeFailedException` if the operation fails.
  /// Throws `AlreadyLikedException` if the event is already liked.
  Future<String> likeEvent({
    required String eventId,
    required String authorPubkey,
  }) async {
    await _ensureInitialized();

    // Check if already liked
    if (_likeRecords.containsKey(eventId)) {
      throw AlreadyLikedException(eventId);
    }

    // Publish Kind 7 reaction event via NostrClient
    final reactionEvent = await _nostrClient.sendLike(
      eventId,
      content: _likeContent,
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

  /// Unlike an event.
  ///
  /// Creates and publishes a Kind 5 deletion event referencing the
  /// original reaction event. Removes the like record from local storage.
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
  /// This is a convenience method that combines [isLiked], [likeEvent],
  /// and [unlikeEvent].
  Future<bool> toggleLike({
    required String eventId,
    required String authorPubkey,
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
      await likeEvent(eventId: eventId, authorPubkey: authorPubkey);
      return true;
    }
  }

  /// Get the like count for an event.
  ///
  /// Queries relays for the count of Kind 7 reactions on the event.
  /// Note: This counts all likes, not just the current user's.
  Future<int> getLikeCount(String eventId) async {
    // Query relays for count of Kind 7 reactions on this event
    final filter = Filter(
      kinds: const [_reactionKind],
      e: [eventId],
    );

    final result = await _nostrClient.countEvents([filter]);
    return result.count;
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

    // Then, fetch from relays (authoritative)
    final filter = Filter(
      kinds: const [_reactionKind],
      authors: [_nostrClient.publicKey],
      limit: _defaultReactionFetchLimit,
    );

    try {
      final events = await _nostrClient.queryEvents([filter]);
      final newRecords = <LikeRecord>[];

      for (final event in events) {
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
    unawaited(_likedIdsController.close());
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
