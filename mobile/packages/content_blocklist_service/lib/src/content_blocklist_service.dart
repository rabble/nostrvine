// ABOUTME: Content blocklist service for filtering unwanted content from feeds
// ABOUTME: Maintains internal blocklist while allowing explicit profile visits
// ABOUTME: Persists blocks to SharedPreferences and publishes kind 30000

import 'dart:async';
import 'dart:convert';

import 'package:content_blocklist_service/src/block_list_signer.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

/// SharedPreferences key for persisted block list
const _blockedUsersPrefsKey = 'blocked_users_list';

/// SharedPreferences key for severed followers (follow broken by block)
const _severedFollowersPrefsKey = 'severed_followers_list';

/// Service for managing content blocklist
///
/// This service maintains an internal blocklist of npubs whose content
/// should be filtered from all general feeds (home, explore, hashtag feeds).
/// Users can still explicitly visit blocked profiles if they choose to
/// follow them.
///
/// Blocks are persisted to SharedPreferences for survival across restarts,
/// and published to Nostr as kind 30000 events (d=block) for cross-device sync.
class ContentBlocklistService {
  /// Creates a [ContentBlocklistService].
  ///
  /// [prefs] is used to persist blocks across app restarts. Pass `null` for
  /// in-memory-only operation (e.g. in tests).
  /// [onChanged] is invoked whenever the blocklist changes so listeners
  /// can refresh dependent state.
  ContentBlocklistService({
    SharedPreferences? prefs,
    void Function()? onChanged,
  }) : _prefs = prefs,
       _onChanged = onChanged {
    // Initialize with the specific npub requested
    _addInitialBlockedContent();
    _loadBlockedUsers();
    _loadSeveredFollowers();
    Log.info(
      'ContentBlocklistService initialized with '
      '$totalBlockedCount blocked accounts',
      name: 'ContentBlocklistService',
      category: LogCategory.system,
    );
  }

  final SharedPreferences? _prefs;
  final void Function()? _onChanged;
  // Internal blocklist of public keys (hex format) - kept empty for now
  static const Set<String> _internalBlocklist = {
    // Add blocked public keys here in hex format if needed
  };

  // Runtime blocklist (can be modified)
  final Set<String> _runtimeBlocklist = <String>{};

  // Mutual mute blocklist (populated from kind 10000 events)
  final Set<String> _mutualMuteBlocklist = <String>{};

  // Users who have blocked us (populated from kind 30000 events with d=block)
  final Set<String> _blockedByOthers = <String>{};

  // Followers whose follow relationship was severed by a block.
  // Persists across unblocking so these users remain hidden from our
  // followers list until they explicitly re-follow.
  final Set<String> _severedFollowers = <String>{};

  // Subscription tracking for mutual mutes
  String? _mutualMuteSubscriptionId;
  bool _mutualMuteSyncStarted = false;
  String? _ourPubkey;

  // Subscription tracking for block list sync
  bool _blockListSyncStarted = false;

  // Services for Nostr publishing (injected via sync methods)
  BlockListSigner? _signer;
  NostrClient? _nostrClient;

  void _notifyChanged() {
    _onChanged?.call();
  }

  void _addInitialBlockedContent() {
    // No hardcoded blocks - moderation should happen at relay level
    // Users can still block individuals via the app UI
  }

  /// Load persisted blocked users from SharedPreferences
  void _loadBlockedUsers() {
    final prefs = _prefs;
    if (prefs == null) return;

    final stored = prefs.getString(_blockedUsersPrefsKey);
    if (stored == null || stored.isEmpty) return;

    try {
      final list = (jsonDecode(stored) as List<dynamic>).cast<String>();
      _runtimeBlocklist.addAll(list);
      Log.info(
        'Loaded ${list.length} blocked users from persistence',
        name: 'ContentBlocklistService',
        category: LogCategory.system,
      );
    } on Object catch (e) {
      Log.error(
        'Failed to load persisted blocked users: $e',
        name: 'ContentBlocklistService',
        category: LogCategory.system,
      );
    }
  }

