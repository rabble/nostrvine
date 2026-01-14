import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:db_client/db_client.dart' hide Filter;
import 'package:meta/meta.dart';
import 'package:nostr_client/src/models/models.dart';
import 'package:nostr_client/src/relay_manager.dart';
import 'package:nostr_gateway/nostr_gateway.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

/// {@template nostr_client}
/// Abstraction layer for Nostr communication
///
/// This client wraps nostr_sdk and provides:
/// - Subscription deduplication (prevents duplicate subscriptions)
/// - Gateway integration for cached queries
/// - Clean API for repositories to use
/// - Proper resource management
/// - Relay management via RelayManager
/// {@endtemplate}
class NostrClient {
  /// {@macro nostr_client}
  ///
  /// Creates a new NostrClient instance with the given configuration.
  /// The RelayManager is created internally using the Nostr instance's
  /// RelayPool to ensure they share the same connection pool.
  ///
  /// Optional [dbClient] enables local caching of events for faster
  /// queries and auto-caching of subscription events.
  factory NostrClient({
    required NostrClientConfig config,
    required RelayManagerConfig relayManagerConfig,
    GatewayClient? gatewayClient,
    AppDbClient? dbClient,
  }) {
    final nostr = _createNostr(config);
    final relayManager = RelayManager(
      config: relayManagerConfig,
      relayPool: nostr.relayPool,
    );
    return NostrClient._internal(
      nostr: nostr,
      relayManager: relayManager,
      gatewayClient: gatewayClient,
      dbClient: dbClient,
    );
  }

  /// Internal constructor used by factory and testing constructors
  NostrClient._internal({
    required Nostr nostr,
    required RelayManager relayManager,
    GatewayClient? gatewayClient,
    AppDbClient? dbClient,
  }) : _nostr = nostr,
       _relayManager = relayManager,
       _gatewayClient = gatewayClient,
       _dbClient = dbClient;

  /// Creates a NostrClient with injected dependencies for testing
  @visibleForTesting
  NostrClient.forTesting({
    required Nostr nostr,
    required RelayManager relayManager,
    GatewayClient? gatewayClient,
    AppDbClient? dbClient,
  }) : _nostr = nostr,
       _relayManager = relayManager,
       _gatewayClient = gatewayClient,
       _dbClient = dbClient;

  static Nostr _createNostr(NostrClientConfig config) {
    RelayBase tempRelayGenerator(String url) => RelayBase(
      url,
      RelayStatus(url),
      channelFactory: config.webSocketChannelFactory,
    );
    return Nostr(
      config.signer,
      config.publicKey,
      config.eventFilters,
      tempRelayGenerator,
      onNotice: config.onNotice,
      channelFactory: config.webSocketChannelFactory,
    );
  }

  final Nostr _nostr;
  final GatewayClient? _gatewayClient;
  final RelayManager _relayManager;
  final AppDbClient? _dbClient;

  /// Convenience getter for the NostrEventsDao
  NostrEventsDao? get _nostrEventsDao => _dbClient?.database.nostrEventsDao;

  /// Helper to cache an event with default expiry.
  ///
  /// Fire-and-forget pattern - errors are silently ignored since caching
  /// failures should not affect the send operation's success.
  void _cacheEvent(Event event) {
    try {
      unawaited(_nostrEventsDao?.upsertEvent(event));
    } on Object {
      // Ignore cache errors
    }
  }

  /// Checks if an event kind supports safe optimistic caching.
  ///
  /// Returns `false` for:
  /// - Deletion events (Kind 5): They remove data, not add
  /// - Replaceable events (Kind 0, 3, 10000-19999): Upsert deletes old event
  /// - Parameterized replaceable (Kind 30000-39999): Same issue
  ///
  /// For these kinds, caching on success is safer to avoid data loss on
  /// rollback.
  bool _canOptimisticallyCache(int kind) {
    if (kind == EventKind.eventDeletion) return false;
    if (EventKind.isReplaceable(kind)) return false;
    if (EventKind.isParameterizedReplaceable(kind)) return false;
    return true;
  }

