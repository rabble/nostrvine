// ABOUTME: Repository for managing follow relationships (follow/unfollow)
// ABOUTME: Single source of truth for follow data with in-memory cache, local storage, and API sync
// ABOUTME: Supports offline queuing via callback injection

// TODO(refactor): Extract this to packages/follow_repository once dependencies are resolved.
// Currently blocked by app-level dependencies:
// - PersonalEventCacheService (needs interface extraction)
// - unified_logger (needs logging abstraction)
// See packages/nostr_client for the pattern to follow.

import 'dart:async';
import 'dart:convert';

import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/constants/nostr_event_kinds.dart';
import 'package:openvine/services/immediate_completion_helper.dart';
import 'package:openvine/services/personal_event_cache_service.dart';
import 'package:openvine/services/relay_discovery_service.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Callback to check if the device is currently online
typedef IsOnlineCallback = bool Function();

/// Callback to queue an action for offline sync
typedef QueueOfflineFollowCallback =
    Future<void> Function({required bool isFollow, required String pubkey});

/// Callback to fetch following list from REST API (funnelcake)
typedef FetchFollowingFromApiCallback =
    Future<List<String>> Function(String pubkey);

/// Callback to fetch followers list from REST API (funnelcake)
typedef FetchFollowersFromApiCallback =
    Future<List<String>> Function(String pubkey);

/// Callback to fetch follower count from a source with accurate counts
/// (e.g. SocialService which uses COUNT queries to indexer relays).
typedef FetchFollowerCountCallback = Future<int> Function(String pubkey);

/// Repository for managing follow relationships.
/// Single source of truth for follow data.
///
/// Responsibilities:
/// - In-memory cache of following pubkeys
/// - Local storage persistence (SharedPreferences)
/// - Network sync (Nostr Kind 3 events)
///
/// Exposes a stream for reactive updates to the following list.
class FollowRepository {
  FollowRepository({
    required NostrClient nostrClient,
    PersonalEventCacheService? personalEventCache,
    FunnelcakeApiClient? funnelcakeApiClient,
    IsOnlineCallback? isOnline,
    QueueOfflineFollowCallback? queueOfflineAction,
    FetchFollowingFromApiCallback? fetchFollowingFromApi,
    FetchFollowersFromApiCallback? fetchFollowersFromApi,
    FetchFollowerCountCallback? fetchFollowerCount,
    List<String>? indexerRelayUrls,
  }) : _nostrClient = nostrClient,
       _personalEventCache = personalEventCache,
       _funnelcakeApiClient = funnelcakeApiClient,
       _isOnline = isOnline,
       _queueOfflineAction = queueOfflineAction,
       _fetchFollowingFromApi = fetchFollowingFromApi,
       _fetchFollowersFromApi = fetchFollowersFromApi,
       _fetchFollowerCount = fetchFollowerCount,
       _indexerRelayUrls =
           indexerRelayUrls ?? IndexerRelayConfig.defaultIndexers;

  final NostrClient _nostrClient;
  final PersonalEventCacheService? _personalEventCache;
  final FunnelcakeApiClient? _funnelcakeApiClient;

  /// Callback to check if the device is online
  final IsOnlineCallback? _isOnline;

  /// Callback to queue actions for offline sync
  final QueueOfflineFollowCallback? _queueOfflineAction;

  /// Callback to fetch following list from REST API (fast, non-blocking)
  final FetchFollowingFromApiCallback? _fetchFollowingFromApi;

  /// Callback to fetch followers list from REST API (fast, non-blocking)
  final FetchFollowersFromApiCallback? _fetchFollowersFromApi;

  /// Callback to fetch accurate follower count (e.g. from SocialService)
  final FetchFollowerCountCallback? _fetchFollowerCount;

  /// Indexer relay URLs for direct WebSocket queries.
  /// Pass empty list in tests to prevent real network connections.
  final List<String> _indexerRelayUrls;

  // Default indexer relays come from IndexerRelayConfig.defaultIndexers.

  // BehaviorSubject replays last value to late subscribers, fixing race condition
  // where BLoC subscribes AFTER initial emission
  final _followingSubject = BehaviorSubject<List<String>>.seeded(const []);
  Stream<List<String>> get followingStream => _followingSubject.stream;

  // In-memory cache
  List<String> _followingPubkeys = [];
  Event? _currentUserContactListEvent;
  bool _isInitialized = false;

  // Real-time sync subscription for cross-device synchronization
  StreamSubscription<Event>? _contactListSubscription;
  String? _contactListSubscriptionId;