  /// Save blocked users to SharedPreferences
  ///
  /// Awaits the platform write so the block survives an immediate app kill.
  Future<void> _saveBlockedUsers() async {
    final prefs = _prefs;
    if (prefs == null) return;

    try {
      final json = jsonEncode(_runtimeBlocklist.toList());
      await prefs.setString(_blockedUsersPrefsKey, json);
    } on Object catch (e) {
      Log.error(
        'Failed to persist blocked users: $e',
        name: 'ContentBlocklistService',
        category: LogCategory.system,
      );
    }
  }

  /// Load persisted severed followers from SharedPreferences
  void _loadSeveredFollowers() {
    final prefs = _prefs;
    if (prefs == null) return;

    final stored = prefs.getString(_severedFollowersPrefsKey);
    if (stored == null || stored.isEmpty) return;

    try {
      final list = (jsonDecode(stored) as List<dynamic>).cast<String>();
      _severedFollowers.addAll(list);
      Log.info(
        'Loaded ${list.length} severed followers from persistence',
        name: 'ContentBlocklistService',
        category: LogCategory.system,
      );
    } on Object catch (e) {
      Log.error(
        'Failed to load persisted severed followers: $e',
        name: 'ContentBlocklistService',
        category: LogCategory.system,
      );
    }
  }

  /// Save severed followers to SharedPreferences
  ///
  /// Awaits the platform write so the data survives an immediate app kill.
  Future<void> _saveSeveredFollowers() async {
    final prefs = _prefs;
    if (prefs == null) return;

    try {
      final json = jsonEncode(_severedFollowers.toList());
      await prefs.setString(_severedFollowersPrefsKey, json);
    } on Object catch (e) {
      Log.error(
        'Failed to persist severed followers: $e',
        name: 'ContentBlocklistService',
        category: LogCategory.system,
      );
    }
  }

  /// Check if a follower's relationship was severed by a block
  ///
  /// Returns true if the pubkey was added to severed followers when blocked.
  /// This persists across unblocking so the user stays hidden from our
  /// followers list until they explicitly re-follow.
  bool isFollowSevered(String pubkey) => _severedFollowers.contains(pubkey);

  /// Remove a pubkey from the severed followers set
  ///
  /// Call this when the user explicitly re-follows to restore them
  /// in the followers list.
  void removeSeveredFollower(String pubkey) {
    if (_severedFollowers.remove(pubkey)) {
      unawaited(_saveSeveredFollowers());
      Log.debug(
        'Removed severed follower: $pubkey',
        name: 'ContentBlocklistService',
        category: LogCategory.system,
      );
    }
  }

  /// Publish our block list to Nostr as kind 30000 with d=block
  Future<void> _publishBlockListToNostr() async {
    final signer = _signer;
    final nostrClient = _nostrClient;

    if (signer == null || nostrClient == null) {
      Log.debug(
        'Cannot publish block list - Nostr services not yet injected',
        name: 'ContentBlocklistService',
        category: LogCategory.system,
      );
      return;
    }

    if (!signer.isAuthenticated) {
      Log.warning(
        'Cannot publish block list - user not authenticated',
        name: 'ContentBlocklistService',
        category: LogCategory.system,
      );
      return;
    }

    try {
      final tags = <List<String>>[
        ['d', 'block'],
        ['title', 'Block List'],
        ['client', 'diVine'],
      ];

      for (final pubkey in _runtimeBlocklist) {
        tags.add(['p', pubkey]);
      }

      final event = await signer.createAndSignEvent(
        kind: 30000,
        content: 'Block list',
        tags: tags,
      );

      if (event != null) {
        final sentEvent = await nostrClient.publishEvent(event);

        if (sentEvent != null) {
          Log.info(
            'Published block list to Nostr with '
            '${_runtimeBlocklist.length} entries',
            name: 'ContentBlocklistService',
            category: LogCategory.system,
          );
        } else {
          Log.warning(
            'Failed to publish block list event to relays',
            name: 'ContentBlocklistService',
            category: LogCategory.system,
          );
        }
      }
    } on Object catch (e) {
      Log.error(
        'Error publishing block list to Nostr: $e',
        name: 'ContentBlocklistService',
        category: LogCategory.system,
      );
    }
  }

