// ABOUTME: Service for discovering user relays via NIP-65 (kind 10002)
// ABOUTME: Queries indexer relays to find where users publish their relay lists
// ABOUTME: Caches discovered relay lists by npub for quick access

import 'dart:async';
import 'dart:convert';

import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Configuration for indexer relays used to discover user relay lists
class IndexerRelayConfig {
  /// Well-known indexer relays that maintain broad coverage of kind 10002 events
  /// These are specialized indexers that index and serve NIP-65 relay lists
  static const List<String> defaultIndexers = [
    'wss://purplepag.es', // Purple Pages - primary NIP-65 indexer
    'wss://user.kindpag.es', // Kind Pages - specialized user metadata indexer
    'wss://index.coracle.social', // Coracle Social - comprehensive indexer
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

/// Service for discovering and caching user relay lists via NIP-65
class RelayDiscoveryService {
  RelayDiscoveryService({List<String>? indexerRelays})
    : _indexerRelays = indexerRelays ?? IndexerRelayConfig.defaultIndexers;

  final List<String> _indexerRelays;
  static const String _cachePrefix = 'relay_discovery_';
  static const Duration _cacheExpiry = Duration(hours: 24);

  /// Discover relay list for a given npub
  ///
  /// Steps:
  /// 1. Check cache for recent discovery
  /// 2. If not cached, query indexer relays for kind 10002
  /// 3. Parse relay list from event content/tags
  /// 4. Cache result for future use
  /// 5. Return list of relays with read/write flags
  ///
  /// If [nostrClient] is provided, uses it to query indexers directly.
  /// Otherwise returns cached results only (if available).
  Future<RelayDiscoveryResult> discoverRelays(
    String npub, {
    NostrClient? nostrClient,
  }) async {
    Log.info(
      'Starting relay discovery for npub: ${_maskNpub(npub)}',
      name: 'RelayDiscoveryService',
      category: LogCategory.relay,
    );

    // Check cache first
    final cached = await _getCachedRelays(npub);
    if (cached != null) {
      Log.info(
        'Found ${cached.length} cached relays for ${_maskNpub(npub)}',
        name: 'RelayDiscoveryService',
        category: LogCategory.relay,
      );
      return RelayDiscoveryResult.success(cached, 'cache');
    }

    // If no NostrClient provided, can't query - return failure
    if (nostrClient == null) {
      Log.warning(
        'No NostrClient provided - cannot query indexers',
        name: 'RelayDiscoveryService',
        category: LogCategory.relay,
      );
      return RelayDiscoveryResult.failure('NostrClient required for discovery');
    }

    // Query indexers for kind 10002 (NIP-65 relay list)
    try {
      final pubkeyHex = _npubToHex(npub);
      if (pubkeyHex == null) {
        return RelayDiscoveryResult.failure('Invalid npub format');
      }

      Log.debug(
        'Querying ${_indexerRelays.length} indexers for kind 10002...',
        name: 'RelayDiscoveryService',
        category: LogCategory.relay,
      );

      // Try each indexer until we find the relay list
      for (final indexerUrl in _indexerRelays) {
        try {
          final relays = await _queryIndexer(
            indexerUrl,
            pubkeyHex,
            nostrClient,
          );
          if (relays.isNotEmpty) {
            Log.info(
              'Found ${relays.length} relays on indexer: $indexerUrl',
              name: 'RelayDiscoveryService',
              category: LogCategory.relay,
            );

            // Cache the result
            await _cacheRelays(npub, relays);

            return RelayDiscoveryResult.success(relays, indexerUrl);
          }
        } catch (e) {
          Log.warning(
            'Failed to query indexer $indexerUrl: $e',
            name: 'RelayDiscoveryService',
            category: LogCategory.relay,
          );
          continue;
        }
      }

      // No relay list found on any indexer
      Log.warning(
        'No relay list found for ${_maskNpub(npub)} on any indexer',
        name: 'RelayDiscoveryService',
        category: LogCategory.relay,
      );
      return RelayDiscoveryResult.failure('No relay list found');
    } catch (e) {
      Log.error(
        'Relay discovery failed: $e',
        name: 'RelayDiscoveryService',
        category: LogCategory.relay,
      );
      return RelayDiscoveryResult.failure('Discovery failed: $e');
    }
  }

  /// Discover relay list for a given npub, skipping if user already has
  /// configured relays.
  ///
  /// This is the preferred method for automatic discovery during login.
  /// If configured_relays already exists in SharedPreferences, it means the
  /// user has a relay configuration (either from previous discovery or manual
  /// edits), so we skip NIP-65 discovery to preserve it.
  ///
  /// Returns a failure result with specific message if:
  /// - User already has configured relays (preserves existing config)
  ///
  /// Otherwise proceeds with normal [discoverRelays] behavior.
  Future<RelayDiscoveryResult> discoverRelaysIfNotConfigured(
    String npub, {
    NostrClient? nostrClient,
  }) async {
    // Check if user already has configured relays
    final prefs = await SharedPreferences.getInstance();
    final configuredRelays = prefs.getStringList('configured_relays');
    final hasConfiguredRelays =
        configuredRelays != null && configuredRelays.isNotEmpty;

    if (hasConfiguredRelays) {
      Log.info(
        'User already has ${configuredRelays.length} configured relays - '
        'skipping NIP-65 discovery for ${_maskNpub(npub)}',
        name: 'RelayDiscoveryService',
        category: LogCategory.relay,
      );

      // Return failure result - user's configured relays should be used instead
      return RelayDiscoveryResult.failure('User has configured relays');
    }

    // Proceed with normal discovery
    return discoverRelays(npub, nostrClient: nostrClient);
  }

  /// Query a specific indexer relay for kind 10002 event using NostrClient
  Future<List<DiscoveredRelay>> _queryIndexer(
    String indexerUrl,
    String pubkeyHex,
    NostrClient client,
  ) async {
    Log.debug(
      'Querying indexer: $indexerUrl for kind 10002',
      name: 'RelayDiscoveryService',
      category: LogCategory.relay,
    );

    try {
      // Temporarily add the indexer relay
      final added = await client.addRelay(indexerUrl);
      if (!added) {
        Log.warning(
          'Failed to add indexer relay: $indexerUrl',
          name: 'RelayDiscoveryService',
          category: LogCategory.relay,
        );
        return [];
      }

      // Create filter for kind 10002 (NIP-65 relay list)
      final filter = Filter(
        kinds: [10002],
        authors: [pubkeyHex],
        limit: 1, // Only need the most recent
      );

      // Query with timeout
      final events = await client
          .queryEvents([filter])
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              Log.warning(
                'Timeout querying indexer: $indexerUrl',
                name: 'RelayDiscoveryService',
                category: LogCategory.relay,
              );
              return <Event>[];
            },
          );

      // Remove the indexer relay after querying
      await client.removeRelay(indexerUrl);

      if (events.isEmpty) {
        Log.debug(
          'No kind 10002 event found on $indexerUrl',
          name: 'RelayDiscoveryService',
          category: LogCategory.relay,
        );
        return [];
      }

      // Parse the relay list from the event
      final event = events.first;
      final relays = _parseRelayList(event);

      Log.info(
        'Successfully parsed ${relays.length} relays from $indexerUrl',
        name: 'RelayDiscoveryService',
        category: LogCategory.relay,
      );

      return relays;
    } catch (e) {
      Log.error(
        'Error querying indexer $indexerUrl: $e',
        name: 'RelayDiscoveryService',
        category: LogCategory.relay,
      );

      // Try to remove the relay on error
      try {
        await client.removeRelay(indexerUrl);
      } catch (_) {
        // Ignore cleanup errors
      }

      return [];
    }
  }

