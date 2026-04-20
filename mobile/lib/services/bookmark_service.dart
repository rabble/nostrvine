// ABOUTME: Service for managing NIP-51 bookmarks (kind 10003) and bookmark sets (kind 30003)
// ABOUTME: Handles creation, updates, and management of user's bookmark collections

import 'dart:async';
import 'dart:convert';

import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/nostr_list_service_mixin.dart';
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

/// Result of a bookmark publish operation.
///
/// Carries the per-relay [PublishOutcome] and the mapped
/// [PublishUserFeedback] so the UI can render a retry affordance for
/// transient failures and surface rejection reasons when the relay refused
/// the event. For replaceable bookmark events (kind 10003, 30003), local
/// state is only committed when [success] is true (i.e. at least one relay
/// acknowledged). On failure, any in-memory mutation has been rolled back.
class BookmarkResult {
  const BookmarkResult({
    required this.success,
    this.outcome,
    this.feedback,
    this.set,
  });

  /// Whether at least one relay accepted the publish and local state has been
  /// committed. `false` when the operation was a no-op, failed pre-publish
  /// (not authenticated), or every relay rejected/timed out.
  final bool success;

  /// Per-relay outcome. `null` when the publish never reached a relay
  /// (e.g. auth missing, event construction failed).
  final PublishOutcome? outcome;

  /// Mapped user feedback for snackbars. `null` iff [outcome] is `null`.
  final PublishUserFeedback? feedback;

  /// Populated only by [BookmarkService.createBookmarkSet] on success — the
  /// set as persisted locally with its assigned id.
  final BookmarkSet? set;

  static BookmarkResult successResult({
    required PublishOutcome outcome,
    required PublishUserFeedback feedback,
    BookmarkSet? set,
  }) => BookmarkResult(
    success: true,
    outcome: outcome,
    feedback: feedback,
    set: set,
  );

  static BookmarkResult failure({
    PublishOutcome? outcome,
    PublishUserFeedback? feedback,
  }) => BookmarkResult(
    success: false,
    outcome: outcome,
    feedback: feedback,
  );

  /// Result when an operation short-circuits (e.g. already bookmarked, not
  /// authenticated) without publishing an event. [success] reflects whether
  /// the post-condition holds locally despite no publish being attempted.
  static BookmarkResult noop({required bool success}) =>
      BookmarkResult(success: success);
}

/// Service for managing NIP-51 bookmarks and bookmark sets
class BookmarkService with NostrListServiceMixin {
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

  // Mixin interface implementations
  @override
  NostrClient get nostrService => _nostrService;
  @override
  AuthService get authService => _authService;

  static const String globalBookmarksStorageKey = 'global_bookmarks';
  static const String bookmarkSetsStorageKey = 'bookmark_sets';
  static const String globalBookmarksId = 'global_bookmarks';

  // Global bookmarks (Kind 10003)
  final List<BookmarkItem> _globalBookmarks = [];

  // Bookmark sets (Kind 30003)
  final List<BookmarkSet> _bookmarkSets = [];

  bool _isInitialized = false;

  // Getters
  List<BookmarkItem> get globalBookmarks => List.unmodifiable(_globalBookmarks);
  List<BookmarkSet> get bookmarkSets => List.unmodifiable(_bookmarkSets);
  bool get isInitialized => _isInitialized;

  /// Initialize the service
  Future<void> initialize() async {
    try {
      if (!_authService.isAuthenticated) {
        Log.warning(
          'Cannot initialize bookmarks - user not authenticated',
          name: 'BookmarkService',
          category: LogCategory.system,
        );
        return;
      }

      // 1. Load from SharedPreferences cache (fast, may be stale)
      _loadBookmarksFromSharedPreferences();

      // 2. Load from relay (authoritative)
      await _loadBookmarksFromNostr();

      // 3. Update SharedPreferences cache for next startup
      await _saveBookmarksToSharedPreferences();

      _isInitialized = true;
      Log.info(
        'Bookmark service initialized with ${_globalBookmarks.length} global bookmarks and ${_bookmarkSets.length} bookmark sets',
        name: 'BookmarkService',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Failed to initialize bookmark service: $e',
        name: 'BookmarkService',
        category: LogCategory.system,
      );
    }
  }