  /// Removes an optimistically cached event on send failure.
  ///
  /// Fire-and-forget pattern - errors are silently ignored since rollback
  /// failures should not affect the operation's result.
  void _rollbackCachedEvent(String eventId) {
    try {
      unawaited(_nostrEventsDao?.deleteEventsByIds([eventId]));
    } on Object {
      // Ignore rollback errors
    }
  }

  /// Handles a NIP-09 deletion event (Kind 5) by removing target events
  /// from the local database.
  ///
  /// Extracts event IDs from 'e' tags and deletes them from both the events
  /// table and video_metrics table.
  ///
  /// Fire-and-forget pattern - errors are silently ignored.
  void _handleDeletionEvent(Event deletionEvent) {
    if (deletionEvent.kind != EventKind.eventDeletion) return;

    // Extract target event IDs from 'e' tags
    final targetEventIds = <String>[];
    for (final dynamic tag in deletionEvent.tags) {
      if (tag is List && tag.isNotEmpty && tag[0] == 'e' && tag.length > 1) {
        final eventId = tag[1];
        if (eventId is String) {
          targetEventIds.add(eventId);
        }
      }
    }

    if (targetEventIds.isEmpty) return;

    // Delete target events from the database (fire-and-forget)
    try {
      unawaited(_nostrEventsDao?.deleteEventsByIds(targetEventIds));
    } on Object {
      // Ignore deletion errors
    }
  }

  /// Tracks whether dispose() has been called
  bool _isDisposed = false;

  /// Public key of the client
  String get publicKey => _nostr.publicKey;

  /// Whether the client has been initialized
  ///
  /// Returns true if the relay manager is initialized
  bool get isInitialized => _relayManager.isInitialized;

  /// Whether the client has been disposed
  ///
  /// After disposal, the client should not be used
  bool get isDisposed => _isDisposed;

  /// Whether the client has keys configured
  ///
  /// Returns true if the public key is not empty
  bool get hasKeys => publicKey.isNotEmpty;

  /// Initializes the client by connecting to configured relays
  ///
  /// This must be called before using the client to ensure relay connections
  /// are established. Can be called multiple times safely.
  Future<void> initialize() async {
    await _relayManager.initialize();
  }

  /// Map of subscription IDs to their filter hashes (for deduplication)
  final Map<String, String> _subscriptionFilters = {};

  /// Map of active subscriptions
  final Map<String, StreamController<Event>> _subscriptionStreams = {};

  /// Publishes an event to relays
  ///
  /// Delegates to nostr_sdk for relay management and broadcasting.
  ///
  /// **Caching strategy:**
  /// - Regular events: Optimistic cache before send, rollback on failure
  /// - Replaceable events (0, 3, 10000-39999): Cache on success only
  ///   (upsert deletes old record, so rollback would lose data)
  /// - Deletion events (Kind 5): Removes target events from cache on success
  ///
  /// Returns the sent event if successful, or `null` if failed.
  Future<Event?> publishEvent(
    Event event, {
    List<String>? targetRelays,
  }) async {
    final useOptimisticCache = _canOptimisticallyCache(event.kind);

    // Optimistic cache for regular events only
    if (useOptimisticCache) {
      _cacheEvent(event);
    }

    // Checks health of relays, attempts reconnection if none connected,
    // and exits if reconnect is unsuccessful
    if (_relayManager.connectedRelays.isEmpty) {
      await retryDisconnectedRelays();
      if (_relayManager.connectedRelays.isEmpty) {
        // Rollback optimistic cache on failure
        if (useOptimisticCache) {
          _rollbackCachedEvent(event.id);
        }
        return null;
      }
    }

    final sentEvent = await _nostr.sendEvent(
      event,
      targetRelays: targetRelays,
    );

    if (sentEvent == null) {
      // Rollback optimistic cache on failure
      if (useOptimisticCache) {
        _rollbackCachedEvent(event.id);
      }
      return null;
    }

    // Handle successful send
    if (sentEvent.kind == EventKind.eventDeletion) {
      // NIP-09: Remove target events from cache
      _handleDeletionEvent(sentEvent);
    } else if (!useOptimisticCache) {
      // Cache replaceable events on success (not optimistically)
      _cacheEvent(sentEvent);
    }

    return sentEvent;
  }

