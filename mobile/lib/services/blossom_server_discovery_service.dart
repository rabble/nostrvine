// ABOUTME: Service for discovering user Blossom media servers via kind 10063
// ABOUTME: Queries indexer relays to find users' preferred media servers (BUD-03)
// ABOUTME: Caches discovered server lists by npub for quick access

import 'dart:async';
import 'dart:convert';

import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Configuration for indexer relays used to discover user Blossom server lists
class BlossomIndexerConfig {
  /// Well-known indexer relays that maintain broad coverage of kind 10063 events
  /// These are the same indexers used for NIP-65 relay discovery
  static const List<String> defaultIndexers = [
    'wss://purplepag.es', // Purple Pages - primary metadata indexer
    'wss://user.kindpag.es', // Kind Pages - specialized user metadata indexer
    'wss://index.coracle.social', // Coracle Social - comprehensive indexer
  ];
}

/// Represents a discovered Blossom server from kind 10063
class DiscoveredBlossomServer {
  const DiscoveredBlossomServer({required this.url, this.priority});

  factory DiscoveredBlossomServer.fromJson(Map<String, dynamic> json) {
    return DiscoveredBlossomServer(
      url: json['url'] as String,
      priority: json['priority'] as int?,
    );
  }

  /// Server URL (e.g., "https://cdn.satellite.earth")
  final String url;

  /// Priority/order from kind 10063 event (lower = higher priority)
  /// First server in list has priority 0, second has 1, etc.
  final int? priority;

  Map<String, dynamic> toJson() => {'url': url, 'priority': priority};

  @override
  String toString() => 'BlossomServer(url: $url, priority: $priority)';
}

/// Result of Blossom server discovery operation
class BlossomDiscoveryResult {
  const BlossomDiscoveryResult({
    required this.success,
    required this.servers,
    this.errorMessage,
    this.source,
  });

  factory BlossomDiscoveryResult.success(
    List<DiscoveredBlossomServer> servers,
    String? source,
  ) {
    return BlossomDiscoveryResult(
      success: true,
      servers: servers,
      source: source,
    );
  }

  factory BlossomDiscoveryResult.failure(String error) {
    return BlossomDiscoveryResult(
      success: false,
      servers: [],
      errorMessage: error,
    );
  }

  final bool success;
  final List<DiscoveredBlossomServer> servers;
  final String? errorMessage;
  final String? source; // 'cache' or relay URL where found

  bool get hasServers => servers.isNotEmpty;

  /// Get servers sorted by priority (lowest priority number first)
  List<DiscoveredBlossomServer> get serversByPriority {
    final sorted = List<DiscoveredBlossomServer>.from(servers);
    sorted.sort((a, b) {
      final aPriority = a.priority ?? 999;
      final bPriority = b.priority ?? 999;
      return aPriority.compareTo(bPriority);
    });
    return sorted;
  }
}

/// Service for discovering and caching user Blossom media servers via kind 10063
///
/// BUD-03 spec: Users publish a replaceable event (kind 10063) listing their
/// preferred Blossom servers. The order matters - first server is most trusted.
class BlossomServerDiscoveryService {
  BlossomServerDiscoveryService({List<String>? indexerRelays})
    : _indexerRelays = indexerRelays ?? BlossomIndexerConfig.defaultIndexers;

  final List<String> _indexerRelays;
  static const String _cachePrefix = 'blossom_server_discovery_';
  static const Duration _cacheExpiry = Duration(hours: 24);

