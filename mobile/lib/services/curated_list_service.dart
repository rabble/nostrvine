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
import 'package:models/models.dart' hide LogCategory;
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/utils/curated_list_ext.dart';
import 'package:openvine/utils/nostr_event_ext.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

/// Callback type for list subscription events
/// Called with listId and the video IDs in that list
typedef OnListSubscribedCallback =
    Future<void> Function(String listId, List<String> videoIds);

/// Callback type for list unsubscription events
/// Called with listId when a list is unsubscribed
typedef OnListUnsubscribedCallback = void Function(String listId);

/// Result of a curated-list mutation that can trigger a Nostr publish.
///
/// Mirrors the bookmark/deletion result shapes: on success, [outcome] and
/// [feedback] are populated and callers can render a success confirmation;
/// on failure, [feedback.retryable] drives whether the UI exposes a retry
/// affordance.
///
/// Operations that can skip the publish (unauthenticated user, private
/// list, empty list) return a "noop" result where [outcome] and [feedback]
/// are both null and [success] reflects whether the local state mutation
/// is durable.
class CuratedListResult {
  const CuratedListResult({
    required this.success,
    this.outcome,
    this.feedback,
    this.list,
  });

  /// Whether the requested mutation is durable — either because a relay
  /// accepted the publish, or because the operation did not require a
  /// publish in the first place (private list, unauthenticated user).
  final bool success;

  /// Per-relay publish outcome. `null` when the mutation skipped publishing.
  final PublishOutcome? outcome;

  /// Mapped user feedback. `null` iff [outcome] is `null`.
  final PublishUserFeedback? feedback;

  /// Populated by mutators that return a new/updated list (e.g. [create]).
  final CuratedList? list;

  static CuratedListResult successResult({
    PublishOutcome? outcome,
    PublishUserFeedback? feedback,
    CuratedList? list,
  }) => CuratedListResult(
    success: true,
    outcome: outcome,
    feedback: feedback,
    list: list,
  );