  /// Queries events with given filters
  ///
  /// Query flow: **Cache + (Gateway → WebSocket)**
  ///
  /// If [useCache] is `true` and cache is available, checks local cache first.
  /// If [useGateway] is `true` and gateway is enabled, attempts to use
  /// the REST gateway for cached responses (empty responses are valid).
  /// Falls back to WebSocket query only if cache misses and gateway fails.
  ///
  /// Results from gateway/websocket are cached for future queries.
  Future<List<Event>> queryEvents(
    List<Filter> filters, {
    String? subscriptionId,
    List<String>? tempRelays,
    List<int> relayTypes = RelayType.all,
    bool sendAfterAuth = false,
    bool useGateway = true,
    bool useCache = true,
  }) async {
    final cacheResults = <Event>[];

    // 1. Get cache results (don't return early - we'll merge with network)
    final dao = _nostrEventsDao;
    if (useCache && dao != null && filters.length == 1) {
      cacheResults.addAll(await dao.getEventsByFilter(filters.first));
    }

    // 2. Try gateway (fast REST)
    if (useGateway && filters.length == 1) {
      final gatewayClient = _gatewayClient;
      if (gatewayClient != null) {
        final response = await _tryGateway(
          () => gatewayClient.query(filters.first),
        );
        // Accept gateway response even if empty - null means gateway failed
        if (response != null) {
          // Cache gateway results if any (fire-and-forget)
          if (response.hasEvents) {
            try {
              unawaited(_nostrEventsDao?.upsertEventsBatch(response.events));
            } on Object {
              // Ignore cache errors
            }
          }
          // Merge cache + gateway and return (respecting original limit)
          return _mergeEvents(
            cacheResults,
            response.events,
            limit: filters.first.limit,
          );
        }
      }
    }

    // 3. Fall back to WebSocket query
    final filtersJson = filters.map((f) => f.toJson()).toList();
    final websocketEvents = await _nostr.queryEvents(
      filtersJson,
      id: subscriptionId,
      tempRelays: tempRelays,
      relayTypes: relayTypes,
      sendAfterAuth: sendAfterAuth,
    );

    // Cache websocket results (fire-and-forget)
    if (websocketEvents.isNotEmpty) {
      try {
        unawaited(_nostrEventsDao?.upsertEventsBatch(websocketEvents));
      } on Object {
        // Ignore cache errors
      }
    }

    // Merge cache + websocket and return (respecting original limit)
    // Use first filter's limit since cache only works with single filters
    final limit = filters.isNotEmpty ? filters.first.limit : null;
    return _mergeEvents(cacheResults, websocketEvents, limit: limit);
  }