  /// Check if a public key is blocked
  bool isBlocked(String pubkey) {
    // Check both internal and runtime blocklists
    return _internalBlocklist.contains(pubkey) ||
        _runtimeBlocklist.contains(pubkey);
  }

  /// Check if content should be filtered from feeds
  ///
  /// Filters content from:
  /// - Users we blocked (internal + runtime blocklist)
  /// - Users who mutually muted us (kind 10000)
  /// - Users who blocked us (kind 30000, d=block) — hides our content
  ///   from their feeds and their content from ours
  bool shouldFilterFromFeeds(String pubkey) {
    return _internalBlocklist.contains(pubkey) ||
        _runtimeBlocklist.contains(pubkey) ||
        _mutualMuteBlocklist.contains(pubkey) ||
        _blockedByOthers.contains(pubkey);
  }

  /// Check if another user has muted us (mutual mute blocking)
  ///
  /// This is different from [isBlocked] which checks users WE blocked.
  /// Use this for profile viewing - users can view profiles they blocked,
  /// but cannot view profiles of users who muted them.
  bool hasMutedUs(String pubkey) => _mutualMuteBlocklist.contains(pubkey);

  /// Check if another user has blocked us via kind 30000 (d=block)
  ///
  /// Use this for blockee-side enforcement - prevent viewing profiles of
  /// users who have blocked us, and prevent following them.
  bool hasBlockedUs(String pubkey) => _blockedByOthers.contains(pubkey);

  /// Add a public key to the runtime blocklist
  ///
  /// Persists to SharedPreferences and publishes to Nostr (kind 30000).
  /// Awaits the local write so the block survives an immediate app kill.
  /// If [ourPubkey] is provided, it will be used to prevent self-blocking.
  /// Otherwise falls back to [_ourPubkey] set during
  /// [syncMuteListsInBackground].
  Future<void> blockUser(String pubkey, {String? ourPubkey}) async {
    // Guard: Prevent blocking self
    final selfPubkey = ourPubkey ?? _ourPubkey;
    if (selfPubkey != null && pubkey == selfPubkey) {
      Log.warning(
        'Attempted to block self - ignoring',
        name: 'ContentBlocklistService',
        category: LogCategory.system,
      );
      return;
    }

    if (!_runtimeBlocklist.contains(pubkey)) {
      _runtimeBlocklist.add(pubkey);
      await _saveBlockedUsers();
      _notifyChanged();
      await _publishBlockListToNostr();

      Log.debug(
        'Added user to blocklist: $pubkey',
        name: 'ContentBlocklistService',
        category: LogCategory.system,
      );
    }

    // Track as severed follower so they stay hidden from our followers
    // list even after unblocking (until they explicitly re-follow).
    if (!_severedFollowers.contains(pubkey)) {
      _severedFollowers.add(pubkey);
      await _saveSeveredFollowers();
    }
  }

  /// Remove a public key from the runtime blocklist
  ///
  /// Persists to SharedPreferences and publishes updated list to Nostr.
  /// Awaits the local write so the change survives an immediate app kill.
  /// Note: Cannot remove users from internal blocklist.
  Future<void> unblockUser(String pubkey) async {
    if (_runtimeBlocklist.contains(pubkey)) {
      _runtimeBlocklist.remove(pubkey);
      await _saveBlockedUsers();
      _notifyChanged();
      await _publishBlockListToNostr();

      Log.info(
        'Removed user from blocklist: $pubkey',
        name: 'ContentBlocklistService',
        category: LogCategory.system,
      );
      // coverage:ignore-start
    } else if (_internalBlocklist.contains(pubkey)) {
      // Internal blocklist is intentionally empty; this branch is
      // unreachable in production. Retained as a guard in case hardcoded
      // moderation blocks are re-introduced.
      Log.warning(
        'Cannot unblock user from internal blocklist: $pubkey',
        name: 'ContentBlocklistService',
        category: LogCategory.system,
      );
      // coverage:ignore-end
    }
  }

