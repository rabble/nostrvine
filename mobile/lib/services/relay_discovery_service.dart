// ABOUTME: Service for discovering user relays via NIP-65 (kind 10002)
// ABOUTME: Queries indexer relays via direct WebSocket to find relay lists
// ABOUTME: Caches discovered relay lists by npub for quick access

import 'dart:async';
import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/utils/relay_url_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

/// Configuration for indexer relays used to discover user relay lists
class IndexerRelayConfig {
  /// Well-known indexer relays that maintain broad coverage of kind 10002 events
  /// These are specialized indexers that index and serve NIP-65 relay lists
  static const List<String> defaultIndexers = [
    'wss://purplepag.es', // Purple Pages - primary NIP-65 indexer
    'wss://user.kindpag.es', // Kind Pages - specialized user metadata indexer
    // NOTE: relay.damus.io was here but returns 503 sporadically, slowing
    // discovery. relay.nos.social actively crawls kind 10002 via
    // nos-event-service, giving it broad NIP-65 coverage.
    'wss://relay.nos.social',
  ];

  /// Safe fallback relay set for users without a discoverable NIP-65 relay
  /// list (kind 10002).
  ///
  /// Imported accounts that have never published a relay list — or whose
  /// relay list is hosted on a non-indexed relay — would otherwise stay
  /// connected only to the Divine relay, which makes NIP-17 DMs invisible
  /// to peers writing on other relays. This list is added to the user's
  /// connected pool whenever NIP-65 discovery returns empty or fails, so
  /// DM reachability degrades gracefully instead of silently breaking.
  ///
  /// These are general-purpose public Nostr relays that accept gift wraps
  /// (kind 1059). The set is intentionally small to bound bandwidth and
  /// keep first-connect latency reasonable. Users can still override this
  /// by adding their own relays via Settings → Relays.
  ///
  /// NOTE: relay.damus.io was removed from [defaultIndexers] because it
  /// returns 503 sporadically (see comment above). It is acceptable here
  /// because fallback connections are fire-and-forget — a single relay's
  /// transient 503 does not block the others, and [RelayPool.add] will
  /// retry on reconnect. If it proves persistently unreliable, replace it
  /// with another general-purpose relay that accepts kind 1059.
  ///
  /// See #2931.
  static const List<String> safeFallbackRelays = [
    'wss://relay.nos.social',
    'wss://relay.damus.io',
    'wss://nos.lol',
    'wss://relay.primal.net',
  ];
}

/// Represents a discovered relay with read/write permissions
class DiscoveredRelay {
  const DiscoveredRelay({
    required this.url,
    this.read = true,
    this.write = true,
  });

  factory DiscoveredRelay.fromJson(Map<String, dynamic> json) {
    return DiscoveredRelay(
      url: json['url'] as String,
      read: json['read'] as bool? ?? true,
      write: json['write'] as bool? ?? true,
    );
  }

  final String url;
  final bool read;
  final bool write;

  Map<String, dynamic> toJson() => {'url': url, 'read': read, 'write': write};

  @override
  String toString() => 'DiscoveredRelay(url: $url, read: $read, write: $write)';
}

/// Result of relay discovery operation
class RelayDiscoveryResult {
  const RelayDiscoveryResult({
    required this.success,
    required this.relays,
    this.errorMessage,
    this.foundOnIndexer,
  });

  factory RelayDiscoveryResult.success(
    List<DiscoveredRelay> relays,
    String? indexer,
  ) {
    return RelayDiscoveryResult(
      success: true,
      relays: relays,
      foundOnIndexer: indexer,
    );
  }

  factory RelayDiscoveryResult.failure(String error) {
    return RelayDiscoveryResult(
      success: false,
      relays: [],
      errorMessage: error,
    );
  }

  final bool success;
  final List<DiscoveredRelay> relays;
  final String? errorMessage;
  final String? foundOnIndexer;

