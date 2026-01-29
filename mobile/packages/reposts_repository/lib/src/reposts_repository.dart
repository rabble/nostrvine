// ABOUTME: Repository for managing user reposts (Kind 16 generic reposts).
// ABOUTME: Coordinates between NostrClient for relay operations and
// ABOUTME: RepostsLocalStorage for persistence. Handles Kind 16 reposts
// ABOUTME: and Kind 5 deletions for repost/unrepost.

import 'dart:async';

import 'package:meta/meta.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:reposts_repository/src/exceptions.dart';
import 'package:reposts_repository/src/models/repost_record.dart';
import 'package:reposts_repository/src/models/reposts_sync_result.dart';
import 'package:reposts_repository/src/reposts_local_storage.dart';
import 'package:rxdart/rxdart.dart';

/// Default limit for fetching user reposts from relays.
const _defaultRepostFetchLimit = 500;

/// Repository for managing user reposts (Kind 16 generic reposts) on videos.
///
/// This repository provides a unified interface for:
/// - Reposting videos (publishing Kind 16 generic repost events)
/// - Unreposting videos (publishing Kind 5 deletion events)
/// - Querying repost status
/// - Syncing user's reposts from relays
/// - Persisting repost records locally
///
/// The repository abstracts away the complexity of:
/// - Managing the mapping between addressable IDs and repost event IDs
/// - Coordinating between Nostr relays and local storage
/// - Handling optimistic updates and error recovery
///
/// This implementation:
/// - Uses `NostrClient` to publish reposts and deletions to relays
/// - Uses `RepostsLocalStorage` to persist repost records locally
/// - Maintains an in-memory cache for fast lookups
/// - Provides reactive streams for UI updates
/// - Handles authentication state changes automatically
class RepostsRepository {
  /// Creates a new reposts repository.
  ///
  /// Parameters:
  /// - [nostrClient]: Client for Nostr relay communication
  /// - [localStorage]: Optional local storage for persistence
  /// - [authStateStream]: Optional stream of authentication state
  /// - [isAuthenticated]: Initial authentication state
  RepostsRepository({
    required NostrClient nostrClient,
    RepostsLocalStorage? localStorage,
    Stream<bool>? authStateStream,
    bool isAuthenticated = false,
  }) : _nostrClient = nostrClient,
       _localStorage = localStorage,
       _isAuthenticated = isAuthenticated {
    // Listen to auth state changes if stream provided
    if (authStateStream != null) {
      _authSubscription = authStateStream.listen(_handleAuthChange);
    }
  }

  final NostrClient _nostrClient;
  final RepostsLocalStorage? _localStorage;
  StreamSubscription<bool>? _authSubscription;

  /// Whether the user is currently authenticated.
  bool _isAuthenticated;

  /// In-memory cache of repost records keyed by addressable ID.
  final Map<String, RepostRecord> _repostRecords = {};

  /// Reactive stream controller for reposted addressable IDs.
  final _repostedIdsController = BehaviorSubject<Set<String>>.seeded({});

  /// Whether the repository has been initialized with data from storage.
  bool _isInitialized = false;

  /// Emits the current set of reposted addressable IDs.
  void _emitRepostedIds() {
    _repostedIdsController.add(_repostRecords.keys.toSet());
  }

  /// Stream of reposted addressable IDs (reactive).
  ///
  /// Emits a new set whenever the user's reposts change.
  /// This is useful for UI components that need to reactively update.
  Stream<Set<String>> watchRepostedAddressableIds() {
    // If we have local storage, delegate to its reactive stream
    if (_localStorage != null) {
      return _localStorage.watchRepostedAddressableIds();
    }
    return _repostedIdsController.stream;
  }

  /// Get the current set of reposted addressable IDs.
  ///
  /// This is a one-shot query that returns the current state.
  Future<Set<String>> getRepostedAddressableIds() async {
    await _ensureInitialized();
    return _repostRecords.keys.toSet();
  }

  /// Get reposted addressable IDs ordered by recency (most recent first).
  ///
  /// Returns a list of addressable IDs sorted by the `createdAt` timestamp
  /// of the repost, with the most recent reposts first.
  Future<List<String>> getOrderedRepostedAddressableIds() async {
    await _ensureInitialized();

    // Sort records by createdAt descending (most recent first)
    final sortedRecords = _repostRecords.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return sortedRecords.map((r) => r.addressableId).toList();
  }

  /// Check if a specific video is reposted.
  ///
  /// Returns `true` if the user has reposted the video, `false` otherwise.
  Future<bool> isReposted(String addressableId) async {
    await _ensureInitialized();
    return _repostRecords.containsKey(addressableId);
  }

