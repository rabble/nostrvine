// ABOUTME: Social interaction service managing follow sets (NIP-51 Kind 30000)
// ABOUTME: Note: NIP-02 contact list (follow/unfollow) is handled by FollowRepository
// ABOUTME: Note: Follower count stats are handled by FollowRepository
// ABOUTME: Note: NIP-18 reposts are handled by RepostsRepository

import 'dart:async';

import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/constants/nip71_migration.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/personal_event_cache_service.dart';
import 'package:unified_logger/unified_logger.dart';

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
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String?,
    imageUrl: json['imageUrl'] as String?,
    pubkeys: List<String>.from(json['pubkeys'] as Iterable? ?? []),
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    nostrEventId: json['nostrEventId'] as String?,
  );
}

/// Service for managing social interactions on Nostr (follow sets).
class SocialService {
  SocialService(
    this._nostrService,
    this._authService, {
    PersonalEventCacheService? personalEventCache,
  }) : _personalEventCache = personalEventCache;

  final NostrClient _nostrService;
  final AuthService _authService;
  final PersonalEventCacheService? _personalEventCache;

  // Cache for follow sets (NIP-51 Kind 30000)
  final List<FollowSet> _followSets = <FollowSet>[];

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
            '${NIP71VideoKinds.addressableShortVideo}',
          ], // Request deletion of addressable short video events per NIP-71
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
