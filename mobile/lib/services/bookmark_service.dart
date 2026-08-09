// ABOUTME: Service for managing NIP-51 bookmarks (kind 10003) and bookmark sets (kind 30003)
// ABOUTME: Handles creation, updates, and management of user's bookmark collections

import 'dart:async';
import 'dart:convert';

import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

/// Represents a bookmarked item
class BookmarkItem {
  const BookmarkItem({
    required this.type,
    required this.id,
    this.relay,
    this.petname,
  });

  final String
  type; // 'e' (event), 'a' (parameterized replaceable), 't' (hashtag), 'r' (URL)
  final String id; // Event ID, article ID, hashtag, or URL
  final String? relay; // Optional relay hint
  final String? petname; // Optional petname/label

  List<String> toTag() {
    final tag = [type, id];
    if (relay != null) tag.add(relay!);
    if (petname != null) tag.add(petname!);
    return tag;
  }

  static BookmarkItem fromTag(List<String> tag) {
    return BookmarkItem(
      type: tag[0],
      id: tag[1],
      relay: tag.length > 2 ? tag[2] : null,
      petname: tag.length > 3 ? tag[3] : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'id': id,
    'relay': relay,
    'petname': petname,
  };

  static BookmarkItem fromJson(Map<String, dynamic> json) => BookmarkItem(
    type: json['type'] as String,
    id: json['id'] as String,
    relay: json['relay'] as String?,
    petname: json['petname'] as String?,
  );

  @override
  bool operator ==(Object other) =>
      other is BookmarkItem && other.type == type && other.id == id;

  @override
  int get hashCode => Object.hash(type, id);
}

/// Represents a bookmark set (categorized bookmarks)
class BookmarkSet {
  const BookmarkSet({
    required this.id,
    required this.name,
    required this.items,
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
  final List<BookmarkItem> items;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? nostrEventId;

  BookmarkSet copyWith({
    String? id,
    String? name,
    String? description,
    String? imageUrl,
    List<BookmarkItem>? items,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? nostrEventId,
  }) => BookmarkSet(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
    imageUrl: imageUrl ?? this.imageUrl,
    items: items ?? this.items,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    nostrEventId: nostrEventId ?? this.nostrEventId,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'imageUrl': imageUrl,
    'items': items.map((item) => item.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'nostrEventId': nostrEventId,
  };

  static BookmarkSet fromJson(Map<String, dynamic> json) => BookmarkSet(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String?,
    imageUrl: json['imageUrl'] as String?,
    items: (json['items'] as List<dynamic>)
        .map((item) => BookmarkItem.fromJson(item as Map<String, dynamic>))
        .toList(),
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    nostrEventId: json['nostrEventId'] as String?,
  );
}

/// Outcome of [BookmarkService.toggleVideoInGlobalBookmarks].
///
/// Carries the state observed *after* reconciling with the relay, so callers
/// render "Saved" / "Removed" from what actually happened rather than from a
/// local read that predates the sync.
class BookmarkToggleResult {
  const BookmarkToggleResult({
    required this.succeeded,
    required this.wasBookmarked,
    required this.isBookmarked,
  });

  /// Whether the change reconciled and a relay accepted the new list.
  final bool succeeded;

  /// Whether the video was bookmarked before the toggle, per the relay.
  final bool wasBookmarked;

  /// Whether the video is bookmarked now. Equals [wasBookmarked] when the
  /// toggle failed, since nothing was published.
  final bool isBookmarked;
}

/// Service for managing NIP-51 bookmarks and bookmark sets
class BookmarkService {
  BookmarkService({
    required NostrClient nostrService,
    required AuthService authService,
    required SharedPreferences prefs,
  }) : _nostrService = nostrService,
       _authService = authService,
       _prefs = prefs {
    _loadBookmarksFromSharedPreferences();
  }

  final NostrClient _nostrService;
  final AuthService _authService;
  final SharedPreferences _prefs;

  static const String globalBookmarksStorageKey = 'global_bookmarks';
  static const String bookmarkSetsStorageKey = 'bookmark_sets';
  static const String globalBookmarksId = 'global_bookmarks';

  /// NIP-51 kind for the uncategorized ("global") bookmark list.
  static const int globalBookmarksKind = 10003;

  // Global bookmarks (Kind 10003)
  final List<BookmarkItem> _globalBookmarks = [];

  // Bookmark sets (Kind 30003)
  final List<BookmarkSet> _bookmarkSets = [];

  /// The `content` of the newest kind-10003 we have seen for this user.
  ///
  /// NIP-51 reserves `.content` for the NIP-44-encrypted private item array.
  /// Divine cannot read those items yet, so it carries the ciphertext through
  /// untouched instead of overwriting another client's private bookmarks.
  String _lastKnownRemoteContent = '';

  // Getters
  List<BookmarkItem> get globalBookmarks => List.unmodifiable(_globalBookmarks);
  List<BookmarkSet> get bookmarkSets => List.unmodifiable(_bookmarkSets);

  // === GLOBAL BOOKMARKS (Kind 10003) ===

  /// Reconciles [globalBookmarks] against the user's kind-10003 on the relay.
  ///
  /// Returns `false` when the remote list could not be established — signed
  /// out, no reachable relay, or a timed-out query. **Callers that are about
  /// to publish must not write on `false`**: kind 10003 is replaceable, so
  /// republishing a list this device never reconciled deletes every bookmark
  /// it has not seen (see `replaceable-event-preservation`).
  ///
  /// A zero-event answer is only trusted when the relay actually answered,
  /// which is why this uses [NostrClient.queryEventsDetailed] rather than
  /// [NostrClient.queryEvents] — the latter cannot tell "you have no
  /// bookmarks" apart from "nobody replied", and treating the second as the
  /// first is precisely how the list gets destroyed.
  Future<bool> syncGlobalBookmarks() async {
    final pubkey = _authService.currentPublicKeyHex;
    if (!_authService.isAuthenticated || pubkey == null) {
      Log.warning(
        'Skipping bookmark sync - user not authenticated',
        name: 'BookmarkService',
        category: LogCategory.system,
      );
      return false;
    }

    try {
      final result = await _nostrService.queryEventsDetailed([
        Filter(kinds: [globalBookmarksKind], authors: [pubkey], limit: 1),
      ]);

      if (result.timedOut || result.noRelays) {
        Log.warning(
          'Bookmark sync inconclusive (timedOut=${result.timedOut}, '
          'noRelays=${result.noRelays}) - remote list left unchanged',
          name: 'BookmarkService',
          category: LogCategory.system,
        );
        return false;
      }

      final events = result.events
          .where((event) => event.kind == globalBookmarksKind)
          .toList();
      if (events.isEmpty) {
        // The relay answered and has nothing: a genuinely empty list.
        _globalBookmarks.clear();
        _lastKnownRemoteContent = '';
      } else {
        events.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _adoptGlobalBookmarksFromEvent(events.first);
      }

      await _saveBookmarksToSharedPreferences();

      Log.info(
        'Synced ${_globalBookmarks.length} global bookmarks from relay',
        name: 'BookmarkService',
        category: LogCategory.system,
      );
      return true;
    } catch (e) {
      Log.error(
        'Failed to sync global bookmarks from relay: $e',
        name: 'BookmarkService',
        category: LogCategory.system,
      );
      return false;
    }
  }

  /// Add a video event to global bookmarks
  Future<bool> addVideoToGlobalBookmarks(
    String videoEventId, {
    String? relay,
    String? petname,
  }) async {
    return addToGlobalBookmarks(
      BookmarkItem(type: 'e', id: videoEventId, relay: relay, petname: petname),
    );
  }

  /// Remove a video event from global bookmarks (kind 10003 `e` tag).
  Future<bool> removeVideoFromGlobalBookmarks(String videoEventId) async {
    return removeFromGlobalBookmarks(BookmarkItem(type: 'e', id: videoEventId));
  }

  /// If [videoEventId] is globally bookmarked, removes it; otherwise adds it.
  ///
  /// The direction is decided *after* reconciling with the relay, so a video
  /// bookmarked on another device is removed rather than added a second time.
  /// The returned [BookmarkToggleResult] carries both the reconciled
  /// before-state and the resulting state; callers must not assume the
  /// direction from their own pre-read.
  Future<BookmarkToggleResult> toggleVideoInGlobalBookmarks(
    String videoEventId, {
    String? relay,
    String? petname,
  }) async {
    final reconciled = await syncGlobalBookmarks();
    final wasBookmarked = isVideoBookmarkedGlobally(videoEventId);

    if (!reconciled) {
      return BookmarkToggleResult(
        succeeded: false,
        wasBookmarked: wasBookmarked,
        isBookmarked: wasBookmarked,
      );
    }

    final succeeded = wasBookmarked
        ? await removeFromGlobalBookmarks(
            BookmarkItem(type: 'e', id: videoEventId),
            alreadyReconciled: true,
          )
        : await addToGlobalBookmarks(
            BookmarkItem(
              type: 'e',
              id: videoEventId,
              relay: relay,
              petname: petname,
            ),
            alreadyReconciled: true,
          );

    return BookmarkToggleResult(
      succeeded: succeeded,
      wasBookmarked: wasBookmarked,
      isBookmarked: succeeded ? !wasBookmarked : wasBookmarked,
    );
  }

  /// Add an item to global bookmarks.
  ///
  /// Reconciles with the relay first and refuses to publish if that fails, so
  /// a device whose cache is empty (fresh install, second device) cannot
  /// replace the user's list with a one-item one.
  ///
  /// Pass [alreadyReconciled] when the caller has just run
  /// [syncGlobalBookmarks] and the extra round trip would be redundant.
  Future<bool> addToGlobalBookmarks(
    BookmarkItem item, {
    bool alreadyReconciled = false,
  }) async {
    try {
      if (!alreadyReconciled && !await syncGlobalBookmarks()) {
        Log.warning(
          'Not adding to global bookmarks: could not reconcile with relay',
          name: 'BookmarkService',
          category: LogCategory.system,
        );
        return false;
      }

      // Check if already bookmarked
      if (_globalBookmarks.contains(item)) {
        Log.debug(
          'Item already in global bookmarks: ${item.id}',
          name: 'BookmarkService',
          category: LogCategory.system,
        );
        return true;
      }

      _globalBookmarks.add(item);
      await _saveBookmarks();

      final published = await _publishGlobalBookmarksToNostr();
      if (!published) return false;

      Log.info(
        'Added item to global bookmarks: ${item.id}',
        name: 'BookmarkService',
        category: LogCategory.system,
      );

      return true;
    } catch (e) {
      Log.error(
        'Failed to add to global bookmarks: $e',
        name: 'BookmarkService',
        category: LogCategory.system,
      );
      return false;
    }
  }

  /// Remove an item from global bookmarks.
  ///
  /// Reconciles with the relay first for the same reason as
  /// [addToGlobalBookmarks] — the republished list must be the user's real
  /// one minus [item], not this device's cache minus [item].
  Future<bool> removeFromGlobalBookmarks(
    BookmarkItem item, {
    bool alreadyReconciled = false,
  }) async {
    try {
      if (!alreadyReconciled && !await syncGlobalBookmarks()) {
        Log.warning(
          'Not removing from global bookmarks: could not reconcile with relay',
          name: 'BookmarkService',
          category: LogCategory.system,
        );
        return false;
      }

      final removed = _globalBookmarks.remove(item);
      if (!removed) {
        Log.warning(
          'Item not found in global bookmarks: ${item.id}',
          name: 'BookmarkService',
          category: LogCategory.system,
        );
        return false;
      }

      await _saveBookmarks();

      final published = await _publishGlobalBookmarksToNostr();
      if (!published) return false;

      Log.info(
        'Removed item from global bookmarks: ${item.id}',
        name: 'BookmarkService',
        category: LogCategory.system,
      );

      return true;
    } catch (e) {
      Log.error(
        'Failed to remove from global bookmarks: $e',
        name: 'BookmarkService',
        category: LogCategory.system,
      );
      return false;
    }
  }

  /// Check if an item is in global bookmarks
  bool isInGlobalBookmarks(String itemId, String type) {
    return _globalBookmarks.any(
      (item) => item.id == itemId && item.type == type,
    );
  }

  /// Check if a video event is bookmarked globally
  bool isVideoBookmarkedGlobally(String videoEventId) {
    return isInGlobalBookmarks(videoEventId, 'e');
  }

  // === BOOKMARK SETS (Kind 30003) ===

  /// Create a new bookmark set
  Future<BookmarkSet?> createBookmarkSet({
    required String name,
    String? description,
    String? imageUrl,
  }) async {
    try {
      final setId = 'bookmarkset_${DateTime.now().millisecondsSinceEpoch}';
      final now = DateTime.now();

      final newSet = BookmarkSet(
        id: setId,
        name: name,
        description: description,
        imageUrl: imageUrl,
        items: [],
        createdAt: now,
        updatedAt: now,
      );

      _bookmarkSets.add(newSet);
      await _saveBookmarks();

      // Publish to Nostr if authenticated
      if (_authService.isAuthenticated) {
        await _publishBookmarkSetToNostr(newSet);
      }

      Log.info(
        'Created new bookmark set: $name ($setId)',
        name: 'BookmarkService',
        category: LogCategory.system,
      );

      return newSet;
    } catch (e) {
      Log.error(
        'Failed to create bookmark set: $e',
        name: 'BookmarkService',
        category: LogCategory.system,
      );
      return null;
    }
  }

  /// Add an item to a bookmark set
  Future<bool> addToBookmarkSet(String setId, BookmarkItem item) async {
    try {
      final setIndex = _bookmarkSets.indexWhere((set) => set.id == setId);
      if (setIndex == -1) {
        Log.warning(
          'Bookmark set not found: $setId',
          name: 'BookmarkService',
          category: LogCategory.system,
        );
        return false;
      }

      final set = _bookmarkSets[setIndex];

      // Check if item is already in the set
      if (set.items.contains(item)) {
        Log.debug(
          'Item already in bookmark set: ${item.id}',
          name: 'BookmarkService',
          category: LogCategory.system,
        );
        return true;
      }

      final updatedItems = [...set.items, item];
      final updatedSet = set.copyWith(
        items: updatedItems,
        updatedAt: DateTime.now(),
      );

      _bookmarkSets[setIndex] = updatedSet;
      await _saveBookmarks();

      // Update on Nostr if authenticated
      if (_authService.isAuthenticated) {
        await _publishBookmarkSetToNostr(updatedSet);
      }

      Log.debug(
        'Added item to bookmark set "${set.name}": ${item.id}',
        name: 'BookmarkService',
        category: LogCategory.system,
      );

      return true;
    } catch (e) {
      Log.error(
        'Failed to add to bookmark set: $e',
        name: 'BookmarkService',
        category: LogCategory.system,
      );
      return false;
    }
  }

  /// Remove an item from a bookmark set
  Future<bool> removeFromBookmarkSet(String setId, BookmarkItem item) async {
    try {
      final setIndex = _bookmarkSets.indexWhere((set) => set.id == setId);
      if (setIndex == -1) {
        Log.warning(
          'Bookmark set not found: $setId',
          name: 'BookmarkService',
          category: LogCategory.system,
        );
        return false;
      }

      final set = _bookmarkSets[setIndex];
      final updatedItems = set.items.where((i) => i != item).toList();

      final updatedSet = set.copyWith(
        items: updatedItems,
        updatedAt: DateTime.now(),
      );

      _bookmarkSets[setIndex] = updatedSet;
      await _saveBookmarks();

      // Update on Nostr if authenticated
      if (_authService.isAuthenticated) {
        await _publishBookmarkSetToNostr(updatedSet);
      }

      Log.debug(
        'Removed item from bookmark set "${set.name}": ${item.id}',
        name: 'BookmarkService',
        category: LogCategory.system,
      );

      return true;
    } catch (e) {
      Log.error(
        'Failed to remove from bookmark set: $e',
        name: 'BookmarkService',
        category: LogCategory.system,
      );
      return false;
    }
  }

  /// Update bookmark set metadata
  Future<bool> updateBookmarkSet({
    required String setId,
    String? name,
    String? description,
    String? imageUrl,
  }) async {
    try {
      final setIndex = _bookmarkSets.indexWhere((set) => set.id == setId);
      if (setIndex == -1) {
        return false;
      }

      final set = _bookmarkSets[setIndex];
      final updatedSet = set.copyWith(
        name: name ?? set.name,
        description: description ?? set.description,
        imageUrl: imageUrl ?? set.imageUrl,
        updatedAt: DateTime.now(),
      );

      _bookmarkSets[setIndex] = updatedSet;
      await _saveBookmarks();

      // Update on Nostr if authenticated
      if (_authService.isAuthenticated) {
        await _publishBookmarkSetToNostr(updatedSet);
      }

      Log.debug(
        'Updated bookmark set: ${updatedSet.name}',
        name: 'BookmarkService',
        category: LogCategory.system,
      );

      return true;
    } catch (e) {
      Log.error(
        'Failed to update bookmark set: $e',
        name: 'BookmarkService',
        category: LogCategory.system,
      );
      return false;
    }
  }

  /// Delete a bookmark set
  Future<bool> deleteBookmarkSet(String setId) async {
    try {
      final setIndex = _bookmarkSets.indexWhere((set) => set.id == setId);
      if (setIndex == -1) {
        return false;
      }

      final set = _bookmarkSets[setIndex];

      // For replaceable events (kind 30003), we don't need a deletion event
      // The event is automatically replaced when publishing with the same d-tag

      _bookmarkSets.removeAt(setIndex);
      await _saveBookmarks();

      Log.debug(
        'Deleted bookmark set: ${set.name}',
        name: 'BookmarkService',
        category: LogCategory.system,
      );

      return true;
    } catch (e) {
      Log.error(
        'Failed to delete bookmark set: $e',
        name: 'BookmarkService',
        category: LogCategory.system,
      );
      return false;
    }
  }

  /// Get bookmark set by ID
  BookmarkSet? getBookmarkSetById(String setId) {
    try {
      return _bookmarkSets.firstWhere((set) => set.id == setId);
    } catch (e) {
      return null;
    }
  }

  /// Check if an item is in a specific bookmark set
  bool isInBookmarkSet(String setId, String itemId, String type) {
    final set = getBookmarkSetById(setId);
    return set?.items.any((item) => item.id == itemId && item.type == type) ??
        false;
  }

  // === NOSTR PUBLISHING ===

  /// Public method to publish a bookmark set to Nostr (for background sync)
  Future<bool> publishBookmarkSetToNostr(String setId) async {
    try {
      final set = getBookmarkSetById(setId);
      if (set == null) {
        Log.warning(
          'Cannot publish bookmark set - not found: $setId',
          name: 'BookmarkService',
          category: LogCategory.system,
        );
        return false;
      }

      await _publishBookmarkSetToNostr(set);
      return true;
    } catch (e) {
      Log.error(
        'Failed to publish bookmark set $setId: $e',
        name: 'BookmarkService',
        category: LogCategory.system,
      );
      return false;
    }
  }

  /// Publish global bookmarks to Nostr as NIP-51 kind 10003 event.
  ///
  /// Returns whether a relay accepted the event. Callers treat `false` as a
  /// failed mutation so the UI can say the save did not stick, rather than
  /// showing a bookmark that exists only on this device.
  Future<bool> _publishGlobalBookmarksToNostr() async {
    try {
      if (!_authService.isAuthenticated) {
        Log.warning(
          'Cannot publish bookmarks - user not authenticated',
          name: 'BookmarkService',
          category: LogCategory.system,
        );
        return false;
      }

      // Create NIP-51 kind 10003 tags
      final tags = <List<String>>[];

      // Add bookmark items as tags
      for (final item in _globalBookmarks) {
        tags.add(item.toTag());
      }

      final event = await _authService.createAndSignEvent(
        kind: globalBookmarksKind,
        // NIP-51 reserves `content` for the encrypted private item array, so
        // it is either the ciphertext we read back or empty — never prose.
        content: _lastKnownRemoteContent,
        tags: tags,
      );

      if (event == null) return false;

      final sentEvent = await _nostrService.publishEvent(event);
      if (sentEvent is! PublishSuccess) {
        Log.warning(
          'Relay did not accept global bookmarks: ${event.id}',
          name: 'BookmarkService',
          category: LogCategory.system,
        );
        return false;
      }

      Log.debug(
        'Published global bookmarks to Nostr: ${event.id}',
        name: 'BookmarkService',
        category: LogCategory.system,
      );
      return true;
    } catch (e) {
      Log.error(
        'Failed to publish global bookmarks to Nostr: $e',
        name: 'BookmarkService',
        category: LogCategory.system,
      );
      return false;
    }
  }

  /// Publish bookmark set to Nostr as NIP-51 kind 30003 event
  Future<void> _publishBookmarkSetToNostr(BookmarkSet set) async {
    try {
      if (!_authService.isAuthenticated) {
        Log.warning(
          'Cannot publish bookmark set - user not authenticated',
          name: 'BookmarkService',
          category: LogCategory.system,
        );
        return;
      }

      // Create NIP-51 kind 30003 tags
      final tags = <List<String>>[
        ['d', set.id], // Identifier for replaceable event
        ['title', set.name],
      ];

      // Add description if present
      if (set.description != null && set.description!.isNotEmpty) {
        tags.add(['description', set.description!]);
      }

      // Add image if present
      if (set.imageUrl != null && set.imageUrl!.isNotEmpty) {
        tags.add(['image', set.imageUrl!]);
      }

      // Add bookmark items as tags
      for (final item in set.items) {
        tags.add(item.toTag());
      }

      final content = set.description ?? 'Bookmark collection: ${set.name}';

      final event = await _authService.createAndSignEvent(
        kind: 30003, // NIP-51 bookmark set
        content: content,
        tags: tags,
      );

      if (event != null) {
        final sentEvent = await _nostrService.publishEvent(event);
        if (sentEvent is PublishSuccess) {
          // Update local set with Nostr event ID
          final setIndex = _bookmarkSets.indexWhere((s) => s.id == set.id);
          if (setIndex != -1) {
            _bookmarkSets[setIndex] = set.copyWith(nostrEventId: event.id);
            await _saveBookmarks();
          }
          Log.debug(
            'Published bookmark set to Nostr: ${set.name} (${event.id})',
            name: 'BookmarkService',
            category: LogCategory.system,
          );
        }
      }
    } catch (e) {
      Log.error(
        'Failed to publish bookmark set to Nostr: $e',
        name: 'BookmarkService',
        category: LogCategory.system,
      );
    }
  }

  // === NOSTR LOADING ===

  /// Replace the in-memory list with the contents of a kind-10003 [event].
  ///
  /// Also captures `event.content`. Divine cannot decrypt NIP-51 private
  /// items, so carrying the ciphertext through unchanged is what keeps a
  /// republish from deleting bookmarks another client stored privately.
  void _adoptGlobalBookmarksFromEvent(Event event) {
    _lastKnownRemoteContent = event.content;
    _globalBookmarks.clear();

    for (final tag in event.tags) {
      if (tag.length >= 2 && ['e', 'a', 't', 'r'].contains(tag[0])) {
        final item = BookmarkItem(
          type: tag[0],
          id: tag[1],
          relay: tag.length > 2 ? tag[2] : null,
          petname: tag.length > 3 ? tag[3] : null,
        );
        _globalBookmarks.add(item);
      }
    }
  }

  // === STORAGE ===

  /// Load bookmarks from SharedPreferences cache (fast startup)
  void _loadBookmarksFromSharedPreferences() {
    // Load global bookmarks
    final globalBookmarksJson = _prefs.getString(globalBookmarksStorageKey);
    if (globalBookmarksJson != null) {
      try {
        final List<dynamic> bookmarksData = jsonDecode(globalBookmarksJson);
        _globalBookmarks.clear();
        _globalBookmarks.addAll(
          bookmarksData.map(
            (json) => BookmarkItem.fromJson(json as Map<String, dynamic>),
          ),
        );
        Log.debug(
          'Loaded ${_globalBookmarks.length} global bookmarks from storage',
          name: 'BookmarkService',
          category: LogCategory.system,
        );
      } catch (e) {
        Log.error(
          'Failed to load global bookmarks: $e',
          name: 'BookmarkService',
          category: LogCategory.system,
        );
      }
    }

    // Load bookmark sets
    final bookmarkSetsJson = _prefs.getString(bookmarkSetsStorageKey);
    if (bookmarkSetsJson != null) {
      try {
        final List<dynamic> setsData = jsonDecode(bookmarkSetsJson);
        _bookmarkSets.clear();
        _bookmarkSets.addAll(
          setsData.map(
            (json) => BookmarkSet.fromJson(json as Map<String, dynamic>),
          ),
        );
        Log.debug(
          'Loaded ${_bookmarkSets.length} bookmark sets from storage',
          name: 'BookmarkService',
          category: LogCategory.system,
        );
      } catch (e) {
        Log.error(
          'Failed to load bookmark sets: $e',
          name: 'BookmarkService',
          category: LogCategory.system,
        );
      }
    }
  }

  /// Get all bookmark sets that contain a specific video
  List<BookmarkSet> getBookmarkSetsContainingVideo(String videoEventId) {
    return _bookmarkSets
        .where(
          (set) => set.items.any(
            (item) => item.type == 'e' && item.id == videoEventId,
          ),
        )
        .toList();
  }

  /// Get readable summary of bookmark status for a video
  String getVideoBookmarkSummary(String videoEventId) {
    final isInGlobal = isVideoBookmarkedGlobally(videoEventId);
    final bookmarkSets = getBookmarkSetsContainingVideo(videoEventId);

    if (!isInGlobal && bookmarkSets.isEmpty) {
      return 'Not bookmarked';
    }

    final parts = <String>[];
    if (isInGlobal) {
      parts.add('Bookmarked');
    }

    if (bookmarkSets.isNotEmpty) {
      if (bookmarkSets.length == 1) {
        parts.add('in "${bookmarkSets.first.name}"');
      } else {
        parts.add('in ${bookmarkSets.length} bookmark sets');
      }
    }

    return parts.join(' ');
  }

  /// Save bookmarks to SharedPreferences cache
  Future<void> _saveBookmarksToSharedPreferences() async {
    try {
      // Save global bookmarks
      final globalBookmarksJson = _globalBookmarks
          .map((item) => item.toJson())
          .toList();
      await _prefs.setString(
        globalBookmarksStorageKey,
        jsonEncode(globalBookmarksJson),
      );

      // Save bookmark sets
      final bookmarkSetsJson = _bookmarkSets
          .map((set) => set.toJson())
          .toList();
      await _prefs.setString(
        bookmarkSetsStorageKey,
        jsonEncode(bookmarkSetsJson),
      );
    } catch (e) {
      Log.error(
        'Failed to save bookmarks to SharedPreferences: $e',
        name: 'BookmarkService',
        category: LogCategory.system,
      );
    }
  }

  /// Save bookmarks to local storage (backwards compatibility)
  Future<void> _saveBookmarks() async {
    await _saveBookmarksToSharedPreferences();
  }
}