  /// Get all blocked public keys (for debugging)
  Set<String> get blockedPubkeys => {
    ..._internalBlocklist,
    ..._runtimeBlocklist,
  };

  /// Get count of blocked accounts
  int get totalBlockedCount =>
      _internalBlocklist.length + _runtimeBlocklist.length;

  /// Filter a list of content by removing blocked authors
  List<T> filterContent<T>(List<T> content, String Function(T) getPubkey) =>
      content.where((item) => !shouldFilterFromFeeds(getPubkey(item))).toList();

  /// Filter DM conversations where the other participant is blocked.
  ///
  /// [userPubkey] is the current user's pubkey, used to identify which
  /// participant is "the other one" in each conversation.
  List<DmConversation> filterBlockedConversations(
    List<DmConversation> conversations, {
    required String userPubkey,
  }) {
    return conversations.where((conv) {
      final otherPubkey = conv.participantPubkeys.firstWhere(
        (pk) => pk != userPubkey,
        orElse: () => '',
      );
      // Exclude self-conversations (no "other" participant found).
      if (otherPubkey.isEmpty) return false;
      return !shouldFilterFromFeeds(otherPubkey);
    }).toList();
  }

  /// Check if user is in internal (permanent) blocklist
  bool isInternallyBlocked(String pubkey) =>
      _internalBlocklist.contains(pubkey);

  /// Get runtime blocked users (can be modified)
  Set<String> get runtimeBlockedUsers => Set.unmodifiable(_runtimeBlocklist);

  /// Clear all runtime blocks (keeps internal blocks)
  void clearRuntimeBlocks() {
    if (_runtimeBlocklist.isNotEmpty) {
      _runtimeBlocklist.clear();
      unawaited(_saveBlockedUsers());

      Log.debug(
        'Cleared all runtime blocks',
        name: 'ContentBlocklistService',
        category: LogCategory.system,
      );
    }
  }

  /// Get stats about blocking
  Map<String, dynamic> get blockingStats => {
    'internal_blocks': _internalBlocklist.length,
    'runtime_blocks': _runtimeBlocklist.length,
    'total_blocks': totalBlockedCount,
  };

  /// Start background sync of mutual mute lists (NIP-51 kind 10000)
  /// Subscribes to kind 10000 events WHERE our pubkey appears in 'p' tags
  Future<void> syncMuteListsInBackground(
    NostrClient nostrService,
    String ourPubkey,
  ) async {
    // If the NostrClient changed (e.g., account switch), the old subscription
    // was on a disposed client. Reset so we create a fresh subscription.
    if (_mutualMuteSyncStarted && _nostrClient != nostrService) {
      _mutualMuteSyncStarted = false;
    }

    if (_mutualMuteSyncStarted) {
      Log.debug(
        'Mutual mute sync already started, skipping',
        name: 'ContentBlocklistService',
        category: LogCategory.system,
      );
      return;
    }

    _ourPubkey = ourPubkey;

    // Store references for Nostr publishing
    _nostrClient = nostrService;

    Log.info(
      'Starting mutual mute list sync for pubkey: $ourPubkey',
      name: 'ContentBlocklistService',
      category: LogCategory.system,
    );

    try {
      // Subscribe to kind 10000 (mute list) events WHERE our pubkey is in
      // 'p' tags
      final filter = Filter(kinds: const [10000])..p = [ourPubkey];

      final subscription = nostrService.subscribe([filter]);

      _mutualMuteSyncStarted = true;
      _mutualMuteSubscriptionId =
          'mutual-mute-${DateTime.now().millisecondsSinceEpoch}';

      // Listen to the stream
      subscription.listen(_handleMuteListEvent);

      Log.info(
        'Mutual mute subscription created: $_mutualMuteSubscriptionId',
        name: 'ContentBlocklistService',
        category: LogCategory.system,
      );
    } on Object catch (e) {
      Log.error(
        'Failed to start mutual mute sync: $e',
        name: 'ContentBlocklistService',
        category: LogCategory.system,
      );
    }
  }