  /// Check if a video is reposted (synchronous, from cache only).
  ///
  /// This is useful for UI components that need immediate feedback.
  /// Note: May return stale data if cache hasn't been initialized.
  bool isRepostedSync(String addressableId) {
    return _repostRecords.containsKey(addressableId);
  }

  /// Get the repost count for a video by its addressable ID.
  ///
  /// Queries relays for the count of Kind 16 generic reposts referencing the
  /// video by its addressable ID (using the `a` tag).
  ///
  /// Note: This counts all reposts from all users, not just the current user's.
  Future<int> getRepostCount(String addressableId) async {
    // Query relays for count of Kind 16 reposts referencing this addressable ID
    final filter = Filter(
      kinds: const [EventKind.genericRepost],
      a: [addressableId],
    );

    final result = await _nostrClient.countEvents([filter]);
    return result.count;
  }

  /// Get the repost count for a video by its event ID.
  ///
  /// Queries relays for the count of Kind 6 (repost) and Kind 16 (generic
  /// repost) events referencing the video by its event ID (using the `e` tag).
  ///
  /// Use this method for non-addressable videos (videos without a d-tag).
  ///
  /// Note: This counts all reposts from all users, not just the current user's.
  Future<int> getRepostCountByEventId(String eventId) async {
    // Query relays for count of Kind 6 and Kind 16 reposts referencing this
    // event ID
    final filter = Filter(
      kinds: const [EventKind.repost, EventKind.genericRepost],
      e: [eventId],
    );

    final result = await _nostrClient.countEvents([filter]);
    return result.count;
  }

  /// Repost a video.
  ///
  /// Creates and publishes a Kind 16 generic repost event.
  /// The repost event is broadcast to Nostr relays and the mapping
  /// is stored locally for later retrieval.
  ///
  /// Parameters:
  /// - [addressableId]: The addressable ID of the video (kind:pubkey:d-tag)
  /// - [originalAuthorPubkey]: The pubkey of the video's author
  /// - [eventId]: Optional event ID for better relay compatibility. Including
  ///   this allows relays to index the repost by `#e` tag, which is more
  ///   universally supported than `#a` tag.
  ///
  /// Returns the repost event ID (needed for unreposts).
  ///
  /// Throws `RepostFailedException` if the operation fails.
  /// Throws `AlreadyRepostedException` if the video is already reposted.
  /// Throws `MissingDTagException` if the video is missing a d-tag.
  Future<String> repostVideo({
    required String addressableId,
    required String originalAuthorPubkey,
    String? eventId,
  }) async {
    await _ensureInitialized();

    // Check if already reposted
    if (_repostRecords.containsKey(addressableId)) {
      throw AlreadyRepostedException(addressableId);
    }

    // Create and publish Kind 16 generic repost event
    final sentEvent = await _nostrClient.sendGenericRepost(
      addressableId: addressableId,
      targetKind: EventKind.videoVertical,
      authorPubkey: originalAuthorPubkey,
      eventId: eventId,
    );

    if (sentEvent == null) {
      throw const RepostFailedException('Failed to publish repost to relays');
    }

    // Create and store the repost record
    final record = RepostRecord(
      addressableId: addressableId,
      repostEventId: sentEvent.id,
      originalAuthorPubkey: originalAuthorPubkey,
      createdAt: DateTime.now(),
    );

    _repostRecords[addressableId] = record;
    await _localStorage?.saveRepostRecord(record);
    _emitRepostedIds();

    return sentEvent.id;
  }

  /// Unrepost a video.
  ///
  /// Creates and publishes a Kind 5 deletion event referencing the
  /// original repost event. Removes the repost record from local storage.
  ///
  /// Throws `UnrepostFailedException` if the operation fails.
  /// Throws `NotRepostedException` if the video is not currently reposted.
  Future<void> unrepostVideo(String addressableId) async {
    await _ensureInitialized();

    // Try in-memory cache first, then fall back to database
    var record = _repostRecords[addressableId];
    if (record == null && _localStorage != null) {
      record = await _localStorage.getRepostRecord(addressableId);
    }

    if (record == null) {
      throw NotRepostedException(addressableId);
    }

    // Publish Kind 5 deletion event via NostrClient
    final deletionEvent = await _nostrClient.deleteEvent(
      record.repostEventId,
    );

    if (deletionEvent == null) {
      throw const UnrepostFailedException(
        'Failed to publish unrepost deletion',
      );
    }

    // Remove from cache and storage
    _repostRecords.remove(addressableId);
    await _localStorage?.deleteRepostRecord(addressableId);
    _emitRepostedIds();
  }

