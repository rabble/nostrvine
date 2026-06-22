// ABOUTME: Content blocklist service for filtering unwanted content from feeds
// ABOUTME: Tracks our blocks, our kind-10000 mutes, and mutual block/mute state
// ABOUTME: Persists to SharedPreferences and publishes the kind 10000 mute list

import 'dart:async';
import 'dart:convert';

import 'package:content_blocklist_repository/src/block_list_signer.dart';
import 'package:content_blocklist_repository/src/blocklist_change.dart';
import 'package:content_policy/content_policy.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

/// SharedPreferences key for persisted block list
const _blockedUsersPrefsKey = 'blocked_users_list';

/// SharedPreferences key for our own kind-10000 muted authors
const _mutedUsersPrefsKey = 'muted_users_list';

/// SharedPreferences key for severed followers (follow broken by block)
const _severedFollowersPrefsKey = 'severed_followers_list';

/// SharedPreferences key recording which account's per-account state the
/// persisted sets belong to. Written on identity adoption so the next
/// construction hydrates the right account before auth resolves.
const _activePubkeyPrefsKey = 'blocklist_active_pubkey';

/// SharedPreferences key prefix recording that the one-time migration of a
/// legacy kind 30000 (d=block) block list into the standard kind 10000 mute
/// list has completed for an account. Scoped per account as `base.pubkey`.
const _blockListMigratedPrefsKeyBase = 'block_list_migrated_to_mute_list';

class _MuteListPublishShape {
  const _MuteListPublishShape({required this.tags, required this.content});

  final List<List<String>> tags;
  final String content;
}