  static CuratedListResult failure({
    PublishOutcome? outcome,
    PublishUserFeedback? feedback,
    CuratedList? list,
  }) => CuratedListResult(
    success: false,
    outcome: outcome,
    feedback: feedback,
    list: list,
  );
}

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

  /// Internal method to create a list with optional explicit ID.
  ///
  /// Returns the created list on success, or `null` if publish failed and
  /// local state was rolled back. For the default (empty, private) list
  /// creation, publishing is skipped and the list is always persisted.
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
    final now = DateTime.now();
    final listId = id ?? 'list_${now.millisecondsSinceEpoch}';

    final newList = CuratedList(
      id: listId,
      name: name,
      description: description,
      imageUrl: imageUrl,
      videoEventIds: const [],
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

    // Empty lists don't publish (see _publishListToNostr) and private lists
    // never publish — both are local-only success.
    if (!_authService.isAuthenticated ||
        !isPublic ||
        newList.videoEventIds.isEmpty) {
      Log.info(
        'Created new curated list: $name ($listId)',
        name: 'CuratedListService',
        category: LogCategory.system,
      );
      return newList;
    }

    final publish = await _publishListToNostr(newList);
    if (!publish.success) {
      _lists.removeWhere((l) => l.id == listId);
      await _saveLists();
      return null;
    }

    Log.info(
      'Created new curated list: $name ($listId)',
      name: 'CuratedListService',
      category: LogCategory.system,
    );
    // Prefer the published (nostrEventId-stamped) copy when available.
    return publish.list ?? newList;
  }

  /// Add video to a list.
  ///
  /// Returns `true` when the video is persisted locally and (for public
  /// lists) the kind 30005 event has been accepted by at least one relay.
  /// Returns `false` on relay-level failure — the local mutation is
  /// rolled back in that case so local and relay state stay consistent.
  ///
  /// Prefer [addVideoToListResult] when the caller needs the per-relay
  /// outcome to drive a retry affordance in the UI.
  Future<bool> addVideoToList(String listId, String videoEventId) async =>
      (await addVideoToListResult(listId, videoEventId)).success;

  /// [addVideoToList] variant that returns the full [CuratedListResult]
  /// so the UI can render retry-able failure snackbars.
  Future<CuratedListResult> addVideoToListResult(
    String listId,
    String videoEventId,
  ) async {
    final listIndex = _lists.indexWhere((list) => list.id == listId);
    if (listIndex == -1) {
      Log.warning(
        'List not found: $listId',
        name: 'CuratedListService',
        category: LogCategory.system,
      );
      return CuratedListResult.failure();
    }

    final originalList = _lists[listIndex];

    // Already in the list — no-op (local + relay state already match).
    if (originalList.videoEventIds.contains(videoEventId)) {
      Log.warning(
        'Video already in list: $videoEventId',
        name: 'CuratedListService',
        category: LogCategory.system,
      );
      return CuratedListResult.successResult(list: originalList);
    }

    final updatedList = originalList.copyWith(
      videoEventIds: [...originalList.videoEventIds, videoEventId],
      updatedAt: DateTime.now(),
    );

    _lists[listIndex] = updatedList;
    await _saveLists();

    // Private lists never publish — the local mutation is authoritative.
    if (!updatedList.isPublic || !_authService.isAuthenticated) {
      Log.debug(
        '➕ Added video to list "${originalList.name}": $videoEventId',
        name: 'CuratedListService',
        category: LogCategory.system,
      );
      return CuratedListResult.successResult(list: updatedList);
    }

    final publish = await _publishListToNostr(updatedList);
    if (!publish.success) {
      // Rollback: restore the previous list so local state matches relay.
      _lists[listIndex] = originalList;
      await _saveLists();
      return publish;
    }

    Log.debug(
      '➕ Added video to list "${originalList.name}": $videoEventId',
      name: 'CuratedListService',
      category: LogCategory.system,
    );
    return publish;
  }

  /// Remove video from a list. Returns `true` on durable success.
  Future<bool> removeVideoFromList(
    String listId,
    String videoEventId,
  ) async => (await removeVideoFromListResult(listId, videoEventId)).success;

  /// [removeVideoFromList] variant returning the full [CuratedListResult].
  Future<CuratedListResult> removeVideoFromListResult(
    String listId,
    String videoEventId,
  ) async {
    final listIndex = _lists.indexWhere((list) => list.id == listId);
    if (listIndex == -1) {
      Log.warning(
        'List not found: $listId',
        name: 'CuratedListService',
        category: LogCategory.system,
      );
      return CuratedListResult.failure();
    }

    final originalList = _lists[listIndex];
    final updatedList = originalList.copyWith(
      videoEventIds: originalList.videoEventIds
          .where((id) => id != videoEventId)
          .toList(),
      updatedAt: DateTime.now(),
    );

    _lists[listIndex] = updatedList;
    await _saveLists();

    if (!updatedList.isPublic || !_authService.isAuthenticated) {
      Log.debug(
        '➖ Removed video from list "${originalList.name}": $videoEventId',
        name: 'CuratedListService',
        category: LogCategory.system,
      );
      return CuratedListResult.successResult(list: updatedList);
    }

    final publish = await _publishListToNostr(updatedList);
    if (!publish.success) {
      _lists[listIndex] = originalList;
      await _saveLists();
      return publish;
    }

    Log.debug(
      '➖ Removed video from list "${originalList.name}": $videoEventId',
      name: 'CuratedListService',
      category: LogCategory.system,
    );
    return publish;
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

  /// Update list metadata with enhanced playlist features.
  ///
  /// Gates local state commit on relay confirmation when the list is
  /// public — transient failures roll back the local mutation.
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
    final listIndex = _lists.indexWhere((list) => list.id == listId);
    if (listIndex == -1) {
      return false;
    }

    final originalList = _lists[listIndex];
    final updatedList = originalList.copyWith(
      name: name ?? originalList.name,
      description: description ?? originalList.description,
      imageUrl: imageUrl ?? originalList.imageUrl,
      isPublic: isPublic ?? originalList.isPublic,
      tags: tags ?? originalList.tags,
      isCollaborative: isCollaborative ?? originalList.isCollaborative,
      allowedCollaborators:
          allowedCollaborators ?? originalList.allowedCollaborators,
      thumbnailEventId: thumbnailEventId ?? originalList.thumbnailEventId,
      playOrder: playOrder ?? originalList.playOrder,
      updatedAt: DateTime.now(),
    );

    _lists[listIndex] = updatedList;
    await _saveLists();

    if (!updatedList.isPublic || !_authService.isAuthenticated) {
      Log.debug(
        '✏️ Updated list: ${updatedList.name}',
        name: 'CuratedListService',
        category: LogCategory.system,
      );
      return true;
    }

    final publish = await _publishListToNostr(updatedList);
    if (!publish.success) {
      _lists[listIndex] = originalList;
      await _saveLists();
      return false;
    }

    Log.debug(
      '✏️ Updated list: ${updatedList.name}',
      name: 'CuratedListService',
      category: LogCategory.system,
    );
    return true;
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

  /// Reorder videos in a playlist (manual play order).
  ///
  /// Gates local commit on relay confirmation for public lists; rolls
  /// back on transient failure.
  Future<bool> reorderVideos(String listId, List<String> newOrder) async {
    final listIndex = _lists.indexWhere((list) => list.id == listId);
    if (listIndex == -1) {
      Log.warning(
        'List not found: $listId',
        name: 'CuratedListService',
        category: LogCategory.system,
      );
      return false;
    }

    final originalList = _lists[listIndex];

    // Validate that all current videos are included in the new order.
    final currentVideos = Set<String>.from(originalList.videoEventIds);
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

    final updatedList = originalList.copyWith(
      videoEventIds: newOrder,
      playOrder: PlayOrder.manual, // Set to manual when reordering.
      updatedAt: DateTime.now(),
    );

    _lists[listIndex] = updatedList;
    await _saveLists();

    if (!updatedList.isPublic || !_authService.isAuthenticated) {
      Log.debug(
        '📱 Reordered videos in list "${originalList.name}"',
        name: 'CuratedListService',
        category: LogCategory.system,
      );
      return true;
    }

    final publish = await _publishListToNostr(updatedList);
    if (!publish.success) {
      _lists[listIndex] = originalList;
      await _saveLists();
      return false;
    }

    Log.debug(
      '📱 Reordered videos in list "${originalList.name}"',
      name: 'CuratedListService',
      category: LogCategory.system,
    );
    return true;
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

  /// Add collaborator to a list.
  Future<bool> addCollaborator(String listId, String pubkey) async {
    final listIndex = _lists.indexWhere((list) => list.id == listId);
    if (listIndex == -1) {
      return false;
    }

    final originalList = _lists[listIndex];
    if (!originalList.isCollaborative) {
      Log.warning(
        'Cannot add collaborator - list is not collaborative',
        name: 'CuratedListService',
        category: LogCategory.system,
      );
      return false;
    }

    if (originalList.allowedCollaborators.contains(pubkey)) {
      Log.debug(
        'User already a collaborator: $pubkey',
        name: 'CuratedListService',
        category: LogCategory.system,
      );
      return true;
    }

    final updatedList = originalList.copyWith(
      allowedCollaborators: [...originalList.allowedCollaborators, pubkey],
      updatedAt: DateTime.now(),
    );

    _lists[listIndex] = updatedList;
    await _saveLists();

    if (!updatedList.isPublic || !_authService.isAuthenticated) {
      Log.debug(
        '✅ Added collaborator to list "${originalList.name}": $pubkey',
        name: 'CuratedListService',
        category: LogCategory.system,
      );
      return true;
    }

    final publish = await _publishListToNostr(updatedList);
    if (!publish.success) {
      _lists[listIndex] = originalList;
      await _saveLists();
      return false;
    }

    Log.debug(
      '✅ Added collaborator to list "${originalList.name}": $pubkey',
      name: 'CuratedListService',
      category: LogCategory.system,
    );
    return true;
  }

  /// Remove collaborator from a list.
  Future<bool> removeCollaborator(String listId, String pubkey) async {
    final listIndex = _lists.indexWhere((list) => list.id == listId);
    if (listIndex == -1) {
      return false;
    }

    final originalList = _lists[listIndex];
    final updatedList = originalList.copyWith(
      allowedCollaborators: originalList.allowedCollaborators
          .where((collaborator) => collaborator != pubkey)
          .toList(),
      updatedAt: DateTime.now(),
    );

    _lists[listIndex] = updatedList;
    await _saveLists();

    if (!updatedList.isPublic || !_authService.isAuthenticated) {
      Log.debug(
        '➖ Removed collaborator from list "${originalList.name}": $pubkey',
        name: 'CuratedListService',
        category: LogCategory.system,
      );
      return true;
    }

    final publish = await _publishListToNostr(updatedList);
    if (!publish.success) {
      _lists[listIndex] = originalList;
      await _saveLists();
      return false;
    }

    Log.debug(
      '➖ Removed collaborator from list "${originalList.name}": $pubkey',
      name: 'CuratedListService',
      category: LogCategory.system,
    );
    return true;
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

  /// Publish list to Nostr as NIP-51 kind 30005 event.
  ///
  /// Uses [NostrClient.publishEventWithRetry] so transient failures retry
  /// on a bounded schedule. Returns a [CuratedListResult]; callers are
  /// responsible for rolling back local state when `success` is false.
  ///
  /// Returns a "noop success" when the publish is deliberately skipped
  /// (unauthenticated user or empty list). Those cases do not represent
  /// relay-level failure and don't need to trigger a rollback.
  Future<CuratedListResult> _publishListToNostr(CuratedList list) async {
    if (!_authService.isAuthenticated) {
      Log.warning(
        'Cannot publish list - user not authenticated',
        name: 'CuratedListService',
        category: LogCategory.system,
      );
      return CuratedListResult.successResult(list: list);
    }

    // Don't spam relay with empty lists.
    if (list.videoEventIds.isEmpty) {
      Log.debug(
        'Skipping publish of empty list: ${list.name}',
        name: 'CuratedListService',
        category: LogCategory.system,
      );
      return CuratedListResult.successResult(list: list);
    }

    final content = list.description ?? 'Curated video list: ${list.name}';
    final tags = list.getEventTags();

    final event = await _authService.createAndSignEvent(
      kind: 30005, // NIP-51 curated list
      content: content,
      tags: tags,
    );

    if (event == null) {
      Log.error(
        'Failed to sign kind 30005 curated-list event',
        name: 'CuratedListService',
        category: LogCategory.system,
      );
      return CuratedListResult.failure(list: list);
    }

    final outcome = await _nostrService.publishEventWithRetry(event);
    final feedback = PublishResultMapper.map(outcome);

    if (!outcome.acceptedByAny) {
      Log.warning(
        'Curated-list publish not accepted by any relay: $outcome',
        name: 'CuratedListService',
        category: LogCategory.system,
      );
      return CuratedListResult.failure(
        outcome: outcome,
        feedback: feedback,
        list: list,
      );
    }

    // Update local list with Nostr event ID so subsequent loads can link
    // the local cache back to its latest published event.
    final listIndex = _lists.indexWhere((l) => l.id == list.id);
    CuratedList updatedList = list;
    if (listIndex != -1) {
      updatedList = list.copyWith(nostrEventId: event.id);
      _lists[listIndex] = updatedList;
      await _saveLists();
    }
    Log.debug(
      'Published list to Nostr: ${list.name} (${event.id})',
      name: 'CuratedListService',
      category: LogCategory.system,
    );
    return CuratedListResult.successResult(
      outcome: outcome,
      feedback: feedback,
      list: updatedList,
    );
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
      "📋 Fetching user's curated lists from relays for pubkey: $userPubkey",
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
          case 'description':
            if (tag.length > 1) description = tag[1];
          case 'image':
            if (tag.length > 1) imageUrl = tag[1];
          case 'thumbnail':
            if (tag.length > 1) thumbnailEventId = tag[1];
          case 'playorder':
            if (tag.length > 1) playOrderStr = tag[1];
          case 't':
            if (tag.length > 1) tags.add(tag[1]);
          case 'e':
            if (tag.length > 1) videoEventIds.add(tag[1]);
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
          case 'collaborative':
            if (tag.length > 1 && tag[1] == 'true') isCollaborative = true;
          case 'collaborator':
            if (tag.length > 1) allowedCollaborators.add(tag[1]);
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
        createdAt: event.createdAtDateTime,
        updatedAt: event.createdAtDateTime,
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