  /// Toggle repost status for a video.
  ///
  /// If the video is not reposted, reposts it and returns `true`.
  /// If the video is reposted, unreposts it and returns `false`.
  ///
  /// Parameters:
  /// - [addressableId]: The addressable ID of the video (kind:pubkey:d-tag)
  /// - [originalAuthorPubkey]: The pubkey of the video's author
  /// - [eventId]: Optional event ID for better relay compatibility
  ///
  /// This is a convenience method that combines [isReposted], [repostVideo],
  /// and [unrepostVideo].
  Future<bool> toggleRepost({
    required String addressableId,
    required String originalAuthorPubkey,
    String? eventId,
  }) async {
    await _ensureInitialized();

    // Query the database directly as source of truth to avoid cache/db
    // inconsistency after app restart
    final isCurrentlyReposted =
        await _localStorage?.isReposted(addressableId) ??
        _repostRecords.containsKey(addressableId);

    if (isCurrentlyReposted) {
      await unrepostVideo(addressableId);
      return false;
    } else {
      await repostVideo(
        addressableId: addressableId,
        originalAuthorPubkey: originalAuthorPubkey,
        eventId: eventId,
      );
      return true;
    }
  }

  /// Get a repost record by addressable ID.
  ///
  /// Returns the full [RepostRecord] including the repost event ID,
  /// or `null` if the video is not reposted.
  Future<RepostRecord?> getRepostRecord(String addressableId) async {
    await _ensureInitialized();
    return _repostRecords[addressableId];
  }

  /// Sync all user's reposts from relays.
  ///
  /// Fetches the user's Kind 16 events from relays and updates local storage.
  /// This should be called on startup to ensure local state matches relay
  /// state.
  ///
  /// Returns a [RepostsSyncResult] containing all synced data needed by UI.
  ///
  /// Throws `SyncFailedException` if syncing fails.
  Future<RepostsSyncResult> syncUserReposts() async {
    // First, load from local storage (fast)
    if (_localStorage != null) {
      final records = await _localStorage.getAllRepostRecords();
      for (final record in records) {
        _repostRecords[record.addressableId] = record;
      }
      _emitRepostedIds();
    }

    // Then, fetch from relays (authoritative)
    final filter = Filter(
      kinds: const [EventKind.genericRepost],
      authors: [_nostrClient.publicKey],
      limit: _defaultRepostFetchLimit,
    );

    try {
      final events = await _nostrClient.queryEvents([filter]);
      final newRecords = <RepostRecord>[];

      for (final event in events) {
        final addressableId = _extractAddressableId(event);
        final authorPubkey = _extractOriginalAuthorPubkey(event);

        if (addressableId != null && authorPubkey != null) {
          final record = RepostRecord(
            addressableId: addressableId,
            repostEventId: event.id,
            originalAuthorPubkey: authorPubkey,
            createdAt: DateTime.fromMillisecondsSinceEpoch(
              event.createdAt * 1000,
            ),
          );

          // Only update if we don't have this record or the new one is newer
          final existing = _repostRecords[addressableId];
          if (existing == null ||
              record.createdAt.isAfter(existing.createdAt)) {
            _repostRecords[addressableId] = record;
            newRecords.add(record);
          }
        }
      }

      // Batch save new records to storage
      if (newRecords.isNotEmpty && _localStorage != null) {
        await _localStorage.saveRepostRecordsBatch(newRecords);
      }

      _emitRepostedIds();
      _isInitialized = true;

      return _buildSyncResult();
    } catch (e) {
      // If relay sync fails but we have local data, don't throw
      if (_repostRecords.isNotEmpty) {
        _isInitialized = true;
        return _buildSyncResult();
      }
      throw SyncFailedException('Failed to sync user reposts: $e');
    }
  }

  /// Fetch reposted addressable IDs for any user from relays.
  ///
  /// Unlike [syncUserReposts], this method:
  /// - Does NOT cache results locally (since it's not the current user's data)
  /// - Does NOT require authentication
  /// - Is intended for viewing other users' reposted content
  ///
  /// Returns a list of addressable IDs that the specified user has reposted,
  /// ordered by recency (most recent first).
  ///
  /// Parameters:
  /// - [pubkey]: The public key (hex) of the user whose reposts to fetch
  ///
  /// Throws [FetchRepostsFailedException] if the fetch fails.
  Future<List<String>> fetchUserReposts(String pubkey) async {
    final filter = Filter(
      kinds: const [EventKind.genericRepost],
      authors: [pubkey],
      limit: _defaultRepostFetchLimit,
    );

    try {
      final events = await _nostrClient.queryEvents([filter]);
      final repostedIds = <String>[];
      final seenIds = <String>{};

      // Sort events by createdAt descending (most recent first)
      events.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      for (final event in events) {
        final addressableId = _extractAddressableId(event);
        if (addressableId != null && !seenIds.contains(addressableId)) {
          seenIds.add(addressableId);
          repostedIds.add(addressableId);
        }
      }

      return repostedIds;
    } catch (e) {
      throw FetchRepostsFailedException(
        'Failed to fetch reposts for user $pubkey: $e',
      );
    }
  }

