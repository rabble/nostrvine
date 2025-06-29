// ABOUTME: Service for managing NIP-51 curated lists (kind 30005) for video collections
// ABOUTME: Handles creation, updates, and management of user's public video lists

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'nostr_service_interface.dart';
import 'auth_service.dart';
import '../utils/unified_logger.dart';

/// Represents a curated list of videos
class CuratedList {
  final String id;
  final String name;
  final String? description;
  final String? imageUrl;
  final List<String> videoEventIds;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isPublic;
  final String? nostrEventId;

  const CuratedList({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    required this.videoEventIds,
    required this.createdAt,
    required this.updatedAt,
    this.isPublic = true,
    this.nostrEventId,
  });

  CuratedList copyWith({
    String? id,
    String? name,
    String? description,
    String? imageUrl,
    List<String>? videoEventIds,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isPublic,
    String? nostrEventId,
  }) {
    return CuratedList(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      videoEventIds: videoEventIds ?? this.videoEventIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isPublic: isPublic ?? this.isPublic,
      nostrEventId: nostrEventId ?? this.nostrEventId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
      'videoEventIds': videoEventIds,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isPublic': isPublic,
      'nostrEventId': nostrEventId,
    };
  }

  static CuratedList fromJson(Map<String, dynamic> json) {
    return CuratedList(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      imageUrl: json['imageUrl'],
      videoEventIds: List<String>.from(json['videoEventIds'] ?? []),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      isPublic: json['isPublic'] ?? true,
      nostrEventId: json['nostrEventId'],
    );
  }
}

/// Service for managing NIP-51 curated lists
class CuratedListService extends ChangeNotifier {
  final INostrService _nostrService;
  final AuthService _authService;
  final SharedPreferences _prefs;

  static const String listsStorageKey = 'curated_lists';
  static const String defaultListId = 'my_vine_list';

  final List<CuratedList> _lists = [];
  bool _isInitialized = false;

  CuratedListService({
    required INostrService nostrService,
    required AuthService authService,
    required SharedPreferences prefs,
  }) : _nostrService = nostrService,
       _authService = authService,
       _prefs = prefs {
    _loadLists();
  }

  // Getters
  List<CuratedList> get lists => List.unmodifiable(_lists);
  bool get isInitialized => _isInitialized;

  /// Initialize the service and create default list if needed
  Future<void> initialize() async {
    try {
      if (!_authService.isAuthenticated) {
        Log.warning('Cannot initialize curated lists - user not authenticated', name: 'CuratedListService', category: LogCategory.system);
        return;
      }

      // Create default list if it doesn't exist
      if (!hasDefaultList()) {
        await _createDefaultList();
      }

      _isInitialized = true;
      Log.info('Curated list service initialized with ${_lists.length} lists', name: 'CuratedListService', category: LogCategory.system);
      notifyListeners();
    } catch (e) {
      Log.error('Failed to initialize curated list service: $e', name: 'CuratedListService', category: LogCategory.system);
    }
  }

  /// Check if default list exists
  bool hasDefaultList() {
    return _lists.any((list) => list.id == defaultListId);
  }

  /// Get the default "My List" for quick adding
  CuratedList? getDefaultList() {
    try {
      return _lists.firstWhere((list) => list.id == defaultListId);
    } catch (e) {
      return null;
    }
  }

  /// Create a new curated list
  Future<CuratedList?> createList({
    required String name,
    String? description,
    String? imageUrl,
    bool isPublic = true,
  }) async {
    try {
      final listId = 'list_${DateTime.now().millisecondsSinceEpoch}';
      final now = DateTime.now();

      final newList = CuratedList(
        id: listId,
        name: name,
        description: description,
        imageUrl: imageUrl,
        videoEventIds: [],
        createdAt: now,
        updatedAt: now,
        isPublic: isPublic,
      );

      _lists.add(newList);
      await _saveLists();

      // Publish to Nostr if user is authenticated and list is public
      if (_authService.isAuthenticated && isPublic) {
        await _publishListToNostr(newList);
      }

      Log.info('Created new curated list: $name ($listId)', name: 'CuratedListService', category: LogCategory.system);
      notifyListeners();
      return newList;
    } catch (e) {
      Log.error('Failed to create curated list: $e', name: 'CuratedListService', category: LogCategory.system);
      return null;
    }
  }