  /// Discover Blossom server list for a given npub
  ///
  /// Steps:
  /// 1. Check cache for recent discovery
  /// 2. If not cached, query indexer relays for kind 10063
  /// 3. Parse server list from event tags
  /// 4. Cache result for future use
  /// 5. Return list of servers with priority order
  ///
  /// This uses the SAME indexers as NIP-65 relay discovery, since indexers
  /// also maintain kind 10063 events for Nostr-native users.
  ///
  /// If [nostrClient] is provided, uses it to query indexers directly.
  /// Otherwise returns cached results only (if available).
  Future<BlossomDiscoveryResult> discoverServers(
    String npub, {
    NostrClient? nostrClient,
  }) async {
    Log.info(
      'Starting Blossom server discovery for npub: ${_maskNpub(npub)}',
      name: 'BlossomServerDiscoveryService',
      category: LogCategory.system,
    );

    // Check cache first
    final cached = await _getCachedServers(npub);
    if (cached != null) {
      Log.info(
        'Found ${cached.length} cached Blossom servers for ${_maskNpub(npub)}',
        name: 'BlossomServerDiscoveryService',
        category: LogCategory.system,
      );
      return BlossomDiscoveryResult.success(cached, 'cache');
    }

    // If no NostrClient provided, can't query - return failure
    if (nostrClient == null) {
      Log.warning(
        'No NostrClient provided - cannot query indexers',
        name: 'BlossomServerDiscoveryService',
        category: LogCategory.system,
      );
      return BlossomDiscoveryResult.failure(
        'NostrClient required for discovery',
      );
    }

    // Query indexers for kind 10063 (BUD-03 User Server List)
    try {
      final pubkeyHex = _npubToHex(npub);
      if (pubkeyHex == null) {
        return BlossomDiscoveryResult.failure('Invalid npub format');
      }

      Log.debug(
        'Querying ${_indexerRelays.length} indexers for kind 10063...',
        name: 'BlossomServerDiscoveryService',
        category: LogCategory.system,
      );

      // Try each indexer until we find the server list
      for (final indexerUrl in _indexerRelays) {
        try {
          final servers = await _queryIndexer(
            indexerUrl,
            pubkeyHex,
            nostrClient,
          );
          if (servers.isNotEmpty) {
            Log.info(
              'Found ${servers.length} Blossom servers on indexer: $indexerUrl',
              name: 'BlossomServerDiscoveryService',
              category: LogCategory.system,
            );

            // Cache the result
            await _cacheServers(npub, servers);

            return BlossomDiscoveryResult.success(servers, indexerUrl);
          }
        } catch (e) {
          Log.warning(
            'Failed to query indexer $indexerUrl: $e',
            name: 'BlossomServerDiscoveryService',
            category: LogCategory.system,
          );
          continue;
        }
      }

      // No server list found on any indexer
      Log.info(
        'No Blossom server list found for ${_maskNpub(npub)} on any indexer',
        name: 'BlossomServerDiscoveryService',
        category: LogCategory.system,
      );
      return BlossomDiscoveryResult.failure('No server list found');
    } catch (e) {
      Log.error(
        'Blossom server discovery failed: $e',
        name: 'BlossomServerDiscoveryService',
        category: LogCategory.system,
      );
      return BlossomDiscoveryResult.failure('Discovery failed: $e');
    }
  }

  /// Query a specific indexer relay for kind 10063 event using NostrClient
  Future<List<DiscoveredBlossomServer>> _queryIndexer(
    String indexerUrl,
    String pubkeyHex,
    NostrClient client,
  ) async {
    Log.debug(
      'Querying indexer: $indexerUrl for kind 10063',
      name: 'BlossomServerDiscoveryService',
      category: LogCategory.system,
    );

    try {
      // Temporarily add the indexer relay
      final added = await client.addRelay(indexerUrl);
      if (!added) {
        Log.warning(
          'Failed to add indexer relay: $indexerUrl',
          name: 'BlossomServerDiscoveryService',
          category: LogCategory.system,
        );
        return [];
      }

      // Create filter for kind 10063 (BUD-03 User Server List)
      final filter = Filter(
        kinds: [10063],
        authors: [pubkeyHex],
        limit: 1, // Only need the most recent (replaceable event)
      );

      // Query with timeout
      final events = await client
          .queryEvents([filter])
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              Log.warning(
                'Timeout querying indexer: $indexerUrl',
                name: 'BlossomServerDiscoveryService',
                category: LogCategory.system,
              );
              return <Event>[];
            },
          );

