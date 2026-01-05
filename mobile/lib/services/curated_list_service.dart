// ABOUTME: Service for managing NIP-51 curated lists (kind 30005) for video collections
// ABOUTME: Handles creation, updates, and management of user's video lists
//
// WARNING: "Private" lists (isPublic: false) are stored in SharedPreferences only.
// They are EPHEMERAL - lost if user clears app data, uninstalls, or switches phones.
// There is NO backup mechanism for private lists.
//
// TODO: Implement encrypted private lists using NIP-44 to encrypt list content
// before publishing to Nostr. This would allow private lists to be backed up
// on relays while remaining unreadable to others. Until then, "private" lists
// are effectively broken - they provide no real privacy (just local-only) and
// no durability (no backup).

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/utils/curated_list_ext.dart';
import 'package:openvine/utils/nostr_event_ext.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Enum for playlist ordering options
enum PlayOrder {
  chronological, // Order by date added
  reverse, // Reverse chronological order
  manual, // Custom manual order
  shuffle, // Randomized order
}

/// Extension for PlayOrder serialization
extension PlayOrderExtension on PlayOrder {
  String get value {
    switch (this) {
      case PlayOrder.chronological:
        return 'chronological';
      case PlayOrder.reverse:
        return 'reverse';
      case PlayOrder.manual:
        return 'manual';
      case PlayOrder.shuffle:
        return 'shuffle';
    }
  }

  static PlayOrder fromString(String value) {
    switch (value) {
      case 'chronological':
        return PlayOrder.chronological;
      case 'reverse':
        return PlayOrder.reverse;
      case 'manual':
        return PlayOrder.manual;
      case 'shuffle':
        return PlayOrder.shuffle;
      default:
        return PlayOrder.chronological;
    }
  }
}

/// Represents a curated list of videos with enhanced playlist features
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
class CuratedList {
  const CuratedList({
    required this.id,
    required this.name,
    required this.videoEventIds,
    required this.createdAt,
    required this.updatedAt,
    this.pubkey,
    this.description,
    this.imageUrl,
    this.isPublic = true,
    this.nostrEventId,
    this.tags = const [],
    this.isCollaborative = false,
    this.allowedCollaborators = const [],
    this.thumbnailEventId,
    this.playOrder = PlayOrder.chronological,
  });

  final String id;
  final String name;
  final String? pubkey; // Creator's pubkey for attribution
  final String? description;
  final String? imageUrl;
  final List<String> videoEventIds;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Whether to publish this list to Nostr relays.
  /// WARNING: isPublic=false means LOCAL-ONLY storage (SharedPreferences).
  /// Private lists have NO backup - lost on app uninstall or device change.
  /// TODO: Implement NIP-44 encrypted lists for true private + backed up lists.
  final bool isPublic;
  final String? nostrEventId;
  final List<String> tags; // Tags for categorization and discovery
  final bool isCollaborative; // Allow others to add videos
  final List<String> allowedCollaborators; // Pubkeys allowed to collaborate
  final String? thumbnailEventId; // Featured video as thumbnail
  final PlayOrder playOrder; // How videos should be ordered

  CuratedList copyWith({
    String? id,
    String? name,
    String? pubkey,
    String? description,
    String? imageUrl,
    List<String>? videoEventIds,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isPublic,
    String? nostrEventId,
    List<String>? tags,
    bool? isCollaborative,
    List<String>? allowedCollaborators,
    String? thumbnailEventId,
    PlayOrder? playOrder,
  }) => CuratedList(
    id: id ?? this.id,
    name: name ?? this.name,
    pubkey: pubkey ?? this.pubkey,
    description: description ?? this.description,
    imageUrl: imageUrl ?? this.imageUrl,
    videoEventIds: videoEventIds ?? this.videoEventIds,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    isPublic: isPublic ?? this.isPublic,
    nostrEventId: nostrEventId ?? this.nostrEventId,
    tags: tags ?? this.tags,
    isCollaborative: isCollaborative ?? this.isCollaborative,
    allowedCollaborators: allowedCollaborators ?? this.allowedCollaborators,
    thumbnailEventId: thumbnailEventId ?? this.thumbnailEventId,
    playOrder: playOrder ?? this.playOrder,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'pubkey': pubkey,
    'description': description,
    'imageUrl': imageUrl,
    'videoEventIds': videoEventIds,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'isPublic': isPublic,
    'nostrEventId': nostrEventId,
    'tags': tags,
    'isCollaborative': isCollaborative,
    'allowedCollaborators': allowedCollaborators,
    'thumbnailEventId': thumbnailEventId,
    'playOrder': playOrder.value,
  };

  static CuratedList fromJson(Map<String, dynamic> json) => CuratedList(
    id: json['id'],
    name: json['name'],
    pubkey: json['pubkey'],
    description: json['description'],
    imageUrl: json['imageUrl'],
    videoEventIds: List<String>.from(json['videoEventIds'] ?? []),
    createdAt: DateTime.parse(json['createdAt']),
    updatedAt: DateTime.parse(json['updatedAt']),
    isPublic: json['isPublic'] ?? true,
    nostrEventId: json['nostrEventId'],
    tags: List<String>.from(json['tags'] ?? []),
    isCollaborative: json['isCollaborative'] ?? false,
    allowedCollaborators: List<String>.from(json['allowedCollaborators'] ?? []),
    thumbnailEventId: json['thumbnailEventId'],
    playOrder: PlayOrderExtension.fromString(
      json['playOrder'] ?? 'chronological',
    ),
  );
}

/// Callback type for list subscription events
/// Called with listId and the video IDs in that list
typedef OnListSubscribedCallback =
    Future<void> Function(String listId, List<String> videoIds);

/// Callback type for list unsubscription events
/// Called with listId when a list is unsubscribed
typedef OnListUnsubscribedCallback = void Function(String listId);

