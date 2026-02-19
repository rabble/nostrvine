// ABOUTME: Social interaction service managing follow sets and follower stats
// ABOUTME: Handles NIP-51 follow sets and follower/following counts
// ABOUTME: Note: NIP-02 contact list (follow/unfollow) is handled by FollowRepository
// ABOUTME: Note: NIP-18 reposts are handled by RepostsRepository

import 'dart:async';

import 'package:nostr_sdk/filter.dart';
import 'package:openvine/constants/nip71_migration.dart';
import 'package:openvine/services/analytics_api_service.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/immediate_completion_helper.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/services/personal_event_cache_service.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Represents a follow set (NIP-51 Kind 30000)
class FollowSet {
  const FollowSet({
    required this.id,
    required this.name,
    required this.pubkeys,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.imageUrl,
    this.nostrEventId,
  });

  final String id;
  final String name;
  final String? description;
  final String? imageUrl;
  final List<String> pubkeys;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? nostrEventId;

  FollowSet copyWith({
    String? id,
    String? name,
    String? description,
    String? imageUrl,
    List<String>? pubkeys,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? nostrEventId,
  }) => FollowSet(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
    imageUrl: imageUrl ?? this.imageUrl,
    pubkeys: pubkeys ?? this.pubkeys,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    nostrEventId: nostrEventId ?? this.nostrEventId,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'imageUrl': imageUrl,
    'pubkeys': pubkeys,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'nostrEventId': nostrEventId,
  };

  static FollowSet fromJson(Map<String, dynamic> json) => FollowSet(
    id: json['id'],
    name: json['name'],
    description: json['description'],
    imageUrl: json['imageUrl'],
    pubkeys: List<String>.from(json['pubkeys'] ?? []),
    createdAt: DateTime.parse(json['createdAt']),
    updatedAt: DateTime.parse(json['updatedAt']),
    nostrEventId: json['nostrEventId'],
  );
}

/// Service for managing social interactions on Nostr
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
class SocialService {
  SocialService(
    this._nostrService,
    this._authService, {
    PersonalEventCacheService? personalEventCache,
    AnalyticsApiService? analyticsApiService,
  }) : _personalEventCache = personalEventCache,
       _analyticsApiService = analyticsApiService {
    _initialize();
  }
  final NostrClient _nostrService;
  final AuthService _authService;
  final PersonalEventCacheService? _personalEventCache;
  final AnalyticsApiService? _analyticsApiService;

  // Cache for follower/following counts
  final Map<String, Map<String, int>> _followerStats =
      <String, Map<String, int>>{};

  // Cache for follow sets (NIP-51 Kind 30000)
  final List<FollowSet> _followSets = <FollowSet>[];

  /// Initialize the service
  Future<void> _initialize() async {
    Log.debug(
      '🤝 Initializing SocialService',
      name: 'SocialService',
      category: LogCategory.system,
    );

    Log.info(
      'SocialService initialized',
      name: 'SocialService',
      category: LogCategory.system,
    );
  }

  // === FOLLOWER STATS ===

  /// Get cached follower stats for a pubkey
  Map<String, int>? getCachedFollowerStats(String pubkey) =>
      _followerStats[pubkey];

  // === FOLLOW SETS GETTERS ===

  /// Get all follow sets
  List<FollowSet> get followSets => List.unmodifiable(_followSets);

  /// Get follow set by ID
  FollowSet? getFollowSetById(String setId) {
    try {
      return _followSets.firstWhere((set) => set.id == setId);
    } catch (e) {
      return null;
    }
  }

  /// Check if a pubkey is in a specific follow set
  bool isInFollowSet(String setId, String pubkey) {
    final set = getFollowSetById(setId);
    return set?.pubkeys.contains(pubkey) ?? false;
  }

  // === FOLLOWER STATS ===