  /// Start background sync of block lists (kind 30000, d=block).
  ///
  /// Subscribes to two filter sets in a single subscription:
  /// 1. Kind 30000 events where our pubkey is in 'p' tags — detects when
  ///    other users block us.
  /// 2. All of our own kind 30000 events — restores our block list from
  ///    the relay so blocks survive app reinstalls (SharedPreferences is
  ///    wiped on uninstall, but the relay keeps the event). The `d=block`
  ///    check is done in [_handleBlockListEvent] instead of in the filter
  ///    because not all relays support `#d` tag filtering.
  ///
  /// Using `subscribe` (persistent stream) instead of `queryEvents`
  /// (one-shot) ensures events arrive even if relays connect after this
  /// method is called.
  Future<void> syncBlockListsInBackground(
    NostrClient nostrService,
    BlockListSigner signer,
    String ourPubkey,
  ) async {
    // If the NostrClient changed (e.g., account switch), the old subscription
    // was on a disposed client. Reset so we create a fresh subscription.
    if (_blockListSyncStarted && _nostrClient != nostrService) {
      _blockListSyncStarted = false;
    }

    if (_blockListSyncStarted) {
      Log.debug(
        'Block list sync already started, skipping',
        name: 'ContentBlocklistService',
        category: LogCategory.system,
      );
      return;
    }

    _ourPubkey = ourPubkey;
    _signer = signer;
    _nostrClient = nostrService;

    Log.info(
      'Starting block list sync for pubkey: $ourPubkey',
      name: 'ContentBlocklistService',
      category: LogCategory.system,
    );

    try {
      // Filter 1: Others' block lists that include our pubkey
      final othersFilter = Filter(kinds: const [30000])..p = [ourPubkey];

      // Filter 2: Our own block list (for relay-based restoration)
      // Omit the d-tag constraint here — not all relays support #d
      // filtering, and _handleBlockListEvent already checks for d=block.
      final ownFilter = Filter(
        authors: [ourPubkey],
        kinds: const [30000],
      );

      nostrService
          .subscribe([othersFilter, ownFilter])
          .listen(_handleBlockListEvent);

      _blockListSyncStarted = true;

      Log.info(
        'Block list subscription created (includes own block list restore)',
        name: 'ContentBlocklistService',
        category: LogCategory.system,
      );
    } on Object catch (e) {
      Log.error(
        'Failed to start block list sync: $e',
        name: 'ContentBlocklistService',
        category: LogCategory.system,
      );
    }
  }

  /// Handle incoming kind 10000 mute list events
  /// Adds/removes muter based on whether our pubkey is in their 'p' tags
  void _handleMuteListEvent(Event event) {
    if (event.kind != 10000) {
      Log.warning(
        'Received non-10000 event in mute list handler: ${event.kind}',
        name: 'ContentBlocklistService',
        category: LogCategory.system,
      );
      return;
    }

    final muterPubkey = event.pubkey;

    // Check if our pubkey is in this user's mute list
    final stillMuted = event.tags.any(
      (tag) =>
          tag.isNotEmpty &&
          tag[0] == 'p' &&
          tag.length >= 2 &&
          tag[1] == _ourPubkey,
    );

    if (stillMuted) {
      // They muted us - add to blocklist
      if (!_mutualMuteBlocklist.contains(muterPubkey)) {
        _mutualMuteBlocklist.add(muterPubkey);
        _notifyChanged();
        Log.info(
          'Added mutual mute: $muterPubkey',
          name: 'ContentBlocklistService',
          category: LogCategory.system,
        );
      }
    } else {
      // They removed us from mute list - remove from blocklist
      if (_mutualMuteBlocklist.contains(muterPubkey)) {
        _mutualMuteBlocklist.remove(muterPubkey);
        _notifyChanged();
        Log.info(
          'Removed mutual mute (unmuted): $muterPubkey',
          name: 'ContentBlocklistService',
          category: LogCategory.system,
        );
      }
    }
  }