  // === GLOBAL BOOKMARKS (Kind 10003) ===

  /// Add a video event to global bookmarks
  Future<BookmarkResult> addVideoToGlobalBookmarks(
    String videoEventId, {
    String? relay,
    String? petname,
  }) async {
    return addToGlobalBookmarks(
      BookmarkItem(type: 'e', id: videoEventId, relay: relay, petname: petname),
    );
  }

  /// Add an item to global bookmarks.
  ///
  /// For the replaceable kind 10003 event we optimistically mutate the in-
  /// memory list, publish with retry, and roll back the mutation if no relay
  /// accepted.
  Future<BookmarkResult> addToGlobalBookmarks(BookmarkItem item) async {
    // Check if already bookmarked — short-circuit without a publish.
    if (_globalBookmarks.contains(item)) {
      Log.debug(
        'Item already in global bookmarks: ${item.id}',
        name: 'BookmarkService',
        category: LogCategory.system,
      );
      return BookmarkResult.noop(success: true);
    }

    if (!_authService.isAuthenticated) {
      Log.warning(
        'Cannot bookmark - user not authenticated',
        name: 'BookmarkService',
        category: LogCategory.system,
      );
      return BookmarkResult.noop(success: false);
    }

    // Optimistically mutate, persist cache so the UI reads through state.
    _globalBookmarks.add(item);
    await _saveBookmarks();

    final result = await _publishGlobalBookmarksToNostr();
    if (!result.success) {
      // Rollback: addressable/replaceable kinds demand relay confirmation
      // before we treat the bookmark as durable.
      _globalBookmarks.remove(item);
      await _saveBookmarks();
      return result;
    }

    Log.info(
      'Added item to global bookmarks: ${item.id}',
      name: 'BookmarkService',
      category: LogCategory.system,
    );
    return result;
  }