/// Service for managing NIP-51 curated lists
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
class CuratedListService extends ChangeNotifier {
  CuratedListService({
    required NostrClient nostrService,
    required AuthService authService,
    required SharedPreferences prefs,
    OnListSubscribedCallback? onListSubscribed,
    OnListUnsubscribedCallback? onListUnsubscribed,
  }) : _nostrService = nostrService,
       _authService = authService,
       _prefs = prefs,
       _onListSubscribed = onListSubscribed,
       _onListUnsubscribed = onListUnsubscribed {
    _loadLists();
    _loadSubscribedListIds();
  }
  final NostrClient _nostrService;
  final AuthService _authService;
  final SharedPreferences _prefs;

  /// Callback invoked when a list is subscribed (for video cache sync)
  OnListSubscribedCallback? _onListSubscribed;

  /// Callback invoked when a list is unsubscribed (for video cache cleanup)
  OnListUnsubscribedCallback? _onListUnsubscribed;

  /// Sets the callback for list subscription events
  /// Used by the provider layer to wire up SubscribedListVideoCache
  void setOnListSubscribed(OnListSubscribedCallback? callback) {
    _onListSubscribed = callback;
  }

  /// Sets the callback for list unsubscription events
  /// Used by the provider layer to wire up SubscribedListVideoCache
  void setOnListUnsubscribed(OnListUnsubscribedCallback? callback) {
    _onListUnsubscribed = callback;
  }

  static const String listsStorageKey = 'curated_lists';
  static const String subscribedListsStorageKey = 'subscribed_list_ids';
  static const String defaultListId = 'my_vine_list';

  final List<CuratedList> _lists = [];
  final Set<String> _subscribedListIds = {};
  bool _isInitialized = false;

  // Track relay sync status
  bool _hasSyncedWithRelays = false;

  // Getters
  List<CuratedList> get lists => List.unmodifiable(_lists);
  bool get isInitialized => _isInitialized;

  /// Get all subscribed list IDs
  Set<String> get subscribedListIds => Set.unmodifiable(_subscribedListIds);

  /// Get all subscribed lists
  List<CuratedList> get subscribedLists {
    return _lists
        .where((list) => _subscribedListIds.contains(list.id))
        .toList();
  }

  /// Initialize the service and create default list if needed.
  ///
  /// This method returns quickly after loading local cache.
  /// Relay sync happens in background and does not block initialization.
  Future<void> initialize() async {
    try {
      if (!_authService.isAuthenticated) {
        Log.warning(
          'Cannot initialize curated lists - user not authenticated',
          name: 'CuratedListService',
          category: LogCategory.system,
        );
        return;
      }

      // Create default list if it doesn't exist
      if (!hasDefaultList()) {
        await _createDefaultList();
      }

      // Mark initialized IMMEDIATELY after local cache is ready
      // This allows downstream consumers to access cached lists without waiting
      _isInitialized = true;
      notifyListeners();
      Log.info(
        'Curated list service initialized with ${_lists.length} lists (local cache ready)',
        name: 'CuratedListService',
        category: LogCategory.system,
      );

      // Sync with relays in BACKGROUND - does not block initialization
      // When relay sync completes, it will merge new lists and notify listeners
      unawaited(_syncWithRelaysInBackground());
    } catch (e) {
      Log.error(
        'Failed to initialize curated list service: $e',
        name: 'CuratedListService',
        category: LogCategory.system,
      );
    }
  }

  /// Sync with relays in background without blocking.
  /// Merges relay data with local cache when complete.
  Future<void> _syncWithRelaysInBackground() async {
    try {
      await fetchUserListsFromRelays();
      Log.info(
        'Background relay sync complete, now have ${_lists.length} lists',
        name: 'CuratedListService',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Background relay sync failed: $e',
        name: 'CuratedListService',
        category: LogCategory.system,
      );
    }
  }

  /// Check if default list exists
  bool hasDefaultList() => _lists.any((list) => list.id == defaultListId);

  /// Get the default "My List" for quick adding
  CuratedList? getDefaultList() {
    try {
      return _lists.firstWhere((list) => list.id == defaultListId);
    } catch (e) {
      return null;
    }
  }

  /// Create a new curated list with enhanced playlist features
  Future<CuratedList?> createList({
    required String name,
    String? description,
    String? imageUrl,
    bool isPublic = true,
    List<String> tags = const [],
    bool isCollaborative = false,
    List<String> allowedCollaborators = const [],
    String? thumbnailEventId,
    PlayOrder playOrder = PlayOrder.chronological,
  }) async {
    return _createList(
      name: name,
      description: description,
      imageUrl: imageUrl,
      isPublic: isPublic,
      tags: tags,
      isCollaborative: isCollaborative,
      allowedCollaborators: allowedCollaborators,
      thumbnailEventId: thumbnailEventId,
      playOrder: playOrder,
    );
  }

  /// Internal method to create a list with optional explicit ID
  Future<CuratedList?> _createList({
    required String name,
    String? id,
    String? description,
    String? imageUrl,
    bool isPublic = true,
    List<String> tags = const [],
    bool isCollaborative = false,
    List<String> allowedCollaborators = const [],
    String? thumbnailEventId,
    PlayOrder playOrder = PlayOrder.chronological,
  }) async {
    try {
      final now = DateTime.now();
      final listId = id ?? 'list_${now.millisecondsSinceEpoch}';

      final newList = CuratedList(
        id: listId,
        name: name,
        description: description,
        imageUrl: imageUrl,
        videoEventIds: [],
        createdAt: now,
        updatedAt: now,
        isPublic: isPublic,
        tags: tags,
        isCollaborative: isCollaborative,
        allowedCollaborators: allowedCollaborators,
        thumbnailEventId: thumbnailEventId,
        playOrder: playOrder,
      );

      _lists.add(newList);
      await _saveLists();

      // Publish to Nostr if user is authenticated and list is public
      if (_authService.isAuthenticated && isPublic) {
        await _publishListToNostr(newList);
      }

      Log.info(
        'Created new curated list: $name ($listId)',
        name: 'CuratedListService',
        category: LogCategory.system,
      );

      return newList;
    } catch (e) {
      Log.error(
        'Failed to create curated list: $e',
        name: 'CuratedListService',
        category: LogCategory.system,
      );
      return null;
    }
  }

