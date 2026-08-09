// ABOUTME: Service for the NIP-51 global bookmark list (kind 10003)
// ABOUTME: Reconciles with the relay before every read and every publish

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

/// Service for the user's NIP-51 global bookmark list (kind 10003).
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

  /// NIP-51 kind for the uncategorized ("global") bookmark list.
  static const int globalBookmarksKind = 10003;

  // Global bookmarks (Kind 10003)
  final List<BookmarkItem> _globalBookmarks = [];

  /// The `content` of the newest kind-10003 we have seen for this user.
  ///
  /// NIP-51 reserves `.content` for the NIP-44-encrypted private item array.
  /// Divine cannot read those items yet, so it carries the ciphertext through
  /// untouched instead of overwriting another client's private bookmarks.
  String _lastKnownRemoteContent = '';

  List<BookmarkItem> get globalBookmarks => List.unmodifiable(_globalBookmarks);

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
      await _saveBookmarksToSharedPreferences();

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

      await _saveBookmarksToSharedPreferences();

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

  // === NOSTR PUBLISHING ===

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
        _globalBookmarks.add(BookmarkItem.fromTag(tag));
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
    } catch (e) {
      Log.error(
        'Failed to save bookmarks to SharedPreferences: $e',
        name: 'BookmarkService',
        category: LogCategory.system,
      );
    }
  }
}