  // Getters
  List<String> get followingPubkeys => List.unmodifiable(_followingPubkeys);
  bool get isInitialized => _isInitialized;
  int get followingCount => _followingPubkeys.length;

  /// Emit current state to stream (only if the list actually changed)
  void _emitFollowingList() {
    if (!_followingSubject.isClosed) {
      final newList = List<String>.unmodifiable(_followingPubkeys);
      final currentList = _followingSubject.valueOrNull;
      if (currentList == null ||
          newList.length != currentList.length ||
          !_listsEqual(newList, currentList)) {
        _followingSubject.add(newList);
      }
    }
  }

  /// Compare two lists for equality by value
  bool _listsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Dispose resources (idempotent — safe to call multiple times).
  Future<void> dispose() async {
    _contactListSubscription?.cancel();
    if (_contactListSubscriptionId != null) {
      await _nostrClient.unsubscribe(_contactListSubscriptionId!);
      _contactListSubscriptionId = null;
    }
    if (!_followingSubject.isClosed) {
      _followingSubject.close();
    }
  }

  /// Check if current user is following a specific pubkey
  bool isFollowing(String pubkey) => _followingPubkeys.contains(pubkey);

  /// Get the list of followers for the current user.
  ///
  /// Queries Nostr relays for Kind 3 (contact list) events that mention
  /// the current user's pubkey in their 'p' tags.
  ///
  /// Returns a list of unique pubkeys of users who follow the current user.
  Future<List<String>> getMyFollowers() async {
    return _fetchFollowers(_nostrClient.publicKey);
  }

  /// Get the list of followers for another user.
  ///
  /// Queries Nostr relays for Kind 3 (contact list) events that mention
  /// the target pubkey in their 'p' tags.
  ///
  /// Returns a list of unique pubkeys of users who follow the target.
  Future<List<String>> getFollowers(String pubkey) async {
    return _fetchFollowers(pubkey);
  }

  /// Get an accurate follower count for the current user.
  ///
  /// Delegates to [_fetchFollowerCount] callback (typically SocialService)
  /// which uses COUNT queries to indexer relays for accurate results.
  /// Returns 0 if no callback is configured.
  Future<int> getMyFollowerCount() async {
    return getFollowerCount(_nostrClient.publicKey);
  }