  /// Add video to a list
  Future<bool> addVideoToList(String listId, String videoEventId) async {
    try {
      final listIndex = _lists.indexWhere((list) => list.id == listId);
      if (listIndex == -1) {
        Log.warning(
          'List not found: $listId',
          name: 'CuratedListService',
          category: LogCategory.system,
        );
        return false;
      }

      final list = _lists[listIndex];

      // Check if video is already in the list
      if (list.videoEventIds.contains(videoEventId)) {
        Log.warning(
          'Video already in list: $videoEventId',
          name: 'CuratedListService',
          category: LogCategory.system,
        );
        return true; // Return true since it's already there
      }

      // Add video to list
      final updatedVideoIds = [...list.videoEventIds, videoEventId];
      final updatedList = list.copyWith(
        videoEventIds: updatedVideoIds,
        updatedAt: DateTime.now(),
      );

      _lists[listIndex] = updatedList;
      await _saveLists();

      // Update on Nostr if public
      if (updatedList.isPublic && _authService.isAuthenticated) {
        await _publishListToNostr(updatedList);
      }

      Log.debug(
        '➕ Added video to list "${list.name}": $videoEventId',
        name: 'CuratedListService',
        category: LogCategory.system,
      );

      return true;
    } catch (e) {
      Log.error(
        'Failed to add video to list: $e',
        name: 'CuratedListService',
        category: LogCategory.system,
      );
      return false;
    }
  }

  /// Remove video from a list
  Future<bool> removeVideoFromList(String listId, String videoEventId) async {
    try {
      final listIndex = _lists.indexWhere((list) => list.id == listId);
      if (listIndex == -1) {
        Log.warning(
          'List not found: $listId',
          name: 'CuratedListService',
          category: LogCategory.system,
        );
        return false;
      }

      final list = _lists[listIndex];
      final updatedVideoIds = list.videoEventIds
          .where((id) => id != videoEventId)
          .toList();

      final updatedList = list.copyWith(
        videoEventIds: updatedVideoIds,
        updatedAt: DateTime.now(),
      );

      _lists[listIndex] = updatedList;
      await _saveLists();

      // Update on Nostr if public
      if (updatedList.isPublic && _authService.isAuthenticated) {
        await _publishListToNostr(updatedList);
      }

      Log.debug(
        '➖ Removed video from list "${list.name}": $videoEventId',
        name: 'CuratedListService',
        category: LogCategory.system,
      );

      return true;
    } catch (e) {
      Log.error(
        'Failed to remove video from list: $e',
        name: 'CuratedListService',
        category: LogCategory.system,
      );
      return false;
    }
  }

  /// Check if video is in a specific list
  bool isVideoInList(String listId, String videoEventId) {
    final list = _lists.where((l) => l.id == listId).firstOrNull;
    return list?.videoEventIds.contains(videoEventId) ?? false;
  }

  /// Check if video is in default list
  bool isVideoInDefaultList(String videoEventId) =>
      isVideoInList(defaultListId, videoEventId);

  /// Get list by ID
  CuratedList? getListById(String listId) {
    try {
      return _lists.firstWhere((list) => list.id == listId);
    } catch (e) {
      return null;
    }
  }

  /// Update list metadata with enhanced playlist features
  Future<bool> updateList({
    required String listId,
    String? name,
    String? description,
    String? imageUrl,
    bool? isPublic,
    List<String>? tags,
    bool? isCollaborative,
    List<String>? allowedCollaborators,
    String? thumbnailEventId,
    PlayOrder? playOrder,
  }) async {
    try {
      final listIndex = _lists.indexWhere((list) => list.id == listId);
      if (listIndex == -1) {
        return false;
      }

      final list = _lists[listIndex];
      final updatedList = list.copyWith(
        name: name ?? list.name,
        description: description ?? list.description,
        imageUrl: imageUrl ?? list.imageUrl,
        isPublic: isPublic ?? list.isPublic,
        tags: tags ?? list.tags,
        isCollaborative: isCollaborative ?? list.isCollaborative,
        allowedCollaborators: allowedCollaborators ?? list.allowedCollaborators,
        thumbnailEventId: thumbnailEventId ?? list.thumbnailEventId,
        playOrder: playOrder ?? list.playOrder,
        updatedAt: DateTime.now(),
      );

      _lists[listIndex] = updatedList;
      await _saveLists();

      // Update on Nostr if public
      if (updatedList.isPublic && _authService.isAuthenticated) {
        await _publishListToNostr(updatedList);
      }

      Log.debug(
        '✏️ Updated list: ${updatedList.name}',
        name: 'CuratedListService',
        category: LogCategory.system,
      );

      return true;
    } catch (e) {
      Log.error(
        'Failed to update list: $e',
        name: 'CuratedListService',
        category: LogCategory.system,
      );
      return false;
    }
  }

  /// Delete a list
  Future<bool> deleteList(String listId) async {
    try {
      // Don't allow deleting the default list
      if (listId == defaultListId) {
        Log.warning(
          'Cannot delete default list',
          name: 'CuratedListService',
          category: LogCategory.system,
        );
        return false;
      }

      final listIndex = _lists.indexWhere((list) => list.id == listId);
      if (listIndex == -1) {
        return false;
      }

      final list = _lists[listIndex];

      // For replaceable events (kind 30005), we don't need a deletion event
      // The event is automatically replaced when publishing with the same d-tag

      _lists.removeAt(listIndex);
      await _saveLists();

      Log.debug(
        '📱️ Deleted list: ${list.name}',
        name: 'CuratedListService',
        category: LogCategory.system,
      );

      return true;
    } catch (e) {
      Log.error(
        'Failed to delete list: $e',
        name: 'CuratedListService',
        category: LogCategory.system,
      );
      return false;
    }
  }

  // === ENHANCED PLAYLIST FEATURES ===