  /// Counts events matching the given filters using NIP-45.
  ///
  /// This is more efficient than [queryEvents] when you only need the count,
  /// not the actual events. Uses NIP-45 COUNT requests to relays.
  ///
  /// Falls back to client-side counting if relay doesn't support NIP-45.
  ///
  /// Example - Count followers:
  /// ```dart
  /// final result = await client.countEvents([
  ///   Filter(kinds: [3], p: [pubkey]),
  /// ]);
  /// print('Follower count: ${result.count}');
  /// ```
  ///
  /// Example - Count reactions on an event:
  /// ```dart
  /// final result = await client.countEvents([
  ///   Filter(kinds: [7], e: [eventId]),
  /// ]);
  /// print('Reaction count: ${result.count}');
  /// ```
  Future<CountResult> countEvents(
    List<Filter> filters, {
    String? subscriptionId,
    List<String>? tempRelays,
    List<int> relayTypes = RelayType.all,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final filtersJson = filters.map((f) => f.toJson()).toList();

    try {
      // Try NIP-45 COUNT first
      final response = await _nostr.countEvents(
        filtersJson,
        id: subscriptionId,
        tempRelays: tempRelays,
        relayTypes: relayTypes,
        timeout: timeout,
      );

      return CountResult(
        count: response.count,
        approximate: response.approximate,
      );
    } on CountNotSupportedException {
      // Fall back to fetching events and counting client-side
      final events = await queryEvents(
        filters,
        tempRelays: tempRelays,
        relayTypes: relayTypes,
      );

      return CountResult(
        count: events.length,
        source: CountSource.clientSide,
      );
    }
  }

  /// Fetches a single event by ID
  ///
  /// Query flow: **Cache → Gateway → WebSocket**
  ///
  /// If [useCache] is `true` and cache is available, checks local cache first.
  /// If [useGateway] is `true` and gateway is enabled, attempts to use
  /// the REST gateway for faster cached responses.
  /// Falls back to WebSocket query if both are unavailable.
  ///
  /// Results from gateway/websocket are cached for future queries.
  Future<Event?> fetchEventById(
    String eventId, {
    String? relayUrl,
    bool useGateway = true,
    bool useCache = true,
  }) async {
    // 1. Check cache first
    final dao = _nostrEventsDao;
    if (useCache && dao != null) {
      final cached = await dao.getEventById(eventId);
      if (cached != null) {
        return cached;
      }
    }

    // 2. Try gateway
    final targetRelays = relayUrl != null ? [relayUrl] : null;
    if (useGateway) {
      final gatewayClient = _gatewayClient;
      if (gatewayClient != null) {
        final event = await _tryGateway(
          () => gatewayClient.getEvent(eventId),
        );
        if (event != null) {
          // Cache gateway result (fire-and-forget)
          try {
            unawaited(_nostrEventsDao?.upsertEvent(event));
          } on Object {
            // Ignore cache errors
          }
          return event;
        }
      }
    }

    // 3. Fall back to WebSocket query
    final filters = [
      Filter(ids: [eventId], limit: 1),
    ];
    final events = await queryEvents(
      filters,
      useGateway: false,
      useCache: false, // Already checked cache above
      tempRelays: targetRelays,
    );
    if (events.isNotEmpty) {
      // Cache websocket result (fire-and-forget)
      try {
        unawaited(_nostrEventsDao?.upsertEvent(events.first));
      } on Object {
        // Ignore cache errors
      }

      return events.first;
    }
    return null;
  }

  /// Fetches a profile (kind 0) by pubkey
  ///
  /// Query flow: **Cache → Gateway → WebSocket**
  ///
  /// If [useCache] is `true` and cache is available, checks local cache first.
  /// If [useGateway] is `true` and gateway is enabled, attempts to use
  /// the REST gateway for faster cached responses.
  /// Falls back to WebSocket query if both are unavailable.
  ///
  /// Results from gateway/websocket are cached for future queries.
  Future<Event?> fetchProfile(
    String pubkey, {
    bool useGateway = true,
    bool useCache = true,
  }) async {
    // 1. Check cache first
    final dao = _nostrEventsDao;
    if (useCache && dao != null) {
      final cached = await dao.getProfileByPubkey(pubkey);
      if (cached != null) {
        return cached;
      }
    }

    // 2. Try gateway
    if (useGateway) {
      final gatewayClient = _gatewayClient;
      if (gatewayClient != null) {
        final profile = await _tryGateway(
          () => gatewayClient.getProfile(pubkey),
        );
        if (profile != null) {
          // Cache gateway result (fire-and-forget)
          try {
            unawaited(_nostrEventsDao?.upsertEvent(profile));
          } on Object {
            // Ignore cache errors
          }
          return profile;
        }
      }
    }

    // 3. Fall back to WebSocket query
    final filters = [
      Filter(authors: [pubkey], kinds: [EventKind.metadata], limit: 1),
    ];
    final events = await queryEvents(
      filters,
      useGateway: false,
      useCache: false, // Already checked cache above
    );
    if (events.isNotEmpty) {
      // Cache websocket result (fire-and-forget)
      try {
        unawaited(_nostrEventsDao?.upsertEvent(events.first));
      } on Object {
        // Ignore cache errors
      }
      return events.first;
    }
    return null;
  }

  /// Subscribes to events matching the given filters
  ///
  /// Returns a stream of events. Automatically deduplicates subscriptions
  /// with identical filters to prevent duplicate WebSocket subscriptions.
  Stream<Event> subscribe(
    List<Filter> filters, {
    String? subscriptionId,
    List<String>? tempRelays,
    List<String>? targetRelays,
    List<int> relayTypes = RelayType.all,
    bool sendAfterAuth = false,
    void Function()? onEose,
  }) {
    // Generate deterministic subscription ID based on filter content
    final filterHash = _generateFilterHash(filters);
    final id = subscriptionId ?? 'sub_$filterHash';

    // Check if we already have this exact subscription
    if (_subscriptionStreams.containsKey(id) &&
        !_subscriptionStreams[id]!.isClosed) {
      return _subscriptionStreams[id]!.stream;
    }

    // Create new stream controller
    final controller = StreamController<Event>.broadcast();
    _subscriptionStreams[id] = controller;
    _subscriptionFilters[id] = filterHash;

    // Convert filters to JSON format expected by nostr_sdk
    final filtersJson = filters.map((f) => f.toJson()).toList();

    // Subscribe using nostr_sdk
    final actualId = _nostr.subscribe(
      filtersJson,
      (event) {
        // Handle NIP-09 deletion events by removing target events from DB
        if (event.kind == EventKind.eventDeletion) {
          _handleDeletionEvent(event);
        } else {
          // Auto-cache non-deletion events (fire-and-forget)
          try {
            unawaited(_nostrEventsDao?.upsertEvent(event));
          } on Object {
            // Ignore sync cache errors
          }
        }

        if (!controller.isClosed) {
          controller.add(event);
        }
      },
      id: id,
      tempRelays: tempRelays,
      targetRelays: targetRelays,
      relayTypes: relayTypes,
      sendAfterAuth: sendAfterAuth,
      onEose: onEose,
    );

    // If nostr_sdk generated a different ID, update our mapping
    if (actualId != id && actualId.isNotEmpty) {
      _subscriptionStreams.remove(id);
      _subscriptionStreams[actualId] = controller;
      _subscriptionFilters[actualId] = filterHash;
    }

    return controller.stream;
  }

  /// Unsubscribes from a subscription
  Future<void> unsubscribe(String subscriptionId) async {
    _nostr.unsubscribe(subscriptionId);
    final controller = _subscriptionStreams.remove(subscriptionId);
    if (controller != null && !controller.isClosed) {
      await controller.close();
    }
    _subscriptionFilters.remove(subscriptionId);
  }

  /// Closes all subscriptions
  ///
  /// Properly awaits each subscription's stream controller closure to ensure
  /// all resources are cleaned up before returning.
  Future<void> closeAllSubscriptions() async {
    final subscriptionIds = _subscriptionStreams.keys.toList();
    for (final id in subscriptionIds) {
      await unsubscribe(id);
    }
  }

  /// Adds a relay connection
  ///
  /// Delegates to RelayManager for persistence and status tracking.
  Future<bool> addRelay(String relayUrl) async {
    return _relayManager.addRelay(relayUrl);
  }

  /// Removes a relay connection
  ///
  /// Delegates to RelayManager.
  Future<bool> removeRelay(String relayUrl) async {
    return _relayManager.removeRelay(relayUrl);
  }

  /// Gets list of configured relay URLs
  List<String> get configuredRelays => _relayManager.configuredRelays;

  /// Gets list of connected relay URLs
  List<String> get connectedRelays => _relayManager.connectedRelays;

  /// Gets count of connected relays
  int get connectedRelayCount => _relayManager.connectedRelayCount;

  /// Gets count of configured relays
  int get configuredRelayCount => _relayManager.configuredRelayCount;

  /// Gets relay statuses
  Map<String, RelayConnectionStatus> get relayStatuses =>
      _relayManager.currentStatuses;

  /// Stream of relay status updates
  Stream<Map<String, RelayConnectionStatus>> get relayStatusStream =>
      _relayManager.statusStream;

  /// Primary relay for client operations
  ///
  /// Returns the first connected relay, or first configured relay,
  /// or the default relay URL if none are configured.
  String get primaryRelay {
    if (connectedRelays.isNotEmpty) {
      return connectedRelays.first;
    }
    if (configuredRelays.isNotEmpty) {
      return configuredRelays.first;
    }
    return 'wss://relay.divine.video';
  }

  /// Gets relay statistics for diagnostics
  ///
  /// Returns a map containing relay connection stats.
  Future<Map<String, dynamic>?> getRelayStats() async {
    return {
      'connectedRelays': connectedRelayCount,
      'configuredRelays': configuredRelayCount,
      'relays': configuredRelays,
    };
  }

  /// Retry connecting to all disconnected relays
  Future<void> retryDisconnectedRelays() async {
    await _relayManager.retryDisconnectedRelays();
  }

  /// Force reconnect all relays (disconnect first, then reconnect)
  ///
  /// Use this when WebSocket connections may have been silently dropped
  /// (e.g., after app backgrounding).
  Future<void> forceReconnectAll() async {
    await _relayManager.forceReconnectAll();
  }

  /// Gets relay connection status as a simple map.
  ///
  /// Returns `Map<String, bool>` where the value indicates if
  /// the relay is connected.
  Map<String, bool> getRelayStatus() {
    final statuses = relayStatuses;
    final result = <String, bool>{};
    for (final entry in statuses.entries) {
      result[entry.key] =
          entry.value.state == RelayState.connected ||
          entry.value.state == RelayState.authenticated;
    }
    return result;
  }

  /// Sends a like reaction to an event
  ///
  /// Successfully sent events are cached locally with 1-day expiry.
  Future<Event?> sendLike(
    String eventId, {
    String? content,
    List<String>? tempRelays,
    List<String>? targetRelays,
  }) async {
    final likeEvent = await _nostr.sendLike(
      eventId,
      content: content,
      tempRelays: tempRelays,
      targetRelays: targetRelays,
    );
    if (likeEvent != null) {
      _cacheEvent(likeEvent);
    }
    return likeEvent;
  }

  /// Sends a user profile (Kind 0 metadata event).
  ///
  /// Successfully sent events are cached locally with 1-day expiry.
  Future<Event?> sendProfile({
    required Map<String, dynamic> profileContent,
  }) async {
    final profileEvent = await _nostr.sendProfile(
      content: jsonEncode(profileContent),
    );

    if (profileEvent != null) {
      _cacheEvent(profileEvent);
    }

    return profileEvent;
  }

  /// Sends a repost
  ///
  /// Successfully sent events are cached locally with 1-day expiry.
  Future<Event?> sendRepost(
    String eventId, {
    String? relayAddr,
    String content = '',
    List<String>? tempRelays,
    List<String>? targetRelays,
  }) async {
    final repostEvent = await _nostr.sendRepost(
      eventId,
      relayAddr: relayAddr,
      content: content,
      tempRelays: tempRelays,
      targetRelays: targetRelays,
    );
    if (repostEvent != null) {
      _cacheEvent(repostEvent);
    }
    return repostEvent;
  }

  /// Deletes an event
  ///
  /// Sends a NIP-09 deletion event (Kind 5) and removes the target event
  /// from the local database cache.
  Future<Event?> deleteEvent(
    String eventId, {
    List<String>? tempRelays,
    List<String>? targetRelays,
  }) async {
    final deletionEvent = await _nostr.deleteEvent(
      eventId,
      tempRelays: tempRelays,
      targetRelays: targetRelays,
    );
    if (deletionEvent != null) {
      // Delete target event from local database
      _handleDeletionEvent(deletionEvent);
    }
    return deletionEvent;
  }

  /// Deletes multiple events
  ///
  /// Sends a NIP-09 deletion event (Kind 5) and removes the target events
  /// from the local database cache.
  Future<Event?> deleteEvents(
    List<String> eventIds, {
    List<String>? tempRelays,
    List<String>? targetRelays,
  }) async {
    final deletionEvent = await _nostr.deleteEvents(
      eventIds,
      tempRelays: tempRelays,
      targetRelays: targetRelays,
    );
    if (deletionEvent != null) {
      // Delete target events from local database
      _handleDeletionEvent(deletionEvent);
    }
    return deletionEvent;
  }

  /// Sends a contact list
  ///
  /// Successfully sent events are cached locally with 1-day expiry.
  Future<Event?> sendContactList(
    ContactList contacts,
    String content, {
    List<String>? tempRelays,
    List<String>? targetRelays,
  }) async {
    final contactListEvent = await _nostr.sendContactList(
      contacts,
      content,
      tempRelays: tempRelays,
      targetRelays: targetRelays,
    );
    if (contactListEvent != null) {
      _cacheEvent(contactListEvent);
    }
    return contactListEvent;
  }

  /// Searches for video events using NIP-50 search
  ///
  /// Returns a stream of video events (kind 34236) matching the search query.
  /// Uses NIP-50 search parameter for full-text search on compatible relays.
  Stream<Event> searchVideos(
    String query, {
    List<String>? authors,
    DateTime? since,
    DateTime? until,
    int? limit,
  }) {
    final filter = Filter(
      kinds: const [34236], // Video events only (no reposts for search)
      authors: authors,
      since: since != null ? since.millisecondsSinceEpoch ~/ 1000 : null,
      until: until != null ? until.millisecondsSinceEpoch ~/ 1000 : null,
      limit: limit ?? 100,
      search: query,
    );

    return subscribe([filter]);
  }

  /// Searches for user profiles using NIP-50 search
  ///
  /// Returns a stream of profile events (kind 0) matching the search query.
  /// Uses NIP-50 search parameter for full-text search on compatible relays.
  Stream<Event> searchUsers(
    String query, {
    int? limit,
  }) {
    final filter = Filter(
      kinds: const [EventKind.metadata],
      limit: limit ?? 100,
      search: query,
    );

    return subscribe([filter]);
  }

  /// Disposes the client and cleans up resources
  ///
  /// Closes all subscriptions, disconnects from relays, and cleans up
  /// internal state. After calling this, the client should not be used.
  Future<void> dispose() async {
    await closeAllSubscriptions();
    await _relayManager.dispose();
    _nostr.close();
    _subscriptionFilters.clear();
    _isDisposed = true;
  }

  /// Generates a deterministic hash for filters
  /// to prevent duplicate subscriptions
  String _generateFilterHash(List<Filter> filters) {
    final json = filters.map((f) => f.toJson()).toList();
    final jsonString = jsonEncode(json);
    final bytes = utf8.encode(jsonString);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16);
  }