  /// Remove an item from global bookmarks.
  ///
  /// Optimistically removes the item, publishes the replacement event, and
  /// re-inserts on failure so the UI reverts to "bookmarked".
  Future<BookmarkResult> removeFromGlobalBookmarks(BookmarkItem item) async {
    final originalIndex = _globalBookmarks.indexOf(item);
    if (originalIndex == -1) {
      Log.warning(
        'Item not found in global bookmarks: ${item.id}',
        name: 'BookmarkService',
        category: LogCategory.system,
      );
      return BookmarkResult.noop(success: false);
    }

    if (!_authService.isAuthenticated) {
      Log.warning(
        'Cannot remove bookmark - user not authenticated',
        name: 'BookmarkService',
        category: LogCategory.system,
      );
      return BookmarkResult.noop(success: false);
    }

    _globalBookmarks.removeAt(originalIndex);
    await _saveBookmarks();

    final result = await _publishGlobalBookmarksToNostr();
    if (!result.success) {
      // Rollback: re-insert at the original position so the order is stable.
      _globalBookmarks.insert(originalIndex, item);
      await _saveBookmarks();
      return result;
    }

    Log.info(
      'Removed item from global bookmarks: ${item.id}',
      name: 'BookmarkService',
      category: LogCategory.system,
    );
    return result;
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

  /// Create a new bookmark set.
  ///
  /// Optimistically appends the set to local state, publishes, and removes it
  /// on failure so the UI doesn't surface a ghost set.
  Future<BookmarkResult> createBookmarkSet({
    required String name,
    String? description,
    String? imageUrl,
  }) async {
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

    if (!_authService.isAuthenticated) {
      // Allow local-only use when not authenticated: persist but surface
      // a failure so the UI can explain the missing sync.
      _bookmarkSets.add(newSet);
      await _saveBookmarks();
      return BookmarkResult.noop(success: false);
    }

    _bookmarkSets.add(newSet);
    await _saveBookmarks();

    final result = await _publishBookmarkSetToNostr(newSet);
    if (!result.success) {
      _bookmarkSets.removeWhere((s) => s.id == newSet.id);
      await _saveBookmarks();
      return result;
    }

    // Re-read the possibly-updated set (published with nostrEventId).
    final stored = _bookmarkSets.firstWhere(
      (s) => s.id == newSet.id,
      orElse: () => newSet,
    );
    Log.info(
      'Created new bookmark set: $name ($setId)',
      name: 'BookmarkService',
      category: LogCategory.system,
    );
    return BookmarkResult.successResult(
      outcome: result.outcome!,
      feedback: result.feedback!,
      set: stored,
    );
  }

  /// Add an item to a bookmark set.
  Future<BookmarkResult> addToBookmarkSet(
    String setId,
    BookmarkItem item,
  ) async {
    final setIndex = _bookmarkSets.indexWhere((set) => set.id == setId);
    if (setIndex == -1) {
      Log.warning(
        'Bookmark set not found: $setId',
        name: 'BookmarkService',
        category: LogCategory.system,
      );
      return BookmarkResult.noop(success: false);
    }

    final set = _bookmarkSets[setIndex];
    if (set.items.contains(item)) {
      Log.debug(
        'Item already in bookmark set: ${item.id}',
        name: 'BookmarkService',
        category: LogCategory.system,
      );
      return BookmarkResult.noop(success: true);
    }

    if (!_authService.isAuthenticated) {
      return BookmarkResult.noop(success: false);
    }

    final updatedSet = set.copyWith(
      items: [...set.items, item],
      updatedAt: DateTime.now(),
    );
    _bookmarkSets[setIndex] = updatedSet;
    await _saveBookmarks();

    final result = await _publishBookmarkSetToNostr(updatedSet);
    if (!result.success) {
      // Rollback: restore previous set value at the original index.
      _bookmarkSets[setIndex] = set;
      await _saveBookmarks();
      return result;
    }
    return result;
  }

  /// Remove an item from a bookmark set.
  Future<BookmarkResult> removeFromBookmarkSet(
    String setId,
    BookmarkItem item,
  ) async {
    final setIndex = _bookmarkSets.indexWhere((set) => set.id == setId);
    if (setIndex == -1) {
      Log.warning(
        'Bookmark set not found: $setId',
        name: 'BookmarkService',
        category: LogCategory.system,
      );
      return BookmarkResult.noop(success: false);
    }

    final set = _bookmarkSets[setIndex];
    if (!set.items.contains(item)) {
      return BookmarkResult.noop(success: true);
    }

    if (!_authService.isAuthenticated) {
      return BookmarkResult.noop(success: false);
    }

    final updatedSet = set.copyWith(
      items: set.items.where((i) => i != item).toList(),
      updatedAt: DateTime.now(),
    );
    _bookmarkSets[setIndex] = updatedSet;
    await _saveBookmarks();

    final result = await _publishBookmarkSetToNostr(updatedSet);
    if (!result.success) {
      _bookmarkSets[setIndex] = set;
      await _saveBookmarks();
      return result;
    }
    return result;
  }

  /// Update bookmark set metadata.
  Future<BookmarkResult> updateBookmarkSet({
    required String setId,
    String? name,
    String? description,
    String? imageUrl,
  }) async {
    final setIndex = _bookmarkSets.indexWhere((set) => set.id == setId);
    if (setIndex == -1) {
      return BookmarkResult.noop(success: false);
    }

    if (!_authService.isAuthenticated) {
      return BookmarkResult.noop(success: false);
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

    final result = await _publishBookmarkSetToNostr(updatedSet);
    if (!result.success) {
      _bookmarkSets[setIndex] = set;
      await _saveBookmarks();
      return result;
    }
    return result;
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

  /// Public method to publish a bookmark set to Nostr (for background sync).
  ///
  /// Returns [BookmarkResult.success] when at least one relay accepted.
  Future<BookmarkResult> publishBookmarkSetToNostr(String setId) async {
    final set = getBookmarkSetById(setId);
    if (set == null) {
      Log.warning(
        'Cannot publish bookmark set - not found: $setId',
        name: 'BookmarkService',
        category: LogCategory.system,
      );
      return BookmarkResult.noop(success: false);
    }
    return _publishBookmarkSetToNostr(set);
  }

  /// Publish global bookmarks to Nostr as NIP-51 kind 10003 event.
  ///
  /// Uses [NostrClient.publishEventWithRetry] so transient failures
  /// automatically retry once per relay. Returns a [BookmarkResult]; callers
  /// gate local state commits on `result.success`.
  Future<BookmarkResult> _publishGlobalBookmarksToNostr() async {
    if (!_authService.isAuthenticated) {
      Log.warning(
        'Cannot publish bookmarks - user not authenticated',
        name: 'BookmarkService',
        category: LogCategory.system,
      );
      return BookmarkResult.noop(success: false);
    }

    // Create NIP-51 kind 10003 tags
    final tags = <List<String>>[
      ['client', 'diVine'],
    ];

    // Add bookmark items as tags
    for (final item in _globalBookmarks) {
      tags.add(item.toTag());
    }

    final event = await _authService.createAndSignEvent(
      kind: 10003, // NIP-51 global bookmarks
      content: 'Divine global bookmarks',
      tags: tags,
    );

    if (event == null) {
      Log.error(
        'Failed to sign kind 10003 bookmark event',
        name: 'BookmarkService',
        category: LogCategory.system,
      );
      return BookmarkResult.failure();
    }

    final outcome = await _nostrService.publishEventWithRetry(event);
    final feedback = PublishResultMapper.map(outcome);

    if (!outcome.acceptedByAny) {
      Log.warning(
        'Global bookmark publish not accepted by any relay: $outcome',
        name: 'BookmarkService',
        category: LogCategory.system,
      );
      return BookmarkResult.failure(outcome: outcome, feedback: feedback);
    }

    Log.debug(
      'Published global bookmarks to Nostr: ${event.id}',
      name: 'BookmarkService',
      category: LogCategory.system,
    );
    return BookmarkResult.successResult(outcome: outcome, feedback: feedback);
  }

  /// Publish bookmark set to Nostr as NIP-51 kind 30003 event.
  Future<BookmarkResult> _publishBookmarkSetToNostr(BookmarkSet set) async {
    if (!_authService.isAuthenticated) {
      Log.warning(
        'Cannot publish bookmark set - user not authenticated',
        name: 'BookmarkService',
        category: LogCategory.system,
      );
      return BookmarkResult.noop(success: false);
    }

    // Create NIP-51 kind 30003 tags
    final tags = <List<String>>[
      ['d', set.id], // Identifier for replaceable event
      ['title', set.name],
      ['client', 'diVine'],
    ];

    if (set.description != null && set.description!.isNotEmpty) {
      tags.add(['description', set.description!]);
    }

    if (set.imageUrl != null && set.imageUrl!.isNotEmpty) {
      tags.add(['image', set.imageUrl!]);
    }

    for (final item in set.items) {
      tags.add(item.toTag());
    }

    final content = set.description ?? 'Bookmark collection: ${set.name}';

    final event = await _authService.createAndSignEvent(
      kind: 30003, // NIP-51 bookmark set
      content: content,
      tags: tags,
    );

    if (event == null) {
      Log.error(
        'Failed to sign kind 30003 bookmark-set event',
        name: 'BookmarkService',
        category: LogCategory.system,
      );
      return BookmarkResult.failure();
    }

    final outcome = await _nostrService.publishEventWithRetry(event);
    final feedback = PublishResultMapper.map(outcome);

    if (!outcome.acceptedByAny) {
      Log.warning(
        'Bookmark-set publish not accepted by any relay: $outcome',
        name: 'BookmarkService',
        category: LogCategory.system,
      );
      return BookmarkResult.failure(outcome: outcome, feedback: feedback);
    }

    // Update local set with Nostr event ID so subsequent loads/persistence
    // can link the local set back to its latest published event.
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
    return BookmarkResult.successResult(outcome: outcome, feedback: feedback);
  }

  // === NOSTR LOADING ===

  /// Load bookmarks from relay (authoritative)
  Future<void> _loadBookmarksFromNostr() async {
    try {
      // Get all our published events using the universal query
      final myEvents = await getMyPublishedEvents();

      // Filter for bookmark-related events
      final bookmarkEvents = filterMyEventsByKind(myEvents, [10003, 30003]);

      if (bookmarkEvents.isEmpty) {
        Log.debug(
          'No bookmark events found in relay',
          name: 'BookmarkService',
          category: LogCategory.system,
        );
        return;
      }

      // Process global bookmarks (kind 10003) - latest replaces previous
      final globalBookmarkEvents = bookmarkEvents
          .where((e) => e.kind == 10003)
          .toList();
      if (globalBookmarkEvents.isNotEmpty) {
        // Sort by created_at to get the latest
        globalBookmarkEvents.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _parseGlobalBookmarksFromEvent(globalBookmarkEvents.first);
        Log.debug(
          'Loaded global bookmarks from Nostr event: ${globalBookmarkEvents.first.id}',
          name: 'BookmarkService',
          category: LogCategory.system,
        );
      }

      // Process bookmark sets (kind 30003) - latest per d-tag
      final bookmarkSetEvents = filterMyParameterizedEvents(myEvents, [30003]);
      for (final event in bookmarkSetEvents.values) {
        _parseBookmarkSetFromEvent(event);
      }

      Log.info(
        'Loaded ${_globalBookmarks.length} global bookmarks and ${_bookmarkSets.length} bookmark sets from relay',
        name: 'BookmarkService',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Failed to load bookmarks from relay: $e',
        name: 'BookmarkService',
        category: LogCategory.system,
      );
    }
  }

  /// Parse global bookmarks from NIP-51 kind 10003 event
  void _parseGlobalBookmarksFromEvent(Event event) {
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

  /// Parse bookmark set from NIP-51 kind 30003 event
  void _parseBookmarkSetFromEvent(Event event) {
    // Extract d-tag (identifier)
    String? dTag;
    String? title;
    String? description;
    String? imageUrl;

    for (final tag in event.tags) {
      if (tag.length >= 2) {
        switch (tag[0]) {
          case 'd':
            dTag = tag[1];
          case 'title':
            title = tag[1];
          case 'description':
            description = tag[1];
          case 'image':
            imageUrl = tag[1];
        }
      }
    }

    if (dTag == null) {
      Log.warning(
        'Bookmark set event missing d-tag: ${event.id}',
        name: 'BookmarkService',
        category: LogCategory.system,
      );
      return;
    }

    // Parse bookmark items from tags
    final items = <BookmarkItem>[];
    for (final tag in event.tags) {
      if (tag.length >= 2 && ['e', 'a', 't', 'r'].contains(tag[0])) {
        final item = BookmarkItem(
          type: tag[0],
          id: tag[1],
          relay: tag.length > 2 ? tag[2] : null,
          petname: tag.length > 3 ? tag[3] : null,
        );
        items.add(item);
      }
    }

    final bookmarkSet = BookmarkSet(
      id: dTag,
      name: title ?? dTag,
      description: description,
      imageUrl: imageUrl,
      items: items,
      createdAt: event.createdAtDateTime,
      updatedAt: event.createdAtDateTime,
      nostrEventId: event.id,
    );

    // Remove existing set with same ID and add updated one
    _bookmarkSets.removeWhere((set) => set.id == dTag);
    _bookmarkSets.add(bookmarkSet);
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