  bool get hasRelays => relays.isNotEmpty;
}

/// Service for discovering and caching user relay lists via NIP-65.
///
/// Uses direct WebSocket connections to indexer relays - no NostrClient needed.
/// This eliminates temp client overhead and avoids relay pool / storage
/// side-effects that caused discovery to fail silently.
class RelayDiscoveryService {
  RelayDiscoveryService({List<String>? indexerRelays})
    : _indexerRelays = indexerRelays ?? IndexerRelayConfig.defaultIndexers;

  final List<String> _indexerRelays;
  static const String _cachePrefix = 'relay_discovery_';
  static const Duration _cacheExpiry = Duration(hours: 24);

  /// Discover relay list for a given npub.
  ///
  /// Steps:
  /// 1. Check cache for recent discovery
  /// 2. If not cached, open direct WebSocket connections to indexer relays
  /// 3. Query for kind 10002 (NIP-65 relay list)
  /// 4. Parse relay list from event tags
  /// 5. Cache result for future use
  /// 6. Return list of relays with read/write flags
  ///
  /// Does NOT require a NostrClient - uses direct WebSocket connections to
  /// indexer relays for a clean, self-contained query.
  Future<RelayDiscoveryResult> discoverRelays(String npub) async {
    Log.info(
      '🔍 Starting relay discovery for $npub',
      name: 'RelayDiscoveryService',
      category: LogCategory.auth,
    );

    // Check cache first (only use if non-empty)
    final cached = await _getCachedRelays(npub);
    if (cached != null && cached.isNotEmpty) {
      Log.info(
        '✅ Found ${cached.length} cached relays for $npub',
        name: 'RelayDiscoveryService',
        category: LogCategory.auth,
      );
      return RelayDiscoveryResult.success(cached, 'cache');
    }

    // Query indexers for kind 10002 (NIP-65 relay list)
    try {
      final pubkeyHex = _npubToHex(npub);
      if (pubkeyHex == null) {
        return RelayDiscoveryResult.failure('Invalid npub format');
      }

      Log.info(
        '🔍 Querying ${_indexerRelays.length} indexers for kind 10002...',
        name: 'RelayDiscoveryService',
        category: LogCategory.auth,
      );

      // Query all indexers in parallel - return on first non-empty result
      final result = await _queryFirstSuccess(pubkeyHex);

      if (result != null) {
        final (relays, indexerUrl) = result;
        Log.info(
          '✅ Found ${relays.length} relays on indexer: $indexerUrl',
          name: 'RelayDiscoveryService',
          category: LogCategory.auth,
        );

        await _cacheRelays(npub, relays);
        return RelayDiscoveryResult.success(relays, indexerUrl);
      }

      // No relay list found on any indexer
      Log.warning(
        '⚠️ No relay list found for $npub on any indexer',
        name: 'RelayDiscoveryService',
        category: LogCategory.auth,
      );
      return RelayDiscoveryResult.failure('No relay list found');
    } catch (e) {
      Log.error(
        '❌ Relay discovery failed: $e',
        name: 'RelayDiscoveryService',
        category: LogCategory.auth,
      );
      return RelayDiscoveryResult.failure('Discovery failed: $e');
    }
  }