  /// Reorder videos in a playlist (manual play order)
  Future<bool> reorderVideos(String listId, List<String> newOrder) async {
    try {
      final listIndex = _lists.indexWhere((list) => list.id == listId);
      if (listIndex == -1) {
        Log.warning(
          'List not found: $listId',
          name: 'CuratedListService',
          category: LogCategory.system,
        );
        return false;
      }

      final list = _lists[listIndex];

      // Validate that all current videos are included in the new order
      final currentVideos = Set<String>.from(list.videoEventIds);
      final newOrderSet = Set<String>.from(newOrder);

      if (currentVideos.difference(newOrderSet).isNotEmpty ||
          newOrderSet.difference(currentVideos).isNotEmpty) {
        Log.warning(
          'Invalid reorder: video lists do not match',
          name: 'CuratedListService',
          category: LogCategory.system,
        );
        return false;
      }

      final updatedList = list.copyWith(
        videoEventIds: newOrder,
        playOrder: PlayOrder.manual, // Set to manual when reordering
        updatedAt: DateTime.now(),
      );

      _lists[listIndex] = updatedList;
      await _saveLists();

      // Update on Nostr if public
      if (updatedList.isPublic && _authService.isAuthenticated) {
        await _publishListToNostr(updatedList);
      }

      Log.debug(
        '📱 Reordered videos in list "${list.name}"',
        name: 'CuratedListService',
        category: LogCategory.system,
      );

      return true;
    } catch (e) {
      Log.error(
        'Failed to reorder videos: $e',
        name: 'CuratedListService',
        category: LogCategory.system,
      );
      return false;
    }
  }

  /// Get ordered video list based on play order setting
  List<String> getOrderedVideoIds(String listId) {
    final list = getListById(listId);
    if (list == null) return [];

    switch (list.playOrder) {
      case PlayOrder.chronological:
        return list.videoEventIds; // Already in chronological order
      case PlayOrder.reverse:
        return list.videoEventIds.reversed.toList();
      case PlayOrder.manual:
        return list.videoEventIds; // Manual order as stored
      case PlayOrder.shuffle:
        final shuffled = List<String>.from(list.videoEventIds);
        shuffled.shuffle();
        return shuffled;
    }
  }

  /// Add collaborator to a list
  Future<bool> addCollaborator(String listId, String pubkey) async {
    try {
      final listIndex = _lists.indexWhere((list) => list.id == listId);
      if (listIndex == -1) {
        return false;
      }

      final list = _lists[listIndex];
      if (!list.isCollaborative) {
        Log.warning(
          'Cannot add collaborator - list is not collaborative',
          name: 'CuratedListService',
          category: LogCategory.system,
        );
        return false;
      }

      if (list.allowedCollaborators.contains(pubkey)) {
        Log.debug(
          'User already a collaborator: $pubkey',
          name: 'CuratedListService',
          category: LogCategory.system,
        );
        return true;
      }

      final updatedCollaborators = [...list.allowedCollaborators, pubkey];
      final updatedList = list.copyWith(
        allowedCollaborators: updatedCollaborators,
        updatedAt: DateTime.now(),
      );

      _lists[listIndex] = updatedList;
      await _saveLists();

      // Update on Nostr if public
      if (updatedList.isPublic && _authService.isAuthenticated) {
        await _publishListToNostr(updatedList);
      }

      Log.debug(
        '✅ Added collaborator to list "${list.name}": $pubkey',
        name: 'CuratedListService',
        category: LogCategory.system,
      );

      return true;
    } catch (e) {
      Log.error(
        'Failed to add collaborator: $e',
        name: 'CuratedListService',
        category: LogCategory.system,
      );
      return false;
    }
  }

  /// Remove collaborator from a list
  Future<bool> removeCollaborator(String listId, String pubkey) async {
    try {
      final listIndex = _lists.indexWhere((list) => list.id == listId);
      if (listIndex == -1) {
        return false;
      }

      final list = _lists[listIndex];
      final updatedCollaborators = list.allowedCollaborators
          .where((collaborator) => collaborator != pubkey)
          .toList();

      final updatedList = list.copyWith(
        allowedCollaborators: updatedCollaborators,
        updatedAt: DateTime.now(),
      );

      _lists[listIndex] = updatedList;
      await _saveLists();

      // Update on Nostr if public
      if (updatedList.isPublic && _authService.isAuthenticated) {
        await _publishListToNostr(updatedList);
      }

      Log.debug(
        '➖ Removed collaborator from list "${list.name}": $pubkey',
        name: 'CuratedListService',
        category: LogCategory.system,
      );

      return true;
    } catch (e) {
      Log.error(
        'Failed to remove collaborator: $e',
        name: 'CuratedListService',
        category: LogCategory.system,
      );
      return false;
    }
  }

  /// Check if a user can collaborate on a list
  bool canCollaborate(String listId, String pubkey) {
    final list = getListById(listId);
    if (list == null) return false;

    // List owner can always collaborate
    if (_authService.currentPublicKeyHex == pubkey) return true;

    // Check if collaborative and user is allowed
    return list.isCollaborative && list.allowedCollaborators.contains(pubkey);
  }

  /// Get lists by tag for discovery
  List<CuratedList> getListsByTag(String tag) {
    return _lists
        .where((list) => list.isPublic && list.tags.contains(tag.toLowerCase()))
        .toList();
  }

  /// Get all unique tags across all lists
  List<String> getAllTags() {
    final allTags = <String>{};
    for (final list in _lists) {
      if (list.isPublic) {
        allTags.addAll(list.tags);
      }
    }
    return allTags.toList()..sort();
  }

  /// Search lists by name or description
  List<CuratedList> searchLists(String query) {
    if (query.trim().isEmpty) return [];

    final lowerQuery = query.toLowerCase();
    return _lists
        .where(
          (list) =>
              list.isPublic &&
              (list.name.toLowerCase().contains(lowerQuery) ||
                  (list.description?.toLowerCase().contains(lowerQuery) ??
                      false) ||
                  list.tags.any(
                    (tag) => tag.toLowerCase().contains(lowerQuery),
                  )),
        )
        .toList();
  }

  /// Get all lists that contain a specific video
  List<CuratedList> getListsContainingVideo(String videoEventId) {
    return _lists
        .where((list) => list.videoEventIds.contains(videoEventId))
        .toList();
  }

  // === SUBSCRIPTION MANAGEMENT ===

