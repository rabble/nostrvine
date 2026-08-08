// ABOUTME: Repository for managing user likes (Kind 7 reactions).
// ABOUTME: Coordinates between NostrClient for relay operations and
// ABOUTME: LikesLocalStorage for persistence. Handles Kind 7 reactions
// ABOUTME: and Kind 5 deletions for likes/unlikes.
// ABOUTME: Supports offline queuing via callback injection.

import 'dart:async';
import 'dart:math';

import 'package:likes_repository/src/blocked_liker_filter.dart';
import 'package:likes_repository/src/exceptions.dart';
import 'package:likes_repository/src/likes_local_storage.dart';
import 'package:likes_repository/src/models/like_record.dart';
import 'package:likes_repository/src/models/likes_sync_result.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:rxdart/rxdart.dart';
import 'package:unified_logger/unified_logger.dart';

/// Default limit for fetching user reactions from relays.
const _defaultReactionFetchLimit = 500;

/// NIP-25 reaction content for a like/upvote.
const _likeContent = '+';

/// NIP-25 reaction content for a downvote.
const _downvoteContent = '-';

/// Max number of reaction ids per Kind 5 deletion REQ.
///
/// The resolver scopes the deletion query to the reaction ids it fetched,
/// which can approach the relay's per-REQ cap (~5000) on a very
/// high-engagement video. A single `#e` filter with that many 64-char ids
/// (~67 bytes each in JSON) would build a REQ frame near/over the relay's
/// `max_message_length` (512KB); an oversized frame errors the socket and
/// `queryEvents` fails open, silently counting deleted likes. Chunking keeps
/// every frame small (500 ids ~= 34KB, well under 512KB and the advertised
/// `max_event_tags` of 2000). See #5751.
const _deletionReqEidChunkSize = 500;

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
/// - Supports real-time cross-device sync via persistent subscriptions
class LikesRepository {
  /// Creates a new likes repository.
  ///
  /// Parameters:
  /// - [nostrClient]: Client for Nostr relay communication
  /// - [localStorage]: Optional local storage for persistence
  /// - [isOnline]: Optional callback to check connectivity status
  /// - [queueOfflineAction]: Optional callback to queue actions when offline
  /// - [blockFilter]: Optional callback to hide blocked/muted users from
  ///   engagement lists ([fetchEventLikers])
  LikesRepository({
    required NostrClient nostrClient,
    LikesLocalStorage? localStorage,
    IsOnlineCallback? isOnline,
    QueueOfflineActionCallback? queueOfflineAction,
    BlockedLikerFilter? blockFilter,
  }) : _nostrClient = nostrClient,
       _localStorage = localStorage,
       _isOnline = isOnline,
       _queueOfflineAction = queueOfflineAction,
       _blockFilter = blockFilter;

  final NostrClient _nostrClient;
  final LikesLocalStorage? _localStorage;

  /// Callback to hide blocked/muted users from engagement lists
  final BlockedLikerFilter? _blockFilter;

  /// Callback to check if the device is online
  final IsOnlineCallback? _isOnline;

  /// Callback to queue actions for offline sync
  final QueueOfflineActionCallback? _queueOfflineAction;

  /// In-memory cache of like records keyed by target event ID.
  final Map<String, LikeRecord> _likeRecords = {};

  /// Companion index of [_likeRecords], keyed by addressable coordinate
  /// (`kind:pubkey:d-tag`) instead of target event ID.
  ///
  /// Lets own-like state survive a target edit that mints a new event id
  /// for the same coordinate (#6020) — a like recorded against the pre-edit
  /// id stays resolvable via [isLikedByCoordinate]/[getLikeRecordByCoordinate]
  /// after the edit. Populated everywhere [_likeRecords] is written (see
  /// [_indexLikeRecord]) whenever an addressable id is known, including on
  /// load from persisted storage, so cold app starts resolve correctly too
  /// (unlike the in-memory-only precedent in #4478's comment count cache).
  final Map<String, LikeRecord> _likeRecordsByAddressableId = {};

  /// In-memory cache of downvote records keyed by target event ID.
  ///
  /// Mirror of [_likeRecords] for kind-7 reactions whose content is `-`.
  /// Not persisted to local storage in v1 — relays repopulate via
  /// [syncUserReactions] / [getVoteCounts] on next fetch.
  final Map<String, LikeRecord> _downvoteRecords = {};

  /// Companion index of [_downvoteRecords] keyed by addressable coordinate.
  ///
  /// Mirror of [_likeRecordsByAddressableId] for the downvote side. An edit of
  /// an addressable target mints a new event id under the same coordinate, so
  /// an id-only index loses the downvote the moment the target is edited
  /// (#6124). Unlike the like side there is no persisted companion column:
  /// `personal_reactions` has no reaction-content discriminator and is keyed
  /// `{targetEventId, userPubkey}`, so it cannot represent a like and a
  /// downvote on the same target. Downvotes stay in-memory only, as in v1.
  final Map<String, LikeRecord> _downvoteRecordsByAddressableId = {};

  /// In-memory cache of global like counts keyed by event ID.
  ///
  /// Prevents redundant relay queries when the same video is scrolled
  /// back into view. Adjusted +1/−1 on like/unlike so the cached value
  /// stays consistent with optimistic UI updates.
  final Map<String, int> _likeCountCache = {};

  /// Companion of [_likeCountCache], keyed by addressable coordinate.
  ///
  /// Mirrors the dual-key pattern `comments_repository` shipped in #4478:
  /// a cached count survives a target edit that changes the event id, as
  /// long as the coordinate stayed the same. Read falls back to this map
  /// only on an event-id miss; writes are always dual when a coordinate is
  /// known (see [_readCachedLikeCount]/[_writeCachedLikeCount]).
  final Map<String, int> _likeCountCacheByAddressableId = {};

  /// Reactive stream controller for liked event IDs (ordered by recency).
  final _likedIdsController = BehaviorSubject<List<String>>.seeded([]);

  /// Reactive stream controller for liked addressable coordinates.
  ///
  /// Companion of [_likedIdsController], ticked alongside it (see
  /// [_emitLikedIds]) so a live subscriber (e.g. a video interactions BLoC)
  /// can resolve "is this coordinate liked" reactively, not just via a
  /// one-shot fetch — without this, a consumer subscribed only to
  /// [watchLikedEventIds] would have its own-like state silently flip back
  /// to unliked the next time *any* like/unlike ticks the stream anywhere
  /// in the app, since that stream is blind to coordinate membership
  /// (#6020).
  final _likedAddressableIdsController = BehaviorSubject<Set<String>>.seeded(
    <String>{},
  );

  /// Reactive stream controller for downvoted event IDs (ordered by recency).
  final _downvotedIdsController = BehaviorSubject<List<String>>.seeded(
    <String>[],
  );

  /// Whether the repository has been initialized with data from storage.
  bool _isInitialized = false;

  /// Whether [dispose] has been called.
  ///
  /// Once disposed, all stream emissions are no-ops.
  bool _isDisposed = false;

  /// Real-time sync subscription for cross-device synchronization.
  StreamSubscription<Event>? _reactionSubscription;
  String? _reactionSubscriptionId;

  /// Writes [record] into [_likeRecords] and, when its
  /// [LikeRecord.addressableId] is non-empty, also into
  /// [_likeRecordsByAddressableId].
  ///
  /// Centralizes the dual-write so every write site (like, sync, live
  /// subscription, load-from-storage) stays consistent — mirrors the
  /// `_writeCachedCommentCount` helper from #4478.
  void _indexLikeRecord(LikeRecord record) {
    _likeRecords[record.targetEventId] = record;
    final addressableId = record.addressableId;
    if (addressableId != null && addressableId.isNotEmpty) {
      _likeRecordsByAddressableId[addressableId] = record;
    }
  }

  /// Removes any record for [targetEventId] from both [_likeRecords] and
  /// [_likeRecordsByAddressableId].
  ///
  /// Looks up the record before removing so the addressable-id companion
  /// entry can be found and removed too — [_likeRecordsByAddressableId] is
  /// keyed by coordinate, not by [targetEventId].
  void _deindexLikeRecord(String targetEventId) {
    final record = _likeRecords.remove(targetEventId);
    final addressableId = record?.addressableId;
    if (addressableId != null && addressableId.isNotEmpty) {
      final indexed = _likeRecordsByAddressableId[addressableId];
      if (indexed?.reactionEventId == record?.reactionEventId &&
          indexed?.targetEventId == record?.targetEventId) {
        _likeRecordsByAddressableId.remove(addressableId);
      }
    }
  }