  /// Get follower and following counts for a specific pubkey
  Future<Map<String, int>> getFollowerStats(String pubkey) async {
    Log.debug(
      'Fetching follower stats for: $pubkey',
      name: 'SocialService',
      category: LogCategory.system,
    );

    try {
      // Check cache first
      final cachedStats = _followerStats[pubkey];
      if (cachedStats != null) {
        Log.debug(
          '📱 Using cached follower stats: $cachedStats',
          name: 'SocialService',
          category: LogCategory.system,
        );
        return cachedStats;
      }

      // Fetch from network
      final stats = await _fetchFollowerStats(pubkey);

      // Cache the result only if we got real data — avoid persisting
      // zeros from failed relay queries so the next call retries.
      if (stats['followers']! > 0 || stats['following']! > 0) {
        _followerStats[pubkey] = stats;
      }

      Log.debug(
        'Follower stats fetched: $stats',
        name: 'SocialService',
        category: LogCategory.system,
      );
      return stats;
    } catch (e) {
      Log.error(
        'Error fetching follower stats: $e',
        name: 'SocialService',
        category: LogCategory.system,
      );
      return {'followers': 0, 'following': 0};
    }
  }

  /// Fetch follower stats from the network.
  ///
  /// Tries the REST API first (instant response) and falls back to
  /// WebSocket queries if the REST API is unavailable or returns
  /// `following: 0` (which may indicate unindexed kind 3 data).
  Future<Map<String, int>> _fetchFollowerStats(String pubkey) async {
    // 1. Try REST API first (fast, non-blocking)
    final restResult = await _fetchFollowerStatsViaRest(pubkey);
    if (restResult != null) {
      // If REST reports 0 following, verify via WebSocket. The REST API
      // may not have indexed the user's kind 3 contact list yet.
      if (restResult['following'] == 0) {
        final wsFollowing = await _fetchFollowingCountViaWebSocket(pubkey);
        if (wsFollowing > 0) {
          Log.debug(
            'REST reported 0 following but relay has $wsFollowing '
            '— using relay data for $pubkey',
            name: 'SocialService',
            category: LogCategory.system,
          );
          return {...restResult, 'following': wsFollowing};
        }
      }
      return restResult;
    }

    // 2. Fall back to WebSocket queries (run in parallel)
    return _fetchFollowerStatsViaWebSocket(pubkey);
  }

  /// Try fetching follower stats via the Funnelcake REST API.
  ///
  /// Returns null if the REST API is unavailable or the request fails.
  Future<Map<String, int>?> _fetchFollowerStatsViaRest(String pubkey) async {
    final analyticsApi = _analyticsApiService;
    if (analyticsApi == null || !analyticsApi.isAvailable) {
      return null;
    }

    try {
      final counts = await analyticsApi.getSocialCounts(pubkey);
      if (counts != null) {
        Log.debug(
          'REST API follower stats: ${counts.followerCount} followers, '
          '${counts.followingCount} following for $pubkey',
          name: 'SocialService',
          category: LogCategory.system,
        );
        return {
          'followers': counts.followerCount,
          'following': counts.followingCount,
        };
      }
    } catch (e) {
      Log.warning(
        'REST API follower stats failed, falling back to WebSocket: $e',
        name: 'SocialService',
        category: LogCategory.system,
      );
    }
    return null;
  }

  /// Fetch follower stats via WebSocket queries (parallel).
  ///
  /// Used as a fallback when the REST API is unavailable.
  Future<Map<String, int>> _fetchFollowerStatsViaWebSocket(
    String pubkey,
  ) async {
    try {
      // Run both queries in parallel using Future.wait
      final results = await Future.wait([
        _fetchFollowingCountViaWebSocket(pubkey),
        _fetchFollowersCountViaWebSocket(pubkey),
      ]);

      return {'following': results[0], 'followers': results[1]};
    } catch (e) {
      Log.error(
        'Error fetching follower stats via WebSocket: $e',
        name: 'SocialService',
        category: LogCategory.system,
      );
      return {'followers': 0, 'following': 0};
    }
  }

  /// Get following count via WebSocket (Kind 3 contact list).
  Future<int> _fetchFollowingCountViaWebSocket(String pubkey) async {
    final eventStream = _nostrService.subscribe([
      Filter(authors: [pubkey], kinds: [3], limit: 1),
    ]);

    final event = await ContactListCompletionHelper.queryContactList(
      eventStream: eventStream,
      pubkey: pubkey,
      fallbackTimeoutSeconds: 8,
    );

    if (event != null) {
      final count = event.tags
          .where((tag) => tag.isNotEmpty && tag[0] == 'p')
          .length;
      Log.debug(
        'WebSocket following count: $count for $pubkey',
        name: 'SocialService',
        category: LogCategory.system,
      );
      return count;
    }
    return 0;
  }