  /// Subscribe to a curated list to follow its updates
  /// Subscribe to a curated list (saves list data for offline access)
  Future<bool> subscribeToList(String listId, [CuratedList? listData]) async {
    try {
      // Check if list exists in our cache
      var list = getListById(listId);

      // If list not in cache but listData provided, add it
      if (list == null && listData != null) {
        _lists.add(listData);
        await _saveLists();
        list = listData;
        Log.debug(
          'Added discovered list to cache: ${listData.name}',
          name: 'CuratedListService',
          category: LogCategory.system,
        );
      }

      if (list == null) {
        Log.warning(
          'Cannot subscribe - list not found: $listId',
          name: 'CuratedListService',
          category: LogCategory.system,
        );
        return false;
      }

      // Check if already subscribed
      if (_subscribedListIds.contains(listId)) {
        Log.debug(
          'Already subscribed to list: ${list.name}',
          name: 'CuratedListService',
          category: LogCategory.system,
        );
        return true;
      }

      // Add to subscribed lists
      _subscribedListIds.add(listId);
      await _saveSubscribedListIds();

      Log.info(
        'Subscribed to list: ${list.name} ($listId)',
        name: 'CuratedListService',
        category: LogCategory.system,
      );

      // Trigger video cache sync for this list
      if (_onListSubscribed != null && list.videoEventIds.isNotEmpty) {
        Log.debug(
          'Triggering video cache sync for list: ${list.name} '
          '(${list.videoEventIds.length} videos)',
          name: 'CuratedListService',
          category: LogCategory.system,
        );
        await _onListSubscribed!(listId, list.videoEventIds);
      }

      return true;
    } catch (e) {
      Log.error(
        'Failed to subscribe to list: $e',
        name: 'CuratedListService',
        category: LogCategory.system,
      );
      return false;
    }
  }

  /// Unsubscribe from a curated list
  Future<bool> unsubscribeFromList(String listId) async {
    try {
      // Check if subscribed
      if (!_subscribedListIds.contains(listId)) {
        Log.debug(
          'Not subscribed to list: $listId',
          name: 'CuratedListService',
          category: LogCategory.system,
        );
        return true;
      }

      final list = getListById(listId);
      final listName = list?.name ?? listId;

      // Remove from subscribed lists
      _subscribedListIds.remove(listId);
      await _saveSubscribedListIds();

      Log.info(
        'Unsubscribed from list: $listName ($listId)',
        name: 'CuratedListService',
        category: LogCategory.system,
      );

      // Remove list from video cache
      _onListUnsubscribed?.call(listId);

      return true;
    } catch (e) {
      Log.error(
        'Failed to unsubscribe from list: $e',
        name: 'CuratedListService',
        category: LogCategory.system,
      );
      return false;
    }
  }

  /// Check if user is subscribed to a list
  bool isSubscribedToList(String listId) {
    return _subscribedListIds.contains(listId);
  }

  /// Get readable summary of lists containing a video
  String getVideoListSummary(String videoEventId) {
    final listsContaining = getListsContainingVideo(videoEventId);

    if (listsContaining.isEmpty) {
      return 'Not in any lists';
    }

    if (listsContaining.length == 1) {
      return 'In "${listsContaining.first.name}"';
    }

    if (listsContaining.length <= 3) {
      final names = listsContaining.map((list) => '"${list.name}"').join(', ');
      return 'In $names';
    }

    return 'In ${listsContaining.length} lists';
  }

  /// Create the default "My List" for quick access
  /// Default list is PRIVATE - users can make it public if they want
  Future<void> _createDefaultList() async {
    await _createList(
      id: defaultListId,
      name: 'My List',
      description: 'My favorite vines and videos',
      isPublic: false, // Don't spam the relay with empty default lists
    );
  }

  /// Publish list to Nostr as NIP-51 kind 30005 event
  Future<void> _publishListToNostr(CuratedList list) async {
    try {
      if (!_authService.isAuthenticated) {
        Log.warning(
          'Cannot publish list - user not authenticated',
          name: 'CuratedListService',
          category: LogCategory.system,
        );
        return;
      }

      // Don't spam relay with empty lists
      if (list.videoEventIds.isEmpty) {
        Log.debug(
          'Skipping publish of empty list: ${list.name}',
          name: 'CuratedListService',
          category: LogCategory.system,
        );
        return;
      }

      final content = list.description ?? 'Curated video list: ${list.name}';
      final tags = list.getEventTags();

      final event = await _authService.createAndSignEvent(
        kind: 30005, // NIP-51 curated list
        content: content,
        tags: tags,
      );

      if (event != null) {
        final sentEvent = await _nostrService.publishEvent(event);
        if (sentEvent != null) {
          // Update local list with Nostr event ID
          final listIndex = _lists.indexWhere((l) => l.id == list.id);
          if (listIndex != -1) {
            _lists[listIndex] = list.copyWith(nostrEventId: event.id);
            await _saveLists();
          }
          Log.debug(
            'Published list to Nostr: ${list.name} (${event.id})',
            name: 'CuratedListService',
            category: LogCategory.system,
          );
        }
      }
    } catch (e) {
      Log.error(
        'Failed to publish list to Nostr: $e',
        name: 'CuratedListService',
        category: LogCategory.system,
      );
    }
  }

  /// Load lists from local storage
  void _loadLists() {
    final listsJson = _prefs.getString(listsStorageKey);
    if (listsJson != null) {
      try {
        final List<dynamic> listsData = jsonDecode(listsJson);
        _lists.clear();
        _lists.addAll(
          listsData.map(
            (json) => CuratedList.fromJson(json as Map<String, dynamic>),
          ),
        );
        Log.debug(
          '📱 Loaded ${_lists.length} curated lists from storage',
          name: 'CuratedListService',
          category: LogCategory.system,
        );
      } catch (e) {
        Log.error(
          'Failed to load curated lists: $e',
          name: 'CuratedListService',
          category: LogCategory.system,
        );
      }
    }
  }

  /// Load subscribed list IDs from local storage
  void _loadSubscribedListIds() {
    final subscribedJson = _prefs.getString(subscribedListsStorageKey);
    if (subscribedJson != null) {
      try {
        final List<dynamic> subscribedData = jsonDecode(subscribedJson);
        _subscribedListIds.clear();
        _subscribedListIds.addAll(subscribedData.cast<String>());
        Log.debug(
          '📱 Loaded ${_subscribedListIds.length} subscribed lists from storage',
          name: 'CuratedListService',
          category: LogCategory.system,
        );
      } catch (e) {
        Log.error(
          'Failed to load subscribed list IDs: $e',
          name: 'CuratedListService',
          category: LogCategory.system,
        );
      }
    }
  }