/// Service for managing content blocklist
///
/// This service maintains an internal blocklist of npubs whose content
/// should be filtered from all general feeds (home, explore, hashtag feeds).
/// Users can still explicitly visit blocked profiles if they choose to
/// follow them.
///
/// Blocks are persisted to SharedPreferences for survival across restarts,
/// and published to Nostr as the standard NIP-51 kind 10000 mute list so
/// they interoperate with other clients (Amethyst, Damus, etc.) and the
/// Divine backend (#4037). A legacy kind 30000 (d=block) event is also
/// kept in sync for backward compatibility with older Divine clients.
class ContentBlocklistRepository {
  /// Creates a [ContentBlocklistRepository].
  ///
  /// [prefs] is used to persist blocks across app restarts. Pass `null` for
  /// in-memory-only operation (e.g. in tests).
  /// [onChanged] is invoked whenever the blocklist changes so listeners
  /// can refresh dependent state.
  ContentBlocklistRepository({
    SharedPreferences? prefs,
    void Function()? onChanged,
  }) : _prefs = prefs,
       _onChanged = onChanged {
    // Initialize with the specific npub requested
    _addInitialBlockedContent();
    _activeAccountPubkey = _prefs?.getString(_activePubkeyPrefsKey);
    final seededAccount = _activeAccountPubkey;
    _scopedBasesPresentAtConstruction = seededAccount == null
        ? const <String>{}
        : <String>{
            for (final base in _legacySetsByBase.keys)
              if (_prefs?.getString('$base.$seededAccount') != null) base,
          };
    _loadBlockedUsers();
    _loadMutedUsers();
    _loadSeveredFollowers();
    Log.info(
      'ContentBlocklistRepository initialized with '
      '$totalBlockedCount blocked accounts',
      name: 'ContentBlocklistRepository',
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

  // Authors muted on our own kind 10000 mute list from *other* clients.
  // Our own in-app blocks live in [_runtimeBlocklist] and are deliberately
  // excluded from this set (see [_handleOwnMuteListEvent]) so republishing
  // the merged mute list stays idempotent and unblocking actually removes
  // the entry. The newest own kind 10000 event replaces this set wholesale.
  // Only public 'p' tags are interpreted as authored mutes. Other NIP-51
  // public mute tags and encrypted private entries are preserved verbatim
  // from [_latestOwnMuteListEvent] when we republish.
  final Set<String> _mutedPubkeys = <String>{};

  // Full latest own kind-10000 event, retained so republishing Divine blocks
  // preserves other clients' public t/word/e mutes and encrypted content.
  Event? _latestOwnMuteListEvent;

  // Latest replaceable kind-10000 mute-list event timestamp per author.
  // Prevent stale relay delivery order from resurrecting old mute state.
  final Map<String, int> _latestMuteListEventCreatedAtByAuthor =
      <String, int>{};

  // Users who have blocked us (populated from kind 30000 events with d=block)
  final Set<String> _blockedByOthers = <String>{};

  // Latest replaceable kind-30000 block-list event timestamp per author.
  // Prevent stale relay delivery order from resurrecting old block state.
  final Map<String, int> _latestBlockListEventCreatedAtByAuthor =
      <String, int>{};

  // Followers whose follow relationship was severed by a block.
  // Persists across unblocking so these users remain hidden from our
  // followers list until they explicitly re-follow.
  final Set<String> _severedFollowers = <String>{};

  // Persisted sets that migrate from legacy un-namespaced keys, by key.
  late final Map<String, Set<String>> _legacySetsByBase = {
    _blockedUsersPrefsKey: _runtimeBlocklist,
    _mutedUsersPrefsKey: _mutedPubkeys,
    _severedFollowersPrefsKey: _severedFollowers,
  };

  // Scoped keys of the seeded account that already held data when this
  // instance hydrated. _migrateLegacyKeys treats those as authoritative
  // over the legacy snapshot; a scoped key that appears later in the
  // session was written by a save racing the migration and must be
  // merged with the legacy data, not preferred over it.
  late final Set<String> _scopedBasesPresentAtConstruction;

  final _stateController = StreamController<ContentPolicyState>.broadcast();

  // Granular per-pubkey change events. Subscribers (e.g. VideoEventService)
  // react per-author rather than diffing snapshots from [stateStream].
  // See [changes] for the public getter.
  final _changesController = StreamController<BlocklistChange>.broadcast();

  // Subscription tracking for mutual mutes
  String? _mutualMuteSubscriptionId;
  bool _mutualMuteSyncStarted = false;
  String? _ourPubkey;

  // Account whose persisted sets are currently loaded. Seeded from prefs at
  // construction so hydration covers the window before auth resolves;
  // corrected by [_adoptIdentity] once the session identity is known.
  String? _activeAccountPubkey;

  // Subscription tracking for block list sync
  bool _blockListSyncStarted = false;

  // Services for Nostr publishing (injected via sync methods)
  BlockListSigner? _signer;
  NostrClient? _nostrClient;

  /// A synchronous snapshot of the current policy state.
  ContentPolicyState get currentState => _buildCurrentState();

  /// Emits a new [ContentPolicyState] snapshot whenever the policy changes.
  Stream<ContentPolicyState> get stateStream => _stateController.stream;

  /// Emits per-pubkey [BlocklistChange] events the moment the
  /// composition mutates (block, unblock, mute, unmute, externally-applied
  /// changes).
  ///
  /// Subscribers should use this stream when they need to react to a
  /// specific pubkey transitioning into or out of a hide-bucket — e.g.
  /// dropping that author's videos from open feed surfaces. Diffing the
  /// snapshots from [stateStream] would also work but is brittle and
  /// allocation-heavy.
  ///
  /// Broadcast semantics: late subscribers do not receive past emissions;
  /// the canonical truth is [currentState] / the contains-checks.
  Stream<BlocklistChange> get changes => _changesController.stream;

  ContentPolicyState _buildCurrentState() => ContentPolicyState(
    currentUserPubkey: _ourPubkey,
    mutedPubkeys: Set.unmodifiable(_mutedPubkeys),
    blockedPubkeys: Set.unmodifiable({
      ..._internalBlocklist,
      ..._runtimeBlocklist,
    }),
    pubkeysBlockingUs: Set.unmodifiable(_blockedByOthers),
    pubkeysMutingUs: Set.unmodifiable(_mutualMuteBlocklist),
  );

  void _notifyChanged() {
    _onChanged?.call();
    if (!_stateController.isClosed) {
      _stateController.add(_buildCurrentState());
    }
  }

  /// Emit a granular change on [changes]. Call sites pair this with
  /// [_notifyChanged] so the broad-state listeners and the per-pubkey
  /// listeners stay in sync.
  void _emitChange(BlocklistChange change) {
    if (!_changesController.isClosed) {
      _changesController.add(change);
    }
  }

  void _addInitialBlockedContent() {
    // No hardcoded blocks - moderation should happen at relay level
    // Users can still block individuals via the app UI
  }

  /// Storage key for [base] scoped to the active account.
  ///
  /// Falls back to the legacy un-namespaced key while no account has been
  /// adopted yet (pre-auth or pre-migration installs).
  String _scopedKey(String base) {
    final account = _activeAccountPubkey;
    return account == null ? base : '$base.$account';
  }

  /// Adopts [pubkey] as the session identity, resetting state that
  /// belongs to a different account.
  ///
  /// All in-memory sets are keyed to one identity: `_blockedByOthers` /
  /// `_mutualMuteBlocklist` hold who blocks/mutes *us*, and the persisted
  /// sets are stored per account. Before this existed, the keepAlive
  /// repository carried account A's state into account B after a switch,
  /// filtering the wrong authors and showing false "account not
  /// available" gates (#4969).
  void _adoptIdentity(String pubkey) {
    if (_ourPubkey == pubkey) return;
    final isSwitch = _ourPubkey != null;
    final storedAccountDiffers =
        _activeAccountPubkey != null && _activeAccountPubkey != pubkey;

    _ourPubkey = pubkey;

    if (isSwitch || storedAccountDiffers) {
      _runtimeBlocklist.clear();
      _mutedPubkeys.clear();
      _mutualMuteBlocklist.clear();
      _blockedByOthers.clear();
      _latestOwnMuteListEvent = null;
      _latestMuteListEventCreatedAtByAuthor.clear();
      _latestBlockListEventCreatedAtByAuthor.clear();
      _severedFollowers.clear();
      // Force fresh subscriptions filtered on the new pubkey. On a
      // same-client switch the old subscription's listener is
      // intentionally left in place (no handle is retained to cancel
      // it); its deliveries stay harmless because every handler
      // re-checks the live _ourPubkey at delivery time.
      _mutualMuteSyncStarted = false;
      _blockListSyncStarted = false;
    }

    // Legacy un-namespaced data predates per-account keys and follows
    // the first identity that signed in; the move no-ops for any other
    // account. Must run before _activeAccountPubkey is reassigned.
    unawaited(_migrateLegacyKeys(pubkey));

    _activeAccountPubkey = pubkey;
    unawaited(_saveActiveAccountPubkey(pubkey));

    if (isSwitch || storedAccountDiffers) {
      _loadBlockedUsers();
      _loadMutedUsers();
      _loadSeveredFollowers();
      _notifyChanged();
      Log.info(
        'Adopted new identity; blocklist state reset and reloaded '
        '(${_runtimeBlocklist.length} persisted blocks)',
        name: 'ContentBlocklistRepository',
        category: LogCategory.system,
      );
    }
  }

  /// Persists which account the per-account sets belong to.
  ///
  /// Failures are logged and swallowed — persistence must never break
  /// the in-memory blocklist, matching the other save methods.
  Future<void> _saveActiveAccountPubkey(String pubkey) async {
    final prefs = _prefs;
    if (prefs == null) return;
    try {
      await prefs.setString(_activePubkeyPrefsKey, pubkey);
    } on Object catch (e) {
      Log.error(
        'Failed to persist active blocklist account: $e',
        name: 'ContentBlocklistRepository',
        category: LogCategory.system,
      );
    }
  }

  /// Moves legacy un-namespaced persisted sets to [pubkey]'s scoped keys.
  ///
  /// Runs while no account was ever adopted on this install, or while
  /// [pubkey] is the recorded account — so a move that failed on a
  /// previous launch is retried instead of orphaning the legacy data.
  /// Legacy values merge into the in-memory sets synchronously (a no-op
  /// when construction already hydrated them) and persist via full-set
  /// writes; a legacy key is removed only once its data is confirmed
  /// under the scoped key, so a partial failure never destroys data.
  Future<void> _migrateLegacyKeys(String pubkey) async {
    final prefs = _prefs;
    if (prefs == null) return;
    if (_activeAccountPubkey != null && _activeAccountPubkey != pubkey) {
      return;
    }

    // Decide and merge synchronously so no concurrent write can land
    // between reading a legacy value and folding it into memory.
    final pendingMoves = <String, Set<String>>{};
    final staleBases = <String>[];
    var recovered = false;
    for (final entry in _legacySetsByBase.entries) {
      final base = entry.key;
      final legacy = prefs.getString(base);
      if (legacy == null || legacy.isEmpty) continue;
      final scopedExists = prefs.getString('$base.$pubkey') != null;
      if (scopedExists &&
          (_scopedBasesPresentAtConstruction.contains(base) ||
              _activeAccountPubkey == null)) {
        // A scoped value that predates this adoption is authoritative:
        // merging the stale legacy snapshot could resurrect entries
        // deleted since the original copy. (Before first adoption,
        // saves write the legacy key itself, so a scoped value can
        // only be a leftover from an earlier partially-failed
        // migration — while for the recorded account, one that was
        // absent at construction was written by a save racing this
        // migration and is merged below instead.)
        staleBases.add(base);
        continue;
      }
      try {
        final decoded = (jsonDecode(legacy) as List<dynamic>).cast<String>();
        final target = entry.value;
        final sizeBefore = target.length;
        target.addAll(decoded);
        recovered = recovered || target.length != sizeBefore;
        pendingMoves[base] = target;
      } on Object catch (e) {
        Log.error(
          'Skipping corrupt legacy blocklist key $base: $e',
          name: 'ContentBlocklistRepository',
          category: LogCategory.system,
        );
      }
    }
    if (recovered) {
      // A retried move recovered data that construction could not see;
      // notify so watchers re-filter with it this session.
      _notifyChanged();
    }

    for (final base in staleBases) {
      try {
        await prefs.remove(base);
      } on Object catch (e) {
        Log.error(
          'Failed to drop stale legacy blocklist key $base: $e',
          name: 'ContentBlocklistRepository',
          category: LogCategory.system,
        );
      }
    }

    for (final entry in pendingMoves.entries) {
      // Re-checked before every write: after a mid-flight account
      // switch the live sets belong to the new identity and must not
      // be serialized under [pubkey]'s keys.
      if (_activeAccountPubkey != null && _activeAccountPubkey != pubkey) {
        return;
      }
      try {
        final written = await prefs.setString(
          '${entry.key}.$pubkey',
          jsonEncode(entry.value.toList()),
        );
        if (!written) continue;
        await prefs.remove(entry.key);
      } on Object catch (e) {
        Log.error(
          'Failed to migrate legacy blocklist key ${entry.key}: $e',
          name: 'ContentBlocklistRepository',
          category: LogCategory.system,
        );
      }
    }
  }

  /// Load persisted blocked users from SharedPreferences
  void _loadBlockedUsers() {
    final prefs = _prefs;
    if (prefs == null) return;

    final stored = prefs.getString(_scopedKey(_blockedUsersPrefsKey));
    if (stored == null || stored.isEmpty) return;

    try {
      final list = (jsonDecode(stored) as List<dynamic>).cast<String>();
      _runtimeBlocklist.addAll(list);
      Log.info(
        'Loaded ${list.length} blocked users from persistence',
        name: 'ContentBlocklistRepository',
        category: LogCategory.system,
      );
    } on Object catch (e) {
      Log.error(
        'Failed to load persisted blocked users: $e',
        name: 'ContentBlocklistRepository',
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
      await prefs.setString(_scopedKey(_blockedUsersPrefsKey), json);
    } on Object catch (e) {
      Log.error(
        'Failed to persist blocked users: $e',
        name: 'ContentBlocklistRepository',
        category: LogCategory.system,
      );
    }
  }

  /// Load persisted muted authors from SharedPreferences.
  ///
  /// This is the hydration cache that covers the window between app start
  /// and relay delivery of our own kind 10000 event.
  void _loadMutedUsers() {
    final prefs = _prefs;
    if (prefs == null) return;

    final stored = prefs.getString(_scopedKey(_mutedUsersPrefsKey));
    if (stored == null || stored.isEmpty) return;

    try {
      final list = (jsonDecode(stored) as List<dynamic>).cast<String>();
      _mutedPubkeys.addAll(list);
      Log.info(
        'Loaded ${list.length} muted authors from persistence',
        name: 'ContentBlocklistRepository',
        category: LogCategory.system,
      );
    } on Object catch (e) {
      Log.error(
        'Failed to load persisted muted authors: $e',
        name: 'ContentBlocklistRepository',
        category: LogCategory.system,
      );
    }
  }

  /// Save muted authors to SharedPreferences
  ///
  /// Awaits the platform write so the data survives an immediate app kill.
  Future<void> _saveMutedUsers() async {
    final prefs = _prefs;
    if (prefs == null) return;

    try {
      final json = jsonEncode(_mutedPubkeys.toList());
      await prefs.setString(_scopedKey(_mutedUsersPrefsKey), json);
    } on Object catch (e) {
      Log.error(
        'Failed to persist muted authors: $e',
        name: 'ContentBlocklistRepository',
        category: LogCategory.system,
      );
    }
  }

  /// Load persisted severed followers from SharedPreferences
  void _loadSeveredFollowers() {
    final prefs = _prefs;
    if (prefs == null) return;

    final stored = prefs.getString(_scopedKey(_severedFollowersPrefsKey));
    if (stored == null || stored.isEmpty) return;

    try {
      final list = (jsonDecode(stored) as List<dynamic>).cast<String>();
      _severedFollowers.addAll(list);
      Log.info(
        'Loaded ${list.length} severed followers from persistence',
        name: 'ContentBlocklistRepository',
        category: LogCategory.system,
      );
    } on Object catch (e) {
      Log.error(
        'Failed to load persisted severed followers: $e',
        name: 'ContentBlocklistRepository',
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
      await prefs.setString(_scopedKey(_severedFollowersPrefsKey), json);
    } on Object catch (e) {
      Log.error(
        'Failed to persist severed followers: $e',
        name: 'ContentBlocklistRepository',
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
        name: 'ContentBlocklistRepository',
        category: LogCategory.system,
      );
    }
  }

  /// Publish our mute list to Nostr as a NIP-51 kind 10000 event.
  ///
  /// Blocking a user adds them to the user's standard Nostr mute list so
  /// the block interoperates with other clients (Amethyst, Damus, etc.)
  /// and the Divine backend, all of which key off kind 10000 (#4037).
  ///
  /// Kind 10000 is replaceable, so the event must carry the *entire* list.
  /// We publish the union of our blocks ([_runtimeBlocklist]) and the mutes
  /// authored from other clients ([_mutedPubkeys]) while carrying forward
  /// other public NIP-51 mute tags and encrypted private list content from
  /// the latest own kind 10000 event.
  ///
  /// Returns `true` when the event was accepted by at least one relay.
  Future<bool> _publishMuteListToNostr() async {
    final signer = _signer;
    final nostrClient = _nostrClient;

    if (signer == null || nostrClient == null) {
      Log.debug(
        'Cannot publish mute list - Nostr services not yet injected',
        name: 'ContentBlocklistRepository',
        category: LogCategory.system,
      );
      return false;
    }

    if (!signer.isAuthenticated) {
      Log.warning(
        'Cannot publish mute list - user not authenticated',
        name: 'ContentBlocklistRepository',
        category: LogCategory.system,
      );
      return false;
    }

    try {
      await _refreshLatestOwnMuteList(nostrClient);
      final publishShape = _buildMuteListPublishShape();

      final event = await signer.createAndSignEvent(
        kind: 10000,
        content: publishShape.content,
        tags: publishShape.tags,
      );

      if (event == null) return false;

      final sentEvent = await nostrClient.publishEvent(event);

      if (sentEvent is PublishSuccess) {
        // Record our own write as the newest seen event so a stale relay
        // echo of an older own mute list cannot race back and drop the
        // mutes we just merged in.
        _applyOwnMuteListEvent(sentEvent.event);
        Log.info(
          'Published mute list to Nostr with '
          '${_runtimeBlocklist.length + _mutedPubkeys.length} pubkey entries',
          name: 'ContentBlocklistRepository',
          category: LogCategory.system,
        );
        return true;
      }

      Log.warning(
        'Failed to publish mute list event to relays',
        name: 'ContentBlocklistRepository',
        category: LogCategory.system,
      );
      return false;
    } on Object catch (e) {
      Log.error(
        'Error publishing mute list to Nostr: $e',
        name: 'ContentBlocklistRepository',
        category: LogCategory.system,
      );
      return false;
    }
  }

  Future<void> _refreshLatestOwnMuteList(NostrClient nostrClient) async {
    final ourPubkey = _ourPubkey;
    if (ourPubkey == null) return;

    final muteEvents = await nostrClient.queryEvents([
      Filter(authors: [ourPubkey], kinds: const [10000]),
    ]);

    var newest = _latestOwnMuteListEvent;
    for (final event in muteEvents) {
      if (event.pubkey != ourPubkey) continue;
      if (newest == null || event.createdAt > newest.createdAt) {
        newest = event;
      }
    }

    if (newest != null && newest != _latestOwnMuteListEvent) {
      _applyOwnMuteListEvent(newest);
    }
  }

  _MuteListPublishShape _buildMuteListPublishShape() {
    final source = _latestOwnMuteListEvent;
    final tags = <List<String>>[];
    final includedPubkeys = <String>{};

    if (source != null) {
      for (final tag in source.tags) {
        if (tag.isEmpty || tag[0] != 'p') {
          tags.add(List<String>.of(tag));
          continue;
        }

        if (tag.length < 2) continue;
        final pubkey = tag[1];
        if (_mutedPubkeys.contains(pubkey) && includedPubkeys.add(pubkey)) {
          tags.add(List<String>.of(tag));
        }
      }
    }

    for (final pubkey in _mutedPubkeys) {
      if (includedPubkeys.add(pubkey)) {
        tags.add(['p', pubkey]);
      }
    }

    for (final pubkey in _runtimeBlocklist) {
      if (includedPubkeys.add(pubkey)) {
        tags.add(['p', pubkey]);
      }
    }

    return _MuteListPublishShape(tags: tags, content: source?.content ?? '');
  }

  /// Publish our legacy block list to Nostr as kind 30000 with d=block.
  ///
  /// Retained for backward compatibility with older Divine clients that
  /// still read kind 30000. New interop goes through the standard kind
  /// 10000 mute list ([_publishMuteListToNostr]).
  // TODO(codex): Remove legacy kind 30000 publishing after kind 10000 rollout.
  // Tracking issue: #5462.
  Future<void> _publishBlockListToNostr() async {
    final signer = _signer;
    final nostrClient = _nostrClient;

    if (signer == null || nostrClient == null) {
      Log.debug(
        'Cannot publish block list - Nostr services not yet injected',
        name: 'ContentBlocklistRepository',
        category: LogCategory.system,
      );
      return;
    }

    if (!signer.isAuthenticated) {
      Log.warning(
        'Cannot publish block list - user not authenticated',
        name: 'ContentBlocklistRepository',
        category: LogCategory.system,
      );
      return;
    }

    try {
      final tags = <List<String>>[
        ['d', 'block'],
        ['title', 'Block List'],
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

        if (sentEvent is PublishSuccess) {
          Log.info(
            'Published block list to Nostr with '
            '${_runtimeBlocklist.length} entries',
            name: 'ContentBlocklistRepository',
            category: LogCategory.system,
          );
        } else {
          Log.warning(
            'Failed to publish block list event to relays',
            name: 'ContentBlocklistRepository',
            category: LogCategory.system,
          );
        }
      }
    } on Object catch (e) {
      Log.error(
        'Error publishing block list to Nostr: $e',
        name: 'ContentBlocklistRepository',
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

  /// The buckets whose union is hidden from feeds, held as live references
  /// to the underlying sets. Every instance is stable for the repository's
  /// lifetime — the `const` internal list plus four `final` sets that are
  /// only ever mutated in place — so both [feedHiddenPubkeys] and
  /// [shouldFilterFromFeeds] derive from this one list and cannot drift. A
  /// new hide-bucket is added here exactly once.
  late final List<Set<String>> _hideBuckets = [
    _internalBlocklist,
    _runtimeBlocklist,
    _mutedPubkeys,
    _mutualMuteBlocklist,
    _blockedByOthers,
  ];

  /// The union of every pubkey hidden from feeds:
  /// - Users we blocked (internal + runtime blocklist)
  /// - Users we muted via our own kind 10000 mute list
  /// - Users who mutually muted us (kind 10000)
  /// - Users who blocked us (kind 30000, d=block) — hides our content
  ///   from their feeds and their content from ours
  ///
  /// This is the canonical feed-hide set. UI surfaces that need the
  /// materialized set — e.g. DM reaction filtering in `conversation_view`
  /// — read this rather than re-deriving the union by hand, so they stay
  /// in lockstep with [shouldFilterFromFeeds].
  Set<String> get feedHiddenPubkeys => {
    for (final bucket in _hideBuckets) ...bucket,
  };

  /// Whether [pubkey] is in [feedHiddenPubkeys] and so should be filtered
  /// from feeds.
  ///
  /// Implemented as a short-circuiting, allocation-free membership scan
  /// rather than `feedHiddenPubkeys.contains(...)` because this is a hot
  /// path — called per item across ~15 feed surfaces — and materializing
  /// the union on every call would be wasteful.
  bool shouldFilterFromFeeds(String pubkey) {
    for (var i = 0; i < _hideBuckets.length; i++) {
      if (_hideBuckets[i].contains(pubkey)) return true;
    }
    return false;
  }

  /// Check if we muted another user via our own kind 10000 mute list.
  ///
  /// Mutes are authored from other Nostr clients (this app has no mute
  /// action); this reflects the latest own kind 10000 event seen on relays.
  bool isMutedByUs(String pubkey) => _mutedPubkeys.contains(pubkey);

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
  /// Persists to SharedPreferences and publishes the user's kind 10000 mute
  /// list (plus the legacy kind 30000 block list for older Divine clients).
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
        name: 'ContentBlocklistRepository',
        category: LogCategory.system,
      );
      return;
    }

    if (!_runtimeBlocklist.contains(pubkey)) {
      _runtimeBlocklist.add(pubkey);
      await _saveBlockedUsers();
      _emitChange(BlocklistChange(pubkey: pubkey, op: BlocklistOp.blocked));
      _notifyChanged();
      await _publishMuteListToNostr();
      await _publishBlockListToNostr();

      Log.debug(
        'Added user to blocklist: $pubkey',
        name: 'ContentBlocklistRepository',
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
  /// Persists to SharedPreferences and republishes the updated kind 10000
  /// mute list (plus the legacy kind 30000 block list) to Nostr.
  /// Awaits the local write so the change survives an immediate app kill.
  /// Note: Cannot remove users from internal blocklist.
  Future<void> unblockUser(String pubkey) async {
    if (_runtimeBlocklist.contains(pubkey)) {
      _runtimeBlocklist.remove(pubkey);
      await _saveBlockedUsers();
      _emitChange(BlocklistChange(pubkey: pubkey, op: BlocklistOp.unblocked));
      _notifyChanged();
      await _publishMuteListToNostr();
      await _publishBlockListToNostr();

      Log.info(
        'Removed user from blocklist: $pubkey',
        name: 'ContentBlocklistRepository',
        category: LogCategory.system,
      );
      // coverage:ignore-start
    } else if (_internalBlocklist.contains(pubkey)) {
      // Internal blocklist is intentionally empty; this branch is
      // unreachable in production. Retained as a guard in case hardcoded
      // moderation blocks are re-introduced.
      Log.warning(
        'Cannot unblock user from internal blocklist: $pubkey',
        name: 'ContentBlocklistRepository',
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
        name: 'ContentBlocklistRepository',
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

  /// Start background sync of mute lists (NIP-51 kind 10000).
  ///
  /// Subscribes to two filter sets in a single subscription:
  /// 1. Kind 10000 events WHERE our pubkey appears in 'p' tags — detects
  ///    when other users mute us (mutual mute).
  /// 2. Our own kind 10000 event — mutes the user authored from other
  ///    Nostr clients (this app has no mute action), and relay-based
  ///    restoration after reinstall, mirroring the kind 30000 block
  ///    restore in [syncBlockListsInBackground].
  Future<void> syncMuteListsInBackground(
    NostrClient nostrService,
    String ourPubkey,
  ) async {
    // Reset per-account state (and the started flags) if the identity
    // changed, so the subscription below filters on the new pubkey (#4969).
    _adoptIdentity(ourPubkey);

    // If the NostrClient changed (e.g., account switch), the old subscription
    // was on a disposed client. Reset so we create a fresh subscription.
    if (_mutualMuteSyncStarted && _nostrClient != nostrService) {
      _mutualMuteSyncStarted = false;
    }

    if (_mutualMuteSyncStarted) {
      Log.debug(
        'Mutual mute sync already started, skipping',
        name: 'ContentBlocklistRepository',
        category: LogCategory.system,
      );
      return;
    }

    // Store references for Nostr publishing
    _nostrClient = nostrService;

    Log.info(
      'Starting mutual mute list sync for pubkey: $ourPubkey',
      name: 'ContentBlocklistRepository',
      category: LogCategory.system,
    );

    try {
      // Filter 1: others' mute lists that include our pubkey (mutual mute)
      final mutualFilter = Filter(kinds: const [10000])..p = [ourPubkey];

      // Filter 2: our own mute list (mutes authored from other clients +
      // relay-based restoration after reinstall)
      final ownFilter = Filter(authors: [ourPubkey], kinds: const [10000]);

      final subscription = nostrService.subscribe([mutualFilter, ownFilter]);

      _mutualMuteSyncStarted = true;
      _mutualMuteSubscriptionId =
          'mutual-mute-${DateTime.now().millisecondsSinceEpoch}';

      // Listen to the stream
      subscription.listen(_handleMuteListEvent);

      Log.info(
        'Mutual mute subscription created: $_mutualMuteSubscriptionId',
        name: 'ContentBlocklistRepository',
        category: LogCategory.system,
      );
    } on Object catch (e) {
      Log.error(
        'Failed to start mutual mute sync: $e',
        name: 'ContentBlocklistRepository',
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
    // Reset per-account state (and the started flags) if the identity
    // changed, so the subscription below filters on the new pubkey (#4969).
    _adoptIdentity(ourPubkey);

    // If the NostrClient changed (e.g., account switch), the old subscription
    // was on a disposed client. Reset so we create a fresh subscription.
    if (_blockListSyncStarted && _nostrClient != nostrService) {
      _blockListSyncStarted = false;
    }

    if (_blockListSyncStarted) {
      Log.debug(
        'Block list sync already started, skipping',
        name: 'ContentBlocklistRepository',
        category: LogCategory.system,
      );
      return;
    }

    _signer = signer;
    _nostrClient = nostrService;

    Log.info(
      'Starting block list sync for pubkey: $ourPubkey',
      name: 'ContentBlocklistRepository',
      category: LogCategory.system,
    );

    try {
      // Filter 1: Others' block lists that include our pubkey
      final othersFilter = Filter(kinds: const [30000])..p = [ourPubkey];

      // Filter 2: Our own block list (for relay-based restoration)
      // Omit the d-tag constraint here — not all relays support #d
      // filtering, and _handleBlockListEvent already checks for d=block.
      final ownFilter = Filter(authors: [ourPubkey], kinds: const [30000]);

      nostrService
          .subscribe([othersFilter, ownFilter])
          .listen(_handleBlockListEvent);

      _blockListSyncStarted = true;

      // One-time migration (#4037): fold any legacy kind 30000 block list
      // into the standard kind 10000 mute list so pre-existing blocks
      // finally interoperate with other clients. Fire-and-forget so it
      // never blocks startup; guarded by a per-account persisted flag.
      unawaited(
        _migrateLegacyBlockListToMuteList(nostrService, signer, ourPubkey),
      );

      Log.info(
        'Block list subscription created (includes own block list restore)',
        name: 'ContentBlocklistRepository',
        category: LogCategory.system,
      );
    } on Object catch (e) {
      Log.error(
        'Failed to start block list sync: $e',
        name: 'ContentBlocklistRepository',
        category: LogCategory.system,
      );
    }
  }

  /// One-time migration of a legacy kind 30000 (d=block) block list into the
  /// standard NIP-51 kind 10000 mute list (#4037).
  ///
  /// Older app versions only published blocks to a non-standard kind 30000
  /// list that no other client honoured. This appends those entries to the
  /// user's existing kind 10000 mute list and republishes it once, so
  /// pre-existing blocks finally propagate — without dropping any mutes set
  /// on other clients (the existing list is fetched and merged, never
  /// replaced blindly).
  ///
  /// Guarded by a per-account SharedPreferences flag so it runs at most once
  /// per account. The flag is only set after the republish is accepted, so a
  /// failed publish retries on the next launch. Requires persistence; it is a
  /// no-op without prefs (the one-time guarantee can't be tracked otherwise).
  Future<void> _migrateLegacyBlockListToMuteList(
    NostrClient nostrClient,
    BlockListSigner signer,
    String ourPubkey,
  ) async {
    final prefs = _prefs;
    if (prefs == null) return;
    final flagKey = '$_blockListMigratedPrefsKeyBase.$ourPubkey';
    if (prefs.getBool(flagKey) ?? false) return;
    if (!signer.isAuthenticated) return;

    try {
      // 1. Read the legacy kind 30000 d=block list from cache + relays.
      final relayBlocks = <String>{};
      final blockEvents = await nostrClient.queryEvents([
        Filter(authors: [ourPubkey], kinds: const [30000]),
      ]);
      for (final event in blockEvents) {
        if (event.pubkey != ourPubkey) continue;
        final hasBlockDTag = event.tags.any(
          (tag) => tag.length >= 2 && tag[0] == 'd' && tag[1] == 'block',
        );
        if (!hasBlockDTag) continue;
        for (final tag in event.tags) {
          if (tag.length >= 2 && tag[0] == 'p' && tag[1] != ourPubkey) {
            relayBlocks.add(tag[1]);
          }
        }
      }

      // Nothing to migrate. Leave the flag unset because an empty one-shot
      // query can also mean a cold relay miss; retrying on a later launch is
      // safer than permanently skipping a legacy-list migration.
      if (relayBlocks.isEmpty && _runtimeBlocklist.isEmpty) {
        return;
      }

      // 2. Read the existing kind 10000 mute list (newest replaceable wins)
      //    so the merge never drops mutes authored on other clients.
      final muteEvents = await nostrClient.queryEvents([
        Filter(authors: [ourPubkey], kinds: const [10000]),
      ]);
      Event? newestMuteList;
      for (final event in muteEvents) {
        if (event.pubkey != ourPubkey) continue;
        if (newestMuteList == null ||
            event.createdAt > newestMuteList.createdAt) {
          newestMuteList = event;
        }
      }

      // 3. Fold both lists into our in-memory state without removing
      //    anything. Legacy entries are our blocks; the rest of the relay's
      //    mute list is preserved as mutes (our own blocks are kept out of
      //    the mute set, matching [_handleOwnMuteListEvent]).
      final newlyBlocked = relayBlocks.difference(_runtimeBlocklist);
      _runtimeBlocklist.addAll(relayBlocks);
      final mutedBeforeMerge = <String>{..._mutedPubkeys};
      if (newestMuteList != null) {
        _applyOwnMuteListEvent(newestMuteList, notify: false, persist: false);
      }
      final newlyMuted = _mutedPubkeys.difference(mutedBeforeMerge);
      await _saveBlockedUsers();
      await _saveMutedUsers();

      // 4. Republish the unified kind 10000 mute list. Only record the
      //    migration as done once the relay accepts it, so a failure retries.
      final published = await _publishMuteListToNostr();
      if (!published) {
        Log.warning(
          'Legacy block-list migration publish failed; retrying next launch',
          name: 'ContentBlocklistRepository',
          category: LogCategory.system,
        );
        return;
      }

      await prefs.setBool(flagKey, true);

      for (final pubkey in newlyBlocked) {
        _emitChange(BlocklistChange(pubkey: pubkey, op: BlocklistOp.blocked));
      }
      for (final pubkey in newlyMuted) {
        _emitChange(BlocklistChange(pubkey: pubkey, op: BlocklistOp.mutedByUs));
      }
      if (newlyBlocked.isNotEmpty || newlyMuted.isNotEmpty) {
        _notifyChanged();
      }

      Log.info(
        'Migrated legacy block list into the kind 10000 mute list '
        '(${_runtimeBlocklist.length} blocks, ${_mutedPubkeys.length} mutes)',
        name: 'ContentBlocklistRepository',
        category: LogCategory.system,
      );
    } on Object catch (e) {
      Log.error(
        'Failed to migrate legacy block list to mute list: $e',
        name: 'ContentBlocklistRepository',
        category: LogCategory.system,
      );
    }
  }

  /// Handle incoming kind 10000 mute list events.
  ///
  /// Routes our own mute list to [_handleOwnMuteListEvent]; for other
  /// authors, adds/removes the muter based on whether our pubkey is in
  /// their 'p' tags (mutual mute).
  void _handleMuteListEvent(Event event) {
    if (event.kind != 10000) {
      Log.warning(
        'Received non-10000 event in mute list handler: ${event.kind}',
        name: 'ContentBlocklistRepository',
        category: LogCategory.system,
      );
      return;
    }

    if (event.pubkey == _ourPubkey) {
      _handleOwnMuteListEvent(event);
      return;
    }

    final muterPubkey = event.pubkey;
    final createdAt = event.createdAt;
    final latestSeen = _latestMuteListEventCreatedAtByAuthor[muterPubkey];

    if (latestSeen != null && createdAt < latestSeen) {
      Log.debug(
        'Ignoring stale mute list event from $muterPubkey '
        '(createdAt=$createdAt < latestSeen=$latestSeen)',
        name: 'ContentBlocklistRepository',
        category: LogCategory.system,
      );
      return;
    }

    _latestMuteListEventCreatedAtByAuthor[muterPubkey] = createdAt;

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
        _emitChange(
          BlocklistChange(pubkey: muterPubkey, op: BlocklistOp.muted),
        );
        _notifyChanged();
        Log.info(
          'Added mutual mute: $muterPubkey',
          name: 'ContentBlocklistRepository',
          category: LogCategory.system,
        );
      }
    } else {
      // They removed us from mute list - remove from blocklist
      if (_mutualMuteBlocklist.contains(muterPubkey)) {
        _mutualMuteBlocklist.remove(muterPubkey);
        _emitChange(
          BlocklistChange(pubkey: muterPubkey, op: BlocklistOp.unmuted),
        );
        _notifyChanged();
        Log.info(
          'Removed mutual mute (unmuted): $muterPubkey',
          name: 'ContentBlocklistRepository',
          category: LogCategory.system,
        );
      }
    }
  }

  /// Replace our muted-authors set from our latest kind 10000 event.
  ///
  /// Kind 10000 is replaceable, so the newest own event is the complete
  /// list and replaces [_mutedPubkeys] wholesale — unlike
  /// [_handleOwnBlockListEvent], which merges to protect locally-authored
  /// blocks that may not have reached relays.
  ///
  /// Our own in-app blocks ([_runtimeBlocklist]) are excluded: this app now
  /// publishes them onto the same kind 10000 list, so an entry that we
  /// blocked must be tracked as a block (not duplicated into the mute set),
  /// otherwise unblocking could never drop it from the republished list.
  /// Our own pubkey is excluded so a malformed self-referential mute list
  /// can never filter the user's own content (#2192).
  void _handleOwnMuteListEvent(Event event) {
    _applyOwnMuteListEvent(event);
  }

  void _applyOwnMuteListEvent(
    Event event, {
    bool notify = true,
    bool persist = true,
  }) {
    final ourPubkey = event.pubkey;
    final createdAt = event.createdAt;
    final latestSeen = _latestMuteListEventCreatedAtByAuthor[ourPubkey];

    if (latestSeen != null && createdAt < latestSeen) {
      Log.debug(
        'Ignoring stale own mute list event '
        '(createdAt=$createdAt < latestSeen=$latestSeen)',
        name: 'ContentBlocklistRepository',
        category: LogCategory.system,
      );
      return;
    }

    _latestMuteListEventCreatedAtByAuthor[ourPubkey] = createdAt;
    _latestOwnMuteListEvent = event;

    final relayMuted = <String>{};
    for (final tag in event.tags) {
      if (tag.isNotEmpty &&
          tag[0] == 'p' &&
          tag.length >= 2 &&
          tag[1] != ourPubkey) {
        relayMuted.add(tag[1]);
      }
    }
    // Entries we blocked in-app are republished onto this same list; keep
    // them out of the mute set so they stay tracked as blocks only.
    relayMuted.removeAll(_runtimeBlocklist);

    final added = relayMuted.difference(_mutedPubkeys);
    final removed = _mutedPubkeys.difference(relayMuted);
    if (added.isEmpty && removed.isEmpty) return;

    _mutedPubkeys
      ..removeAll(removed)
      ..addAll(added);
    if (persist) {
      unawaited(_saveMutedUsers());
    }
    if (notify) {
      for (final pubkey in added) {
        _emitChange(BlocklistChange(pubkey: pubkey, op: BlocklistOp.mutedByUs));
      }
      for (final pubkey in removed) {
        _emitChange(
          BlocklistChange(pubkey: pubkey, op: BlocklistOp.unmutedByUs),
        );
      }
      _notifyChanged();
    }

    Log.info(
      'Synced own mute list: +${added.length} -${removed.length} '
      '(total: ${_mutedPubkeys.length})',
      name: 'ContentBlocklistRepository',
      category: LogCategory.system,
    );
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
    for (final pubkey in added) {
      _emitChange(BlocklistChange(pubkey: pubkey, op: BlocklistOp.blocked));
    }
    _notifyChanged();

    Log.info(
      'Restored ${added.length} blocks from relay '
      '(total: ${_runtimeBlocklist.length})',
      name: 'ContentBlocklistRepository',
      category: LogCategory.system,
    );
  }

  /// Handle another user's block list event.
  ///
  /// Checks if our pubkey is in their 'p' tags, then adds/removes
  /// the blocker from [_blockedByOthers].
  void _handleOthersBlockListEvent(Event event) {
    final blockerPubkey = event.pubkey;
    final createdAt = event.createdAt;
    final latestSeen = _latestBlockListEventCreatedAtByAuthor[blockerPubkey];

    if (latestSeen != null && createdAt < latestSeen) {
      Log.debug(
        'Ignoring stale block list event from $blockerPubkey '
        '(createdAt=$createdAt < latestSeen=$latestSeen)',
        name: 'ContentBlocklistRepository',
        category: LogCategory.system,
      );
      return;
    }

    _latestBlockListEventCreatedAtByAuthor[blockerPubkey] = createdAt;

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
        _emitChange(
          BlocklistChange(pubkey: blockerPubkey, op: BlocklistOp.blockedUs),
        );
        _notifyChanged();
        Log.info(
          'Detected block from user: $blockerPubkey',
          name: 'ContentBlocklistRepository',
          category: LogCategory.system,
        );
      }
    } else {
      if (_blockedByOthers.contains(blockerPubkey)) {
        _blockedByOthers.remove(blockerPubkey);
        _emitChange(
          BlocklistChange(pubkey: blockerPubkey, op: BlocklistOp.unblockedUs),
        );
        _notifyChanged();
        Log.info(
          'Detected unblock from user: $blockerPubkey',
          name: 'ContentBlocklistRepository',
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
    unawaited(_stateController.close());
    unawaited(_changesController.close());
  }
}