  /// Get followers count via WebSocket (Kind 3 events mentioning pubkey).
  Future<int> _fetchFollowersCountViaWebSocket(String pubkey) async {
    final eventStream = _nostrService.subscribe([
      Filter(kinds: [3], p: [pubkey]),
    ]);

    final config = CompletionConfig(
      mode: CompletionMode.exhaustive,
      fallbackTimeoutSeconds: 8,
      serviceName: 'FollowersQuery',
      logCategory: LogCategory.system,
    );

    final followerPubkeys = <String>{};
    final completer = Completer<int>();

    ImmediateCompletionHelper.createImmediateSubscription(
      eventStream: eventStream,
      config: config,
      onEvent: (event) {
        followerPubkeys.add(event.pubkey);
      },
      onComplete: (result) {
        Log.debug(
          'WebSocket followers count: ${followerPubkeys.length} for $pubkey',
          name: 'SocialService',
          category: LogCategory.system,
        );
        if (!completer.isCompleted) {
          completer.complete(followerPubkeys.length);
        }
      },
      onError: (error) {
        Log.error(
          'Error fetching followers count via WebSocket: $error',
          name: 'SocialService',
          category: LogCategory.system,
        );
        if (!completer.isCompleted) {
          completer.complete(followerPubkeys.length);
        }
      },
    );

    return completer.future;
  }

  // === FOLLOW SETS MANAGEMENT (NIP-51 Kind 30000) ===

  /// Create a new follow set
  Future<FollowSet?> createFollowSet({
    required String name,
    String? description,
    String? imageUrl,
    List<String> initialPubkeys = const [],
  }) async {
    try {
      if (!_authService.isAuthenticated) {
        Log.error(
          'Cannot create follow set - user not authenticated',
          name: 'SocialService',
          category: LogCategory.system,
        );
        return null;
      }

      final setId = 'followset_${DateTime.now().millisecondsSinceEpoch}';
      final now = DateTime.now();

      final newSet = FollowSet(
        id: setId,
        name: name,
        description: description,
        imageUrl: imageUrl,
        pubkeys: initialPubkeys,
        createdAt: now,
        updatedAt: now,
      );

      _followSets.add(newSet);

      // Publish to Nostr
      await _publishFollowSetToNostr(newSet);

      Log.info(
        'Created new follow set: $name ($setId)',
        name: 'SocialService',
        category: LogCategory.system,
      );

      return newSet;
    } catch (e) {
      Log.error(
        'Failed to create follow set: $e',
        name: 'SocialService',
        category: LogCategory.system,
      );
      return null;
    }
  }

  /// Add a pubkey to a follow set
  Future<bool> addToFollowSet(String setId, String pubkey) async {
    try {
      final setIndex = _followSets.indexWhere((set) => set.id == setId);
      if (setIndex == -1) {
        Log.warning(
          'Follow set not found: $setId',
          name: 'SocialService',
          category: LogCategory.system,
        );
        return false;
      }

      final set = _followSets[setIndex];

      // Check if pubkey is already in the set
      if (set.pubkeys.contains(pubkey)) {
        Log.debug(
          'Pubkey already in follow set: $pubkey',
          name: 'SocialService',
          category: LogCategory.system,
        );
        return true;
      }

      final updatedPubkeys = [...set.pubkeys, pubkey];
      final updatedSet = set.copyWith(
        pubkeys: updatedPubkeys,
        updatedAt: DateTime.now(),
      );

      _followSets[setIndex] = updatedSet;

      // Update on Nostr
      await _publishFollowSetToNostr(updatedSet);

      Log.debug(
        '➕ Added pubkey to follow set "${set.name}": $pubkey',
        name: 'SocialService',
        category: LogCategory.system,
      );

      return true;
    } catch (e) {
      Log.error(
        'Failed to add to follow set: $e',
        name: 'SocialService',
        category: LogCategory.system,
      );
      return false;
    }
  }