  /// Handle incoming kind 30000 block list events (d=block).
  ///
  /// Routes to the appropriate handler based on whether the event is
  /// authored by us (relay restoration) or by another user (blocked-by).
  void _handleBlockListEvent(Event event) {
    if (event.kind != 30000) return;

    // Only process events with d=block tag
    final hasBlockDTag = event.tags.any(
      (tag) =>
          tag.isNotEmpty &&
          tag[0] == 'd' &&
          tag.length >= 2 &&
          tag[1] == 'block',
    );
    if (!hasBlockDTag) return;

    if (event.pubkey == _ourPubkey) {
      _handleOwnBlockListEvent(event);
    } else {
      _handleOthersBlockListEvent(event);
    }
  }

  /// Restore our block list from a relay-stored event we authored.
  ///
  /// Extracts blocked pubkeys from 'p' tags and merges them into the
  /// runtime blocklist. This ensures blocks survive app reinstalls where
  /// SharedPreferences data is lost but the relay still holds our event.
  void _handleOwnBlockListEvent(Event event) {
    final relayPubkeys = <String>{};
    for (final tag in event.tags) {
      if (tag.isNotEmpty &&
          tag[0] == 'p' &&
          tag.length >= 2 &&
          tag[1] != _ourPubkey) {
        relayPubkeys.add(tag[1]);
      }
    }

    final added = relayPubkeys.difference(_runtimeBlocklist);
    if (added.isEmpty) return;

    _runtimeBlocklist.addAll(added);
    unawaited(_saveBlockedUsers());
    _notifyChanged();

    Log.info(
      'Restored ${added.length} blocks from relay '
      '(total: ${_runtimeBlocklist.length})',
      name: 'ContentBlocklistService',
      category: LogCategory.system,
    );
  }

  /// Handle another user's block list event.
  ///
  /// Checks if our pubkey is in their 'p' tags, then adds/removes
  /// the blocker from [_blockedByOthers].
  void _handleOthersBlockListEvent(Event event) {
    final blockerPubkey = event.pubkey;

    // Check if our pubkey is in this user's block list
    final stillBlocked = event.tags.any(
      (tag) =>
          tag.isNotEmpty &&
          tag[0] == 'p' &&
          tag.length >= 2 &&
          tag[1] == _ourPubkey,
    );

    if (stillBlocked) {
      if (!_blockedByOthers.contains(blockerPubkey)) {
        _blockedByOthers.add(blockerPubkey);
        _notifyChanged();
        Log.info(
          'Detected block from user: $blockerPubkey',
          name: 'ContentBlocklistService',
          category: LogCategory.system,
        );
      }
    } else {
      if (_blockedByOthers.contains(blockerPubkey)) {
        _blockedByOthers.remove(blockerPubkey);
        _notifyChanged();
        Log.info(
          'Detected unblock from user: $blockerPubkey',
          name: 'ContentBlocklistService',
          category: LogCategory.system,
        );
      }
    }
  }

  /// Dispose resources (cancel subscriptions)
  void dispose() {
    // Subscription cleanup would go here if NostrService had unsubscribe method
    _mutualMuteSyncStarted = false;
    _mutualMuteSubscriptionId = null;
    _blockListSyncStarted = false;
  }
}