      // Remove the indexer relay after querying
      await client.removeRelay(indexerUrl);

      if (events.isEmpty) {
        Log.debug(
          'No kind 10063 event found on $indexerUrl',
          name: 'BlossomServerDiscoveryService',
          category: LogCategory.system,
        );
        return [];
      }

      // Parse the server list from the event
      final event = events.first;
      final servers = _parseServerList(event);

      Log.info(
        'Successfully parsed ${servers.length} Blossom servers from $indexerUrl',
        name: 'BlossomServerDiscoveryService',
        category: LogCategory.system,
      );

      return servers;
    } catch (e) {
      Log.error(
        'Error querying indexer $indexerUrl: $e',
        name: 'BlossomServerDiscoveryService',
        category: LogCategory.system,
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

  /// Parse Blossom server list from kind 10063 event
  ///
  /// BUD-03 format:
  /// Tags: [["server", "https://cdn.example.com"], ["server", "https://cdn2.example.com"], ...]
  /// Order is important - first server is most trusted (priority 0)
  List<DiscoveredBlossomServer> _parseServerList(Event event) {
    final servers = <DiscoveredBlossomServer>[];
    int priority = 0;

    for (final tag in event.tags) {
      if (tag.isEmpty || tag[0] != 'server') continue;

      if (tag.length < 2) continue;

      final url = tag[1];

      // Validate URL format
      final uri = Uri.tryParse(url);
      if (uri == null || (!uri.scheme.startsWith('http'))) {
        Log.warning(
          'Invalid server URL in kind 10063: $url',
          name: 'BlossomServerDiscoveryService',
          category: LogCategory.system,
        );
        continue;
      }

      final server = DiscoveredBlossomServer(url: url, priority: priority);

      servers.add(server);
      priority++;
    }

    Log.info(
      'Parsed ${servers.length} Blossom servers from kind 10063 event',
      name: 'BlossomServerDiscoveryService',
      category: LogCategory.system,
    );

    return servers;
  }

  /// Cache server list for a user
  Future<void> _cacheServers(
    String npub,
    List<DiscoveredBlossomServer> servers,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cachePrefix$npub';

      final cacheData = {
        'servers': servers.map((s) => s.toJson()).toList(),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      await prefs.setString(cacheKey, json.encode(cacheData));

      Log.debug(
        'Cached ${servers.length} Blossom servers for ${_maskNpub(npub)}',
        name: 'BlossomServerDiscoveryService',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.warning(
        'Failed to cache Blossom servers: $e',
        name: 'BlossomServerDiscoveryService',
        category: LogCategory.system,
      );
    }
  }

  /// Get cached server list if not expired
  Future<List<DiscoveredBlossomServer>?> _getCachedServers(String npub) async {
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
          name: 'BlossomServerDiscoveryService',
          category: LogCategory.system,
        );
        return null;
      }

      final serversList = cacheData['servers'] as List<dynamic>;
      return serversList
          .map(
            (s) => DiscoveredBlossomServer.fromJson(s as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      Log.warning(
        'Failed to read cached Blossom servers: $e',
        name: 'BlossomServerDiscoveryService',
        category: LogCategory.system,
      );
      return null;
    }
  }

  /// Clear cached servers for a user
  Future<void> clearCache(String npub) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cachePrefix$npub';
      await prefs.remove(cacheKey);

      Log.debug(
        'Cleared Blossom server cache for ${_maskNpub(npub)}',
        name: 'BlossomServerDiscoveryService',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.warning(
        'Failed to clear Blossom server cache: $e',
        name: 'BlossomServerDiscoveryService',
        category: LogCategory.system,
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
        name: 'BlossomServerDiscoveryService',
        category: LogCategory.system,
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