  /// Remove a pubkey from a follow set
  Future<bool> removeFromFollowSet(String setId, String pubkey) async {
    try {
      final setIndex = _followSets.indexWhere((set) => set.id == setId);
      if (setIndex == -1) {
        Log.warning(
          'Follow set not found: $setId',
          name: 'SocialService',
          category: LogCategory.system,
        );
        return false;
      }

      final set = _followSets[setIndex];
      final updatedPubkeys = set.pubkeys.where((pk) => pk != pubkey).toList();

      final updatedSet = set.copyWith(
        pubkeys: updatedPubkeys,
        updatedAt: DateTime.now(),
      );

      _followSets[setIndex] = updatedSet;

      // Update on Nostr
      await _publishFollowSetToNostr(updatedSet);

      Log.debug(
        '➖ Removed pubkey from follow set "${set.name}": $pubkey',
        name: 'SocialService',
        category: LogCategory.system,
      );

      return true;
    } catch (e) {
      Log.error(
        'Failed to remove from follow set: $e',
        name: 'SocialService',
        category: LogCategory.system,
      );
      return false;
    }
  }

  /// Update follow set metadata
  Future<bool> updateFollowSet({
    required String setId,
    String? name,
    String? description,
    String? imageUrl,
  }) async {
    try {
      final setIndex = _followSets.indexWhere((set) => set.id == setId);
      if (setIndex == -1) {
        return false;
      }

      final set = _followSets[setIndex];
      final updatedSet = set.copyWith(
        name: name ?? set.name,
        description: description ?? set.description,
        imageUrl: imageUrl ?? set.imageUrl,
        updatedAt: DateTime.now(),
      );

      _followSets[setIndex] = updatedSet;

      // Update on Nostr
      await _publishFollowSetToNostr(updatedSet);

      Log.debug(
        '✏️ Updated follow set: ${updatedSet.name}',
        name: 'SocialService',
        category: LogCategory.system,
      );

      return true;
    } catch (e) {
      Log.error(
        'Failed to update follow set: $e',
        name: 'SocialService',
        category: LogCategory.system,
      );
      return false;
    }
  }

  /// Delete a follow set
  Future<bool> deleteFollowSet(String setId) async {
    try {
      final setIndex = _followSets.indexWhere((set) => set.id == setId);
      if (setIndex == -1) {
        return false;
      }

      final set = _followSets[setIndex];

      // For replaceable events (kind 30000), we don't need a deletion event
      // The event is automatically replaced when publishing with the same d-tag

      _followSets.removeAt(setIndex);

      Log.debug(
        '🗑️ Deleted follow set: ${set.name}',
        name: 'SocialService',
        category: LogCategory.system,
      );

      return true;
    } catch (e) {
      Log.error(
        'Failed to delete follow set: $e',
        name: 'SocialService',
        category: LogCategory.system,
      );
      return false;
    }
  }

  /// Publish follow set to Nostr as NIP-51 kind 30000 event
  Future<void> _publishFollowSetToNostr(FollowSet set) async {
    try {
      if (!_authService.isAuthenticated) {
        Log.warning(
          'Cannot publish follow set - user not authenticated',
          name: 'SocialService',
          category: LogCategory.system,
        );
        return;
      }

      // Create NIP-51 kind 30000 tags
      final tags = <List<String>>[
        ['d', set.id], // Identifier for replaceable event
        ['title', set.name],
        ['client', 'diVine'],
      ];

      // Add description if present
      if (set.description != null && set.description!.isNotEmpty) {
        tags.add(['description', set.description!]);
      }

      // Add image if present
      if (set.imageUrl != null && set.imageUrl!.isNotEmpty) {
        tags.add(['image', set.imageUrl!]);
      }

      // Add pubkeys as 'p' tags
      for (final pubkey in set.pubkeys) {
        tags.add(['p', pubkey]);
      }

      final content = set.description ?? 'Follow set: ${set.name}';

      final event = await _authService.createAndSignEvent(
        kind: 30000, // NIP-51 follow set
        content: content,
        tags: tags,
      );

      if (event != null) {
        // Cache the follow set event immediately after creation
        _personalEventCache?.cacheUserEvent(event);

        final sentEvent = await _nostrService.publishEvent(event);
        if (sentEvent != null) {
          // Update local set with Nostr event ID
          final setIndex = _followSets.indexWhere((s) => s.id == set.id);
          if (setIndex != -1) {
            _followSets[setIndex] = set.copyWith(nostrEventId: event.id);
          }
          Log.debug(
            'Published follow set to Nostr: ${set.name} (${event.id})',
            name: 'SocialService',
            category: LogCategory.system,
          );
        }
      }
    } catch (e) {
      Log.error(
        'Failed to publish follow set to Nostr: $e',
        name: 'SocialService',
        category: LogCategory.system,
      );
    }
  }

