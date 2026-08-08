import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cache_sync/cache_sync.dart';
import 'package:db_client/db_client.dart' hide Filter;
import 'package:follow_repository/src/follow_list_kind.dart';
import 'package:follow_repository/src/follower_stats.dart';
import 'package:follow_repository/src/followers_snapshot.dart';
import 'package:follow_repository/src/following_snapshot.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

class _SourceResult<T> {
  const _SourceResult({
    required this.value,
    required this.complete,
    this.error,
    this.stackTrace,
  });

  final T value;
  final bool complete;
  final Object? error;
  final StackTrace? stackTrace;
}

class _FollowerStatsFetchResult {
  const _FollowerStatsFetchResult({
    required this.stats,
    required this.followersComplete,
    required this.followingComplete,
  });

  final FollowerStats stats;
  final bool followersComplete;
  final bool followingComplete;

  bool get isComplete => followersComplete && followingComplete;
}

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
    required List<String> indexerRelayUrls,
    IsCacheInitializedCallback? isCacheInitialized,
    GetCachedEventsByKindCallback? getCachedEventsByKind,
    CacheUserEventCallback? cacheUserEvent,
    FunnelcakeApiClient? funnelcakeApiClient,
    ProfileStatsDao? profileStatsDao,
    IsOnlineCallback? isOnline,
    QueueOfflineFollowCallback? queueOfflineAction,
    QueryContactListCallback? queryContactList,
    RelayFactory? relayFactory,
  }) : _nostrClient = nostrClient,
       _isCacheInitialized = isCacheInitialized,
       _getCachedEventsByKind = getCachedEventsByKind,
       _cacheUserEvent = cacheUserEvent,
       _funnelcakeApiClient = funnelcakeApiClient,
       _profileStatsDao = profileStatsDao,
       _isOnline = isOnline,
       _queueOfflineAction = queueOfflineAction,
       _indexerRelayUrls = indexerRelayUrls,
       _queryContactList = queryContactList ?? _defaultQueryContactList,
       _relayFactory = relayFactory ?? _defaultRelayFactory;

  final NostrClient _nostrClient;
  final IsCacheInitializedCallback? _isCacheInitialized;
  final GetCachedEventsByKindCallback? _getCachedEventsByKind;
  final CacheUserEventCallback? _cacheUserEvent;
  final FunnelcakeApiClient? _funnelcakeApiClient;

  /// Callback to check if the device is online
  final IsOnlineCallback? _isOnline;

  /// Callback to queue actions for offline sync
  final QueueOfflineFollowCallback? _queueOfflineAction;

  /// Drift DAO for persisting follower stats across sessions.
  final ProfileStatsDao? _profileStatsDao;

  /// Indexer relay URLs for direct WebSocket queries.
  /// Pass empty list in tests to prevent real network connections.
  final List<String> _indexerRelayUrls;

  /// Callback to query a contact list from a relay event stream.
  final QueryContactListCallback _queryContactList;

  /// Factory for creating relay instances (injectable for testing).
  final RelayFactory _relayFactory;

  /// Default relay factory — creates a real [RelayBase].
  static RelayBase _defaultRelayFactory(String url, RelayStatus status) =>
      RelayBase(url, status);

  /// Default implementation: listen for the first matching contact list
  /// event, with a timeout fallback.
  static Future<Event?> _defaultQueryContactList({
    required Stream<Event> eventStream,
    required String pubkey,
    int fallbackTimeoutSeconds = 10,
  }) async {
    try {
      return await eventStream
          .where((e) => e.kind == EventKind.contactList && e.pubkey == pubkey)
          .first
          .timeout(Duration(seconds: fallbackTimeoutSeconds));
    } on TimeoutException {
      return null;
      // Catching StateError is intentional: `.first` throws it when the
      // stream closes without a matching event.
      // ignore: avoid_catching_errors
    } on StateError {
      return null;
    }
  }

  // BehaviorSubject replays last value to late subscribers, fixing race condition
  // where BLoC subscribes AFTER initial emission.
  // Seeded with null to distinguish "not yet initialized" from "empty following list".
  final _followingSubject = BehaviorSubject<List<String>?>.seeded(null);
  Stream<List<String>> get followingStream =>
      _followingSubject.stream.whereType<List<String>>();

  // In-memory cache — following
  List<String> _followingPubkeys = [];
  Event? _currentUserContactListEvent;
  bool _isInitialized = false;

  // In-memory cache — my followers (populated after first fetch)
  List<String> _cachedMyFollowersPubkeys = [];
  int _cachedMyFollowerCount = 0;
  bool _hasMyFollowersCache = false;
  static const _profileListCacheTtl = Duration(seconds: 30);

  // Real-time sync subscription for cross-device synchronization
  StreamSubscription<Event>? _contactListSubscription;
  String? _contactListSubscriptionId;

  // Getters
  List<String> get followingPubkeys => List.unmodifiable(_followingPubkeys);
  bool get isInitialized => _isInitialized;
  int get followingCount => _followingPubkeys.length;

  /// Drops entries that are not 32-byte hex pubkeys.
  ///
  /// Every source of the following list is untrusted: Kind 3 events are
  /// written by any Nostr client, and both the REST API and our caches are
  /// derived from those events. A single non-hex entry makes
  /// [_broadcastContactList] throw in `Contact`'s constructor, which aborts
  /// the publish and permanently blocks every follow and unfollow — a real
  /// contact list on `wss://relay.divine.video` carries a `["p","nos"]` entry.
  /// Its origin was never identified: `"nos"` matches `tag[1]` of the
  /// `["client","nos",...]` tag the Nos app writes, but no parser reading that
  /// value without filtering on `p` exists in this repo or its history.
  List<String> _sanitizePubkeys(
    List<String> pubkeys, {
    required String source,
  }) {
    final valid = pubkeys.where(keyIsValid).toList();

    final droppedCount = pubkeys.length - valid.length;
    if (droppedCount > 0) {
      final dropped = pubkeys.where((pubkey) => !keyIsValid(pubkey));
      Log.warning(
        'Dropped $droppedCount invalid pubkey(s) from $source: '
        '${dropped.join(', ')}',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
    }

    return valid;
  }

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
    unawaited(_contactListSubscription?.cancel());
    if (_contactListSubscriptionId != null) {
      await _nostrClient.unsubscribe(_contactListSubscriptionId!);
      _contactListSubscriptionId = null;
    }
    if (!_followingSubject.isClosed) {
      unawaited(_followingSubject.close());
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
    final result = await _fetchFollowers(_nostrClient.publicKey);
    _cachedMyFollowersPubkeys = result;
    _hasMyFollowersCache = true;
    return result;
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
  /// Uses multi-source fetching with hysteresis stabilization.
  Future<int> getMyFollowerCount() async {
    final count = await getFollowerCount(_nostrClient.publicKey);
    _cachedMyFollowerCount = count;
    return count;
  }

  /// Progressively streams the current user's followers.
  ///
  /// Yields cached data immediately when available (from a previous fetch),
  /// then fetches fresh data from all sources and yields the updated result.
  /// Each emission contains the full follower list and an accurate count.
  ///
  /// Follows the same progressive-yield pattern as
  /// `VideosRepository.searchVideos`.
  Stream<FollowersSnapshot> watchMyFollowers() async* {
    // Phase 1: Yield cached data immediately (if available)
    if (_hasMyFollowersCache) {
      yield FollowersSnapshot(
        pubkeys: List<String>.unmodifiable(_cachedMyFollowersPubkeys),
        count: _cachedMyFollowerCount,
      );
    }

    // Phase 2: Fetch fresh data from all sources in parallel
    final results = await Future.wait([getMyFollowers(), getMyFollowerCount()]);
    final pubkeys = results[0] as List<String>;
    final countFromService = results[1] as int;
    final count = max(pubkeys.length, countFromService);

    // Cache is updated by getMyFollowers/getMyFollowerCount; store the
    // merged count so the next watchMyFollowers call yields it.
    _cachedMyFollowerCount = count;

    yield FollowersSnapshot(pubkeys: pubkeys, count: count);
  }

  /// Maps the current user's following stream to [FollowingSnapshot] objects.
  ///
  /// Used by [CacheSync.watchStream] in MyFollowingBloc to provide
  /// stale-while-revalidate behaviour backed by the Drift cache.
  Stream<FollowingSnapshot> watchMyFollowing() {
    return followingStream.map(
      (pubkeys) => FollowingSnapshot(pubkeys: pubkeys, count: pubkeys.length),
    );
  }

  /// Fetches the following list for any user by querying their Kind 3
  /// contact list event from Nostr relays.
  ///
  /// Returns a [FollowingSnapshot] with the deduplicated list of followed
  /// pubkeys. Returns an empty snapshot if no event is found.
  Future<FollowingSnapshot> getOthersFollowing(String pubkey) async {
    final events = await _nostrClient.queryEvents([
      Filter(authors: [pubkey], kinds: const [3], limit: 1),
    ]);

    final following = <String>[];
    if (events.isNotEmpty) {
      for (final tag in events.first.tags) {
        if (tag.isNotEmpty && tag[0] == 'p' && tag.length > 1) {
          final followedPubkey = tag[1];
          if (!following.contains(followedPubkey)) {
            following.add(followedPubkey);
          }
        }
      }
    }

    // Backs watchMyFollowingCached() for the current user too, so an invalid
    // entry would surface as a ghost row on the own-Following screen and be
    // persisted to Drift by CacheSync. Count follows the sanitized list so the
    // header cannot disagree with the rows.
    final sanitized = _sanitizePubkeys(
      following,
      source: 'Kind 3 event from $pubkey',
    );

    return FollowingSnapshot(pubkeys: sanitized, count: sanitized.length);
  }

  // ---- CacheSync-backed stale-while-revalidate watchers --------------------
  //
  // These wrap [watchMyFollowers], [watchMyFollowing], [getFollowers], and
  // [getOthersFollowing] with [CacheSync] so consumers (BLoCs) get
  // cache-first emissions followed by live data without knowing about
  // [CacheSync] or cache-key conventions. Cache keys are private to this
  // repository — changing them invalidates every cached entry on every user's
  // device.

  // Cache keys follow the `${pubkey}:${operation}` convention (RFC #4244) so
  // `CacheSync.invalidatePrefix(pubkey)` at sign-out clears every entry for
  // that account without touching other accounts on the same device.
  static String _myFollowersCacheKey(String pubkey) => '$pubkey:my_followers';
  static String _myFollowingCacheKey(String pubkey) => '$pubkey:my_following';
  static String _othersFollowersCacheKey(String pubkey) =>
      '$pubkey:others_followers';
  static String _othersFollowingCacheKey(String pubkey) =>
      '$pubkey:others_following';

  /// Best-effort invalidation of the cached following-list snapshot.
  ///
  /// `follow`/`unfollow` and the offline-sync/merge paths mutate the in-memory
  /// list and SharedPreferences but never the CacheSync disk entry. Without
  /// this, the next [watchMyFollowingCached] read serves a pre-mutation
  /// snapshot and the follow-button state reverts (#5144). Invalidation is
  /// non-fatal: a cache failure must not fail an otherwise-successful follow.
  Future<void> _invalidateMyFollowingCache() async {
    final pubkey = _nostrClient.publicKey;
    if (pubkey.isEmpty) return;
    try {
      await CacheSync.invalidate(_myFollowingCacheKey(pubkey));
    } on Exception catch (e) {
      Log.warning(
        'Failed to invalidate my_following cache: $e',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
    }
  }

  /// Cache-backed stream of the current user's followers.
  ///
  /// Emits a [CacheResult.cached] if disk-cached data exists, then a single
  /// [CacheResult.live] once the network fetch resolves.
  ///
  /// Uses [CacheSync.watchOne] rather than [CacheSync.watchStream] so that
  /// [CacheSync] is the single owner of the stale/live boundary. Wrapping
  /// [watchMyFollowers] with [CacheSync.watchStream] created two cache layers:
  /// CacheSync emitted the disk entry as [CacheResult.cached], but
  /// [watchMyFollowers]'s own in-memory phase then emitted an additional
  /// snapshot that CacheSync incorrectly tagged as [CacheResult.live] before
  /// the real network fetch had completed, breaking [CacheResult.isLive]
  /// semantics.
  Stream<CacheResult<FollowersSnapshot>> watchMyFollowersCached() {
    return CacheSync.watchOne<FollowersSnapshot>(
      key: _myFollowersCacheKey(_nostrClient.publicKey),
      fetch: () async {
        final results = await Future.wait([
          getMyFollowers(),
          getMyFollowerCount(),
        ]);
        final pubkeys = results[0] as List<String>;
        final countFromService = results[1] as int;
        final count = max(pubkeys.length, countFromService);
        _cachedMyFollowerCount = count;
        return FollowersSnapshot(pubkeys: pubkeys, count: count);
      },
      fromJson: FollowersSnapshot.fromJson,
      toJson: (s) => s.toJson(),
    );
  }

  /// Cache-backed stream of the current user's following list.
  ///
  /// Emits a [CacheResult.cached] if disk-cached data exists, then a single
  /// [CacheResult.live] once the network fetch resolves.
  ///
  /// Uses [CacheSync.watchOne] rather than [CacheSync.watchStream] for the
  /// same reason as [watchMyFollowersCached]: [watchMyFollowing] emits from
  /// a [BehaviorSubject] seeded by `initialize()`'s LocalStorage /
  /// PersonalEventCache reads. Subscribing via [CacheSync.watchStream]
  /// would replay that pre-network in-memory snapshot and CacheSync would
  /// incorrectly tag it as [CacheResult.live] before the network refresh
  /// has actually run, breaking the new `isRefreshing` / [CacheResult.isLive]
  /// contract.
  ///
  /// Ongoing follow/unfollow reactivity is handled by [followingStream]
  /// (the in-memory single source of truth). Local toggles and cross-device
  /// kind 3 updates invalidate the [_myFollowingCacheKey] entry via
  /// [_invalidateMyFollowingCache], so the next [watchMyFollowingCached] read
  /// (on a later mount) never serves a pre-mutation snapshot (#5144).
  Stream<CacheResult<FollowingSnapshot>> watchMyFollowingCached() {
    return CacheSync.watchOne<FollowingSnapshot>(
      key: _myFollowingCacheKey(_nostrClient.publicKey),
      fetch: () => getOthersFollowing(_nostrClient.publicKey),
      fromJson: FollowingSnapshot.fromJson,
      toJson: (s) => s.toJson(),
    );
  }

  /// Cache-backed stream of another user's followers.
  ///
  /// Wraps [getFollowers] in a one-shot fetch under [CacheSync.watchOne].
  /// When [forceRefresh] is true, bypasses the cache and fetches live.
  Stream<CacheResult<FollowersSnapshot>> watchOthersFollowersCached(
    String pubkey, {
    bool forceRefresh = false,
  }) {
    return CacheSync.watchOne<FollowersSnapshot>(
      key: _othersFollowersCacheKey(pubkey),
      fetch: () async {
        final results = await Future.wait([
          getFollowers(pubkey),
          getFollowerCount(pubkey),
        ]);
        final followers = results[0] as List<String>;
        final countFromService = results[1] as int;
        final count = max(followers.length, countFromService);
        return FollowersSnapshot(pubkeys: followers, count: count);
      },
      fromJson: FollowersSnapshot.fromJson,
      toJson: (s) => s.toJson(),
      ttl: _profileListCacheTtl,
      policy: forceRefresh
          ? CacheFetchPolicy.networkOnly
          : CacheFetchPolicy.cacheFirst,
    );
  }

  /// Cache-backed stream of another user's following list.
  ///
  /// Wraps [getOthersFollowing] in a one-shot fetch under [CacheSync.watchOne].
  /// When [forceRefresh] is true, bypasses the cache and fetches live.
  Stream<CacheResult<FollowingSnapshot>> watchOthersFollowingCached(
    String pubkey, {
    bool forceRefresh = false,
  }) {
    return CacheSync.watchOne<FollowingSnapshot>(
      key: _othersFollowingCacheKey(pubkey),
      fetch: () => getOthersFollowing(pubkey),
      fromJson: FollowingSnapshot.fromJson,
      toJson: (s) => s.toJson(),
      ttl: _profileListCacheTtl,
      policy: forceRefresh
          ? CacheFetchPolicy.networkOnly
          : CacheFetchPolicy.cacheFirst,
    );
  }

  /// Get an accurate follower count for any user.
  ///
  /// Fetches from multiple sources (REST + WebSocket + indexer relays),
  /// applies hysteresis stabilization, and persists via Drift.
  Future<int> getFollowerCount(String pubkey) async {
    try {
      final stats = await getFollowerStats(pubkey);
      return stats.followers;
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

  /// Server-side name search within [pubkey]'s follower or following list.
  ///
  /// Returns the subset of that list whose profile name, display name, or
  /// NIP-05 matches [query] — the work a client would otherwise do by pulling
  /// every profile down to the device.
  ///
  /// Returns an **empty set** when the search cannot be answered: no
  /// Funnelcake client, a blank query, an API error, or a deployment whose
  /// follow endpoints do not understand `q` yet. Callers must read that as
  /// "no remote matches", never as "no matches" — the API only indexes kind-3
  /// events seen on the Divine relay, so its answer is a supplement to local
  /// matching, not a replacement for it.
  ///
  /// The unsupported-deployment case is the dangerous one and is why the
  /// response's echoed filter is checked rather than assumed: an older server
  /// ignores the unknown `q` key and answers with the plain first page, which
  /// would otherwise be read as "these hundred people all match".
  ///
  /// Capped at one page: a filter UI does not page its own results, and the
  /// server clamps `limit` to 100 regardless.
  Future<Set<String>> searchFollowList({
    required String pubkey,
    required String query,
    required FollowListKind kind,
  }) async {
    final trimmed = query.trim();
    if (pubkey.isEmpty || trimmed.isEmpty) return const {};
    if (_funnelcakeApiClient == null || !_funnelcakeApiClient.isAvailable) {
      return const {};
    }

    try {
      final page = switch (kind) {
        FollowListKind.followers => await _funnelcakeApiClient.getFollowers(
          pubkey: pubkey,
          query: trimmed,
        ),
        FollowListKind.following => await _funnelcakeApiClient.getFollowing(
          pubkey: pubkey,
          query: trimmed,
        ),
      };
      // Only trust the page when the server says which filter produced it.
      if (page.appliedQuery?.trim().toLowerCase() != trimmed.toLowerCase()) {
        Log.warning(
          'Follow-list search ignored by the API; falling back to local '
          'matching',
          name: 'FollowRepository',
          category: LogCategory.system,
        );
        return const {};
      }
      return page.pubkeys.toSet();
    } on FunnelcakeException catch (e) {
      // Expected while the `q` parameter is rolling out, and on any network
      // blip. The caller still has its local filter.
      Log.warning(
        'Follow-list search unavailable: $e',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
      return const {};
    }
  }

  // === FOLLOWER STATS (count stabilization with hysteresis) ===

  /// A new count must drop below this fraction of the persisted count
  /// before being treated as a genuine decrease.
  /// Drops within this threshold are assumed to be relay query variance.
  static const _hysteresisThreshold = 0.8;

  /// In-memory cache for follower/following counts.
  final Map<String, FollowerStats> _followerStatsCache = {};

  /// Load persisted follower stats from the Drift database.
  ///
  /// Returns null if no persisted data exists for this pubkey.
  Future<({int followers, int following, DateTime timestamp})?>
  _loadPersistedStats(String pubkey) async {
    final dao = _profileStatsDao;
    if (dao == null) return null;

    final row = await dao.getStatsRaw(pubkey);
    if (row == null) return null;

    return (
      followers: row.followerCount ?? 0,
      following: row.followingCount ?? 0,
      timestamp: row.cachedAt,
    );
  }

  /// Persist follower stats to the Drift database.
  Future<void> _persistFollowerStats(String pubkey, FollowerStats stats) async {
    await _profileStatsDao?.upsertStats(
      pubkey: pubkey,
      followerCount: stats.followers,
      followingCount: stats.following,
    );
  }

  /// Apply hysteresis: keep the persisted higher count when the fresh fetch was
  /// incomplete or when a complete fetch only dropped within the threshold.
  ///
  /// Returns the stabilized count.
  int _applyHysteresis({
    required int freshCount,
    required int persistedCount,
    required bool freshComplete,
  }) {
    // Fresh count is higher -> always accept. A partial source can discover
    // new followers, but it cannot prove old followers disappeared.
    if (freshCount >= persistedCount) return freshCount;

    if (!freshComplete) return persistedCount;

    // Fresh count is lower - if the drop is within the threshold, keep
    // the persisted count (assumed relay variance). If it dropped below
    // the threshold, accept the new count as a genuine change.
    final threshold = (persistedCount * _hysteresisThreshold).ceil();
    if (freshCount >= threshold) {
      return persistedCount;
    }

    return freshCount;
  }

  /// Compare fresh network counts against the persistent cache and apply
  /// hysteresis to each counter independently.
  FollowerStats _stabilizeStats(
    String pubkey,
    FollowerStats freshStats, {
    required ({int followers, int following, DateTime timestamp})? persisted,
    required bool followersComplete,
    required bool followingComplete,
  }) {
    if (persisted == null) return freshStats;

    final stableFollowers = _applyHysteresis(
      freshCount: freshStats.followers,
      persistedCount: persisted.followers,
      freshComplete: followersComplete,
    );
    final stableFollowing = _applyHysteresis(
      freshCount: freshStats.following,
      persistedCount: persisted.following,
      freshComplete: followingComplete,
    );

    if (stableFollowers != freshStats.followers ||
        stableFollowing != freshStats.following) {
      Log.info(
        'Hysteresis stabilized stats for $pubkey: '
        'fresh=${freshStats.followers}/${freshStats.following} '
        '-> stable=$stableFollowers/$stableFollowing '
        '(persisted=${persisted.followers}/'
        '${persisted.following}, '
        'complete=$followersComplete/$followingComplete)',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
    }

    return FollowerStats(
      followers: stableFollowers,
      following: stableFollowing,
    );
  }

  /// Get follower and following counts for a specific pubkey.
  ///
  /// Returns in-memory cached data when available, otherwise fetches from
  /// the network and stabilizes the result against a persistent cache using
  /// hysteresis to avoid visible count fluctuations across app restarts.
  Future<FollowerStats> getFollowerStats(String pubkey) async {
    Log.debug(
      'Fetching follower stats for: $pubkey',
      name: 'FollowRepository',
      category: LogCategory.system,
    );

    try {
      // Check in-memory cache first
      final cachedStats = _followerStatsCache[pubkey];
      if (cachedStats != null) {
        Log.debug(
          'Using cached follower stats: $cachedStats',
          name: 'FollowRepository',
          category: LogCategory.system,
        );
        return cachedStats;
      }

      // Fetch from network
      final freshResult = await _fetchFollowerStats(pubkey);
      final freshStats = freshResult.stats;

      // When all sources returned zero, treat it as a network failure
      // and fall back to persisted data rather than showing 0.
      if (!freshResult.isComplete &&
          freshStats.followers == 0 &&
          freshStats.following == 0) {
        final persisted = await _loadPersistedStats(pubkey);
        if (persisted != null &&
            (persisted.followers > 0 || persisted.following > 0)) {
          final fallback = FollowerStats(
            followers: persisted.followers,
            following: persisted.following,
          );
          _followerStatsCache[pubkey] = fallback;
          return fallback;
        }
        return freshStats;
      }

      // Apply hysteresis against the persistent cache so counts don't
      // visibly fluctuate across app restarts due to relay variance.
      final persisted = await _loadPersistedStats(pubkey);
      final stats = _stabilizeStats(
        pubkey,
        freshStats,
        persisted: persisted,
        followersComplete: freshResult.followersComplete,
        followingComplete: freshResult.followingComplete,
      );

      // Cache in memory.
      _followerStatsCache[pubkey] = stats;

      // Only re-persist when the value actually changed. When hysteresis keeps
      // the old persisted count, skipping the write preserves the floor until a
      // complete fetch proves the lower value is real.
      if (persisted == null ||
          stats.followers != persisted.followers ||
          stats.following != persisted.following) {
        await _persistFollowerStats(pubkey, stats);
      }

      Log.debug(
        'Follower stats fetched: $stats',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
      return stats;
    } catch (e) {
      Log.error(
        'Error fetching follower stats: $e',
        name: 'FollowRepository',
        category: LogCategory.system,
      );

      // On network failure, try returning persisted data so the UI
      // shows the last known count instead of zero.
      final persisted = await _loadPersistedStats(pubkey);
      if (persisted != null) {
        final fallback = FollowerStats(
          followers: persisted.followers,
          following: persisted.following,
        );
        _followerStatsCache[pubkey] = fallback;
        return fallback;
      }

      return FollowerStats.zero;
    }
  }

  /// Fetch follower stats from the network.
  Future<_FollowerStatsFetchResult> _fetchFollowerStats(String pubkey) async {
    // Run REST stats, follower pubkey union, and following count in parallel.
    final results = await Future.wait([
      _fetchFollowerStatsViaRest(pubkey),
      _fetchFollowersWithCompleteness(pubkey),
      _fetchFollowingCountViaWebSocket(pubkey),
    ]);

    final restResult = results[0] as _SourceResult<FollowerStats?>;
    final followersResult = results[1] as _SourceResult<List<String>>;
    final followingResult = results[2] as _SourceResult<int>;
    final restStats = restResult.value;

    final followers = max(
      followersResult.value.length,
      restStats?.followers ?? 0,
    );
    final following = max(followingResult.value, restStats?.following ?? 0);

    if (restStats != null &&
        (followers != restStats.followers ||
            following != restStats.following)) {
      Log.info(
        'Follower stats merged: REST=${restStats.followers}/'
        '${restStats.following}, followers=${followersResult.value.length}, '
        'following=${followingResult.value} -> using $followers/$following',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
    }

    return _FollowerStatsFetchResult(
      stats: FollowerStats(followers: followers, following: following),
      followersComplete: restResult.complete && followersResult.complete,
      followingComplete:
          restResult.complete &&
          (restStats != null || followingResult.complete),
    );
  }

  /// Try fetching follower stats via the Funnelcake REST API.
  ///
  /// Returns null if the REST API is unavailable.
  Future<_SourceResult<FollowerStats?>> _fetchFollowerStatsViaRest(
    String pubkey,
  ) async {
    final client = _funnelcakeApiClient;
    if (client == null || !client.isAvailable) {
      return const _SourceResult(value: null, complete: true);
    }

    try {
      final counts = await client.getSocialCounts(pubkey);
      if (counts != null) {
        Log.debug(
          'REST API follower stats: '
          '${counts.followerCount} followers, '
          '${counts.followingCount} following '
          'for $pubkey',
          name: 'FollowRepository',
          category: LogCategory.system,
        );
        return _SourceResult(
          value: FollowerStats(
            followers: counts.followerCount,
            following: counts.followingCount,
          ),
          complete: true,
        );
      }
    } catch (e) {
      Log.warning(
        'REST API follower stats failed, '
        'falling back to WebSocket: $e',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
    }
    return const _SourceResult(value: null, complete: false);
  }

  /// Get following count via WebSocket (Kind 3 contact list).
  Future<_SourceResult<int>> _fetchFollowingCountViaWebSocket(
    String pubkey,
  ) async {
    try {
      final eventStream = _nostrClient.subscribe([
        Filter(authors: [pubkey], kinds: [EventKind.contactList], limit: 1),
      ]);

      final event = await _queryContactList(
        eventStream: eventStream,
        pubkey: pubkey,
        fallbackTimeoutSeconds: 3,
      );

      if (event != null) {
        final count = event.tags
            .where((tag) => tag.isNotEmpty && tag[0] == 'p')
            .length;
        Log.debug(
          'WebSocket following count: $count for $pubkey',
          name: 'FollowRepository',
          category: LogCategory.system,
        );
        return _SourceResult(value: count, complete: true);
      }
    } catch (e) {
      Log.warning(
        'Error fetching following count via WebSocket: $e',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
    }
    return const _SourceResult(value: 0, complete: false);
  }

  /// Timeout for fetching followers from relays
  static const _fetchFollowersTimeout = Duration(seconds: 8);

  /// Fetch followers for a given pubkey.
  ///
  /// Runs REST API, connected relay, and indexer relay queries in parallel
  /// and merges results (union of pubkeys). The REST API (Funnelcake) only
  /// indexes kind 3 events seen on the Divine relay, so follower lists are
  /// often incomplete. Connected relays may timeout. Indexer relays
  /// (relay.damus.io, purplepag.es) maintain broad kind 3 indexes and
  /// provide the most complete follower lists.
  ///
  /// Returns empty list on timeout or failure.
  Future<List<String>> _fetchFollowers(String pubkey) async {
    return (await _fetchFollowersWithCompleteness(pubkey)).value;
  }

  Future<_SourceResult<List<String>>> _fetchFollowersWithCompleteness(
    String pubkey,
  ) async {
    if (pubkey.isEmpty) {
      return const _SourceResult(value: [], complete: true);
    }

    // Each source is best-effort here; callers that need stability inspect the
    // aggregate completeness bit before accepting lower counts.
    final sources = _followerSources(pubkey);
    final results = await Future.wait<_SourceResult<List<String>>>([
      sources[0],
      sources[1],
      sources[2],
    ]);
    final apiFollowers = results[0].value;
    final relayFollowers = results[1].value;
    final indexerFollowers = results[2].value;

    // Merge all sources (union of pubkeys)
    final merged = <String>{
      ...apiFollowers,
      ...relayFollowers,
      ...indexerFollowers,
    };

    Log.info(
      'Followers for $pubkey: '
      'API=${apiFollowers.length}, '
      'relays=${relayFollowers.length}, '
      'indexers=${indexerFollowers.length}, '
      'merged=${merged.length}',
      name: 'FollowRepository',
      category: LogCategory.system,
    );

    return _SourceResult(
      value: merged.toList(),
      complete: results.every((result) => result.complete),
    );
  }

  /// The three follower sources, started in parallel.
  ///
  /// Order is fixed — `[REST API, connected relays, indexer relays]` — because
  /// [_fetchFollowers] indexes into the results to log per-source counts.
  /// Failures are *not* swallowed here; each caller applies its own policy.
  List<Future<_SourceResult<List<String>>>> _followerSources(String pubkey) {
    final client = _funnelcakeApiClient;
    final apiFuture = (client?.isAvailable ?? false)
        ? _fetchFollowersFromApi(client!, pubkey)
        : Future<_SourceResult<List<String>>>.value(
            const _SourceResult(value: [], complete: true),
          );

    return [
      apiFuture,
      _fetchFollowersFromRelays(pubkey),
      _fetchFollowerPubkeysFromIndexers(pubkey),
    ];
  }

  Future<_SourceResult<List<String>>> _fetchFollowersFromApi(
    FunnelcakeApiClient client,
    String pubkey,
  ) async {
    try {
      final page = await client.getFollowers(pubkey: pubkey, limit: 5000);
      return _SourceResult(value: page.pubkeys, complete: true);
    } catch (e, stackTrace) {
      Log.warning(
        'Followers REST API query failed for $pubkey: $e',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
      return _SourceResult(
        value: const [],
        complete: false,
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Streams the current user's followers as each source resolves.
  ///
  /// Every emission is the union of all sources that have answered so far, so
  /// the list only ever grows and a pubkey that has been emitted is always
  /// backed by a live source. Consumers that must not show a stale follower
  /// (the mutual-follow user picker) can therefore render the first emission
  /// immediately instead of waiting for the slowest relay.
  ///
  /// The REST API typically answers in ~150ms while indexer relays take up to
  /// ~2s, so the first emission carries the large majority of the final list.
  ///
  /// A failing source is skipped — a working one still yields a usable list,
  /// and a strict consumer keeps filtering rather than falling back. The
  /// stream only emits an error when it ends up with *no* followers at all
  /// and at least one source failed, which is the case where the caller
  /// genuinely cannot tell "you have no followers" from "the lookup broke".
  Stream<List<String>> streamMyFollowers() =>
      _streamFollowers(_nostrClient.publicKey);

  Stream<List<String>> _streamFollowers(String pubkey) async* {
    if (pubkey.isEmpty) {
      yield const [];
      return;
    }

    final merged = <String>{};
    Object? lastError;
    StackTrace? lastStackTrace;

    await for (final result in Stream<_SourceResult<List<String>>>.fromFutures(
      _followerSources(pubkey),
    )) {
      if (result.error != null) {
        final sourceError = result.error!;
        lastError = sourceError;
        lastStackTrace = result.stackTrace;
        Log.warning(
          'Follower source failed: $sourceError',
          name: 'FollowRepository',
          category: LogCategory.system,
        );
      }
      final before = merged.length;
      merged.addAll(result.value);
      // The union only grows, so an unchanged size means this source added
      // nobody — emitting again would just churn the consumer's UI.
      if (merged.length != before) {
        yield List<String>.unmodifiable(merged);
      }
    }

    if (merged.isEmpty && lastError != null) {
      Error.throwWithStackTrace(lastError, lastStackTrace ?? StackTrace.empty);
    }

    if (pubkey == _nostrClient.publicKey) {
      _cachedMyFollowersPubkeys = merged.toList();
      _hasMyFollowersCache = true;
    }
  }

  /// Query connected relays for kind 3 events mentioning a pubkey.
  Future<_SourceResult<List<String>>> _fetchFollowersFromRelays(
    String pubkey,
  ) async {
    try {
      var complete = true;
      Object? error;
      final events = await _nostrClient
          .queryEvents([
            Filter(kinds: const [EventKind.contactList], p: [pubkey]),
          ])
          .timeout(
            _fetchFollowersTimeout,
            onTimeout: () {
              Log.warning(
                'Followers relay query timed out '
                'for $pubkey',
                name: 'FollowRepository',
                category: LogCategory.system,
              );
              complete = false;
              error = TimeoutException(
                'Followers relay query timed out for $pubkey',
                _fetchFollowersTimeout,
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
      return _SourceResult(
        value: followers,
        complete: complete,
        error: error,
      );
    } on TimeoutException catch (e, s) {
      Log.warning(
        'Followers relay query timed out for $pubkey',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
      return _SourceResult(
        value: const [],
        complete: false,
        error: e,
        stackTrace: s,
      );
    } catch (e, s) {
      Log.warning(
        'Followers relay query failed for $pubkey: $e',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
      return _SourceResult(
        value: const [],
        complete: false,
        error: e,
        stackTrace: s,
      );
    }
  }

  /// Query indexer relays for kind 3 events mentioning a pubkey.
  ///
  /// Returns actual pubkeys (not just a count) so results can be merged
  /// with API and connected relay results.
  Future<_SourceResult<List<String>>> _fetchFollowerPubkeysFromIndexers(
    String pubkey,
  ) async {
    final allFollowers = <String>{};
    if (_indexerRelayUrls.isEmpty) {
      return const _SourceResult(value: [], complete: true);
    }

    final results = await Future.wait(
      _indexerRelayUrls.map(
        (url) => _queryIndexerForFollowerPubkeys(url, pubkey).catchError((
          Object e,
          StackTrace stackTrace,
        ) {
          Log.warning(
            'Indexer $url follower pubkey query failed: $e',
            name: 'FollowRepository',
            category: LogCategory.system,
          );
          return _SourceResult<List<String>>(
            value: const [],
            complete: false,
            error: e,
            stackTrace: stackTrace,
          );
        }),
      ),
    );

    for (final result in results) {
      allFollowers.addAll(result.value);
    }

    Log.debug(
      'Indexer follower pubkeys: '
      '${allFollowers.length} for $pubkey',
      name: 'FollowRepository',
      category: LogCategory.system,
    );

    return _SourceResult(
      value: allFollowers.toList(),
      complete: results.every((result) => result.complete),
    );
  }

  /// Query a single indexer relay for kind 3 events mentioning pubkey.
  /// Returns the list of follower pubkeys.
  Future<_SourceResult<List<String>>> _queryIndexerForFollowerPubkeys(
    String indexerUrl,
    String pubkey,
  ) async {
    final relayStatus = RelayStatus(indexerUrl);
    final relay = _relayFactory(indexerUrl, relayStatus);
    final completer = Completer<_SourceResult<List<String>>>();
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
          completer.complete(
            _SourceResult(value: followerPubkeys.toList(), complete: true),
          );
        }
      }
    };

    try {
      final filter = <String, dynamic>{
        'kinds': <int>[EventKind.contactList],
        '#p': <String>[pubkey],
      };
      relay.pendingMessages.add(<dynamic>['REQ', subscriptionId, filter]);

      final connected = await relay.connect();
      if (!connected) {
        return _SourceResult(
          value: const [],
          complete: false,
          error: StateError('Failed to connect to $indexerUrl'),
        );
      }

      final result = await completer.future.timeout(
        _fetchFollowersTimeout,
        onTimeout: () => _SourceResult(
          value: followerPubkeys.toList(),
          complete: false,
          error: TimeoutException(
            'Indexer $indexerUrl follower query timed out',
            _fetchFollowersTimeout,
          ),
        ),
      );

      try {
        await relay.send(<dynamic>['CLOSE', subscriptionId]);
      } catch (e) {
        Log.warning(
          'Error closing $indexerUrl follower query: $e',
          name: 'FollowRepository',
          category: LogCategory.system,
        );
      }
      return result;
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
    final theirFollowers = await _fetchFollowers(_nostrClient.publicKey);
    return theirFollowers.contains(pubkey) ||
        // They follow us means their contact list mentions our pubkey.
        // _fetchFollowers returns authors of events mentioning us in p-tags,
        // so we check if the target pubkey is among those authors.
        await _checkIfTheyFollowUs(pubkey);
  }

  /// Check if [pubkey] follows the current user by querying their Kind 3 event.
  Future<bool> _checkIfTheyFollowUs(String pubkey) async {
    if (pubkey.isEmpty || _nostrClient.publicKey.isEmpty) {
      return false;
    }

    try {
      final events = await _nostrClient
          .queryEvents([
            Filter(
              authors: [pubkey],
              kinds: const [EventKind.contactList],
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

    // Guard: Skip initialization if user is not authenticated.
    // Don't set _isInitialized = true so we can retry when keys are available.
    if (!_nostrClient.hasKeys) {
      Log.debug(
        'FollowRepository.initialize() skipped '
        '- no keys yet',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
      return;
    }

    try {
      // 1. Load from local storage first for immediate UI display
      await _loadFromLocalStorage();

      // 2. Load from PersonalEventCache if available
      await _loadFromPersonalEventCache();

      // 3. If still empty, try REST API (funnelcake) for fast bootstrap
      if (_followingPubkeys.isEmpty &&
          (_funnelcakeApiClient?.isAvailable ?? false)) {
        await _loadFromRestApi();
      }

      // 4. Always query relays for the authoritative kind 3 event, even when
      // a derived source already answered. LocalStorage, PersonalEventCache
      // and the REST index are all derived from this event and can lag or
      // truncate; because the next follow rebuilds and republishes the whole
      // list, accepting an incomplete one destroys every follow it is
      // missing (#6109).
      if (_nostrClient.hasKeys) {
        await _loadFromRelay();
      }

      // 5. Subscribe to contact list for real-time sync and cross-device
      // updates (fires on future changes, not initial load)
      if (_nostrClient.hasKeys) {
        _subscribeToContactList();
      }

      _isInitialized = true;

      // Guarantee at least one post-seed emission for "no follows" users.
      // When the user follows nobody, _emitFollowingList() never fires
      // because the list stays [] which equals the previous value.
      // With null seed, this force-emit of [] will always be distinct.
      if (_followingPubkeys.isEmpty && !_followingSubject.isClosed) {
        _followingSubject.add(const []);
      }
    } catch (e) {
      Log.error(
        'FollowRepository initialization error: $e',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
    }
  }

  /// Follow a user.
  ///
  /// Throws:
  ///
  /// * [ArgumentError] if [pubkey] is not a 32-byte hex pubkey.
  /// * [Exception] if the user is not authenticated.
  /// * Anything the Kind 3 publish or the local-storage write threw, after
  ///   rolling the optimistic update back.
  Future<void> follow(String pubkey) async {
    if (!_nostrClient.hasKeys) {
      Log.error(
        'Cannot follow - user not authenticated',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
      throw Exception('User not authenticated');
    }

    // Guard: keep invalid keys out of the list rather than letting them fail
    // the Kind 3 publish later, which would block every subsequent follow.
    if (!keyIsValid(pubkey)) {
      Log.error(
        'Cannot follow - invalid pubkey: $pubkey',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
      throw ArgumentError.value(pubkey, 'pubkey', 'Invalid key');
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
    await _invalidateMyFollowingCache();

    // Check if offline and queue if needed
    if (_isOnline != null && !_isOnline() && _queueOfflineAction != null) {
      await _queueOfflineAction(isFollow: true, pubkey: pubkey);

      // Save to local storage for persistence
      await _saveToLocalStorage();

      Log.info(
        'Queued follow action for offline sync: '
        '$pubkey',
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
    await _invalidateMyFollowingCache();

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
    await _invalidateMyFollowingCache();

    // Check if offline and queue if needed
    if (_isOnline != null && !_isOnline() && _queueOfflineAction != null) {
      await _queueOfflineAction(isFollow: false, pubkey: pubkey);

      // Save to local storage for persistence
      await _saveToLocalStorage();

      Log.info(
        'Queued unfollow action for offline sync: '
        '$pubkey',
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
    await _invalidateMyFollowingCache();

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
    // Remove self if accidentally included
    final merged = <String>{
      ..._followingPubkeys,
      ..._sanitizePubkeys(additionalPubkeys, source: 'merged follows'),
    }..remove(_nostrClient.publicKey);

    if (merged.length != _followingPubkeys.length ||
        !merged.every(_followingPubkeys.contains)) {
      _followingPubkeys = merged.toList();
      _emitFollowingList();
      await _invalidateMyFollowingCache();

      // Broadcast the merged list
      await _broadcastContactList();
      await _saveToLocalStorage();

      Log.info(
        'Merged contact lists: now following '
        '${_followingPubkeys.length} users',
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
          final decoded = jsonDecode(cached) as List<dynamic>;
          final cachedPubkeys = decoded.cast<String>();
          final sanitizedPubkeys = _sanitizePubkeys(
            cachedPubkeys,
            source: 'LocalStorage',
          );
          _followingPubkeys = sanitizedPubkeys;
          _emitFollowingList();

          if (sanitizedPubkeys.length != cachedPubkeys.length) {
            await _saveToLocalStorage();
          }

          Log.info(
            'Loaded cached following list: '
            '${_followingPubkeys.length} users',
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
    if (_isCacheInitialized?.call() != true) {
      return;
    }

    try {
      final cachedContactLists = _getCachedEventsByKind!(EventKind.contactList);

      if (cachedContactLists.isNotEmpty) {
        // Use the most recent contact list event
        final latestContactList = cachedContactLists.first;

        final pTags = latestContactList.tags.where(
          (tag) => tag.isNotEmpty && tag[0] == 'p',
        );

        final pubkeys = _sanitizePubkeys(
          pTags
              .map((tag) => tag.length > 1 ? tag[1] : '')
              .where((pubkey) => pubkey.isNotEmpty)
              .cast<String>()
              .toList(),
          source: 'PersonalEventCache',
        );

        if (pubkeys.isNotEmpty) {
          // Guard: only accept the cached event when it is at least as
          // large as the list already loaded from LocalStorage. A stale
          // PersonalEventCache entry with fewer pubkeys should not
          // overwrite a fresher LocalStorage value — the network steps
          // will fetch the authoritative event later.
          if (pubkeys.length < _followingPubkeys.length) {
            Log.debug(
              'PersonalEventCache has fewer follows '
              '(${pubkeys.length}) than LocalStorage '
              '(${_followingPubkeys.length}), skipping',
              name: 'FollowRepository',
              category: LogCategory.system,
            );
            return;
          }

          _followingPubkeys = pubkeys;
          _currentUserContactListEvent = latestContactList;
          _emitFollowingList();

          Log.debug(
            'Loaded following from '
            'PersonalEventCache: '
            '${pubkeys.length} users',
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

  /// Upper bound on REST bootstrap paging, mirroring the ceiling the old
  /// single `limit: 5000` request implied.
  static const _restFollowingMaxPubkeys = 5000;

  /// Load following list from REST API (funnelcake) for fast bootstrap.
  ///
  /// Called only when local cache and PersonalEventCache are both empty
  /// (e.g., first login or after identity change cleanup). This provides
  /// the following list before the WebSocket subscription can deliver it.
  ///
  /// The result is a fast first paint, never the last word: it comes from a
  /// derived index that lags, so [initialize] always follows it with the
  /// authoritative Kind 3 from the relay.
  Future<void> _loadFromRestApi() async {
    try {
      final currentUserPubkey = _nostrClient.publicKey;
      if (currentUserPubkey.isEmpty) return;
      if (_funnelcakeApiClient == null || !_funnelcakeApiClient.isAvailable) {
        return;
      }

      Log.info(
        'Loading following list from REST API '
        '(cache was empty)',
        name: 'FollowRepository',
        category: LogCategory.system,
      );

      // The server clamps `limit` to 100 however much we ask for, so page on
      // `offset` instead of requesting one large batch. Asking for 5000 and
      // silently receiving 100 is what let a truncated list become the base
      // for the next publish (#6109).
      final collected = <String>[];
      while (collected.length < _restFollowingMaxPubkeys) {
        final page = await _funnelcakeApiClient.getFollowing(
          pubkey: currentUserPubkey,
          offset: collected.length,
        );

        if (page.pubkeys.isEmpty) break;
        collected.addAll(page.pubkeys);

        if (!page.hasMore && collected.length >= page.total) break;
      }

      final pubkeys = _sanitizePubkeys(collected, source: 'REST API');

      if (pubkeys.isNotEmpty) {
        _followingPubkeys = pubkeys;
        _emitFollowingList();

        // Persist to SharedPreferences so redirect logic can use it
        await _saveToLocalStorage();

        Log.info(
          'Loaded following from REST API: '
          '${pubkeys.length} users',
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
        'Failed to load following from REST API '
        '(will rely on relay): $e',
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
          'Saved following list to cache: '
          '${_followingPubkeys.length} users',
          name: 'FollowRepository',
          category: LogCategory.system,
        );
      }
      // coverage:ignore-start
    } catch (e) {
      Log.error(
        'Failed to save following list to cache: $e',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
    }
    // coverage:ignore-end
  }

  /// Query relays for the user's kind 3 contact list.
  ///
  /// Uses [_queryContactList] callback (same proven approach as
  /// SocialService) to do a one-shot query with proper EOSE handling.
  /// Called when local cache and REST API are both empty.
  Future<void> _loadFromRelay() async {
    try {
      final currentUserPubkey = _nostrClient.publicKey;
      if (currentUserPubkey.isEmpty) return;

      Log.info(
        'Querying relay for authoritative kind 3 contact list',
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
      // coverage:ignore-start
    } catch (e) {
      Log.warning(
        'Failed to load following from relay: $e',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
    }
    // coverage:ignore-end
  }

  /// Query connected relays for kind 3 contact list.
  Future<Event?> _loadContactListFromConnectedRelays(String pubkey) async {
    try {
      final eventStream = _nostrClient.subscribe([
        Filter(
          authors: [pubkey],
          kinds: const [EventKind.contactList],
          limit: 1,
        ),
      ]);

      final event = await _queryContactList(
        eventStream: eventStream,
        pubkey: pubkey,
        fallbackTimeoutSeconds: 5,
      );
      return event;
    } catch (e) {
      Log.warning(
        'Connected relay contact list query '
        'failed: $e',
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
            'Got contact list from indexer '
            '$indexerUrl',
            name: 'FollowRepository',
            category: LogCategory.system,
          );
          return event;
        }
      } catch (e) {
        Log.warning(
          'Indexer $indexerUrl contact list query '
          'failed: $e',
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
    final relay = _relayFactory(indexerUrl, relayStatus);
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
            'Failed to parse kind 3 event from '
            '$indexerUrl: $e',
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
        'kinds': <int>[EventKind.contactList],
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
        'Error querying $indexerUrl for '
        'contact list: $e',
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
      'Subscribing to contact list for: '
      '$currentUserPubkey',
      name: 'FollowRepository',
      category: LogCategory.system,
    );

    // Use a deterministic subscription ID so we can unsubscribe later
    _contactListSubscriptionId = 'follow_repo_contact_list_$currentUserPubkey';

    final eventStream = _nostrClient.subscribe([
      Filter(
        authors: [currentUserPubkey],
        kinds: const [EventKind.contactList],
        limit: 1,
      ),
    ], subscriptionId: _contactListSubscriptionId);

    _contactListSubscription = eventStream.listen(
      (event) {
        // Only process Kind 3 events from the current user
        if (event.kind == EventKind.contactList &&
            event.pubkey == currentUserPubkey) {
          _processContactListEvent(event);
        }
      },
      onError: (Object error) {
        Log.error(
          'Real-time contact list subscription '
          'error: $error',
          name: 'FollowRepository',
          category: LogCategory.system,
        );
      },
    );
  }

  /// Broadcast updated contact list to network (Kind 3 event)
  Future<void> _broadcastContactList() async {
    // Last line of defence: [executeFollowAction] appends without validating,
    // and an invalid pubkey here makes Contact's constructor throw and abort
    // the publish, blocking every follow and unfollow until the entry is gone.
    // Emit so observers do not keep a dropped entry the getter no longer has.
    _followingPubkeys = _sanitizePubkeys(
      _followingPubkeys,
      source: 'in-memory following list',
    );
    _emitFollowingList();

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
    _cacheUserEvent?.call(event);

    _currentUserContactListEvent = event;

    Log.debug(
      'Broadcasted contact list: ${event.id}',
      name: 'FollowRepository',
      category: LogCategory.system,
    );
  }

  // ── Catastrophic-reduction merge guard ──────────────────────────────
  //
  // Protects against buggy external Nostr clients that publish a Kind 3
  // event without first fetching the existing contact list, effectively
  // overwriting hundreds of follows with a single entry.
  //
  // The guard uses a two-condition AND gate:
  //   1. Drastic reduction — the remote list lost more than
  //      [_mergeMaxLossFraction] (50 %) of the local list.
  //   2. New-pubkey fingerprint — the remote list contains at least one
  //      pubkey absent from the local list (the hallmark of a "follow one
  //      user, replace the whole list" bug).
  //
  // When BOTH conditions are true the lists are union-merged and the
  // corrected list is re-broadcast so relays converge on the right state.
  //
  // A legitimate mass-unfollow produces a strict *subset* of the local
  // list, so condition 2 filters it out and the replacement is accepted.
  //
  // The guard is only active when the local list has at least
  // [_mergeMinFollows] entries. With only 1 follow the list can only
  // drop to zero, which is either a legitimate unfollow or a fresh
  // account state — no merge is needed.
  //
  // Edge cases:
  //   • Exactly 50 % loss (equals the ceil threshold) → accepted, not
  //     merged, because the loss is within tolerance.
  //   • Remote list is entirely new pubkeys but same size → accepted,
  //     because condition 1 fails (no size reduction).
  //   • Re-broadcast failure after merge → local list is already
  //     correct; relays will converge on the next publish.
  // ───────────────────────────────────────────────────────────────────

  /// Minimum local-list size for the merge guard to activate. A user with
  /// only 1 follow cannot trigger a "catastrophic reduction" — the list
  /// can only go to zero.
  static const _mergeMinFollows = 2;

  /// Maximum fraction of the local list that may be removed before the
  /// reduction is treated as suspicious. 0.5 → more than half lost
  /// triggers a merge instead of a replace.
  static const _mergeMaxLossFraction = 0.5;

  /// Process a NIP-02 contact list event (Kind 3)
  void _processContactListEvent(Event event) {
    // Only update if this is newer than our current contact list event
    if (_currentUserContactListEvent == null ||
        event.createdAt > _currentUserContactListEvent!.createdAt) {
      _currentUserContactListEvent = event;

      // Extract followed pubkeys from 'p' tags
      final taggedPubkeys = <String>[];
      for (final tag in event.tags) {
        if (tag.isNotEmpty && tag[0] == 'p' && tag.length > 1) {
          taggedPubkeys.add(tag[1]);
        }
      }
      final followedPubkeys = _sanitizePubkeys(
        taggedPubkeys,
        source: 'network Kind 3 event ${event.id}',
      );

      // Guard: detect catastrophic list reduction from buggy external clients.
      // A common Nostr footgun is publishing a Kind 3 event without first
      // fetching the existing contact list, which overwrites the full list
      // with only the newly followed user. We detect this by checking for
      // two conditions simultaneously:
      //   1. The remote list is drastically smaller than the local list.
      //   2. The remote list contains pubkeys NOT already in the local list
      //      (the "only-new-follow" fingerprint of buggy clients).
      // A legitimate mass-unfollow produces a strict subset of the local
      // list, so condition 2 filters it out.
      final localSet = _followingPubkeys.toSet();
      final isDrasticReduction =
          _followingPubkeys.length >= _mergeMinFollows &&
          followedPubkeys.length <
              (_followingPubkeys.length * _mergeMaxLossFraction).ceil();
      final hasNewPubkeys = followedPubkeys.any((pk) => !localSet.contains(pk));

      if (isDrasticReduction && hasNewPubkeys) {
        final merged = <String>{..._followingPubkeys, ...followedPubkeys};

        Log.warning(
          'Catastrophic contact list reduction '
          'detected '
          '(${_followingPubkeys.length} → '
          '${followedPubkeys.length}). '
          'Merging to ${merged.length} follows '
          'instead of replacing.',
          name: 'FollowRepository',
          category: LogCategory.system,
        );

        _followingPubkeys = merged.toList();
        _emitFollowingList();
        unawaited(_saveToLocalStorage());
        unawaited(_invalidateMyFollowingCache());

        // Re-broadcast the merged list so relays have the correct state.
        unawaited(
          _broadcastContactList().catchError((Object e) {
            Log.error(
              'Failed to broadcast merged '
              'contact list: $e',
              name: 'FollowRepository',
              category: LogCategory.system,
            );
          }),
        );
        return;
      }

      _followingPubkeys = followedPubkeys;
      _emitFollowingList();

      Log.info(
        'Updated follow list from network: '
        '${_followingPubkeys.length} following',
        name: 'FollowRepository',
        category: LogCategory.system,
      );

      unawaited(_saveToLocalStorage());
      unawaited(_invalidateMyFollowingCache());
    }
  }
}