  /// Merges cached and network events, deduplicating by event ID.
  /// Network events take precedence (considered fresher).
  ///
  /// If [limit] is provided, returns at most [limit] events sorted by
  /// `created_at` descending (most recent first). This ensures the original
  /// filter's limit is respected even when combining multiple sources.
  List<Event> _mergeEvents(
    List<Event> cached,
    List<Event> network, {
    int? limit,
  }) {
    if (cached.isEmpty && network.isEmpty) return [];
    if (cached.isEmpty) {
      return limit != null && network.length > limit
          ? (network..sort((a, b) => b.createdAt - a.createdAt))
                .take(limit)
                .toList()
          : network;
    }
    if (network.isEmpty) {
      return limit != null && cached.length > limit
          ? (cached..sort((a, b) => b.createdAt - a.createdAt))
                .take(limit)
                .toList()
          : cached;
    }

    final eventMap = <String, Event>{};
    // Add cached events first
    for (final event in cached) {
      eventMap[event.id] = event;
    }
    // Network events overwrite cached (fresher data)
    for (final event in network) {
      eventMap[event.id] = event;
    }

    final merged = eventMap.values.toList();

    // Apply limit if specified, returning the most recent events
    if (limit != null && merged.length > limit) {
      merged.sort((a, b) => b.createdAt - a.createdAt);
      return merged.take(limit).toList();
    }

    return merged;
  }

  /// Attempts to execute a gateway operation
  /// (e.g. query events, fetch events, fetch profiles),
  /// falling back gracefully on failure
  ///
  /// Returns the result if successful, or `null` if gateway is unavailable
  /// or the operation fails. Only falls back for recoverable errors (network,
  /// timeouts, server errors). Client errors (4xx) are not retried.
  Future<T?> _tryGateway<T>(
    Future<T> Function() operation, {
    bool shouldFallback = true,
  }) async {
    if (_gatewayClient == null) {
      return null;
    }

    try {
      return await operation();
    } on Exception catch (_) {
      return null;
    }
  }
}