  // === PROFILE STATISTICS ===

  /// Get video count for a specific user
  Future<int> getUserVideoCount(String pubkey) async {
    Log.debug(
      '📱 Fetching video count for: $pubkey',
      name: 'SocialService',
      category: LogCategory.system,
    );

    try {
      final completer = Completer<int>();
      var videoCount = 0;

      // Subscribe to user's video events using NIP-71 compliant kinds
      final subscription = _nostrService.subscribe([
        Filter(
          authors: [pubkey],
          kinds:
              NIP71VideoKinds.getAllVideoKinds(), // NIP-71 video kinds: 22, 21, 34236, 34235
        ),
      ]);

      subscription.listen(
        (event) {
          videoCount++;
        },
        onDone: () {
          if (!completer.isCompleted) {
            completer.complete(videoCount);
          }
        },
        onError: (error) {
          Log.error(
            'Error fetching video count: $error',
            name: 'SocialService',
            category: LogCategory.system,
          );
          if (!completer.isCompleted) {
            completer.complete(0);
          }
        },
      );

      final result = await completer.future;
      Log.debug(
        '📱 Video count fetched: $result',
        name: 'SocialService',
        category: LogCategory.system,
      );
      return result;
    } catch (e) {
      Log.error(
        'Error fetching video count: $e',
        name: 'SocialService',
        category: LogCategory.system,
      );
      return 0;
    }
  }

  // === ACCOUNT MANAGEMENT ===

  /// Publishes a NIP-62 "right to be forgotten" deletion request event
  Future<void> publishRightToBeForgotten() async {
    if (!_authService.isAuthenticated) {
      Log.error(
        'Cannot publish deletion request - user not authenticated',
        name: 'SocialService',
        category: LogCategory.system,
      );
      throw Exception('User not authenticated');
    }

    Log.debug(
      '📱️ Publishing NIP-62 right to be forgotten event...',
      name: 'SocialService',
      category: LogCategory.system,
    );

    try {
      // Create NIP-62 deletion request event (Kind 5 with special formatting)
      final event = await _authService.createAndSignEvent(
        kind: 5,
        content:
            'REQUEST: Delete all data associated with this pubkey under right to be forgotten',
        tags: [
          ['p', _authService.currentPublicKeyHex!], // Reference to own pubkey
          ['k', '0'], // Request deletion of Kind 0 (profile) events
          ['k', '1'], // Request deletion of Kind 1 (text note) events
          ['k', '3'], // Request deletion of Kind 3 (contact list) events
          ['k', '6'], // Request deletion of Kind 6 (repost) events
          ['k', '7'], // Request deletion of Kind 7 (reaction) events
          [
            'k',
            '34236',
          ], // Request deletion of Kind 34236 (addressable short video) events per NIP-71
        ],
      );

      if (event == null) {
        throw Exception('Failed to create deletion request event');
      }

      // Publish the deletion request
      final sentEvent = await _nostrService.publishEvent(event);

      if (sentEvent == null) {
        throw Exception('Failed to publish deletion request to relays');
      }

      Log.info(
        'NIP-62 deletion request published: ${event.id}',
        name: 'SocialService',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Error publishing deletion request: $e',
        name: 'SocialService',
        category: LogCategory.system,
      );
      rethrow;
    }
  }

  void dispose() {
    Log.debug(
      '📱️ Disposing SocialService',
      name: 'SocialService',
      category: LogCategory.system,
    );
  }
}
