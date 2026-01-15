// ABOUTME: Social interaction service managing likes, follows, comments and reposts
// ABOUTME: Handles NIP-25 reactions, NIP-02 contact lists, and other social Nostr events

import 'dart:async';
import 'dart:convert';

import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/immediate_completion_helper.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/services/personal_event_cache_service.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/constants/nip71_migration.dart';
import 'package:openvine/models/video_event.dart';

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
    required SubscriptionManager subscriptionManager,
    PersonalEventCacheService? personalEventCache,
  }) : _subscriptionManager = subscriptionManager,
       _personalEventCache = personalEventCache {
    _initialize();
  }
  final NostrClient _nostrService;
  final AuthService _authService;
  final SubscriptionManager _subscriptionManager;
  final PersonalEventCacheService? _personalEventCache;

  // Cache for UI state - reposted events by current user
  final Set<String> _repostedEventIds = <String>{};

  // Cache mapping reposted event IDs to their repost event IDs (needed for deletion)
  final Map<String, String> _repostEventIdToRepostId = <String, String>{};

  // Cache for following list (NIP-02 contact list)
  List<String> _followingPubkeys = <String>[];

  // Cache for follower/following counts
  final Map<String, Map<String, int>> _followerStats =
      <String, Map<String, int>>{};

  // Cache for follow sets (NIP-51 Kind 30000)
  final List<FollowSet> _followSets = <FollowSet>[];

  // Current user's latest Kind 3 event for follow list management
  Event? _currentUserContactListEvent;

  // Managed subscription IDs
  String? _followSubscriptionId;
  String? _repostSubscriptionId;
  String? _userRepostsSubscriptionId;

  /// Initialize the service
  Future<void> _initialize() async {
    Log.debug(
      '🤝 Initializing SocialService',
      name: 'SocialService',
      category: LogCategory.system,
    );

    try {
      // Initialize current user's social data if authenticated
      if (_authService.isAuthenticated) {
        // Load cached following list first for immediate UI display
        await _loadFollowingListFromCache();

        // Load cached personal events for instant access
        await _loadCachedPersonalEvents();

        await _loadUserRepostedEvents();
        await fetchCurrentUserFollowList();
      }

      Log.info(
        'SocialService initialized',
        name: 'SocialService',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'SocialService initialization error: $e',
        name: 'SocialService',
        category: LogCategory.system,
      );
    }
  }

  /// Load cached personal events for instant access on startup
  Future<void> _loadCachedPersonalEvents() async {
    if (_personalEventCache?.isInitialized != true) {
      Log.debug(
        'PersonalEventCache not initialized, skipping cached event loading',
        name: 'SocialService',
        category: LogCategory.system,
      );
      return;
    }

    try {
      // Load cached reposts (Kind 6 events) to populate _repostedEventIds
      final cachedReposts = _personalEventCache!.getEventsByKind(6);
      for (final repostEvent in cachedReposts) {
        _processRepostEvent(repostEvent);
      }

      // Load cached contact lists (Kind 3 events) to populate following data
      final cachedContactLists = _personalEventCache.getEventsByKind(3);
      if (cachedContactLists.isNotEmpty) {
        // Use the most recent contact list event
        final latestContactList =
            cachedContactLists.first; // Already sorted by creation time
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

          // Save to SharedPreferences cache as well
          await _saveFollowingListToCache();
        }
      }

      final stats = _personalEventCache.getCacheStats();
      Log.info(
        '📋 Loaded cached personal events on startup:',
        name: 'SocialService',
        category: LogCategory.system,
      );
      Log.info(
        '  - Total events: ${stats['total_events']}',
        name: 'SocialService',
        category: LogCategory.system,
      );
      Log.info(
        '  - Reposts loaded: ${cachedReposts.length}',
        name: 'SocialService',
        category: LogCategory.system,
      );
      Log.info(
        '  - Contact lists loaded: ${cachedContactLists.length}',
        name: 'SocialService',
        category: LogCategory.system,
      );
      Log.info(
        '  - Following count: ${_followingPubkeys.length}',
        name: 'SocialService',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Failed to load cached personal events: $e',
        name: 'SocialService',
        category: LogCategory.system,
      );
    }
  }

  /// Check if current user has reposted an event
  /// Checks using the addressable ID format for Kind 34236 events
  bool hasReposted(String eventId, {String? pubkey, String? dTag}) {
    // For addressable events, check using addressable ID format
    if (pubkey != null && dTag != null) {
      final addressableId =
          '${NIP71VideoKinds.addressableShortVideo}:$pubkey:$dTag';
      return _repostedEventIds.contains(addressableId);
    }

    // Fallback to event ID for backward compatibility
    return _repostedEventIds.contains(eventId);
  }

  // === FOLLOW SYSTEM GETTERS ===

  /// Get current user's following list
  List<String> get followingPubkeys => List.from(_followingPubkeys);

  /// Check if current user is following a specific pubkey
  bool isFollowing(String pubkey) => _followingPubkeys.contains(pubkey);

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

  /// Loads current user's reposted events from their repost history
  Future<void> _loadUserRepostedEvents() async {
    if (!_authService.isAuthenticated) return;

    try {
      final currentUserPubkey = _authService.currentPublicKeyHex;
      if (currentUserPubkey == null) return;

      Log.debug(
        'Loading user reposted events for: $currentUserPubkey',
        name: 'SocialService',
        category: LogCategory.system,
      );

      // Subscribe to current user's reposts (Kind 6) using SubscriptionManager
      _userRepostsSubscriptionId = await _subscriptionManager
          .createSubscription(
            name: 'user_reposts_$currentUserPubkey',
            filters: [
              Filter(
                authors: [currentUserPubkey],
                kinds: [16], // Generic repost (NIP-18) for video events
              ),
            ],
            onEvent: (event) {
              _processRepostEvent(event);
            },
            onError: (error) => Log.error(
              'Error loading user reposts: $error',
              name: 'SocialService',
              category: LogCategory.system,
            ),
            priority: 3, // Lower priority for historical data
          );
    } catch (e) {
      Log.error(
        'Error loading user reposted events: $e',
        name: 'SocialService',
        category: LogCategory.system,
      );
    }
  }

  // === NIP-02 FOLLOW SYSTEM ===

  /// Fetches current user's follow list from their latest Kind 3 event
  Future<void> fetchCurrentUserFollowList() async {
    if (!_authService.isAuthenticated) return;

    try {
      final currentUserPubkey = _authService.currentPublicKeyHex;
      if (currentUserPubkey == null) return;

      Log.debug(
        '📱 Loading follow list for: $currentUserPubkey',
        name: 'SocialService',
        category: LogCategory.system,
      );

      // ✅ Use immediate completion for contact list query
      final eventStream = _nostrService.subscribe([
        Filter(
          authors: [currentUserPubkey],
          kinds: [3], // NIP-02 contact list
          limit: 1, // Get most recent only
        ),
      ]);

      final contactListEvent =
          await ContactListCompletionHelper.queryContactList(
            eventStream: eventStream,
            pubkey: currentUserPubkey,
            fallbackTimeoutSeconds: 10,
          );

      if (contactListEvent != null) {
        Log.debug(
          '✅ Contact list received immediately for $currentUserPubkey',
          name: 'SocialService',
          category: LogCategory.system,
        );
        _processContactListEvent(contactListEvent);
      } else {
        Log.debug(
          '⏰ No contact list found for $currentUserPubkey',
          name: 'SocialService',
          category: LogCategory.system,
        );
      }
    } catch (e) {
      Log.error(
        'Error fetching follow list: $e',
        name: 'SocialService',
        category: LogCategory.system,
      );
    }
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
      Log.info(
        'Updated follow list: ${_followingPubkeys.length} following',
        name: 'SocialService',
        category: LogCategory.system,
      );

      // Persist following list to local storage for aggressive caching
      _saveFollowingListToCache();
    }
  }

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

      // Cache the result
      _followerStats[pubkey] = stats;

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

  /// Fetch follower stats from the network
  Future<Map<String, int>> _fetchFollowerStats(String pubkey) async {
    try {
      // ✅ Use immediate completion for both queries
      var followingCount = 0;
      var followersCount = 0;

      // 1. ✅ Get following count with immediate completion
      final followingEventStream = _nostrService.subscribe([
        Filter(authors: [pubkey], kinds: [3], limit: 1),
      ]);

      final followingEvent = await ContactListCompletionHelper.queryContactList(
        eventStream: followingEventStream,
        pubkey: pubkey,
        fallbackTimeoutSeconds: 8,
      );

      if (followingEvent != null) {
        followingCount = followingEvent.tags
            .where((tag) => tag.isNotEmpty && tag[0] == 'p')
            .length;
        Log.debug(
          '✅ Following count received immediately: $followingCount for $pubkey',
          name: 'SocialService',
          category: LogCategory.system,
        );
      }

      // 2. ✅ Get followers count with immediate completion
      final followersEventStream = _nostrService.subscribe([
        Filter(
          kinds: [3],
          p: [pubkey], // Events that mention this pubkey in p tags
        ),
      ]);

      // Use exhaustive mode to collect all followers
      final config = CompletionConfig(
        mode: CompletionMode.exhaustive,
        fallbackTimeoutSeconds: 8,
        serviceName: 'FollowersQuery',
        logCategory: LogCategory.system,
      );

      final followerPubkeys = <String>{};
      final followersCompleter = Completer<int>();

      ImmediateCompletionHelper.createImmediateSubscription(
        eventStream: followersEventStream,
        config: config,
        onEvent: (event) {
          // Each unique author who has this pubkey in their contact list is a follower
          followerPubkeys.add(event.pubkey);
        },
        onComplete: (result) {
          followersCount = followerPubkeys.length;
          Log.debug(
            '✅ Followers query completed: $followersCount followers for $pubkey',
            name: 'SocialService',
            category: LogCategory.system,
          );
          if (!followersCompleter.isCompleted) {
            followersCompleter.complete(followersCount);
          }
        },
        onError: (error) {
          Log.error(
            'Error fetching followers count: $error',
            name: 'SocialService',
            category: LogCategory.system,
          );
          if (!followersCompleter.isCompleted) {
            followersCompleter.complete(followerPubkeys.length);
          }
        },
      );

      await followersCompleter.future;

      return {'followers': followersCount, 'following': followingCount};
    } catch (e) {
      Log.error(
        'Error fetching follower stats: $e',
        name: 'SocialService',
        category: LogCategory.system,
      );
      return {'followers': 0, 'following': 0};
    }
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

  // === REPOST SYSTEM (NIP-18) ===

  /// Toggles repost state for a video event (repost/unrepost)
  /// Uses NIP-18 for repost (Kind 6) and NIP-09 for unrepost (Kind 5)
  Future<void> toggleRepost(VideoEvent videoToRepost) async {
    if (!_authService.isAuthenticated) {
      Log.error(
        'Cannot repost - user not authenticated',
        name: 'SocialService',
        category: LogCategory.system,
      );
      throw Exception('User not authenticated');
    }

    Log.debug(
      '🔄 Toggling repost for video: ${videoToRepost.id}',
      name: 'SocialService',
      category: LogCategory.system,
    );

    // Extract d-tag from video's rawTags
    final dTagValue = videoToRepost.rawTags['d'];
    if (dTagValue == null || dTagValue.isEmpty) {
      throw Exception('Cannot repost: Video event missing required d tag');
    }

    // Check repost state using addressable ID format
    final addressableId =
        '${NIP71VideoKinds.addressableShortVideo}:${videoToRepost.pubkey}:$dTagValue';
    final wasReposted = _repostedEventIds.contains(addressableId);

    try {
      if (!wasReposted) {
        // Repost the video
        Log.debug(
          '➕ Adding repost for video: ${videoToRepost.id}',
          name: 'SocialService',
          category: LogCategory.system,
        );

        // Create NIP-18 generic repost event (Kind 16) for non-kind-1 events
        final event = await _authService.createAndSignEvent(
          kind: 16,
          content: '',
          tags: [
            ['k', '34236'], // Required k tag for generic repost
            ['a', addressableId],
            ['p', videoToRepost.pubkey],
          ],
        );

        if (event == null) {
          throw Exception('Failed to create repost event');
        }

        // Cache immediately
        _personalEventCache?.cacheUserEvent(event);

        // Publish
        final sentEvent = await _nostrService.publishEvent(event);
        if (sentEvent == null) {
          throw Exception('Failed to publish repost to relays');
        }

        // Update local state
        _repostedEventIds.add(addressableId);
        _repostEventIdToRepostId[addressableId] = event.id;

        Log.info(
          'Repost published for video: ${videoToRepost.id}',
          name: 'SocialService',
          category: LogCategory.system,
        );
      } else {
        // Unrepost by publishing NIP-09 deletion event
        Log.debug(
          '➖ Removing repost for video: ${videoToRepost.id}',
          name: 'SocialService',
          category: LogCategory.system,
        );

        final repostEventId = _repostEventIdToRepostId[addressableId];
        if (repostEventId != null) {
          await _unrepostEvent(repostEventId);

          // Update local state
          _repostedEventIds.remove(addressableId);
          _repostEventIdToRepostId.remove(addressableId);

          Log.info(
            'Unrepost (deletion) published for video: ${videoToRepost.id}',
            name: 'SocialService',
            category: LogCategory.system,
          );
        } else {
          Log.warning(
            'Cannot unrepost - repost event ID not found',
            name: 'SocialService',
            category: LogCategory.system,
          );

          // Fallback: remove from local state only
          _repostedEventIds.remove(addressableId);
        }
      }
    } catch (e) {
      Log.error(
        'Error toggling repost: $e',
        name: 'SocialService',
        category: LogCategory.system,
      );
      rethrow;
    }
  }

  /// Publishes a NIP-09 deletion event for unrepost functionality
  Future<void> _unrepostEvent(String repostEventId) async {
    try {
      // Create NIP-09 deletion event (Kind 5)
      final event = await _authService.createAndSignEvent(
        kind: 5,
        content: 'Unreposted',
        tags: [
          ['e', repostEventId], // Reference to the repost event to delete
        ],
      );

      if (event == null) {
        throw Exception('Failed to create unrepost deletion event');
      }

      // Cache immediately
      _personalEventCache?.cacheUserEvent(event);

      // Publish
      final sentEvent = await _nostrService.publishEvent(event);
      if (sentEvent == null) {
        throw Exception('Failed to publish unrepost to relays');
      }

      Log.debug(
        'Unrepost deletion event published: ${event.id}',
        name: 'SocialService',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Error publishing unrepost deletion: $e',
        name: 'SocialService',
        category: LogCategory.system,
      );
      rethrow;
    }
  }

  /// Reposts a Nostr event (Kind 6)
  Future<void> repostEvent(Event eventToRepost) async {
    if (!_authService.isAuthenticated) {
      Log.error(
        'Cannot repost - user not authenticated',
        name: 'SocialService',
        category: LogCategory.system,
      );
      throw Exception('User not authenticated');
    }

    Log.debug(
      'Reposting event: ${eventToRepost.id}',
      name: 'SocialService',
      category: LogCategory.system,
    );

    try {
      // Create NIP-18 repost event (Kind 6)
      // For addressable events, we need to extract the 'd' tag value
      String? dTagValue;
      for (final tag in eventToRepost.tags) {
        if (tag.isNotEmpty && tag[0] == 'd' && tag.length > 1) {
          dTagValue = tag[1];
          break;
        }
      }

      if (dTagValue == null) {
        throw Exception('Cannot repost: Video event missing required d tag');
      }

      // Use 'a' tag for addressable event reference
      final repostTags = <List<String>>[
        [
          'k',
          '${NIP71VideoKinds.addressableShortVideo}',
        ], // Required k tag for generic repost (kind 16)
        [
          'a',
          '${NIP71VideoKinds.addressableShortVideo}:${eventToRepost.pubkey}:$dTagValue',
        ],
        ['p', eventToRepost.pubkey], // Reference to original author
      ];

      final event = await _authService.createAndSignEvent(
        kind: 16, // Generic repost event for non-kind-1 events (NIP-18)
        content: '', // Content is typically empty for reposts
        tags: repostTags,
      );

      if (event == null) {
        throw Exception('Failed to create repost event');
      }

      // Cache the repost event immediately after creation
      _personalEventCache?.cacheUserEvent(event);

      // Publish the repost event
      final sentEvent = await _nostrService.publishEvent(event);

      if (sentEvent == null) {
        throw Exception('Failed to publish repost to relays');
      }

      // Track the repost locally using the addressable ID format
      final addressableId =
          '${NIP71VideoKinds.addressableShortVideo}:${eventToRepost.pubkey}:$dTagValue';
      _repostedEventIds.add(addressableId);
      _repostEventIdToRepostId[addressableId] = event.id;

      Log.info(
        'Event reposted successfully: ${event.id}',
        name: 'SocialService',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Error reposting event: $e',
        name: 'SocialService',
        category: LogCategory.system,
      );
      rethrow;
    }
  }

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

  /// Save following list to local storage for aggressive caching
  Future<void> _saveFollowingListToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUserPubkey = _authService.currentPublicKeyHex;
      if (currentUserPubkey != null) {
        final key = 'following_list_$currentUserPubkey';
        await prefs.setString(key, jsonEncode(_followingPubkeys));
        Log.debug(
          '💾 Saved following list to cache: ${_followingPubkeys.length} users',
          name: 'SocialService',
          category: LogCategory.system,
        );
      }
    } catch (e) {
      Log.error(
        'Failed to save following list to cache: $e',
        name: 'SocialService',
        category: LogCategory.system,
      );
    }
  }

  /// Load following list from local storage
  Future<void> _loadFollowingListFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUserPubkey = _authService.currentPublicKeyHex;
      if (currentUserPubkey != null) {
        final key = 'following_list_$currentUserPubkey';
        final cached = prefs.getString(key);
        if (cached != null) {
          final List<dynamic> decoded = jsonDecode(cached);
          _followingPubkeys = decoded.cast<String>();
          Log.info(
            '📋 Loaded cached following list: ${_followingPubkeys.length} users',
            name: 'SocialService',
            category: LogCategory.system,
          );
        }
      }
    } catch (e) {
      Log.error(
        'Failed to load following list from cache: $e',
        name: 'SocialService',
        category: LogCategory.system,
      );
    }
  }

  void dispose() {
    Log.debug(
      '📱️ Disposing SocialService',
      name: 'SocialService',
      category: LogCategory.system,
    );

    // Cancel all managed subscriptions
    if (_followSubscriptionId != null) {
      _subscriptionManager.cancelSubscription(_followSubscriptionId!);
      _followSubscriptionId = null;
    }
    if (_repostSubscriptionId != null) {
      _subscriptionManager.cancelSubscription(_repostSubscriptionId!);
      _repostSubscriptionId = null;
    }
    if (_userRepostsSubscriptionId != null) {
      _subscriptionManager.cancelSubscription(_userRepostsSubscriptionId!);
      _userRepostsSubscriptionId = null;
    }
  }

  /// Process a repost event and extract the reposted event ID
  /// Handles 'a' tags for addressable events
  void _processRepostEvent(Event repostEvent) {
    // Check for 'a' tags (addressable event references)
    for (final tag in repostEvent.tags) {
      if (tag.isNotEmpty && tag[0] == 'a' && tag.length > 1) {
        // Parse the 'a' tag format: "kind:pubkey:d-tag-value"
        final parts = tag[1].split(':');
        if (parts.length >= 3 &&
            parts[0] == '${NIP71VideoKinds.addressableShortVideo}') {
          final addressableId = tag[1];
          _repostedEventIds.add(addressableId);
          _repostEventIdToRepostId[addressableId] = repostEvent.id;
          Log.debug(
            '📱 Cached user repost of addressable event: $addressableId (repost: ${repostEvent.id})',
            name: 'SocialService',
            category: LogCategory.system,
          );
          return;
        }
      }
    }
  }
}
