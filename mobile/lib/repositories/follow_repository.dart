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

import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/services/personal_event_cache_service.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Callback to check if the device is currently online
typedef IsOnlineCallback = bool Function();

/// Callback to queue an action for offline sync
typedef QueueOfflineFollowCallback =
    Future<void> Function({required bool isFollow, required String pubkey});

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
    IsOnlineCallback? isOnline,
    QueueOfflineFollowCallback? queueOfflineAction,
  }) : _nostrClient = nostrClient,
       _personalEventCache = personalEventCache,
       _isOnline = isOnline,
       _queueOfflineAction = queueOfflineAction;

  final NostrClient _nostrClient;
  final PersonalEventCacheService? _personalEventCache;

  /// Callback to check if the device is online
  final IsOnlineCallback? _isOnline;

  /// Callback to queue actions for offline sync
  final QueueOfflineFollowCallback? _queueOfflineAction;

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

  /// Dispose resources
  Future<void> dispose() async {
    _contactListSubscription?.cancel();
    if (_contactListSubscriptionId != null) {
      await _nostrClient.unsubscribe(_contactListSubscriptionId!);
      _contactListSubscriptionId = null;
    }
    _followingSubject.close();
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

  /// Timeout for fetching followers from relays
  static const _fetchFollowersTimeout = Duration(seconds: 5);

  /// Fetch followers for a given pubkey from Nostr relays.
  ///
  /// Queries for Kind 3 (contact list) events that mention the target pubkey
  /// in their 'p' tags - these are users who follow the target.
  ///
  /// Returns empty list on timeout to prevent infinite loading.
  Future<List<String>> _fetchFollowers(String pubkey) async {
    if (pubkey.isEmpty) {
      return [];
    }

    try {
      final events = await _nostrClient
          .queryEvents([
            Filter(
              kinds: const [3], // Contact lists
              p: [pubkey], // Events that mention this pubkey
            ),
          ])
          .timeout(
            _fetchFollowersTimeout,
            onTimeout: () {
              Log.warning(
                'Followers query timed out for $pubkey',
                name: 'FollowRepository',
                category: LogCategory.system,
              );
              return <Event>[];
            },
          );

      // Extract unique follower pubkeys (authors of events that follow target)
      final followers = <String>[];
      for (final event in events) {
        if (!followers.contains(event.pubkey)) {
          followers.add(event.pubkey);
        }
      }

      return followers;
    } on TimeoutException {
      Log.warning(
        'Followers query timed out for $pubkey',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
      return [];
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

      // 3. Subscribe to contact list for initial fetch and cross-device sync
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
      final cachedContactLists = _personalEventCache!.getEventsByKind(3);

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

  /// Subscribe to contact list for real time updates.
  ///
  /// Creates a long-running subscription to the current user's Kind 3 events.
  /// When a newer contact list arrives (from another device), updates the local list.
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
        kinds: const [3], // NIP-02 contact list
        limit: 1,
      ),
    ], subscriptionId: _contactListSubscriptionId);

    _contactListSubscription = eventStream.listen(
      (event) {
        // Only process Kind 3 events from the current user
        if (event.kind == 3 && event.pubkey == currentUserPubkey) {
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