  /// Get an accurate follower count for any user.
  ///
  /// Delegates to [_fetchFollowerCount] callback (typically SocialService)
  /// which uses COUNT queries to indexer relays for accurate results.
  /// Returns 0 if no callback is configured.
  Future<int> getFollowerCount(String pubkey) async {
    if (_fetchFollowerCount == null) return 0;
    try {
      return await _fetchFollowerCount(pubkey);
    } catch (e) {
      Log.warning(
        'Error fetching follower count for $pubkey: $e',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
      return 0;
    }
  }

  /// Fetches follower/following counts from the Funnelcake REST API.
  ///
  /// Returns [SocialCounts] or null if the API is unavailable.
  ///
  /// Throws [FunnelcakeException] subtypes on API errors.
  Future<SocialCounts?> getSocialCounts(String pubkey) async {
    if (_funnelcakeApiClient == null || !_funnelcakeApiClient.isAvailable) {
      return null;
    }
    return _funnelcakeApiClient.getSocialCounts(pubkey);
  }

  /// Fetches paginated followers from the Funnelcake REST API.
  ///
  /// Unlike [getFollowers] which merges multiple sources,
  /// this returns paginated results from the API only.
  /// Returns null if the API is unavailable.
  ///
  /// Throws [FunnelcakeException] subtypes on API errors.
  Future<PaginatedPubkeys?> getFollowersFromApi({
    required String pubkey,
    int limit = 100,
    int offset = 0,
  }) async {
    if (_funnelcakeApiClient == null || !_funnelcakeApiClient.isAvailable) {
      return null;
    }
    return _funnelcakeApiClient.getFollowers(
      pubkey: pubkey,
      limit: limit,
      offset: offset,
    );
  }

  /// Fetches paginated following list from the Funnelcake REST API.
  ///
  /// Returns null if the API is unavailable.
  ///
  /// Throws [FunnelcakeException] subtypes on API errors.
  Future<PaginatedPubkeys?> getFollowingFromApi({
    required String pubkey,
    int limit = 100,
    int offset = 0,
  }) async {
    if (_funnelcakeApiClient == null || !_funnelcakeApiClient.isAvailable) {
      return null;
    }
    return _funnelcakeApiClient.getFollowing(
      pubkey: pubkey,
      limit: limit,
      offset: offset,
    );
  }

  /// Timeout for fetching followers from relays
  static const _fetchFollowersTimeout = Duration(seconds: 5);

  /// Fetch followers for a given pubkey.
  ///
  /// Runs REST API, connected relay, and indexer relay queries in parallel
  /// and merges results (union of pubkeys). The REST API (Funnelcake) only
  /// indexes kind 3 events seen on the divine relay, so follower lists are
  /// often incomplete. Connected relays may timeout. Indexer relays
  /// (relay.damus.io, purplepag.es) maintain broad kind 3 indexes and
  /// provide the most complete follower lists.
  ///
  /// Returns empty list on timeout or failure.
  Future<List<String>> _fetchFollowers(String pubkey) async {
    if (pubkey.isEmpty) {
      return [];
    }

    // Run all three sources in parallel for best coverage
    final apiFuture = _fetchFollowersFromApi != null
        ? _fetchFollowersFromApi(pubkey).catchError((_) => <String>[])
        : Future.value(<String>[]);

    final relayFuture = _fetchFollowersFromRelays(pubkey);
    final indexerFuture = _fetchFollowerPubkeysFromIndexers(
      pubkey,
    ).catchError((_) => <String>[]);

    final results = await Future.wait([apiFuture, relayFuture, indexerFuture]);
    final apiFollowers = results[0];
    final relayFollowers = results[1];
    final indexerFollowers = results[2];

    // Merge all sources (union of pubkeys)
    final merged = <String>{
      ...apiFollowers,
      ...relayFollowers,
      ...indexerFollowers,
    };

    Log.info(
      'Followers for $pubkey: API=${apiFollowers.length}, '
      'relays=${relayFollowers.length}, '
      'indexers=${indexerFollowers.length}, merged=${merged.length}',
      name: 'FollowRepository',
      category: LogCategory.system,
    );

    return merged.toList();
  }

  /// Query connected relays for kind 3 events mentioning a pubkey.
  Future<List<String>> _fetchFollowersFromRelays(String pubkey) async {
    try {
      final events = await _nostrClient
          .queryEvents([
            Filter(kinds: const [NostrEventKinds.contactList], p: [pubkey]),
          ])
          .timeout(
            _fetchFollowersTimeout,
            onTimeout: () {
              Log.warning(
                'Followers relay query timed out for $pubkey',
                name: 'FollowRepository',
                category: LogCategory.system,
              );
              return <Event>[];
            },
          );

      final followers = <String>[];
      for (final event in events) {
        if (!followers.contains(event.pubkey)) {
          followers.add(event.pubkey);
        }
      }
      return followers;
    } on TimeoutException {
      Log.warning(
        'Followers relay query timed out for $pubkey',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
      return [];
    }
  }

  /// Query indexer relays for kind 3 events mentioning a pubkey.
  ///
  /// Returns actual pubkeys (not just a count) so results can be merged
  /// with API and connected relay results.
  Future<List<String>> _fetchFollowerPubkeysFromIndexers(String pubkey) async {
    final allFollowers = <String>{};

    final results = await Future.wait(
      _indexerRelayUrls.map(
        (url) => _queryIndexerForFollowerPubkeys(
          url,
          pubkey,
        ).catchError((_) => <String>[]),
      ),
    );

    for (final pubkeys in results) {
      allFollowers.addAll(pubkeys);
    }

    Log.debug(
      'Indexer follower pubkeys: ${allFollowers.length} for $pubkey',
      name: 'FollowRepository',
      category: LogCategory.system,
    );

    return allFollowers.toList();
  }

  /// Query a single indexer relay for kind 3 events mentioning pubkey.
  /// Returns the list of follower pubkeys.
  Future<List<String>> _queryIndexerForFollowerPubkeys(
    String indexerUrl,
    String pubkey,
  ) async {
    final relayStatus = RelayStatus(indexerUrl);
    final relay = RelayBase(indexerUrl, relayStatus);
    final completer = Completer<List<String>>();
    final followerPubkeys = <String>{};
    final subscriptionId = 'fr_${DateTime.now().millisecondsSinceEpoch}';

    relay.onMessage = (relay, jsonMsg) async {
      if (jsonMsg.isEmpty) return;

      final messageType = jsonMsg[0] as String;

      if (messageType == 'EVENT' && jsonMsg.length >= 3) {
        final eventJson = jsonMsg[2] as Map<String, dynamic>;
        final eventPubkey = eventJson['pubkey'] as String?;
        if (eventPubkey != null) {
          followerPubkeys.add(eventPubkey);
        }
      } else if (messageType == 'EOSE') {
        if (!completer.isCompleted) {
          completer.complete(followerPubkeys.toList());
        }
      }
    };

    try {
      final filter = <String, dynamic>{
        'kinds': <int>[NostrEventKinds.contactList],
        '#p': <String>[pubkey],
      };
      relay.pendingMessages.add(<dynamic>['REQ', subscriptionId, filter]);

      final connected = await relay.connect();
      if (!connected) {
        return [];
      }

      final result = await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: followerPubkeys.toList,
      );

      await relay.send(<dynamic>['CLOSE', subscriptionId]);
      return result;
    } catch (e) {
      Log.warning(
        'Error querying $indexerUrl for followers: $e',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
      return followerPubkeys.toList();
    } finally {
      try {
        await relay.disconnect();
      } catch (_) {}
    }
  }

  /// Check if the current user and another user mutually follow each other.
  ///
  /// Returns true only if:
  /// 1. The current user is following [pubkey] (local cache check, instant)
  /// 2. [pubkey] is following the current user (relay query for their Kind 3)
  ///
  /// Returns false if either direction is not a follow, or on timeout/error.
  Future<bool> isMutualFollow(String pubkey) async {
    // Step 1: Check if we follow them (instant, from local cache)
    if (!isFollowing(pubkey)) return false;

    // Step 2: Check if they follow us (requires relay query)
    try {
      final theirFollowers = await _fetchFollowers(_nostrClient.publicKey);
      return theirFollowers.contains(pubkey) ||
          // They follow us means their contact list mentions our pubkey.
          // _fetchFollowers returns authors of events mentioning us in p-tags,
          // so we check if the target pubkey is among those authors.
          await _checkIfTheyFollowUs(pubkey);
    } catch (e) {
      Log.warning(
        'Failed to check mutual follow for $pubkey: $e',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
      return false;
    }
  }

  /// Check if [pubkey] follows the current user by querying their Kind 3 event.
  Future<bool> _checkIfTheyFollowUs(String pubkey) async {
    if (pubkey.isEmpty || _nostrClient.publicKey.isEmpty) return false;

    try {
      final events = await _nostrClient
          .queryEvents([
            Filter(
              authors: [pubkey],
              kinds: const [NostrEventKinds.contactList],
              limit: 1,
            ),
          ])
          .timeout(_fetchFollowersTimeout, onTimeout: () => <Event>[]);

      if (events.isEmpty) return false;

      // Check if our pubkey is in their contact list p-tags
      final contactList = events.first;
      for (final tag in contactList.tags) {
        if (tag.isNotEmpty &&
            tag[0] == 'p' &&
            tag.length > 1 &&
            tag[1] == _nostrClient.publicKey) {
          return true;
        }
      }
      return false;
    } catch (e) {
      Log.warning(
        'Failed to check if $pubkey follows us: $e',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
      return false;
    }
  }

  /// Toggle follow status for a user.
  Future<void> toggleFollow(String pubkey) async {
    if (isFollowing(pubkey)) {
      await unfollow(pubkey);
    } else {
      await follow(pubkey);
    }
  }

  /// Initialize the repository - load from local cache, then sync with network
  Future<void> initialize() async {
    if (_isInitialized) return;

    Log.debug(
      'Initializing FollowRepository',
      name: 'FollowRepository',
      category: LogCategory.system,
    );

    try {
      // 1. Load from local storage first for immediate UI display
      await _loadFromLocalStorage();

      // 2. Load from PersonalEventCache if available
      await _loadFromPersonalEventCache();

      // 3. If still empty, try REST API (funnelcake) for fast bootstrap
      if (_followingPubkeys.isEmpty && _fetchFollowingFromApi != null) {
        await _loadFromRestApi();
      }

      // 4. If still empty, query relays for kind 3 contact list directly.
      // The REST API may not have indexed the user's contact list yet,
      // but the relay has the authoritative kind 3 event.
      if (_followingPubkeys.isEmpty && _nostrClient.hasKeys) {
        await _loadFromRelay();
      }

      // 5. Subscribe to contact list for real-time sync and cross-device
      // updates (fires on future changes, not initial load)
      if (_nostrClient.hasKeys) {
        _subscribeToContactList();
      }

      _isInitialized = true;

      Log.info(
        'FollowRepository initialized: ${_followingPubkeys.length} following',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'FollowRepository initialization error: $e',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
    }
  }

  /// Follow a user
  Future<void> follow(String pubkey) async {
    if (!_nostrClient.hasKeys) {
      Log.error(
        'Cannot follow - user not authenticated',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
      throw Exception('User not authenticated');
    }

    // Guard: Prevent following self
    if (pubkey == _nostrClient.publicKey) {
      Log.warning(
        'Attempted to follow self - ignoring',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
      return;
    }

    if (_followingPubkeys.contains(pubkey)) {
      Log.debug(
        'Already following user: $pubkey',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
      return;
    }

    Log.debug(
      'Following user: $pubkey',
      name: 'FollowRepository',
      category: LogCategory.system,
    );

    // Store previous state for rollback
    final previousFollowList = List<String>.from(_followingPubkeys);

    // 1. Update in-memory cache immediately
    _followingPubkeys = [..._followingPubkeys, pubkey];
    _emitFollowingList();

    // Check if offline and queue if needed
    if (_isOnline != null && !_isOnline() && _queueOfflineAction != null) {
      await _queueOfflineAction(isFollow: true, pubkey: pubkey);

      // Save to local storage for persistence
      await _saveToLocalStorage();

      Log.info(
        'Queued follow action for offline sync: $pubkey',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
      return;
    }

    try {
      // 2. Broadcast to network
      await _broadcastContactList();

      // 3. Save to local storage
      await _saveToLocalStorage();

      Log.info(
        'Successfully followed user: $pubkey',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
    } catch (e) {
      // Rollback on failure
      _followingPubkeys = previousFollowList;
      _emitFollowingList();

      Log.error(
        'Error following user: $e',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
      rethrow;
    }
  }

  /// Execute a follow action directly (for use by sync service).
  ///
  /// This method bypasses offline queuing and directly broadcasts to relays.
  /// Used by PendingActionService to execute queued actions.
  Future<void> executeFollowAction(String pubkey) async {
    if (!_nostrClient.hasKeys) {
      throw Exception('User not authenticated');
    }

    // Ensure pubkey is in the list (it should be from optimistic update)
    if (!_followingPubkeys.contains(pubkey)) {
      _followingPubkeys = [..._followingPubkeys, pubkey];
      _emitFollowingList();
    }

    // Broadcast to network
    await _broadcastContactList();

    // Save to local storage
    await _saveToLocalStorage();

    Log.info(
      'Executed follow action for: $pubkey',
      name: 'FollowRepository',
      category: LogCategory.system,
    );
  }

  /// Unfollow a user
  Future<void> unfollow(String pubkey) async {
    if (!_nostrClient.hasKeys) {
      Log.error(
        'Cannot unfollow - user not authenticated',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
      throw Exception('User not authenticated');
    }

    // Guard: Prevent unfollowing self
    if (pubkey == _nostrClient.publicKey) {
      Log.warning(
        'Attempted to unfollow self - ignoring',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
      return;
    }

    if (!_followingPubkeys.contains(pubkey)) {
      Log.debug(
        'Not following user: $pubkey',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
      return;
    }

    Log.debug(
      'Unfollowing user: $pubkey',
      name: 'FollowRepository',
      category: LogCategory.system,
    );

    // Store previous state for rollback
    final previousFollowList = List<String>.from(_followingPubkeys);

    // 1. Update in-memory cache immediately
    _followingPubkeys = _followingPubkeys.where((p) => p != pubkey).toList();
    _emitFollowingList();

    // Check if offline and queue if needed
    if (_isOnline != null && !_isOnline() && _queueOfflineAction != null) {
      await _queueOfflineAction(isFollow: false, pubkey: pubkey);

      // Save to local storage for persistence
      await _saveToLocalStorage();

      Log.info(
        'Queued unfollow action for offline sync: $pubkey',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
      return;
    }

    try {
      // 2. Broadcast to network
      await _broadcastContactList();

      // 3. Save to local storage
      await _saveToLocalStorage();

      Log.info(
        'Successfully unfollowed user: $pubkey',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
    } catch (e) {
      // Rollback on failure
      _followingPubkeys = previousFollowList;
      _emitFollowingList();

      Log.error(
        'Error unfollowing user: $e',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
      rethrow;
    }
  }

  /// Execute an unfollow action directly (for use by sync service).
  ///
  /// This method bypasses offline queuing and directly broadcasts to relays.
  /// Used by PendingActionService to execute queued actions.
  Future<void> executeUnfollowAction(String pubkey) async {
    if (!_nostrClient.hasKeys) {
      throw Exception('User not authenticated');
    }

    // Ensure pubkey is removed from the list (it should be from optimistic update)
    if (_followingPubkeys.contains(pubkey)) {
      _followingPubkeys = _followingPubkeys.where((p) => p != pubkey).toList();
      _emitFollowingList();
    }

    // Broadcast to network
    await _broadcastContactList();

    // Save to local storage
    await _saveToLocalStorage();

    Log.info(
      'Executed unfollow action for: $pubkey',
      name: 'FollowRepository',
      category: LogCategory.system,
    );
  }

  /// Merge follows from another contact list event (union merge for conflict resolution).
  ///
  /// Used when syncing offline actions - combines local follows with
  /// any follows that were added on other devices while offline.
  Future<void> mergeFollows(List<String> additionalPubkeys) async {
    final merged = <String>{..._followingPubkeys, ...additionalPubkeys};

    // Remove self if accidentally included
    merged.remove(_nostrClient.publicKey);

    if (merged.length != _followingPubkeys.length ||
        !merged.every(_followingPubkeys.contains)) {
      _followingPubkeys = merged.toList();
      _emitFollowingList();

      // Broadcast the merged list
      await _broadcastContactList();
      await _saveToLocalStorage();

      Log.info(
        'Merged contact lists: now following ${_followingPubkeys.length} users',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
    }
  }

  /// Load following list from local storage (SharedPreferences)
  Future<void> _loadFromLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUserPubkey = _nostrClient.publicKey;

      if (currentUserPubkey.isNotEmpty) {
        final key = 'following_list_$currentUserPubkey';
        final cached = prefs.getString(key);

        if (cached != null) {
          final List<dynamic> decoded = jsonDecode(cached);
          _followingPubkeys = decoded.cast<String>();
          _emitFollowingList();

          Log.info(
            'Loaded cached following list: ${_followingPubkeys.length} users',
            name: 'FollowRepository',
            category: LogCategory.system,
          );
        }
      }
    } catch (e) {
      Log.error(
        'Failed to load following list from cache: $e',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
    }
  }

  /// Load from PersonalEventCache (Kind 3 events)
  Future<void> _loadFromPersonalEventCache() async {
    if (_personalEventCache?.isInitialized != true) return;

    try {
      final cachedContactLists = _personalEventCache!.getEventsByKind(
        NostrEventKinds.contactList,
      );

      if (cachedContactLists.isNotEmpty) {
        // Use the most recent contact list event
        final latestContactList = cachedContactLists.first;

        final pTags = latestContactList.tags.where(
          (tag) => tag.isNotEmpty && tag[0] == 'p',
        );

        final pubkeys = pTags
            .map((tag) => tag.length > 1 ? tag[1] : '')
            .where((pubkey) => pubkey.isNotEmpty)
            .cast<String>()
            .toList();

        if (pubkeys.isNotEmpty) {
          _followingPubkeys = pubkeys;
          _currentUserContactListEvent = latestContactList;
          _emitFollowingList();

          Log.debug(
            'Loaded following from PersonalEventCache: ${pubkeys.length} users',
            name: 'FollowRepository',
            category: LogCategory.system,
          );
        }
      }
    } catch (e) {
      Log.error(
        'Failed to load from PersonalEventCache: $e',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
    }
  }

  /// Load following list from REST API (funnelcake) for fast bootstrap.
  ///
  /// Called only when local cache and PersonalEventCache are both empty
  /// (e.g., first login or after identity change cleanup). This provides
  /// the following list before the WebSocket subscription can deliver it.
  Future<void> _loadFromRestApi() async {
    try {
      final currentUserPubkey = _nostrClient.publicKey;
      if (currentUserPubkey.isEmpty) return;

      Log.info(
        'Loading following list from REST API (cache was empty)',
        name: 'FollowRepository',
        category: LogCategory.system,
      );

      final pubkeys = await _fetchFollowingFromApi!(currentUserPubkey);

      if (pubkeys.isNotEmpty) {
        _followingPubkeys = pubkeys;
        _emitFollowingList();

        // Persist to SharedPreferences so redirect logic can use it
        await _saveToLocalStorage();

        Log.info(
          'Loaded following from REST API: ${pubkeys.length} users',
          name: 'FollowRepository',
          category: LogCategory.system,
        );
      } else {
        Log.debug(
          'REST API returned empty following list',
          name: 'FollowRepository',
          category: LogCategory.system,
        );
      }
    } catch (e) {
      Log.warning(
        'Failed to load following from REST API (will rely on relay): $e',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
    }
  }

  /// Save following list to local storage
  Future<void> _saveToLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUserPubkey = _nostrClient.publicKey;

      if (currentUserPubkey.isNotEmpty) {
        final key = 'following_list_$currentUserPubkey';
        await prefs.setString(key, jsonEncode(_followingPubkeys));

        Log.debug(
          'Saved following list to cache: ${_followingPubkeys.length} users',
          name: 'FollowRepository',
          category: LogCategory.system,
        );
      }
    } catch (e) {
      Log.error(
        'Failed to save following list to cache: $e',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
    }
  }

  /// Query relays for the user's kind 3 contact list.
  ///
  /// Uses [ContactListCompletionHelper] (same proven approach as
  /// SocialService) to do a one-shot query with proper EOSE handling.
  /// Called when local cache and REST API are both empty.
  Future<void> _loadFromRelay() async {
    try {
      final currentUserPubkey = _nostrClient.publicKey;
      if (currentUserPubkey.isEmpty) return;

      Log.info(
        'Querying relay for kind 3 contact list '
        '(REST API had no data)',
        name: 'FollowRepository',
        category: LogCategory.system,
      );

      // Query connected relays and indexer relays in parallel.
      // Connected relays may not have the contact list yet (relay discovery
      // runs in background and may not have completed), so also query indexer
      // relays directly as a fallback.
      final results = await Future.wait([
        _loadContactListFromConnectedRelays(currentUserPubkey),
        _loadContactListFromIndexer(currentUserPubkey),
      ]);

      // Use whichever returned a result (prefer the one with more p-tags)
      final connectedResult = results[0];
      final indexerResult = results[1];

      final event = _pickBestContactList(connectedResult, indexerResult);

      if (event != null) {
        _processContactListEvent(event);

        Log.info(
          'Loaded following from relay kind 3: '
          '${_followingPubkeys.length} users',
          name: 'FollowRepository',
          category: LogCategory.system,
        );
      } else {
        Log.debug(
          'No kind 3 contact list found on relay '
          '(user may genuinely follow nobody)',
          name: 'FollowRepository',
          category: LogCategory.system,
        );
      }
    } catch (e) {
      Log.warning(
        'Failed to load following from relay: $e',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
    }
  }

  /// Query connected relays for kind 3 contact list.
  Future<Event?> _loadContactListFromConnectedRelays(String pubkey) async {
    try {
      final eventStream = _nostrClient.subscribe([
        Filter(
          authors: [pubkey],
          kinds: const [NostrEventKinds.contactList],
          limit: 1,
        ),
      ]);

      return await ContactListCompletionHelper.queryContactList(
        eventStream: eventStream,
        pubkey: pubkey,
        fallbackTimeoutSeconds: 5,
      );
    } catch (e) {
      Log.warning(
        'Connected relay contact list query failed: $e',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
      return null;
    }
  }

  /// Query indexer relays directly for the user's kind 3 contact list.
  ///
  /// Connected relays may not be ready yet (relay discovery runs in
  /// background), so this provides a reliable fallback via direct WebSocket.
  Future<Event?> _loadContactListFromIndexer(String pubkey) async {
    for (final indexerUrl in _indexerRelayUrls) {
      try {
        final event = await _queryIndexerForContactList(indexerUrl, pubkey);
        if (event != null) {
          Log.info(
            'Got contact list from indexer $indexerUrl',
            name: 'FollowRepository',
            category: LogCategory.system,
          );
          return event;
        }
      } catch (e) {
        Log.warning(
          'Indexer $indexerUrl contact list query failed: $e',
          name: 'FollowRepository',
          category: LogCategory.system,
        );
      }
    }
    return null;
  }

  /// Query a single indexer relay for kind 3 via direct WebSocket.
  Future<Event?> _queryIndexerForContactList(
    String indexerUrl,
    String pubkey,
  ) async {
    final relayStatus = RelayStatus(indexerUrl);
    final relay = RelayBase(indexerUrl, relayStatus);
    final completer = Completer<Event?>();
    final subscriptionId = 'cl_${DateTime.now().millisecondsSinceEpoch}';
    Event? bestEvent;

    relay.onMessage = (relay, jsonMsg) async {
      if (jsonMsg.isEmpty) return;

      final messageType = jsonMsg[0] as String;

      if (messageType == 'EVENT' && jsonMsg.length >= 3) {
        final eventJson = jsonMsg[2] as Map<String, dynamic>;
        try {
          final event = Event.fromJson(eventJson);
          if (bestEvent == null || event.createdAt > bestEvent!.createdAt) {
            bestEvent = event;
          }
        } catch (e) {
          Log.warning(
            'Failed to parse kind 3 event from $indexerUrl: $e',
            name: 'FollowRepository',
            category: LogCategory.system,
          );
        }
      } else if (messageType == 'EOSE') {
        if (!completer.isCompleted) {
          completer.complete(bestEvent);
        }
      }
    };

    try {
      final filter = <String, dynamic>{
        'kinds': <int>[NostrEventKinds.contactList],
        'authors': <String>[pubkey],
        'limit': 1,
      };
      relay.pendingMessages.add(<dynamic>['REQ', subscriptionId, filter]);

      final connected = await relay.connect();
      if (!connected) return null;

      final result = await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => bestEvent,
      );

      await relay.send(<dynamic>['CLOSE', subscriptionId]);
      return result;
    } catch (e) {
      Log.warning(
        'Error querying $indexerUrl for contact list: $e',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
      return bestEvent;
    } finally {
      try {
        await relay.disconnect();
      } catch (_) {}
    }
  }

  /// Pick the best contact list from two sources.
  /// Prefers the newest event by createdAt since kind 3 is replaceable
  /// (NIP-02) — a user may intentionally unfollow people, reducing p-tags.
  Event? _pickBestContactList(Event? a, Event? b) {
    if (a == null) return b;
    if (b == null) return a;
    return b.createdAt > a.createdAt ? b : a;
  }

  /// Subscribe to contact list for real-time sync and cross-device updates.
  ///
  /// Creates a long-running subscription to the current user's Kind 3 events.
  /// When a newer contact list arrives (from another device or this one),
  /// updates the local list.
  void _subscribeToContactList() {
    final currentUserPubkey = _nostrClient.publicKey;
    if (currentUserPubkey.isEmpty) return;

    Log.debug(
      'Subscribing to contact list for: $currentUserPubkey',
      name: 'FollowRepository',
      category: LogCategory.system,
    );

    // Use a deterministic subscription ID so we can unsubscribe later
    _contactListSubscriptionId = 'follow_repo_contact_list_$currentUserPubkey';

    final eventStream = _nostrClient.subscribe([
      Filter(
        authors: [currentUserPubkey],
        kinds: const [NostrEventKinds.contactList],
        limit: 1,
      ),
    ], subscriptionId: _contactListSubscriptionId);

    _contactListSubscription = eventStream.listen(
      (event) {
        // Only process Kind 3 events from the current user
        if (event.kind == NostrEventKinds.contactList &&
            event.pubkey == currentUserPubkey) {
          _processContactListEvent(event);
        }
      },
      onError: (error) {
        Log.error(
          'Real-time contact list subscription error: $error',
          name: 'FollowRepository',
          category: LogCategory.system,
        );
      },
    );
  }

  /// Broadcast updated contact list to network (Kind 3 event)
  Future<void> _broadcastContactList() async {
    // Create ContactList with all followed pubkeys
    final contactList = ContactList();
    for (final pubkey in _followingPubkeys) {
      contactList.add(Contact(publicKey: pubkey));
    }

    // Preserve existing content from previous contact list event if available
    final content = _currentUserContactListEvent?.content ?? '';

    // Send the contact list via NostrClient (creates, signs, and broadcasts)
    final event = await _nostrClient.sendContactList(contactList, content);

    if (event == null) {
      throw Exception('Failed to broadcast contact list');
    }

    // Cache the contact list event
    _personalEventCache?.cacheUserEvent(event);

    _currentUserContactListEvent = event;

    Log.debug(
      'Broadcasted contact list: ${event.id}',
      name: 'FollowRepository',
      category: LogCategory.system,
    );
  }

  /// Process a NIP-02 contact list event (Kind 3)
  void _processContactListEvent(Event event) {
    // Only update if this is newer than our current contact list event
    if (_currentUserContactListEvent == null ||
        event.createdAt > _currentUserContactListEvent!.createdAt) {
      _currentUserContactListEvent = event;

      // Extract followed pubkeys from 'p' tags
      final followedPubkeys = <String>[];
      for (final tag in event.tags) {
        if (tag.isNotEmpty && tag[0] == 'p' && tag.length > 1) {
          followedPubkeys.add(tag[1]);
        }
      }

      _followingPubkeys = followedPubkeys;
      _emitFollowingList();

      Log.info(
        'Updated follow list from network: ${_followingPubkeys.length} following',
        name: 'FollowRepository',
        category: LogCategory.system,
      );

      _saveToLocalStorage();
    }
  }
}