  /// Indexes [record] into [_downvoteRecords] and, when it carries a
  /// coordinate, [_downvoteRecordsByAddressableId].
  void _indexDownvoteRecord(LikeRecord record) {
    _downvoteRecords[record.targetEventId] = record;
    final addressableId = record.addressableId;
    if (addressableId != null && addressableId.isNotEmpty) {
      _downvoteRecordsByAddressableId[addressableId] = record;
    }
  }

  /// Removes any downvote record for [targetEventId] from both indexes.
  void _deindexDownvoteRecord(String targetEventId) {
    final record = _downvoteRecords.remove(targetEventId);
    final addressableId = record?.addressableId;
    if (addressableId != null && addressableId.isNotEmpty) {
      final indexed = _downvoteRecordsByAddressableId[addressableId];
      if (indexed?.reactionEventId == record?.reactionEventId &&
          indexed?.targetEventId == record?.targetEventId) {
        _downvoteRecordsByAddressableId.remove(addressableId);
      }
    }
  }

  /// Resolves a downvote record by target event id, falling back to
  /// [addressableId] when the id-keyed lookup misses.
  ///
  /// An addressable target that has been edited answers to a new event id but
  /// the same coordinate, so the coordinate is the durable key (#6124).
  LikeRecord? _lookupDownvoteRecord(String eventId, String? addressableId) {
    final byId = _downvoteRecords[eventId];
    if (byId != null) return byId;
    if (addressableId == null || addressableId.isEmpty) return null;
    return _downvoteRecordsByAddressableId[addressableId];
  }

  /// Emits the current liked event IDs ordered by recency (most recent
  /// first), and the current liked addressable coordinates alongside them.
  ///
  /// Guards against emitting after [dispose] has been called or the controller
  /// has been closed, which can happen if [clearCache] runs during or after
  /// [dispose] (e.g. on logout).
  void _emitLikedIds() {
    if (_isDisposed || _likedIdsController.isClosed) return;
    final sortedRecords = _likeRecords.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _likedIdsController.add(sortedRecords.map((r) => r.targetEventId).toList());
    if (!_likedAddressableIdsController.isClosed) {
      _likedAddressableIdsController.add(
        _likeRecordsByAddressableId.keys.toSet(),
      );
    }
  }

  /// Emits the current downvoted event IDs ordered by recency.
  ///
  /// Mirror of [_emitLikedIds] for the downvote stream. Guarded against
  /// post-dispose / post-close emission for the same reason.
  void _emitDownvotedIds() {
    if (_isDisposed || _downvotedIdsController.isClosed) return;
    final sortedRecords = _downvoteRecords.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _downvotedIdsController.add(
      sortedRecords.map((r) => r.targetEventId).toList(),
    );
  }

  /// Stream of liked event IDs ordered by recency (reactive).
  ///
  /// Emits an ordered list (most recent first) whenever the user's likes
  /// change. This is useful for UI components that need to reactively update
  /// while preserving pagination order.
  Stream<List<String>> watchLikedEventIds() async* {
    // The public stream follows the repository cache, not direct storage
    // watches, so it stays consistent with isLiked/getOrderedLikedEventIds.
    await _ensureInitialized();
    yield* _likedIdsController.stream;
  }