  /// Fetch repost records for any user from relays with full metadata.
  ///
  /// Similar to [fetchUserReposts] but returns full [RepostRecord] objects
  /// including repost event IDs and timestamps.
  ///
  /// Parameters:
  /// - [pubkey]: The public key (hex) of the user whose reposts to fetch
  ///
  /// Throws [FetchRepostsFailedException] if the fetch fails.
  Future<List<RepostRecord>> fetchUserRepostRecords(String pubkey) async {
    final filter = Filter(
      kinds: const [EventKind.genericRepost],
      authors: [pubkey],
      limit: _defaultRepostFetchLimit,
    );

    try {
      final events = await _nostrClient.queryEvents([filter]);
      final records = <RepostRecord>[];
      final seenIds = <String>{};

      // Sort events by createdAt descending (most recent first)
      events.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      for (final event in events) {
        final addressableId = _extractAddressableId(event);
        final authorPubkey = _extractOriginalAuthorPubkey(event);

        if (addressableId != null &&
            authorPubkey != null &&
            !seenIds.contains(addressableId)) {
          seenIds.add(addressableId);
          records.add(
            RepostRecord(
              addressableId: addressableId,
              repostEventId: event.id,
              originalAuthorPubkey: authorPubkey,
              createdAt: DateTime.fromMillisecondsSinceEpoch(
                event.createdAt * 1000,
              ),
            ),
          );
        }
      }

      return records;
    } catch (e) {
      throw FetchRepostsFailedException(
        'Failed to fetch reposts for user $pubkey: $e',
      );
    }
  }

  /// Builds a [RepostsSyncResult] from the current in-memory cache.
  RepostsSyncResult _buildSyncResult() {
    // Sort records by createdAt descending (most recent first)
    final sortedRecords = _repostRecords.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final orderedAddressableIds = sortedRecords
        .map((r) => r.addressableId)
        .toList();
    final addressableIdToRepostId = <String, String>{};
    for (final record in sortedRecords) {
      addressableIdToRepostId[record.addressableId] = record.repostEventId;
    }

    return RepostsSyncResult(
      orderedAddressableIds: orderedAddressableIds,
      addressableIdToRepostId: addressableIdToRepostId,
    );
  }

  /// Clear all local repost data.
  ///
  /// Used when logging out or clearing user data.
  /// Does not affect data on relays.
  Future<void> clearCache() async {
    _repostRecords.clear();
    await _localStorage?.clearAll();
    _emitRepostedIds();
    _isInitialized = false;
  }

  /// Dispose of resources.
  ///
  /// Should be called when the repository is no longer needed.
  void dispose() {
    unawaited(_authSubscription?.cancel());
    unawaited(_repostedIdsController.close());
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

  /// Whether the repository is ready for operations.
  ///
  /// Returns false if not authenticated.
  @visibleForTesting
  bool get isAuthenticated => _isAuthenticated;

  /// Ensures the repository is initialized with data from storage.
  Future<void> _ensureInitialized() async {
    if (_isInitialized) return;

    if (_localStorage != null) {
      final records = await _localStorage.getAllRepostRecords();
      for (final record in records) {
        _repostRecords[record.addressableId] = record;
      }
      _emitRepostedIds();
    }
    _isInitialized = true;
  }

  /// Extracts the addressable ID from a repost event's 'a' tag.
  ///
  /// According to NIP-18, generic reposts use the 'a' tag to reference
  /// the addressable event being reposted.
  String? _extractAddressableId(Event event) {
    for (final tag in event.tags) {
      if (tag is List && tag.isNotEmpty && tag[0] == 'a' && tag.length > 1) {
        return tag[1] as String;
      }
    }
    return null;
  }

  /// Extracts the original author pubkey from a repost event's 'p' tag.
  String? _extractOriginalAuthorPubkey(Event event) {
    for (final tag in event.tags) {
      if (tag is List && tag.isNotEmpty && tag[0] == 'p' && tag.length > 1) {
        return tag[1] as String;
      }
    }
    return null;
  }
}