  /// Query all indexers in parallel and return the first non-empty result.
  ///
  /// Uses a [Completer] to resolve as soon as any indexer returns relays,
  /// rather than waiting for all indexers to finish. If all indexers return
  /// empty or fail, returns null.
  ///
  // TODO: cancel remaining WebSocket connections on first success. Currently
  // losing queries complete naturally (EOSE or 10s timeout) which is harmless
  // but wastes resources.
  Future<(List<DiscoveredRelay>, String)?> _queryFirstSuccess(
    String pubkeyHex,
  ) async {
    final completer = Completer<(List<DiscoveredRelay>, String)?>();
    var pendingCount = _indexerRelays.length;

    for (final indexerUrl in _indexerRelays) {
      unawaited(
        queryIndexerDirect(indexerUrl, pubkeyHex)
            .then((relays) {
              if (!completer.isCompleted && relays.isNotEmpty) {
                completer.complete((relays, indexerUrl));
              } else {
                pendingCount--;
                if (pendingCount == 0 && !completer.isCompleted) {
                  completer.complete(null);
                }
              }
            })
            .catchError((Object e) {
              Log.warning(
                '⚠️ Failed to query indexer $indexerUrl: $e',
                name: 'RelayDiscoveryService',
                category: LogCategory.auth,
              );
              pendingCount--;
              if (pendingCount == 0 && !completer.isCompleted) {
                completer.complete(null);
              }
            }),
      );
    }

    return completer.future;
  }

  /// Query a specific indexer relay for kind 10002 event via direct WebSocket.
  ///
  /// Opens a direct WebSocket connection to the indexer, sends a REQ for the
  /// user's kind 10002 event, waits for EVENT/EOSE, and disconnects.
  /// This is self-contained - no NostrClient or relay pool needed.
  @visibleForTesting
  Future<List<DiscoveredRelay>> queryIndexerDirect(
    String indexerUrl,
    String pubkeyHex,
  ) async {
    Log.info(
      '  Querying indexer: $indexerUrl',
      name: 'RelayDiscoveryService',
      category: LogCategory.auth,
    );

    final relayStatus = RelayStatus(indexerUrl);
    final relay = RelayBase(indexerUrl, relayStatus);
    final completer = Completer<List<DiscoveredRelay>>();
    final events = <Map<String, dynamic>>[];
    final subscriptionId = 'rd_${DateTime.now().millisecondsSinceEpoch}';

    // Set up message handler before connecting
    relay.onMessage = (relay, json) async {
      if (json.isEmpty) return;

      final messageType = json[0] as String;

      if (messageType == 'EVENT' && json.length >= 3) {
        // Collect the raw event JSON
        final eventJson = json[2] as Map<String, dynamic>;
        events.add(eventJson);
      } else if (messageType == 'EOSE') {
        // All stored events received - parse and complete
        if (!completer.isCompleted) {
          if (events.isEmpty) {
            completer.complete(<DiscoveredRelay>[]);
          } else {
            // Parse the most recent event's relay list
            final relays = _parseRelayListFromJson(events.first);
            completer.complete(relays);
          }
        }
      } else if (messageType == 'NOTICE') {
        Log.warning(
          '  NOTICE from $indexerUrl: ${json.length > 1 ? json[1] : ""}',
          name: 'RelayDiscoveryService',
          category: LogCategory.auth,
        );
      }
    };

    try {
      // Add the REQ message to pending (will be sent when connection opens)
      final filter = <String, dynamic>{
        'kinds': <int>[10002],
        'authors': <String>[pubkeyHex],
        'limit': 1,
      };
      relay.pendingMessages.add(<dynamic>['REQ', subscriptionId, filter]);

      // Connect - this opens WebSocket and sends the pending REQ
      final connected = await relay.connect();
      if (!connected) {
        Log.warning(
          '  Failed to connect to $indexerUrl',
          name: 'RelayDiscoveryService',
          category: LogCategory.auth,
        );
        return [];
      }

      // Wait for EOSE (or timeout)
      final result = await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          Log.warning(
            '  Timeout querying indexer: $indexerUrl',
            name: 'RelayDiscoveryService',
            category: LogCategory.auth,
          );
          return <DiscoveredRelay>[];
        },
      );

      // Send CLOSE before disconnecting
      await relay.send(<dynamic>['CLOSE', subscriptionId]);

      Log.info(
        '  Got ${result.length} relays from $indexerUrl',
        name: 'RelayDiscoveryService',
        category: LogCategory.auth,
      );