  /// Parse relay list from kind 10002 event
  ///
  /// NIP-65 format:
  /// Tags: [["r", "<relay-url>"], ["r", "<relay-url>", "read"], ["r", "<relay-url>", "write"]]
  List<DiscoveredRelay> _parseRelayList(Event event) {
    final relays = <DiscoveredRelay>[];

    for (final tag in event.tags) {
      if (tag.isEmpty || tag[0] != 'r') continue;

      if (tag.length < 2) continue;

      final url = tag[1];
      // tag[2] can be "read" or "write" or omitted (meaning both)
      final permission = tag.length > 2 ? tag[2] : null;

      final relay = DiscoveredRelay(
        url: url,
        read: permission == null || permission == 'read',
        write: permission == null || permission == 'write',
      );

      relays.add(relay);
    }

    Log.info(
      'Parsed ${relays.length} relays from kind 10002 event',
      name: 'RelayDiscoveryService',
      category: LogCategory.relay,
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

      Log.debug(
        'Cached ${relays.length} relays for ${_maskNpub(npub)}',
        name: 'RelayDiscoveryService',
        category: LogCategory.relay,
      );
    } catch (e) {
      Log.warning(
        'Failed to cache relays: $e',
        name: 'RelayDiscoveryService',
        category: LogCategory.relay,
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
        Log.debug(
          'Cache expired for ${_maskNpub(npub)}',
          name: 'RelayDiscoveryService',
          category: LogCategory.relay,
        );
        return null;
      }

      final relaysList = cacheData['relays'] as List<dynamic>;
      return relaysList
          .map((r) => DiscoveredRelay.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      Log.warning(
        'Failed to read cached relays: $e',
        name: 'RelayDiscoveryService',
        category: LogCategory.relay,
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

      Log.debug(
        'Cleared relay cache for ${_maskNpub(npub)}',
        name: 'RelayDiscoveryService',
        category: LogCategory.relay,
      );
    } catch (e) {
      Log.warning(
        'Failed to clear relay cache: $e',
        name: 'RelayDiscoveryService',
        category: LogCategory.relay,
      );
    }
  }

  /// Convert npub to hex format
  String? _npubToHex(String npub) {
    try {
      // Use nostr_sdk's Bech32 decoding - returns hex pubkey directly
      return Nip19.decode(npub);
    } catch (e) {
      Log.error(
        'Failed to decode npub: $e',
        name: 'RelayDiscoveryService',
        category: LogCategory.relay,
      );
      return null;
    }
  }

  /// Mask npub for logging (show first 8 and last 4 characters)
  String _maskNpub(String npub) {
    if (npub.length <= 12) return npub;
    final lastFour = npub.substring(npub.length - 4);
    return '${npub.substring(0, 8)}...$lastFour';
  }
}
