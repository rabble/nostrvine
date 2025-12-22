// ABOUTME: Repository for managing follow relationships (follow/unfollow)
// ABOUTME: Single source of truth for follow data with in-memory cache, local storage, and API sync

// TODO(refactor): Extract this to packages/follow_repository once dependencies are resolved.
// Currently blocked by app-level dependencies:
// - PersonalEventCacheService (needs interface extraction)
// - ImmediateCompletionHelper (needs to move to a shared package)
// - unified_logger (needs logging abstraction)
// See packages/nostr_client for the pattern to follow.

import 'dart:async';
import 'dart:convert';

import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/services/immediate_completion_helper.dart';
import 'package:openvine/services/personal_event_cache_service.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  }) : _nostrClient = nostrClient,
       _personalEventCache = personalEventCache;

  final NostrClient _nostrClient;
  final PersonalEventCacheService? _personalEventCache;

  // Stream controller for reactive updates
  final _followingStreamController = StreamController<List<String>>.broadcast();
  Stream<List<String>> get followingStream => _followingStreamController.stream;

  // In-memory cache
  List<String> _followingPubkeys = [];
  Event? _currentUserContactListEvent;
  bool _isInitialized = false;

  // Getters
  List<String> get followingPubkeys => List.unmodifiable(_followingPubkeys);
  bool get isInitialized => _isInitialized;
  int get followingCount => _followingPubkeys.length;

  /// Emit current state to stream
  void _emitFollowingList() {
    if (!_followingStreamController.isClosed) {
      _followingStreamController.add(List.unmodifiable(_followingPubkeys));
    }
  }

  /// Dispose resources
  void dispose() {
    _followingStreamController.close();
  }

  /// Check if current user is following a specific pubkey
  bool isFollowing(String pubkey) => _followingPubkeys.contains(pubkey);

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

      // 3. Sync from network for latest data
      if (_nostrClient.hasKeys) {
        await _syncFromNetwork();
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

  /// Sync from network (fetch current user's Kind 3 contact list)
  Future<void> _syncFromNetwork() async {
    try {
      final currentUserPubkey = _nostrClient.publicKey;
      if (currentUserPubkey.isEmpty) return;

      Log.debug(
        'Syncing follow list from network for: $currentUserPubkey',
        name: 'FollowRepository',
        category: LogCategory.system,
      );

      final eventStream = _nostrClient.subscribe([
        Filter(
          authors: [currentUserPubkey],
          kinds: const [3], // NIP-02 contact list
          limit: 1,
        ),
      ]);

      final contactListEvent =
          await ContactListCompletionHelper.queryContactList(
            eventStream: eventStream,
            pubkey: currentUserPubkey,
            fallbackTimeoutSeconds: 10,
          );

      if (contactListEvent != null) {
        _processContactListEvent(contactListEvent);
      }
    } catch (e) {
      Log.error(
        'Error syncing follow list from network: $e',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
    }
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