  /// Save lists to local storage
  Future<void> _saveLists() async {
    try {
      notifyListeners();
      final listsJson = _lists.map((list) => list.toJson()).toList();
      await _prefs.setString(listsStorageKey, jsonEncode(listsJson));
    } catch (e) {
      Log.error(
        'Failed to save curated lists: $e',
        name: 'CuratedListService',
        category: LogCategory.system,
      );
    }
  }

  /// Save subscribed list IDs to local storage
  Future<void> _saveSubscribedListIds() async {
    try {
      final subscribedJson = _subscribedListIds.toList();
      await _prefs.setString(
        subscribedListsStorageKey,
        jsonEncode(subscribedJson),
      );
      Log.debug(
        '💾 Saved ${_subscribedListIds.length} subscribed list IDs to storage',
        name: 'CuratedListService',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Failed to save subscribed list IDs: $e',
        name: 'CuratedListService',
        category: LogCategory.system,
      );
    }
  }

  /// Fetch user's curated lists from Nostr relays on app startup
  Future<void> fetchUserListsFromRelays() async {
    if (!_authService.isAuthenticated) {
      Log.warning(
        'Cannot fetch lists from relays - user not authenticated',
        name: 'CuratedListService',
        category: LogCategory.system,
      );
      return;
    }

    if (_hasSyncedWithRelays) {
      Log.debug(
        'Already synced with relays this session',
        name: 'CuratedListService',
        category: LogCategory.system,
      );
      return;
    }

    final userPubkey = _authService.currentPublicKeyHex;
    if (userPubkey == null) return;

    Log.info(
      '📋 Fetching user\'s curated lists from relays for pubkey: $userPubkey',
      name: 'CuratedListService',
      category: LogCategory.system,
    );

    try {
      final completer = Completer<void>();
      final receivedEvents = <Event>[];

      // Subscribe to user's own Kind 30005 events (NIP-51 curated lists)
      final filter = Filter(
        authors: [userPubkey],
        kinds: [30005], // NIP-51 curated lists
      );
      Log.debug(
        '📋 Subscribing with filter: authors=[$userPubkey], kinds=[30005]',
        name: 'CuratedListService',
        category: LogCategory.system,
      );
      final subscription = _nostrService.subscribe([filter]);

      // Set a timeout for the subscription
      Timer? timeoutTimer;
      timeoutTimer = Timer(const Duration(seconds: 10), () {
        Log.debug(
          'Relay sync timeout reached, processing received events',
          name: 'CuratedListService',
          category: LogCategory.system,
        );
        if (!completer.isCompleted) {
          completer.complete();
        }
      });

      subscription.listen(
        (event) {
          receivedEvents.add(event);
          Log.debug(
            'Received list event from relay: ${event.id}...',
            name: 'CuratedListService',
            category: LogCategory.system,
          );
        },
        onDone: () {
          timeoutTimer?.cancel();
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
        onError: (error) {
          Log.error(
            'Error fetching lists from relay: $error',
            name: 'CuratedListService',
            category: LogCategory.system,
          );
          timeoutTimer?.cancel();
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
      );

      await completer.future;

      Log.info(
        '📋 Received ${receivedEvents.length} raw list events from relays',
        name: 'CuratedListService',
        category: LogCategory.system,
      );

      // Process received events
      if (receivedEvents.isNotEmpty) {
        await _processReceivedListEvents(receivedEvents);
      }

      _hasSyncedWithRelays = true;
      Log.info(
        '✅ Relay sync complete. Found ${receivedEvents.length} list events',
        name: 'CuratedListService',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Failed to fetch lists from relays: $e',
        name: 'CuratedListService',
        category: LogCategory.system,
      );
    }
  }

  /// Stream public curated lists from Nostr relays for discovery
  /// Yields lists immediately as they arrive - no waiting for EOSE
  /// Handles deduplication by 'd' tag (keeps newest version)
  /// Use [until] to paginate backwards (set to oldest createdAt from previous batch)
  /// Use [limit] to control how many events to request (default: 500)
  /// Use [excludeIds] to skip lists already known (for pagination)
  Stream<List<CuratedList>> streamPublicListsFromRelays({
    DateTime? until,
    int limit = 500,
    Set<String>? excludeIds,
  }) async* {
    Log.info(
      '📋 Streaming public curated lists from relays (limit: $limit)${until != null ? ' (until: $until)' : ''}'
      '${excludeIds != null ? ' (excluding ${excludeIds.length} known)' : ''}...',
      name: 'CuratedListService',
      category: LogCategory.system,
    );

    // Track lists by d-tag for deduplication (keep newest)
    final listsByDTag = <String, CuratedList>{};
    final skipIds = excludeIds ?? <String>{};
    var totalEventsReceived = 0;
    var listsWithVideos = 0;
    var rejectedCount = 0;

    // Build filter - use until for pagination (convert DateTime to Unix timestamp)
    // Include limit to ensure relays return a reasonable number of events
    final filter = Filter(
      kinds: [30005], // NIP-51 curated lists
      until: until != null ? until.millisecondsSinceEpoch ~/ 1000 : null,
      limit: limit,
    );

    Log.info(
      '📋 Filter: ${filter.toJson()}',
      name: 'CuratedListService',
      category: LogCategory.system,
    );

    final subscription = _nostrService.subscribe([filter]);

    await for (final event in subscription) {
      totalEventsReceived++;
      // Log progress every 100 events (reduced spam)
      if (totalEventsReceived % 100 == 0) {
        Log.info(
          '📋 Progress: $totalEventsReceived events, $listsWithVideos with videos, '
          '$rejectedCount empty',
          name: 'CuratedListService',
          category: LogCategory.system,
        );
      }
      final curatedList = _eventToCuratedList(event);

      // Track rejected lists for summary (don't log each one)
      if (curatedList == null || curatedList.videoEventIds.isEmpty) {
        rejectedCount++;
      }

      if (curatedList != null && curatedList.videoEventIds.isNotEmpty) {
        listsWithVideos++;
        final dTag = curatedList.id;

        // Skip lists we already know about (for pagination)
        if (skipIds.contains(dTag)) {
          continue;
        }

        final existing = listsByDTag[dTag];

        // Keep newest version
        if (existing == null ||
            curatedList.updatedAt.isAfter(existing.updatedAt)) {
          listsByDTag[dTag] = curatedList;

          // Yield current accumulated list sorted by video count
          final sortedLists = listsByDTag.values.toList()
            ..sort(
              (a, b) =>
                  b.videoEventIds.length.compareTo(a.videoEventIds.length),
            );
          yield sortedLists;
        }
      }
    }

    // Log final stats when stream completes
    Log.info(
      '📋 Stream complete: received $totalEventsReceived events, '
      '$listsWithVideos had videos, ${listsByDTag.length} unique lists',
      name: 'CuratedListService',
      category: LogCategory.system,
    );
  }

  /// Fetch public curated lists from Nostr relays for discovery (legacy)
  /// Prefer streamPublicListsFromRelays for immediate results
  /// WARNING: This waits forever since Nostr streams don't close - use stream version
  Future<List<CuratedList>> fetchPublicListsFromRelays({
    List<String>? searchTags,
  }) async {
    final lists = <CuratedList>[];
    await for (final update in streamPublicListsFromRelays()) {
      lists
        ..clear()
        ..addAll(update);
    }

    // Apply tag filter if specified
    if (searchTags != null && searchTags.isNotEmpty) {
      return lists.where((list) {
        return list.tags.any((tag) => searchTags.contains(tag.toLowerCase()));
      }).toList();
    }

    return lists;
  }

  /// Fetch public lists from any user that contain a specific video
  /// Uses Nostr #e filter to find kind 30005 events referencing the video
  /// Returns list of CuratedList objects (progressive loading via stream version)
  Future<List<CuratedList>> fetchPublicListsContainingVideo(
    String videoEventId,
  ) async {
    Log.info(
      '📋 Fetching public lists containing video: $videoEventId',
      name: 'CuratedListService',
      category: LogCategory.system,
    );

    try {
      final completer = Completer<void>();
      final receivedEvents = <Event>[];

      // Build filter for lists containing this video
      final filter = Filter(
        kinds: [30005], // NIP-51 curated lists
        e: [videoEventId], // Lists that reference this video event
        limit: 50,
      );

      // Subscribe to matching events
      final subscription = _nostrService.subscribe([filter]);

      // Set a timeout for the subscription
      Timer? timeoutTimer;
      timeoutTimer = Timer(const Duration(seconds: 10), () {
        Log.debug(
          'Public lists containing video fetch timeout, processing received events',
          name: 'CuratedListService',
          category: LogCategory.system,
        );
        if (!completer.isCompleted) {
          completer.complete();
        }
      });

      subscription.listen(
        (event) {
          receivedEvents.add(event);
          Log.debug(
            'Received public list containing video: ${event.id}',
            name: 'CuratedListService',
            category: LogCategory.system,
          );
        },
        onDone: () {
          timeoutTimer?.cancel();
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
        onError: (error) {
          Log.error(
            'Error fetching public lists containing video: $error',
            name: 'CuratedListService',
            category: LogCategory.system,
          );
          timeoutTimer?.cancel();
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
      );

      await completer.future;

      // Process received events into CuratedList objects
      final publicLists = <CuratedList>[];

      if (receivedEvents.isNotEmpty) {
        // Group events by 'd' tag to handle replaceable events (keep newest)
        final eventsByDTag = <String, Event>{};

        for (final event in receivedEvents) {
          final dTag = _extractDTag(event);
          if (dTag != null) {
            final existingEvent = eventsByDTag[dTag];
            if (existingEvent == null ||
                event.createdAt > existingEvent.createdAt) {
              eventsByDTag[dTag] = event;
            }
          }
        }

        Log.debug(
          'Processing ${eventsByDTag.length} unique public lists containing video',
          name: 'CuratedListService',
          category: LogCategory.system,
        );

        for (final event in eventsByDTag.values) {
          final curatedList = _eventToCuratedList(event);
          if (curatedList != null) {
            publicLists.add(curatedList);
          }
        }
      }

      Log.info(
        '✅ Found ${publicLists.length} public lists containing video',
        name: 'CuratedListService',
        category: LogCategory.system,
      );

      return publicLists;
    } catch (e) {
      Log.error(
        'Failed to fetch public lists containing video: $e',
        name: 'CuratedListService',
        category: LogCategory.system,
      );
      return [];
    }
  }

  /// Stream public lists containing a specific video for progressive loading
  /// Emits CuratedList objects as they arrive from relays
  Stream<CuratedList> streamPublicListsContainingVideo(String videoEventId) {
    Log.info(
      '📋 Streaming public lists containing video: $videoEventId',
      name: 'CuratedListService',
      category: LogCategory.system,
    );

    // Build filter for lists containing this video
    final filter = Filter(
      kinds: [30005], // NIP-51 curated lists
      e: [videoEventId], // Lists that reference this video event
      limit: 50,
    );

    // Track seen d-tags to handle replaceable events
    final seenDTags = <String, Event>{};

    // Subscribe and transform events to CuratedList objects
    return _nostrService
        .subscribe([filter])
        .map((event) {
          final dTag = _extractDTag(event);
          if (dTag == null) return null;

          // Check if we've seen a newer version of this list
          final existing = seenDTags[dTag];
          if (existing != null && existing.createdAt >= event.createdAt) {
            return null; // Skip older version
          }
          seenDTags[dTag] = event;

          return _eventToCuratedList(event);
        })
        .where((list) => list != null)
        .cast<CuratedList>();
  }

  /// Convert a Nostr event to a CuratedList object
  /// Returns null if event is invalid or cannot be parsed
  CuratedList? _eventToCuratedList(Event event) {
    try {
      final dTag = _extractDTag(event);
      if (dTag == null) {
        Log.warning(
          'List event missing d tag: ${event.id}',
          name: 'CuratedListService',
          category: LogCategory.system,
        );
        return null;
      }

      // Extract list metadata from tags (same logic as _processListEvent)
      String? title;
      String? description;
      String? imageUrl;
      String? thumbnailEventId;
      String? playOrderStr;
      final tags = <String>[];
      final videoEventIds = <String>[];
      bool isCollaborative = false;
      final allowedCollaborators = <String>[];

      for (final tag in event.tags) {
        if (tag.isEmpty) continue;

        switch (tag[0]) {
          case 'title':
            if (tag.length > 1) title = tag[1];
            break;
          case 'description':
            if (tag.length > 1) description = tag[1];
            break;
          case 'image':
            if (tag.length > 1) imageUrl = tag[1];
            break;
          case 'thumbnail':
            if (tag.length > 1) thumbnailEventId = tag[1];
            break;
          case 'playorder':
            if (tag.length > 1) playOrderStr = tag[1];
            break;
          case 't':
            if (tag.length > 1) tags.add(tag[1]);
            break;
          case 'e':
            if (tag.length > 1) videoEventIds.add(tag[1]);
            break;
          case 'a':
            // Handle 'a' tags for addressable events (format: kind:pubkey:d-tag)
            // NIP-71 video kinds: 34235 (horizontal), 34236 (vertical), 34237 (live)
            if (tag.length > 1) {
              final aTagValue = tag[1];
              // Parse the coordinate to extract video reference
              // Format: <kind>:<pubkey>:<d-tag>
              final parts = aTagValue.split(':');
              if (parts.length >= 3) {
                final kind = parts[0];
                // Accept all NIP-71 video kinds
                if (kind == '34235' || kind == '34236' || kind == '34237') {
                  videoEventIds.add(aTagValue);
                }
              }
            }
            break;
          case 'collaborative':
            if (tag.length > 1 && tag[1] == 'true') isCollaborative = true;
            break;
          case 'collaborator':
            if (tag.length > 1) allowedCollaborators.add(tag[1]);
            break;
        }
      }

      // Only log lists that have videos (avoid spam from empty lists)
      if (videoEventIds.isNotEmpty) {
        Log.debug(
          '📋 Found list "$dTag" with ${videoEventIds.length} videos',
          name: 'CuratedListService',
          category: LogCategory.system,
        );
      }

      // Use title or fall back to content or default
      final contentFirstLine = event.content.split('\n').first;
      final name =
          title ??
          (contentFirstLine.isNotEmpty ? contentFirstLine : 'Untitled List');

      return CuratedList(
        id: dTag,
        name: name,
        pubkey: event.pubkey, // Creator's pubkey for attribution
        description: description ?? event.content,
        imageUrl: imageUrl,
        videoEventIds: videoEventIds,
        createdAt: DateTime.fromMillisecondsSinceEpoch(event.createdAt * 1000),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(event.createdAt * 1000),
        isPublic: true, // Lists from relays are public
        nostrEventId: event.id,
        tags: tags,
        isCollaborative: isCollaborative,
        allowedCollaborators: allowedCollaborators,
        thumbnailEventId: thumbnailEventId,
        playOrder: playOrderStr != null
            ? PlayOrderExtension.fromString(playOrderStr)
            : PlayOrder.chronological,
      );
    } catch (e) {
      Log.error(
        'Failed to convert event ${event.id} to CuratedList: $e',
        name: 'CuratedListService',
        category: LogCategory.system,
      );
      return null;
    }
  }

  /// Process list events received from relays
  Future<void> _processReceivedListEvents(List<Event> events) async {
    // Group events by 'd' tag to handle replaceable events
    final eventsByDTag = <String, Event>{};

    for (final event in events) {
      final dTag = _extractDTag(event);
      if (dTag != null) {
        // Keep only the latest event for each 'd' tag
        final existingEvent = eventsByDTag[dTag];
        if (existingEvent == null ||
            event.createdAt > existingEvent.createdAt) {
          eventsByDTag[dTag] = event;
        }
      }
    }

    Log.debug(
      'Processing ${eventsByDTag.length} unique lists from relays',
      name: 'CuratedListService',
      category: LogCategory.system,
    );

    // Process each unique list
    for (final event in eventsByDTag.values) {
      await _processListEvent(event);
    }

    // Save updated lists to local storage
    await _saveLists();
  }

  /// Extract 'd' tag value from event
  String? _extractDTag(Event event) {
    for (final tag in event.tags) {
      if (tag.isNotEmpty && tag[0] == 'd' && tag.length > 1) {
        return tag[1];
      }
    }
    return null;
  }

  /// Process a single list event from Nostr
  Future<void> _processListEvent(Event event) async {
    try {
      final dTag = _extractDTag(event);

      if (dTag == null) {
        Log.warning(
          'List event missing d tag: ${event.id}',
          name: 'CuratedListService',
          category: LogCategory.system,
        );
        return;
      }

      final curatedList = event.toCuratedList();

      // Check if we already have this list locally
      final existingListIndex = _lists.indexWhere((list) => list.id == dTag);

      if (existingListIndex != -1) {
        // Update existing list if relay version is newer
        final existingList = _lists[existingListIndex];
        if (event.createdAt >
            existingList.updatedAt.millisecondsSinceEpoch ~/ 1000) {
          Log.debug(
            'Updating existing list from relay: ${curatedList.name}',
            name: 'CuratedListService',
            category: LogCategory.system,
          );

          _lists[existingListIndex] = curatedList.copyWith(
            createdAt: existingList.createdAt,
          );
        } else {
          Log.debug(
            'Skipping older relay version of list: ${curatedList.name}',
            name: 'CuratedListService',
            category: LogCategory.system,
          );
        }
      } else {
        // Add new list from relay
        Log.debug(
          'Adding new list from relay: ${curatedList.name}',
          name: 'CuratedListService',
          category: LogCategory.system,
        );

        _lists.add(curatedList);
      }
    } catch (e) {
      Log.error(
        'Failed to process list event ${event.id}: $e',
        name: 'CuratedListService',
        category: LogCategory.system,
      );
    }
  }
}