  /// Add video to a list
  Future<bool> addVideoToList(String listId, String videoEventId) async {
    try {
      final listIndex = _lists.indexWhere((list) => list.id == listId);
      if (listIndex == -1) {
        Log.warning('List not found: $listId', name: 'CuratedListService', category: LogCategory.system);
        return false;
      }

      final list = _lists[listIndex];
      
      // Check if video is already in the list
      if (list.videoEventIds.contains(videoEventId)) {
        Log.warning('Video already in list: $videoEventId', name: 'CuratedListService', category: LogCategory.system);
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

      Log.debug('➕ Added video to list "${list.name}": $videoEventId', name: 'CuratedListService', category: LogCategory.system);
      notifyListeners();
      return true;
    } catch (e) {
      Log.error('Failed to add video to list: $e', name: 'CuratedListService', category: LogCategory.system);
      return false;
    }
  }

  /// Remove video from a list
  Future<bool> removeVideoFromList(String listId, String videoEventId) async {
    try {
      final listIndex = _lists.indexWhere((list) => list.id == listId);
      if (listIndex == -1) {
        Log.warning('List not found: $listId', name: 'CuratedListService', category: LogCategory.system);
        return false;
      }

      final list = _lists[listIndex];
      final updatedVideoIds = list.videoEventIds.where((id) => id != videoEventId).toList();

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

      Log.debug('➖ Removed video from list "${list.name}": $videoEventId', name: 'CuratedListService', category: LogCategory.system);
      notifyListeners();
      return true;
    } catch (e) {
      Log.error('Failed to remove video from list: $e', name: 'CuratedListService', category: LogCategory.system);
      return false;
    }
  }

  /// Check if video is in a specific list
  bool isVideoInList(String listId, String videoEventId) {
    final list = _lists.where((l) => l.id == listId).firstOrNull;
    return list?.videoEventIds.contains(videoEventId) ?? false;
  }

  /// Check if video is in default list
  bool isVideoInDefaultList(String videoEventId) {
    return isVideoInList(defaultListId, videoEventId);
  }

  /// Get list by ID
  CuratedList? getListById(String listId) {
    try {
      return _lists.firstWhere((list) => list.id == listId);
    } catch (e) {
      return null;
    }
  }

  /// Update list metadata
  Future<bool> updateList({
    required String listId,
    String? name,
    String? description,
    String? imageUrl,
    bool? isPublic,
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
        updatedAt: DateTime.now(),
      );

      _lists[listIndex] = updatedList;
      await _saveLists();

      // Update on Nostr if public
      if (updatedList.isPublic && _authService.isAuthenticated) {
        await _publishListToNostr(updatedList);
      }

      Log.debug('✏️ Updated list: ${updatedList.name}', name: 'CuratedListService', category: LogCategory.system);
      notifyListeners();
      return true;
    } catch (e) {
      Log.error('Failed to update list: $e', name: 'CuratedListService', category: LogCategory.system);
      return false;
    }
  }

  /// Delete a list
  Future<bool> deleteList(String listId) async {
    try {
      // Don't allow deleting the default list
      if (listId == defaultListId) {
        Log.warning('Cannot delete default list', name: 'CuratedListService', category: LogCategory.system);
        return false;
      }

      final listIndex = _lists.indexWhere((list) => list.id == listId);
      if (listIndex == -1) {
        return false;
      }

      final list = _lists[listIndex];
      _lists.removeAt(listIndex);
      await _saveLists();

      // TODO: Send deletion event to Nostr if it was published

      Log.debug('�️ Deleted list: ${list.name}', name: 'CuratedListService', category: LogCategory.system);
      notifyListeners();
      return true;
    } catch (e) {
      Log.error('Failed to delete list: $e', name: 'CuratedListService', category: LogCategory.system);
      return false;
    }
  }

  /// Create the default "My List" for quick access
  Future<void> _createDefaultList() async {
    await createList(
      name: 'My List',
      description: 'My favorite vines and videos',
      isPublic: true,
    );

    // Update the ID to be the default ID
    final listIndex = _lists.indexWhere((list) => list.name == 'My List');
    if (listIndex != -1) {
      final list = _lists[listIndex];
      _lists[listIndex] = list.copyWith(id: defaultListId);
      await _saveLists();
    }
  }

  /// Publish list to Nostr as NIP-51 kind 30005 event
  Future<void> _publishListToNostr(CuratedList list) async {
    try {
      if (!_authService.isAuthenticated) {
        Log.warning('Cannot publish list - user not authenticated', name: 'CuratedListService', category: LogCategory.system);
        return;
      }

      // Create NIP-51 kind 30005 tags
      final tags = <List<String>>[
        ['d', list.id], // Identifier for replaceable event
        ['title', list.name],
        ['client', 'openvine'],
      ];

      // Add description if present
      if (list.description != null && list.description!.isNotEmpty) {
        tags.add(['description', list.description!]);
      }

      // Add image if present
      if (list.imageUrl != null && list.imageUrl!.isNotEmpty) {
        tags.add(['image', list.imageUrl!]);
      }

      // Add video events as 'e' tags
      for (final videoEventId in list.videoEventIds) {
        tags.add(['e', videoEventId]);
      }

      final content = list.description ?? 'Curated video list: ${list.name}';

      final event = await _authService.createAndSignEvent(
        kind: 30005, // NIP-51 curated list
        content: content,
        tags: tags,
      );

      if (event != null) {
        final result = await _nostrService.broadcastEvent(event);
        if (result.successCount > 0) {
          // Update local list with Nostr event ID
          final listIndex = _lists.indexWhere((l) => l.id == list.id);
          if (listIndex != -1) {
            _lists[listIndex] = list.copyWith(nostrEventId: event.id);
            await _saveLists();
          }
          Log.debug('Published list to Nostr: ${list.name} (${event.id})', name: 'CuratedListService', category: LogCategory.system);
        }
      }
    } catch (e) {
      Log.error('Failed to publish list to Nostr: $e', name: 'CuratedListService', category: LogCategory.system);
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
          listsData.map((json) => CuratedList.fromJson(json))
        );
        Log.debug('� Loaded ${_lists.length} curated lists from storage', name: 'CuratedListService', category: LogCategory.system);
      } catch (e) {
        Log.error('Failed to load curated lists: $e', name: 'CuratedListService', category: LogCategory.system);
      }
    }
  }

  /// Save lists to local storage
  Future<void> _saveLists() async {
    try {
      final listsJson = _lists.map((list) => list.toJson()).toList();
      await _prefs.setString(listsStorageKey, jsonEncode(listsJson));
    } catch (e) {
      Log.error('Failed to save curated lists: $e', name: 'CuratedListService', category: LogCategory.system);
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}