      return result;
    } catch (e) {
      Log.error(
        '  Error querying indexer $indexerUrl: $e',
        name: 'RelayDiscoveryService',
        category: LogCategory.auth,
      );
      return [];
    } finally {
      try {
        await relay.disconnect();
      } catch (_) {}
    }
  }

  /// Parse relay list from kind 10002 event JSON.
  ///
  /// NIP-65 format:
  /// Tags: [["r", "<relay-url>"], ["r", "<relay-url>", "read"],
  ///        ["r", "<relay-url>", "write"]]
  @visibleForTesting
  List<DiscoveredRelay> parseRelayListFromJson(Map<String, dynamic> json) =>
      _parseRelayListFromJson(json);

  List<DiscoveredRelay> _parseRelayListFromJson(Map<String, dynamic> json) {
    final relays = <DiscoveredRelay>[];
    final tags = json['tags'] as List<dynamic>? ?? [];

    for (final tag in tags) {
      if (tag is! List || tag.isEmpty || tag[0] != 'r') continue;
      if (tag.length < 2) continue;

      final url = tag[1] as String;

      // Accept wss:// for any host, ws:// only for loopback (#3362).
      if (!isRelayUrlAllowed(url)) {
        Log.warning(
          '  Skipping disallowed relay URL: $url',
          name: 'RelayDiscoveryService',
          category: LogCategory.auth,
        );
        continue;
      }

      final permission = tag.length > 2 ? tag[2] as String? : null;

      final relay = DiscoveredRelay(
        url: url,
        read: permission == null || permission == 'read',
        write: permission == null || permission == 'write',
      );

      relays.add(relay);
    }

    Log.info(
      '  Parsed ${relays.length} relays from kind 10002 event',
      name: 'RelayDiscoveryService',
      category: LogCategory.auth,
    );

    return relays;
  }

  /// Cache relay list for a user
  Future<void> _cacheRelays(String npub, List<DiscoveredRelay> relays) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cachePrefix$npub';

      final cacheData = {
        'relays': relays.map((r) => r.toJson()).toList(),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      await prefs.setString(cacheKey, json.encode(cacheData));
    } catch (e) {
      Log.warning(
        'Failed to cache relays: $e',
        name: 'RelayDiscoveryService',
        category: LogCategory.auth,
      );
    }
  }

  /// Get cached relay list if not expired
  Future<List<DiscoveredRelay>?> _getCachedRelays(String npub) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cachePrefix$npub';

      final cacheJson = prefs.getString(cacheKey);
      if (cacheJson == null) return null;

      final cacheData = json.decode(cacheJson) as Map<String, dynamic>;
      final timestamp = cacheData['timestamp'] as int;

      // Check if cache is expired
      final cacheAge = DateTime.now().millisecondsSinceEpoch - timestamp;
      if (cacheAge > _cacheExpiry.inMilliseconds) {
        return null;
      }

      final relaysList = cacheData['relays'] as List<dynamic>;
      return relaysList
          .map((r) => DiscoveredRelay.fromJson(r as Map<String, dynamic>))
          .where((r) => isRelayUrlAllowed(r.url))
          .toList();
    } catch (e) {
      Log.warning(
        'Failed to read cached relays: $e',
        name: 'RelayDiscoveryService',
        category: LogCategory.auth,
      );
      return null;
    }
  }

  /// Clear cached relays for a user
  Future<void> clearCache(String npub) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cachePrefix$npub';
      await prefs.remove(cacheKey);
    } catch (e) {
      Log.warning(
        'Failed to clear relay cache: $e',
        name: 'RelayDiscoveryService',
        category: LogCategory.auth,
      );
    }
  }

  /// Convert npub to hex format
  String? _npubToHex(String npub) {
    try {
      return Nip19.decode(npub);
    } catch (e) {
      Log.error(
        'Failed to decode npub: $e',
        name: 'RelayDiscoveryService',
        category: LogCategory.auth,
      );
      return null;
    }
  }
}