  /// Stream of liked addressable coordinates (reactive).
  ///
  /// Companion of [watchLikedEventIds] keyed by `kind:pubkey:d-tag`
  /// coordinate instead of event id. A live consumer that cares about an
  /// addressable target's own-like state should combine both streams —
  /// membership in either means the target is liked — so a coordinate-only
  /// hit (the target's underlying reaction is for a pre-edit event id)
  /// isn't missed (#6020).
  Stream<Set<String>> watchLikedAddressableIds() async* {
    await _ensureInitialized();
    yield* _likedAddressableIdsController.stream;
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

  /// Get the like record for an addressable coordinate
  /// (`kind:pubkey:d-tag`), or `null` if the coordinate is not liked.
  ///
  /// Resolves own-like state for an addressable target across an edit that
  /// minted a new event id for the same coordinate (#6020) — a like made
  /// against a pre-edit version of the target is still found here after
  /// the edit, even though [isLiked] with the new event id would miss.
  Future<LikeRecord?> getLikeRecordByCoordinate(String addressableId) async {
    await _ensureInitialized();
    return _likeRecordsByAddressableId[addressableId];
  }

  /// Check if a specific addressable coordinate is liked.
  ///
  /// Thin bool wrapper over [getLikeRecordByCoordinate], mirroring the
  /// [isLiked]/[getLikeRecord] pair shape.
  Future<bool> isLikedByCoordinate(String addressableId) async {
    return (await getLikeRecordByCoordinate(addressableId)) != null;
  }

  /// Check if [eventId] is liked, falling back to [addressableId] (when
  /// provided) on a miss.
  ///
  /// This is the composed check callers with both an event id and an
  /// optional coordinate should use — e.g. a video interactions BLoC
  /// resolving "is my own video liked" without needing to know whether the
  /// underlying reaction was recorded against this exact event id or a
  /// pre-edit version of the same coordinate (#6020). Mirrors
  /// [getLikeCount]'s existing eventId+addressableId parameter shape;
  /// keeps the fallback/composition policy in the repository layer per
  /// this codebase's architecture convention, rather than pushing two
  /// sequential calls onto the caller.
  Future<bool> isLikedResolvingCoordinate({
    required String eventId,
    String? addressableId,
  }) async {
    if (await isLiked(eventId)) return true;
    if (addressableId == null || addressableId.isEmpty) return false;
    return isLikedByCoordinate(addressableId);
  }

  /// Stream of downvoted event IDs ordered by recency (reactive).
  ///
  /// Mirror of [watchLikedEventIds] for the downvote side. Local storage
  /// does not yet persist downvotes (v1 limitation); the in-memory stream
  /// is used directly.
  Stream<List<String>> watchDownvotedEventIds() {
    return _downvotedIdsController.stream;
  }

  /// Get the current set of downvoted event IDs (one-shot).
  Future<Set<String>> getDownvotedEventIds() async {
    await _ensureInitialized();
    return _downvoteRecords.keys.toSet();
  }

  /// Get downvoted event IDs ordered by recency (most recent first).
  Future<List<String>> getOrderedDownvotedEventIds() async {
    await _ensureInitialized();
    final sortedRecords = _downvoteRecords.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sortedRecords.map((r) => r.targetEventId).toList();
  }

  /// Check if a specific event is downvoted by the current user.
  Future<bool> isDownvoted(String eventId) async {
    await _ensureInitialized();
    return _downvoteRecords.containsKey(eventId);
  }

  /// Get the downvote record for an event, or null if not downvoted.
  Future<LikeRecord?> getDownvoteRecord(String eventId) async {
    await _ensureInitialized();
    return _downvoteRecords[eventId];
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

    // Check if already liked — by event id, or (when addressableId is
    // known) by coordinate. The coordinate check catches the case where a
    // pre-edit version of this target was already liked under a different
    // event id: without it, a stale heart-unfilled UI (#6020) could lead
    // the user to create a second, duplicate live reaction whose original
    // becomes un-deletable via the normal unlike flow.
    final alreadyLikedByCoordinate =
        addressableId != null &&
        addressableId.isNotEmpty &&
        _likeRecordsByAddressableId.containsKey(addressableId);
    if (_likeRecords.containsKey(eventId) || alreadyLikedByCoordinate) {
      throw AlreadyLikedException(eventId);
    }

    // Snapshot for rollback if the network publish fails
    final previousCount = _readCachedLikeCount(
      eventId,
      addressableId: addressableId,
    );

    // 1. Optimistic-first: write to memory + local storage and tick the
    // watchLikedEventIds stream BEFORE any network I/O. The UI flips here.
    // Mirrors FollowRepository.follow's order-of-operations so likes match
    // the design rabble described — local DB first, network confirms.
    // Storage write is awaited so the placeholder survives an app crash
    // before sync; PendingActionService (offline) and executeLikeAction
    // (sync) reconcile the placeholder ID with the real reaction event ID.
    final placeholderId = 'pending_like_$eventId';
    final placeholder = LikeRecord(
      targetEventId: eventId,
      reactionEventId: placeholderId,
      createdAt: DateTime.now(),
      addressableId: addressableId,
    );
    _indexLikeRecord(placeholder);
    await _bestEffortLocalStorage(
      () async => _localStorage?.saveLikeRecord(placeholder),
      description: 'saving the like placeholder',
    );
    if (previousCount != null) {
      _writeCachedLikeCount(
        eventId,
        previousCount + 1,
        addressableId: addressableId,
      );
    }
    _emitLikedIds();

    // 2. Offline → leave the optimistic state in place; queue replays later
    if (_isOnline != null && !_isOnline() && _queueOfflineAction != null) {
      await _queueOfflineAction(
        isLike: true,
        eventId: eventId,
        authorPubkey: authorPubkey,
        addressableId: addressableId,
        targetKind: targetKind,
      );
      return placeholderId;
    }

    // 3. Online → publish kind 7; on success swap placeholder for real id.
    // On failure, prefer queuing via [_queueOfflineAction] when wired so the
    // optimistic state survives transient relay-pool problems (e.g. all
    // configured relays in `disconnected` state at publish time but
    // [ConnectionStatusService] still reports online because at least one
    // relay is technically connected). Without a wired callback, fall back
    // to rollback + rethrow to preserve the original contract for tests
    // and non-app embedders.
    try {
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

      final confirmed = LikeRecord(
        targetEventId: eventId,
        reactionEventId: reactionEvent.id,
        createdAt: placeholder.createdAt,
        addressableId: addressableId,
      );
      _indexLikeRecord(confirmed);
      await _bestEffortLocalStorage(
        () async => _localStorage?.saveLikeRecord(confirmed),
        description: 'saving the confirmed like',
      );

      return reactionEvent.id;
    } catch (e, stackTrace) {
      if (_queueOfflineAction != null) {
        Log.error(
          'Like publish failed; queuing optimistic action for retry',
          name: 'LikesRepository',
          category: LogCategory.relay,
          error: e,
          stackTrace: stackTrace,
        );
        await _queueOfflineAction(
          isLike: true,
          eventId: eventId,
          authorPubkey: authorPubkey,
          addressableId: addressableId,
          targetKind: targetKind,
        );
        return placeholderId;
      }
      _deindexLikeRecord(eventId);
      await _bestEffortLocalStorage(
        () async => _localStorage?.deleteLikeRecord(eventId),
        description: 'rolling back the like placeholder',
      );
      if (previousCount != null) {
        _writeCachedLikeCount(
          eventId,
          previousCount,
          addressableId: addressableId,
        );
      }
      _emitLikedIds();
      rethrow;
    }
  }

  /// Execute a like action directly (for use by sync service).
  ///
  /// This method bypasses offline queuing and directly publishes to relays.
  /// Used by PendingActionService to execute queued actions.
  ///
  /// If [addressableId] is already liked by a *different* reaction than the
  /// one queued for [eventId] — e.g. cross-device sync delivered a like for
  /// this coordinate (under a different event id) while this action sat in
  /// the offline queue — reconciles to that reaction instead of publishing
  /// a duplicate. The app-layer queue's own dedup only cancels opposite
  /// actions on the same event id; it has no visibility into reactions
  /// arriving from other devices, so this is the only guard against a
  /// duplicate live reaction on replay (#6020).
  Future<String> executeLikeAction({
    required String eventId,
    required String authorPubkey,
    String? addressableId,
    int? targetKind,
  }) async {
    // Replay can race initialize(): both are fired unawaited at provider
    // build, and the coordinate guard below is memory-only, so an empty
    // cache would make it blind to a persisted cross-device reaction.
    await _ensureInitialized();

    if (addressableId != null && addressableId.isNotEmpty) {
      final byCoordinate = _likeRecordsByAddressableId[addressableId];
      final ownReactionEventId = _likeRecords[eventId]?.reactionEventId;
      if (byCoordinate != null &&
          byCoordinate.reactionEventId != ownReactionEventId) {
        if (ownReactionEventId != null &&
            ownReactionEventId.startsWith('pending_')) {
          // Drop the queued placeholder now that the coordinate reaction
          // is authoritative; leaving it would make a later unlike resolve
          // the placeholder by event id, skip the Kind 5 publish, and
          // strand the real reaction live. NOT _deindexLikeRecord: the
          // placeholder shares the coordinate, so deindexing by event id
          // would evict the cross-device record from the coordinate index.
          _likeRecords.remove(eventId);
          await _localStorage?.deleteLikeRecord(eventId);
          _emitLikedIds();
        }
        return byCoordinate.reactionEventId;
      }
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

    // Update local record with real event ID if we have a placeholder
    final existingRecord = _likeRecords[eventId];
    if (existingRecord != null &&
        existingRecord.reactionEventId.startsWith('pending_')) {
      final record = LikeRecord(
        targetEventId: eventId,
        reactionEventId: reactionEvent.id,
        createdAt: existingRecord.createdAt,
        addressableId: addressableId ?? existingRecord.addressableId,
      );
      _indexLikeRecord(record);
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
  /// [addressableId], when provided, resolves the underlying reaction by
  /// coordinate when no record exists under [eventId] — the case where the
  /// like was recorded against a pre-edit version of this target (#6020).
  /// Without this fallback, unliking the current version after an edit
  /// would silently no-op on the original reaction, leaving it live and
  /// permanently un-deletable via this method.
  ///
  /// Throws `UnlikeFailedException` if the operation fails.
  /// Throws `NotLikedException` if the event is not currently liked.
  Future<void> unlikeEvent(String eventId, {String? addressableId}) async {
    await _ensureInitialized();

    // Try in-memory cache first (by event id, then by coordinate), then
    // fall back to database. This handles both the cache-not-populated-yet
    // case and the post-edit case where the record's real key is a
    // different (pre-edit) event id than the one the caller passed in.
    var record = _likeRecords[eventId];
    if (record == null && addressableId != null && addressableId.isNotEmpty) {
      record = _likeRecordsByAddressableId[addressableId];
    }
    final localStorage = _localStorage;
    if (record == null && localStorage != null) {
      record = await _bestEffortLocalStorage<LikeRecord?>(
        () async {
          final stored = await localStorage.getLikeRecord(eventId);
          if (stored != null) return stored;
          if (addressableId == null || addressableId.isEmpty) return null;
          return localStorage.getLikeRecordByAddressableId(addressableId);
        },
        description: 'reading the like record',
      );
    }

    if (record == null) {
      throw NotLikedException(eventId);
    }

    // The record's own targetEventId is the correct key to deindex/delete
    // — it may be a pre-edit id the caller doesn't know about, when this
    // record was found via the addressableId fallback above.
    final resolvedEventId = record.targetEventId;

    // Snapshot for rollback if the network publish fails
    final snapshotRecord = record;
    final previousCount = _readCachedLikeCount(
      eventId,
      addressableId: addressableId,
    );

    // 1. Optimistic-first: remove from memory + local storage and tick the
    // watchLikedEventIds stream BEFORE any network I/O (mirror of likeEvent).
    _deindexLikeRecord(resolvedEventId);
    await _bestEffortLocalStorage(
      () async => _localStorage?.deleteLikeRecord(resolvedEventId),
      description: 'deleting the like record',
    );
    _decrementLikeCountCache(eventId, addressableId: addressableId);
    _emitLikedIds();

    // 2. Offline → leave the optimistic state in place; queue replays later
    if (_isOnline != null && !_isOnline() && _queueOfflineAction != null) {
      await _queueOfflineAction(
        isLike: false,
        eventId: resolvedEventId,
        authorPubkey: '', // Not needed for unlike
      );
      return;
    }

    // 3. Online → publish kind 5 (skipped for never-synced placeholders).
    // On failure, prefer queuing via [_queueOfflineAction] when wired so the
    // optimistic unlike survives transient relay-pool problems (mirror of
    // [likeEvent]). Without a wired callback, fall back to rollback +
    // rethrow to preserve the original contract.
    if (snapshotRecord.reactionEventId.startsWith('pending_')) {
      // Pending like never reached the relay; nothing to delete on the wire.
      return;
    }

    try {
      final deletionEvent = await _nostrClient.deleteEvent(
        snapshotRecord.reactionEventId,
      );
      if (deletionEvent == null) {
        throw const UnlikeFailedException('Failed to publish unlike deletion');
      }
    } catch (e, stackTrace) {
      if (_queueOfflineAction != null) {
        Log.error(
          'Unlike publish failed; queuing optimistic action for retry',
          name: 'LikesRepository',
          category: LogCategory.relay,
          error: e,
          stackTrace: stackTrace,
        );
        await _queueOfflineAction(
          isLike: false,
          eventId: resolvedEventId,
          authorPubkey: '', // Not needed for unlike
        );
        return;
      }
      _indexLikeRecord(snapshotRecord);
      await _bestEffortLocalStorage(
        () async => _localStorage?.saveLikeRecord(snapshotRecord),
        description: 'restoring the like record',
      );
      if (previousCount != null) {
        _writeCachedLikeCount(
          eventId,
          previousCount,
          addressableId: addressableId,
        );
      }
      _emitLikedIds();
      rethrow;
    }
  }

  /// Execute an unlike action directly (for use by sync service).
  ///
  /// This method bypasses offline queuing and directly publishes to relays.
  /// Used by PendingActionService to execute queued actions.
  ///
  /// [addressableId] resolves the record by coordinate when [eventId] finds
  /// nothing — mirrors [unlikeEvent]'s fallback for the same reason (#6020).
  Future<void> executeUnlikeAction(
    String eventId, {
    String? addressableId,
  }) async {
    // Try to get the record - it may not exist if the like was also offline
    var record = _likeRecords[eventId];
    if (record == null && addressableId != null && addressableId.isNotEmpty) {
      record = _likeRecordsByAddressableId[addressableId];
    }
    if (record == null && _localStorage != null) {
      record = await _localStorage.getLikeRecord(eventId);
      if (record == null && addressableId != null && addressableId.isNotEmpty) {
        record = await _localStorage.getLikeRecordByAddressableId(
          addressableId,
        );
      }
    }

    // If no record exists, the like was never synced either, so we're done
    if (record == null) {
      return;
    }

    final resolvedEventId = record.targetEventId;

    // Skip publishing if this was a pending like
    if (record.reactionEventId.startsWith('pending_')) {
      // Just clean up local storage
      _deindexLikeRecord(resolvedEventId);
      await _localStorage?.deleteLikeRecord(resolvedEventId);
      _emitLikedIds();
      _decrementLikeCountCache(eventId, addressableId: addressableId);
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
    _deindexLikeRecord(resolvedEventId);
    await _localStorage?.deleteLikeRecord(resolvedEventId);
    _emitLikedIds();
    _decrementLikeCountCache(eventId, addressableId: addressableId);
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
    // inconsistency after app restart. Also check by coordinate: after an
    // edit, a like recorded pre-edit resolves under a different event id
    // than the one being toggled here (#6020) — without this check,
    // toggling the (correctly, post-fix) filled heart on the current
    // version would try to *like* again instead of unliking the original.
    final likedByEventId =
        await _localStorage?.isLiked(eventId) ??
        _likeRecords.containsKey(eventId);
    final likedByCoordinate =
        addressableId != null &&
        addressableId.isNotEmpty &&
        _likeRecordsByAddressableId.containsKey(addressableId);
    final isCurrentlyLiked = likedByEventId || likedByCoordinate;

    if (isCurrentlyLiked) {
      await unlikeEvent(eventId, addressableId: addressableId);
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
  /// Returns a cached count when available to avoid redundant relay queries
  /// (e.g. when scrolling back to a previously viewed video). Otherwise
  /// queries relays for the count of Kind 7 reactions on the event.
  /// When [addressableId] is provided, resolves the same active distinct liker
  /// set used by [fetchEventLikers], so the visible count and "Liked by" list
  /// cannot diverge at fetch time for addressable videos. (A cached count is
  /// served as-is and is not re-resolved, so likes from others arriving after
  /// the first fetch show up in the live list but not in a cache-served count.)
  ///
  /// Note: This counts all likes, not just the current user's.
  Future<int> getLikeCount(String eventId, {String? addressableId}) async {
    final cached = _readCachedLikeCount(eventId, addressableId: addressableId);
    if (cached != null) return cached;

    int count;

    if (addressableId != null && addressableId.isNotEmpty) {
      // Resolve the count from the same filtered event fetch as the "Liked by"
      // list (not NIP-45 COUNT) so the two can't diverge. Trade-off: it shares
      // the list's relay cap and query timeout, so a video with more reactions
      // than the relay returns shows count == list, both capped below the true
      // total. Keep it a fetch (not COUNT) to preserve that equality.
      final likersByEvent = await _fetchResolvedLikersByEvent(
        [eventId],
        addressableIds: {eventId: addressableId},
      );
      count = likersByEvent[eventId]?.length ?? 0;
    } else {
      // Query relays for the count of Kind 7 reactions on this event.
      final filterByE = Filter(kinds: const [EventKind.reaction], e: [eventId]);
      final result = await _nostrClient.countEvents([filterByE]);
      count = result.count;
    }

    _writeCachedLikeCount(eventId, count, addressableId: addressableId);
    return count;
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
  ///   counts the active distinct liker set used by [fetchEventLikers].
  ///
  /// Note: when any uncached id in the batch has an addressable id, *all*
  /// uncached ids in that batch are counted via the resolved distinct-liker
  /// path (deduped + filtered); a batch with no addressable ids uses the raw
  /// e-tag tally. So a non-addressable id can get either count depending on
  /// batch composition, and whichever result lands first is cached for the
  /// session.
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

    // Separate cached vs uncached IDs to skip relay queries for known counts
    final counts = <String, int>{};
    final uncachedIds = <String>[];
    for (final id in eventIds) {
      final cached = _readCachedLikeCount(
        id,
        addressableId: addressableIds?[id],
      );
      if (cached != null) {
        counts[id] = cached;
      } else {
        uncachedIds.add(id);
      }
    }

    if (uncachedIds.isEmpty) return counts;

    final uncachedAddressableIds = <String, String>{};
    if (addressableIds != null && addressableIds.isNotEmpty) {
      for (final id in uncachedIds) {
        final aId = addressableIds[id];
        if (aId != null && aId.isNotEmpty) {
          uncachedAddressableIds[id] = aId;
        }
      }
    }

    if (uncachedAddressableIds.isNotEmpty) {
      final likersByEvent = await _fetchResolvedLikersByEvent(
        uncachedIds,
        addressableIds: uncachedAddressableIds,
      );
      for (final id in uncachedIds) {
        final count = likersByEvent[id]?.length ?? 0;
        counts[id] = count;
        _writeCachedLikeCount(
          id,
          count,
          addressableId: uncachedAddressableIds[id],
        );
      }
      return counts;
    }

    // Query relays for count of Kind 7 reactions on uncached events
    final filterByE = Filter(kinds: const [EventKind.reaction], e: uncachedIds);

    // NIP-45 COUNT with multiple event IDs returns total count, not per-event
    // So we need to fall back to querying events and counting client-side
    final eventsByE = await _nostrClient.queryEvents([filterByE]);

    // Count reactions per target event from e-tag query
    final uncachedIdSet = uncachedIds.toSet();
    for (final id in uncachedIds) {
      counts[id] = 0;
    }

    for (final event in eventsByE) {
      for (final tag in event.tags) {
        if (tag.isNotEmpty && tag[0] == 'e' && tag.length > 1) {
          final targetId = tag[1];
          if (uncachedIdSet.contains(targetId)) {
            counts[targetId] = (counts[targetId] ?? 0) + 1;
          }
        }
      }
    }

    // Populate cache with fetched counts
    for (final id in uncachedIds) {
      _writeCachedLikeCount(id, counts[id]!);
    }

    return counts;
  }

  /// Get vote counts (upvotes and downvotes) for multiple events.
  ///
  /// Queries relays for Kind 7 reactions on each event, differentiating
  /// between `+` (upvote) and `-` (downvote) content.
  ///
  /// Pass [addressableIds] — event id to `kind:pubkey:d-tag` coordinate — for
  /// targets that are addressable. An edit republishes such a target under a
  /// new event id, so every vote cast against the previous revision is only
  /// reachable by coordinate; an `e`-only query reports zero and the score
  /// vanishes for every viewer the moment the target is edited (#6124).
  ///
  /// Returns a record of upvote and downvote count maps.
  Future<({Map<String, int> upvotes, Map<String, int> downvotes})>
  getVoteCounts(
    List<String> eventIds, {
    Map<String, String> addressableIds = const {},
  }) async {
    if (eventIds.isEmpty) {
      return (upvotes: <String, int>{}, downvotes: <String, int>{});
    }

    final eventIdByCoordinate = _voteTargetsByCoordinate(
      eventIds,
      addressableIds,
    );

    final events = await _queryVoteTargetReactions(
      eventIds: eventIds,
      eventIdByCoordinate: eventIdByCoordinate,
    );

    final upvotes = <String, int>{};
    final downvotes = <String, int>{};
    for (final eventId in eventIds) {
      upvotes[eventId] = 0;
      downvotes[eventId] = 0;
    }

    // Retracted votes have to be excluded here, not just in
    // [getUserVoteStatuses]. The coordinate leg reaches reactions cast against
    // every earlier revision of the target, including ones their author has
    // since deleted — switching an upvote to a downvote on an edited reply
    // publishes exactly that pair, and counting both leaves netScore 0, which
    // `comment_item.dart` renders by hiding the score outright (#6124).
    final reactionsById = {for (final event in events) event.id: event};
    final deletedReactionIds = await _deletedReactionIds(reactionsById);

    final knownEventIds = eventIds.toSet();
    for (final event in reactionsById.values) {
      if (deletedReactionIds.contains(event.id)) continue;
      final targetId = _resolveVoteTarget(
        event,
        knownEventIds,
        eventIdByCoordinate,
      );
      if (targetId == null) continue;

      if (event.content == _downvoteContent) {
        downvotes[targetId] = downvotes[targetId]! + 1;
      } else {
        // '+' and any other content counts as upvote
        upvotes[targetId] = upvotes[targetId]! + 1;
      }
    }

    return (upvotes: upvotes, downvotes: downvotes);
  }

  /// Get the user's current vote status for multiple events.
  ///
  /// Pass [addressableIds] for addressable targets, for the same reason
  /// [getVoteCounts] needs it: without the coordinate the voter's own arrow
  /// silently un-fills after the target is edited (#6124).
  ///
  /// Returns maps of event IDs the user has upvoted or downvoted.
  Future<({Set<String> upvotedIds, Set<String> downvotedIds})>
  getUserVoteStatuses(
    List<String> eventIds, {
    Map<String, String> addressableIds = const {},
  }) async {
    if (eventIds.isEmpty) {
      return (upvotedIds: <String>{}, downvotedIds: <String>{});
    }

    // Signed out: both queries below are author-scoped, and a null author
    // would widen them to every user's votes rather than narrowing to none.
    final pubkey = await _currentUserPubkey();
    if (pubkey == null) {
      return (upvotedIds: <String>{}, downvotedIds: <String>{});
    }

    final eventIdByCoordinate = _voteTargetsByCoordinate(
      eventIds,
      addressableIds,
    );

    final events = await _queryVoteTargetReactions(
      eventIds: eventIds,
      eventIdByCoordinate: eventIdByCoordinate,
      authors: [pubkey],
    );

    // Also fetch deletions to exclude deleted votes
    final deletionFilter = Filter(
      kinds: const [EventKind.eventDeletion],
      authors: [pubkey],
    );
    final deletions = await _nostrClient.queryEvents([deletionFilter]);

    final deletedIds = <String>{};
    for (final deletion in deletions) {
      for (final tag in deletion.tags) {
        if (tag.isNotEmpty && tag[0] == 'e' && tag.length > 1) {
          deletedIds.add(tag[1]);
        }
      }
    }

    final upvotedIds = <String>{};
    final downvotedIds = <String>{};
    final knownEventIds = eventIds.toSet();

    for (final event in events) {
      if (deletedIds.contains(event.id)) continue;

      final targetId = _resolveVoteTarget(
        event,
        knownEventIds,
        eventIdByCoordinate,
      );
      if (targetId == null) continue;

      if (event.content == _downvoteContent) {
        downvotedIds.add(targetId);
      } else {
        upvotedIds.add(targetId);
      }
    }

    return (upvotedIds: upvotedIds, downvotedIds: downvotedIds);
  }

  Future<List<Event>> _queryVoteTargetReactions({
    required List<String> eventIds,
    required Map<String, String> eventIdByCoordinate,
    List<String>? authors,
  }) async {
    final eEventsFuture = _nostrClient.queryEvents([
      Filter(kinds: const [EventKind.reaction], authors: authors, e: eventIds),
    ]);
    final aEventsFuture = eventIdByCoordinate.isEmpty
        ? Future<List<Event>>.value(const <Event>[])
        : _nostrClient.queryEvents([
            Filter(
              kinds: const [EventKind.reaction],
              authors: authors,
              a: eventIdByCoordinate.keys.toList(),
            ),
          ]);
    final results = await Future.wait([eEventsFuture, aEventsFuture]);

    final eventsById = <String, Event>{};
    for (final event in [...results[0], ...results[1]]) {
      eventsById[event.id] = event;
    }
    return eventsById.values.toList();
  }

  /// Inverts [addressableIds] into a coordinate → event-id lookup, limited to
  /// the ids actually being queried and skipping blank coordinates.
  Map<String, String> _voteTargetsByCoordinate(
    List<String> eventIds,
    Map<String, String> addressableIds,
  ) {
    final byCoordinate = <String, String>{};
    for (final eventId in eventIds) {
      final coordinate = addressableIds[eventId];
      if (coordinate != null && coordinate.isNotEmpty) {
        byCoordinate[coordinate] = eventId;
      }
    }
    return byCoordinate;
  }

  /// Resolves which queried target a reaction belongs to.
  ///
  /// Matches the `e` tag first, then falls back to the `a` tag so a reaction
  /// cast against a superseded revision of an addressable target still lands
  /// on the revision the caller is currently showing (#6124). Returns `null`
  /// when the reaction targets nothing in the queried set.
  ///
  /// Scans the `e` tags last-first: NIP-25 says that when a reaction carries
  /// more than one, "the target event `id` should be last of the `e` tags".
  /// Reading forwards credits a copied ancestor tag instead of the real
  /// target — Divine's own writer emits a single `e` tag, so this only
  /// affects reactions from other clients.
  String? _resolveVoteTarget(
    Event event,
    Set<String> knownEventIds,
    Map<String, String> eventIdByCoordinate,
  ) {
    for (final tag in event.tags.reversed) {
      if (tag.isNotEmpty && tag[0] == 'e' && tag.length > 1) {
        final targetId = tag[1];
        if (knownEventIds.contains(targetId)) return targetId;
      }
    }
    if (eventIdByCoordinate.isEmpty) return null;
    final coordinate = _extractAddressableId(event);
    if (coordinate == null) return null;
    return eventIdByCoordinate[coordinate];
  }

  /// Publish a downvote (Kind 7 reaction with content '-').
  ///
  /// Optimistic-first: writes the downvote record into [_downvoteRecords]
  /// and ticks [watchDownvotedEventIds] BEFORE the kind-7 publish, mirroring
  /// the upvote flow in [likeEvent]. On publish failure the record is
  /// removed and the stream is ticked again.
  ///
  /// Returns the reaction event ID, or a `pending_downvote_*` placeholder
  /// when the network call hasn't been awaited yet (offline or pre-publish
  /// failure).
  ///
  /// Pass [addressableId] (`kind:pubkey:d-tag`) when the target is
  /// addressable, so the reaction carries NIP-25's `a` tag and survives an
  /// edit of the target.
  ///
  /// Throws [AlreadyDownvotedException] if the event is already downvoted.
  /// Throws [LikeFailedException] if the publish fails.
  Future<String> downvoteEvent({
    required String eventId,
    required String authorPubkey,
    int? targetKind,
    String? addressableId,
  }) async {
    await _ensureInitialized();

    if (_lookupDownvoteRecord(eventId, addressableId) != null) {
      throw AlreadyDownvotedException(eventId);
    }
    if (addressableId != null && addressableId.isNotEmpty) {
      final remoteRecord = await _resolveRemoteDownvoteRecord(
        eventId,
        addressableId: addressableId,
      );
      if (remoteRecord != null) {
        _indexDownvoteRecord(remoteRecord);
        _emitDownvotedIds();
        throw AlreadyDownvotedException(eventId);
      }
    }

    // 1. Optimistic-first: write to memory + tick the stream BEFORE any
    // network I/O. The UI flips here. Mirrors [likeEvent]'s ordering.
    final placeholderId = 'pending_downvote_$eventId';
    final placeholder = LikeRecord(
      targetEventId: eventId,
      reactionEventId: placeholderId,
      createdAt: DateTime.now(),
      addressableId: addressableId,
    );
    _indexDownvoteRecord(placeholder);
    _emitDownvotedIds();

    // 2. Online → publish kind 7 with '-'; on success swap the placeholder
    // for the real id, on failure roll back memory + stream.
    try {
      final reactionEvent = await _nostrClient.sendLike(
        eventId,
        content: _downvoteContent,
        addressableId: addressableId,
        targetAuthorPubkey: authorPubkey,
        targetKind: targetKind,
      );

      if (reactionEvent == null) {
        throw const LikeFailedException('Failed to publish downvote reaction');
      }

      _indexDownvoteRecord(
        LikeRecord(
          targetEventId: eventId,
          reactionEventId: reactionEvent.id,
          createdAt: placeholder.createdAt,
          addressableId: addressableId,
        ),
      );

      return reactionEvent.id;
    } catch (_) {
      _deindexDownvoteRecord(eventId);
      _emitDownvotedIds();
      rethrow;
    }
  }

  /// Remove the current user's downvote on an event.
  ///
  /// Optimistic-first: removes the record + ticks [watchDownvotedEventIds]
  /// BEFORE the kind-5 deletion publish. On failure restores the record and
  /// re-ticks the stream. Mirrors [unlikeEvent].
  ///
  /// Pass [addressableId] when the target is addressable: an edit mints a new
  /// event id under the same coordinate, so the coordinate is the only durable
  /// way to find the reaction afterwards. When the in-memory cache holds
  /// nothing, the relay copy is consulted before giving up.
  ///
  /// Throws [NotDownvotedException] when neither the cache nor the relay has a
  /// live downvote for the target.
  /// Throws [UnlikeFailedException] if the deletion publish fails.
  Future<void> removeDownvote(String eventId, {String? addressableId}) async {
    await _ensureInitialized();

    // [_downvoteRecords] is in-memory only in v1, so a cold start leaves it
    // empty while the kind-7 downvote is still live on relays. Falling back
    // to the relay copy keeps the deletion honest: without it this throws
    // [NotDownvotedException], the caller clears its UI, and the downvote
    // survives untouched and reappears on the next fetch (#6124).
    final record =
        _lookupDownvoteRecord(eventId, addressableId) ??
        await _resolveRemoteDownvoteRecord(
          eventId,
          addressableId: addressableId,
        );
    if (record == null) {
      throw NotDownvotedException(eventId);
    }

    final snapshotRecord = record;

    // 1. Optimistic-first: remove from memory and tick the stream. Deindex by
    // the record's own target id: a coordinate hit can resolve to a record
    // filed under a superseded event id.
    _deindexDownvoteRecord(snapshotRecord.targetEventId);
    _emitDownvotedIds();

    // 2. Skip publishing deletion for placeholders that never reached the
    // relay (e.g. publish failed and the user retried before sync).
    if (snapshotRecord.reactionEventId.startsWith('pending_')) {
      return;
    }

    // 3. Publish kind 5 deletion; on failure roll back memory + stream.
    try {
      final deletionEvent = await _nostrClient.deleteEvent(
        snapshotRecord.reactionEventId,
      );
      if (deletionEvent == null) {
        throw const UnlikeFailedException(
          'Failed to publish downvote deletion',
        );
      }
    } catch (_) {
      _indexDownvoteRecord(snapshotRecord);
      _emitDownvotedIds();
      rethrow;
    }
  }

  /// Toggle the current user's downvote on an event.
  ///
  /// Returns `true` when the event ends up downvoted, `false` when the
  /// downvote was removed. Convenience wrapper around [downvoteEvent] /
  /// [removeDownvote] mirroring [toggleLike].
  Future<bool> toggleDownvote({
    required String eventId,
    required String authorPubkey,
    int? targetKind,
    String? addressableId,
  }) async {
    await _ensureInitialized();

    if (_lookupDownvoteRecord(eventId, addressableId) != null) {
      await removeDownvote(eventId, addressableId: addressableId);
      return false;
    }

    await downvoteEvent(
      eventId: eventId,
      authorPubkey: authorPubkey,
      targetKind: targetKind,
      addressableId: addressableId,
    );
    return true;
  }

  /// Delete a reaction event by its ID (Kind 5 deletion).
  ///
  /// Used for vote switching (removing old vote before publishing new one).
  Future<void> deleteReaction(String reactionEventId) async {
    final deletionEvent = await _nostrClient.deleteEvent(reactionEventId);
    if (deletionEvent == null) {
      throw const UnlikeFailedException('Failed to delete reaction');
    }
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
      records.forEach(_indexLikeRecord);
      _emitLikedIds();
    }

    try {
      // Signed out: keep whatever local storage gave us rather than throwing —
      // there is nothing to reconcile against, which is not a sync failure.
      final pubkey = await _currentUserPubkey();
      if (pubkey == null) {
        Log.warning(
          'Skipping reaction sync: signer has no public key',
          name: 'LikesRepository',
        );
        _isInitialized = true;
        return _buildSyncResult();
      }

      // Fetch both reactions and deletions from relays (authoritative)
      final reactionsFilter = Filter(
        kinds: const [EventKind.reaction],
        authors: [pubkey],
        limit: _defaultReactionFetchLimit,
      );

      final deletionsFilter = Filter(
        kinds: const [EventKind.eventDeletion],
        authors: [pubkey],
        limit: _defaultReactionFetchLimit,
      );

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
          if (tag.isNotEmpty && tag[0] == 'e' && tag.length > 1) {
            deletedReactionIds.add(tag[1]);
          }
        }
      }

      final newRecords = <LikeRecord>[];
      final deletedTargetIds = <String>[];
      final deletedDownvoteTargetIds = <String>[];
      var downvoteCacheChanged = false;

      for (final event in reactionEvents) {
        final targetId = _extractTargetEventId(event);
        if (targetId == null) continue;

        // Skip reactions that have been deleted
        if (deletedReactionIds.contains(event.id)) {
          if (_likeRecords.containsKey(targetId)) {
            deletedTargetIds.add(targetId);
          }
          if (_downvoteRecords.containsKey(targetId)) {
            deletedDownvoteTargetIds.add(targetId);
          }
          continue;
        }

        if (event.content == _likeContent) {
          final record = LikeRecord(
            targetEventId: targetId,
            reactionEventId: event.id,
            createdAt: DateTime.fromMillisecondsSinceEpoch(
              event.createdAt * 1000,
            ),
            addressableId: _extractAddressableId(event),
          );

          // Only update if we don't have this record or the new one is
          // newer — except to backfill a missing coordinate. Rows persisted
          // before the addressable_id column existed carry no coordinate,
          // and the relay copy of the same reaction is never *newer*, so
          // without the exemption they would stay coordinate-less forever
          // (#6123). Restricted to the same reaction id: accepting a
          // different (older) coordinate-bearing reaction would repoint the
          // record at the wrong wire event, so unlike would delete the
          // wrong reaction.
          final existing = _likeRecords[targetId];
          final canBackfillCoordinate =
              existing != null &&
              existing.reactionEventId == record.reactionEventId &&
              (existing.addressableId == null ||
                  existing.addressableId!.isEmpty) &&
              record.addressableId != null &&
              record.addressableId!.isNotEmpty;
          if (existing == null ||
              record.createdAt.isAfter(existing.createdAt) ||
              canBackfillCoordinate) {
            _indexLikeRecord(record);
            newRecords.add(record);
          }
        } else if (event.content == _downvoteContent) {
          final record = LikeRecord(
            targetEventId: targetId,
            reactionEventId: event.id,
            createdAt: DateTime.fromMillisecondsSinceEpoch(
              event.createdAt * 1000,
            ),
            addressableId: _extractAddressableId(event),
          );

          // Mirror the upvote freshness check; downvotes aren't persisted
          // in v1 so there's no batch save. The coordinate is indexed
          // alongside the id so an edited target still resolves (#6124).
          final existing = _downvoteRecords[targetId];
          if (existing == null ||
              record.createdAt.isAfter(existing.createdAt)) {
            _indexDownvoteRecord(record);
            downvoteCacheChanged = true;
          }
        }
      }

      // Remove deleted likes from cache and storage
      for (final targetId in deletedTargetIds) {
        _deindexLikeRecord(targetId);
        await _localStorage?.deleteLikeRecord(targetId);
      }

      // Remove deleted downvotes from in-memory cache (no local storage in v1)
      for (final targetId in deletedDownvoteTargetIds) {
        _deindexDownvoteRecord(targetId);
        downvoteCacheChanged = true;
      }

      // Batch save new records to storage
      if (newRecords.isNotEmpty && _localStorage != null) {
        await _localStorage.saveLikeRecordsBatch(newRecords);
      }

      _emitLikedIds();
      if (downvoteCacheChanged) {
        _emitDownvotedIds();
      }
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

  /// Fetch the list of pubkeys that liked the given video event.
  ///
  /// Queries Nostr relays for kind 7 (NIP-25) reaction events that reference
  /// the target event via the `e` tag and (when [addressableId] is provided)
  /// the `a` tag. Both filters are queried because clients may reference
  /// addressable Kind 30000+ events using either form, and querying only one
  /// would miss likers tagged with the other.
  ///
  /// Filters out:
  /// - Reactions with content `'-'` (downvotes)
  /// - Reactions deleted via Kind 5 deletion events from their author
  /// - Likers hidden by the injected block filter (blocked/muted users)
  ///
  /// Pubkeys are deduplicated (a user who liked via both `e` and `a` tags
  /// only appears once) and ordered by reaction recency, most recent first.
  ///
  /// Parameters:
  /// - [eventId]: Hex event ID of the target event (required).
  /// - [addressableId]: Optional `kind:pubkey:d-tag` for Kind 30000+ events.
  ///
  /// Throws [FetchLikersFailedException] if relay queries fail.
  Future<List<String>> fetchEventLikers({
    required String eventId,
    String? addressableId,
  }) async {
    try {
      final likersByEvent = await _fetchResolvedLikersByEvent(
        [eventId],
        addressableIds: addressableId == null || addressableId.isEmpty
            ? null
            : {eventId: addressableId},
      );
      return likersByEvent[eventId] ?? <String>[];
    } catch (e) {
      throw FetchLikersFailedException(
        'Failed to fetch likers for event $eventId: $e',
      );
    }
  }

  Future<Map<String, List<String>>> _fetchResolvedLikersByEvent(
    List<String> eventIds, {
    Map<String, String>? addressableIds,
  }) async {
    if (eventIds.isEmpty) return const {};

    final eventIdSet = eventIds.toSet();
    final aTagToEventId = <String, String>{
      for (final entry in (addressableIds ?? const <String, String>{}).entries)
        if (entry.value.isNotEmpty) entry.value: entry.key,
    };

    final filterByE = Filter(kinds: const [EventKind.reaction], e: eventIds);
    final eEventsFuture = _nostrClient.queryEvents([filterByE]);
    final aEventsFuture = aTagToEventId.isEmpty
        ? Future<List<Event>>.value(const <Event>[])
        : _nostrClient.queryEvents([
            Filter(
              kinds: const [EventKind.reaction],
              a: aTagToEventId.keys.toList(),
            ),
          ]);
    final queryResults = await Future.wait([eEventsFuture, aEventsFuture]);

    final reactionsByTarget = {
      for (final eventId in eventIds) eventId: <String, Event>{},
    };
    final allReactionsById = <String, Event>{};
    for (final event in [...queryResults[0], ...queryResults[1]]) {
      allReactionsById[event.id] = event;
      final targetIds = _reactionTargetEventIds(
        event,
        eventIdSet: eventIdSet,
        aTagToEventId: aTagToEventId,
      );
      for (final targetId in targetIds) {
        reactionsByTarget[targetId]?[event.id] = event;
      }
    }

    if (allReactionsById.isEmpty) {
      return {for (final eventId in eventIds) eventId: <String>[]};
    }

    final deletedReactionIds = await _deletedReactionIds(allReactionsById);

    return {
      for (final entry in reactionsByTarget.entries)
        entry.key: _activeLikerPubkeys(
          entry.value.values,
          deletedReactionIds: deletedReactionIds,
        ),
    };
  }

  /// Resolves which of [reactionsById] their own author has since retracted.
  ///
  /// Scopes the deletion query to the reaction ids already fetched, so an
  /// `authors:` filter would be redundant (dropped to halve the frame size).
  /// Chunks the `#e` list so a very high-engagement target can't build a
  /// single REQ frame over the relay's `max_message_length` — an oversized
  /// frame errors the socket and the query fails open, counting deletes
  /// (#5751).
  ///
  /// Only honors a Kind 5 whose author matches the reaction's author —
  /// otherwise anyone could suppress someone else's vote by publishing a
  /// deletion that references the other user's reaction id.
  Future<Set<String>> _deletedReactionIds(
    Map<String, Event> reactionsById,
  ) async {
    final reactionIds = reactionsById.keys.toList();
    if (reactionIds.isEmpty) return const {};

    final chunkedDeletions = await Future.wait([
      for (var i = 0; i < reactionIds.length; i += _deletionReqEidChunkSize)
        _nostrClient.queryEvents([
          Filter(
            kinds: const [EventKind.eventDeletion],
            e: reactionIds.sublist(
              i,
              min(i + _deletionReqEidChunkSize, reactionIds.length),
            ),
          ),
        ]),
    ]);

    final deleted = <String>{};
    for (final chunk in chunkedDeletions) {
      for (final deletion in chunk) {
        for (final tag in deletion.tags) {
          if (tag.length > 1 && tag[0] == 'e') {
            final targetId = tag[1];
            final target = reactionsById[targetId];
            if (target != null && target.pubkey == deletion.pubkey) {
              deleted.add(targetId);
            }
          }
        }
      }
    }
    return deleted;
  }

  Set<String> _reactionTargetEventIds(
    Event event, {
    required Set<String> eventIdSet,
    required Map<String, String> aTagToEventId,
  }) {
    final targetIds = <String>{};
    for (final tag in event.tags) {
      if (tag.length <= 1) continue;
      final marker = tag[0];
      final value = tag[1];
      if (marker == 'e' && eventIdSet.contains(value)) {
        targetIds.add(value);
      } else if (marker == 'a') {
        final eventId = aTagToEventId[value];
        if (eventId != null) targetIds.add(eventId);
      }
    }
    return targetIds;
  }

  List<String> _activeLikerPubkeys(
    Iterable<Event> reactions, {
    required Set<String> deletedReactionIds,
  }) {
    final survivors =
        reactions
            .where((event) => event.content != _downvoteContent)
            .where((event) => !deletedReactionIds.contains(event.id))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final likerPubkeys = <String>[];
    final seenPubkeys = <String>{};
    for (final event in survivors) {
      if (_blockFilter?.call(event.pubkey) ?? false) continue;
      if (seenPubkeys.add(event.pubkey)) {
        likerPubkeys.add(event.pubkey);
      }
    }
    return likerPubkeys;
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

  /// Initialize the repository — load from local cache, then subscribe for
  /// real-time cross-device sync.
  ///
  /// Follows the same pattern as `FollowRepository.initialize()`:
  /// 1. Load persisted records from local storage for immediate UI display.
  /// 2. Set up a persistent Kind 7 subscription for live updates.
  /// 3. When any loaded record predates the addressable_id column (null
  ///    coordinate), run [syncUserReactions] to backfill coordinates from
  ///    the relay reactions' `a` tags — otherwise likes made before the
  ///    column shipped never resolve by coordinate after an edit (#6123).
  ///
  /// Safe to call multiple times (idempotent).
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Load from local storage first for immediate UI display
    var hasCoordinatelessRecords = false;
    if (_localStorage != null) {
      final records = await _localStorage.getAllLikeRecords();
      records.forEach(_indexLikeRecord);
      hasCoordinatelessRecords = records.any(
        (r) => r.addressableId == null || r.addressableId!.isEmpty,
      );
      _emitLikedIds();
    }

    final pubkey = await _currentUserPubkey();
    if (pubkey != null) {
      _subscribeToReactions(pubkey);
    }

    // Flip the flag before the backfill sync so _ensureInitialized callers
    // aren't blocked on a relay round-trip.
    _isInitialized = true;

    if (hasCoordinatelessRecords && pubkey != null) {
      try {
        await syncUserReactions();
      } on Exception catch (_) {
        // Best-effort coordinate backfill; initialize() must not fail on
        // relay errors. Records missing a coordinate on the wire (e.g.
        // comment likes, which have no a tag) keep a null coordinate.
      }
    }
  }

  /// Subscribe to reactions for real-time sync and cross-device updates.
  ///
  /// Creates a long-running subscription to the current user's Kind 7 events.
  /// When a newer reaction arrives (from another device or this one),
  /// updates the local cache.
  void _subscribeToReactions(String currentUserPubkey) {
    // Use a deterministic subscription ID so we can unsubscribe later
    _reactionSubscriptionId = 'likes_repo_reactions_$currentUserPubkey';

    final eventStream = _nostrClient.subscribe([
      Filter(
        authors: [currentUserPubkey],
        kinds: const [EventKind.reaction],
        limit: 1,
      ),
    ], subscriptionId: _reactionSubscriptionId);

    _reactionSubscription = eventStream.listen(
      _processIncomingReaction,
      onError: (Object error) {
        // Subscription errors are non-fatal; log and continue
      },
    );
  }

  /// Process an incoming Kind 7 reaction event from the subscription.
  ///
  /// Validates the event, deduplicates against existing records, and
  /// updates the in-memory cache + local storage.
  void _processIncomingReaction(Event event) {
    if (_isDisposed) return;

    // Only process Kind 7 reactions from the current user
    if (event.kind != EventKind.reaction) return;
    if (event.pubkey != _nostrClient.publicKey) return;

    final targetId = _extractTargetEventId(event);
    if (targetId == null) return;

    final createdAt = DateTime.fromMillisecondsSinceEpoch(
      event.createdAt * 1000,
    );

    if (event.content == _likeContent) {
      // Deduplicate upvotes
      final existing = _likeRecords[targetId];
      if (existing != null && !createdAt.isAfter(existing.createdAt)) return;

      final record = LikeRecord(
        targetEventId: targetId,
        reactionEventId: event.id,
        createdAt: createdAt,
        addressableId: _extractAddressableId(event),
      );

      _indexLikeRecord(record);
      unawaited(_localStorage?.saveLikeRecord(record));
      _emitLikedIds();
    } else if (event.content == _downvoteContent) {
      // Deduplicate downvotes (in-memory only — no local persistence in v1)
      final existing = _downvoteRecords[targetId];
      if (existing != null && !createdAt.isAfter(existing.createdAt)) return;

      _indexDownvoteRecord(
        LikeRecord(
          targetEventId: targetId,
          reactionEventId: event.id,
          createdAt: createdAt,
          addressableId: _extractAddressableId(event),
        ),
      );
      _emitDownvotedIds();
    }
  }

  void _decrementLikeCountCache(String eventId, {String? addressableId}) {
    _adjustCachedLikeCount(eventId, -1, addressableId: addressableId);
  }

  /// Reads the cached like count, checking event-id first then the
  /// addressable-id companion cache. Returns `null` on a full miss.
  ///
  /// Mirrors `comments_repository`'s `_readCachedCommentCount` (#4478),
  /// applied to like counts (#6020's in-scope follow-up on #4478's own
  /// suggested-but-unimplemented extension).
  int? _readCachedLikeCount(String eventId, {String? addressableId}) {
    final byEventId = _likeCountCache[eventId];
    if (byEventId != null) return byEventId;
    if (addressableId == null || addressableId.isEmpty) return null;
    return _likeCountCacheByAddressableId[addressableId];
  }

  /// Writes [count] into both caches when [addressableId] is provided.
  /// Otherwise writes only the event-id cache.
  void _writeCachedLikeCount(
    String eventId,
    int count, {
    String? addressableId,
  }) {
    _likeCountCache[eventId] = count;
    if (addressableId != null && addressableId.isNotEmpty) {
      _likeCountCacheByAddressableId[addressableId] = count;
    }
  }

  /// Adjusts the cached like count by [delta] (clamped at zero), dual-
  /// writing both caches. No-op if neither cache has a baseline value yet
  /// — an isolated delta without a known total would lie.
  void _adjustCachedLikeCount(
    String eventId,
    int delta, {
    String? addressableId,
  }) {
    final current = _readCachedLikeCount(eventId, addressableId: addressableId);
    if (current == null) return;
    final updated = current + delta;
    _writeCachedLikeCount(
      eventId,
      updated < 0 ? 0 : updated,
      addressableId: addressableId,
    );
  }

  /// Clear all local like data.
  ///
  /// Used when logging out or clearing user data.
  /// Does not affect data on relays.
  ///
  /// Safe to call after [dispose] -- the cache is still cleared but no
  /// stream emission is attempted.
  Future<void> clearCache() async {
    _likeRecords.clear();
    _likeRecordsByAddressableId.clear();
    _downvoteRecords.clear();
    _downvoteRecordsByAddressableId.clear();
    _likeCountCache.clear();
    _likeCountCacheByAddressableId.clear();
    await _localStorage?.clearAll();
    _emitLikedIds();
    _emitDownvotedIds();
    _isInitialized = false;
  }

  /// Dispose of resources.
  ///
  /// Cancels the reaction subscription and closes all stream controllers.
  /// Should be called when the repository is no longer needed.
  void dispose() {
    _isDisposed = true;
    unawaited(_reactionSubscription?.cancel());
    if (_reactionSubscriptionId != null) {
      unawaited(_nostrClient.unsubscribe(_reactionSubscriptionId!));
      _reactionSubscriptionId = null;
    }
    unawaited(_likedIdsController.close());
    unawaited(_likedAddressableIdsController.close());
    unawaited(_downvotedIdsController.close());
  }

  /// The signed-in user's pubkey, or `null` when the signer has no key.
  ///
  /// Resolves through [NostrClient.resolvePublicKey] rather than reading
  /// `publicKey` directly, so a signer that acquired its key after the client
  /// initialized is picked up here instead of leaving every author-scoped
  /// query below filtering on an empty author (#6813).
  Future<String?> _currentUserPubkey() => _nostrClient.resolvePublicKey();

  /// Ensures the repository is initialized with data from storage.
  Future<void> _ensureInitialized() async {
    if (_isInitialized) return;

    final localStorage = _localStorage;
    if (localStorage != null) {
      try {
        final records = await localStorage.getAllLikeRecords();
        records.forEach(_indexLikeRecord);
        _emitLikedIds();
      } on Object catch (e) {
        // Degrade to an in-memory-only cache rather than failing the caller.
        // Callers are publish paths: an unreadable cache costs a stale
        // already-liked check, while throwing here costs the Kind 7.
        Log.warning(
          'Like cache unavailable; continuing without persisted records: $e',
          name: 'LikesRepository',
          category: LogCategory.system,
        );
      }
    }
    // Latched on both paths: an unreadable database stays unreadable for the
    // session, so retrying would re-throw on every call instead of degrading.
    _isInitialized = true;
  }

  /// Runs a local-storage side effect that must never block a relay publish.
  ///
  /// The local database is a cache. A reaction that reached relays survives
  /// without its cache row; a reaction blocked by an unwritable cache is lost
  /// outright. Storage failures are therefore logged and swallowed.
  ///
  /// Expected IO/corruption failures are not Crashlytics-reportable (see the
  /// decision matrix in `.claude/rules/error_handling.md`); the unified log is
  /// where a degraded cache surfaces.
  Future<T?> _bestEffortLocalStorage<T>(
    Future<T> Function() operation, {
    required String description,
  }) async {
    try {
      return await operation();
    } on Object catch (e) {
      Log.warning(
        'Local like storage unavailable ($description); '
        'continuing without it: $e',
        name: 'LikesRepository',
        category: LogCategory.system,
      );
      return null;
    }
  }

  /// Extracts the target event ID from a reaction event's 'e' tag.
  ///
  /// According to NIP-25, the 'e' tag contains the event ID being reacted to.
  String? _extractTargetEventId(Event event) {
    for (final tag in event.tags) {
      if (tag.isNotEmpty && tag[0] == 'e' && tag.length > 1) {
        return tag[1];
      }
    }
    return null;
  }

  /// Extracts the addressable coordinate from a reaction event's 'a' tag.
  ///
  /// Per NIP-25, an 'a' tag SHOULD be included together with the 'e' tag
  /// when reacting to an addressable event, set to the `kind:pubkey:d-tag`
  /// coordinate. Returns `null` when absent (e.g. reactions to non-
  /// addressable targets like comments, or reactions published before this
  /// tag was added). Used to keep own-like state resolvable by coordinate
  /// across a target edit that mints a new event id (#6020).
  String? _extractAddressableId(Event event) {
    for (final tag in event.tags) {
      if (tag.isNotEmpty && tag[0] == 'a' && tag.length > 1) {
        return tag[1];
      }
    }
    return null;
  }

  /// Resolves the current user's still-live downvote on [eventId] from relays.
  ///
  /// Returns the newest non-deleted kind-7 `-` reaction the user has published
  /// against [eventId], or `null` when there is none. Used by
  /// [removeDownvote] to recover from an empty in-memory cache after a cold
  /// start, since downvotes are not persisted locally in v1.
  Future<LikeRecord?> _resolveRemoteDownvoteRecord(
    String eventId, {
    String? addressableId,
  }) async {
    final pubkey = await _currentUserPubkey();
    if (pubkey == null) return null;

    final hasCoordinate = addressableId != null && addressableId.isNotEmpty;
    final reactions = await _queryVoteTargetReactions(
      eventIds: [eventId],
      eventIdByCoordinate: hasCoordinate
          ? {addressableId: eventId}
          : const <String, String>{},
      authors: [pubkey],
    );

    final candidatesById = <String, Event>{};
    for (final event in reactions) {
      if (event.content != _downvoteContent) continue;
      final matches =
          _extractTargetEventId(event) == eventId ||
          (hasCoordinate && _extractAddressableId(event) == addressableId);
      if (matches) candidatesById[event.id] = event;
    }
    final candidates = candidatesById.values.toList();
    if (candidates.isEmpty) return null;

    final deletions = await _nostrClient.queryEvents([
      Filter(
        kinds: const [EventKind.eventDeletion],
        authors: [pubkey],
        e: candidates.map((event) => event.id).toList(),
      ),
    ]);

    final deletedIds = <String>{};
    for (final deletion in deletions) {
      for (final tag in deletion.tags) {
        if (tag.isNotEmpty && tag[0] == 'e' && tag.length > 1) {
          deletedIds.add(tag[1]);
        }
      }
    }

    final live =
        candidates.where((event) => !deletedIds.contains(event.id)).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (live.isEmpty) return null;

    final newest = live.first;
    return LikeRecord(
      targetEventId: eventId,
      reactionEventId: newest.id,
      createdAt: DateTime.fromMillisecondsSinceEpoch(newest.createdAt * 1000),
      addressableId: _extractAddressableId(newest),
    );
  }
}
