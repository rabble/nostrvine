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
  /// toggle failed, since no relay accepted a new list.
  final bool isBookmarked;
}

/// Service for the user's NIP-51 global bookmark list (kind 10003).
class BookmarkService {
  BookmarkService({
    required NostrClient nostrService,
    required AuthService authService,
    required SharedPreferences prefs,
    DateTime Function() now = DateTime.now,
  }) : _nostrService = nostrService,
       _authService = authService,
       _prefs = prefs,
       _now = now {
    _loadBookmarksFromSharedPreferences();
  }

  final NostrClient _nostrService;
  final AuthService _authService;
  final SharedPreferences _prefs;
  final DateTime Function() _now;

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

  /// How long a full-settlement "this user has no list" answer is reused
  /// before the next empty answer is confirmed again.
  ///
  /// Bounds two opposing costs: without it a user who genuinely has no
  /// bookmarks pays a full-settlement wait every time Saved opens, and with an
  /// unbounded latch a list created on another device stays invisible for the
  /// life of the service whenever a relay is mute.
  ///
  /// The exact value is uninteresting because this is only ever consulted
  /// after a read came back empty — a user who has bookmarks never reaches it
  /// and pays nothing for it.
  static const absenceConfirmationTtl = Duration(minutes: 5);

  /// When a full-settlement read last established that this user has no
  /// kind-10003 at all.
  DateTime? _absenceConfirmedAt;

  /// Whether an empty answer from a partial set of relays still has to be
  /// confirmed before it is believed.
  ///
  /// Always, while this device holds bookmarks an unconfirmed empty would
  /// discard. Otherwise whenever the last confirmation has aged out — the
  /// reinstall case starts with an empty cache, so "nothing to lose" is
  /// exactly when the confirmation matters.
  bool get _mustConfirmAbsence {
    if (_globalBookmarks.isNotEmpty) return true;
    final confirmedAt = _absenceConfirmedAt;
    return confirmedAt == null ||
        _now().difference(confirmedAt) >= absenceConfirmationTtl;
  }

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
  ///
  /// Pass [requireAuthoritative] when the result is about to become the base of
  /// a replacing publish. Without it, `true` only means *some* relay answered:
  /// the pool releases a query one second after the first terminal frame, so a
  /// relay that stays connected and never answers is skipped and its copy of
  /// the list is invisible here — indistinguishable from the user having no
  /// bookmarks, and from a newer revision not existing. Republishing on that
  /// answer is what deletes the list. With it, the query holds out for every
  /// relay and an incomplete answer reports `false` instead.
  ///
  /// A non-authoritative read still never *discards* a list on a partial
  /// answer. An empty answer is confirmed against every relay before it is
  /// believed — always while this device holds bookmarks, otherwise at most
  /// once per [absenceConfirmationTtl] counted from the last confirmed
  /// absence. Seeing a list resets that count, so a list that keeps going
  /// missing is re-confirmed each time rather than once per window. An answer
  /// that stays unconfirmed changes nothing. A read that finds a list keeps
  /// the fast trade and pays for none of this.
  Future<bool> syncGlobalBookmarks({bool requireAuthoritative = false}) async {
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
      var events = await _readRemoteGlobalBookmarks(
        pubkey,
        requireAuthoritative: requireAuthoritative,
      );
      if (events == null) return false;
      var answeredAuthoritatively = requireAuthoritative;

      if (events.isEmpty && !requireAuthoritative && _mustConfirmAbsence) {
        // Only *some* relay said the list does not exist, and the settle
        // window's latency trade cannot afford to be wrong about that one
        // answer: it is indistinguishable from a relay that stayed mute. Left
        // unchecked it either tells a user with bookmarks that they have none
        // — the reinstall #6627 is about, where the cache is empty too — or
        // overwrites the snapshot Saved falls back to offline. Confirm it
        // against every relay before believing it.
        events = await _readRemoteGlobalBookmarks(
          pubkey,
          requireAuthoritative: true,
        );
        if (events == null) {
          Log.warning(
            'Empty bookmark answer not confirmed by every relay - keeping '
            'the ${_globalBookmarks.length} bookmarks this device has',
            name: 'BookmarkService',
            category: LogCategory.system,
          );
          return false;
        }
        answeredAuthoritatively = true;
      }

      if (events.isEmpty) {
        // Nobody holds a list, and — because of the confirmation above — that
        // is either an authoritative answer or one that had nothing to
        // destroy. The first save may create one.
        //
        // Only an authoritative answer renews the absence: stamping an
        // unconfirmed one would slide the window forward on every read, and a
        // session that opens Saved often enough would never re-confirm.
        if (answeredAuthoritatively) _absenceConfirmedAt = _now();
        _globalBookmarks.clear();
        _lastKnownRemoteContent = '';
      } else {
        // Seeing the event disproves the absence, so the stamp cannot stand.
        // A list whose items are all private has no public tags, leaving
        // [_globalBookmarks] empty while [_lastKnownRemoteContent] holds
        // another client's ciphertext — a stale stamp would let the next
        // partial empty answer through unconfirmed and wipe it.
        _absenceConfirmedAt = null;
        final newestFirst = [...events]
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _adoptGlobalBookmarksFromEvent(newestFirst.first);
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

  /// The user's kind-10003 events as the relays report them, or `null` when
  /// the answer was inconclusive — no reachable relay, or a query that timed
  /// out. `null` is never "you have no bookmarks": mistaking the two is what
  /// truncates the list.
  ///
  /// An authoritative read skips the local event cache. The cache is merged in
  /// regardless of settlement, so leaving it on would let a stale locally-held
  /// kind-10003 stand in for a relay answer — and the next publish would
  /// resurrect a list the user had already emptied.
  Future<List<Event>?> _readRemoteGlobalBookmarks(
    String pubkey, {
    required bool requireAuthoritative,
  }) async {
    final result = await _nostrService.queryEventsDetailed(
      [
        Filter(kinds: [globalBookmarksKind], authors: [pubkey], limit: 1),
      ],
      useCache: !requireAuthoritative,
      requireAllRelaysSettled: requireAuthoritative,
    );

    if (result.timedOut || result.noRelays) {
      Log.warning(
        'Bookmark sync inconclusive (timedOut=${result.timedOut}, '
        'noRelays=${result.noRelays}, '
        'requireAuthoritative=$requireAuthoritative) - '
        'remote list left unchanged',
        name: 'BookmarkService',
        category: LogCategory.system,
      );
      return null;
    }

    return result.events
        .where((event) => event.kind == globalBookmarksKind)
        .toList();
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
    final reconciled = await syncGlobalBookmarks(requireAuthoritative: true);
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
  /// [syncGlobalBookmarks] with `requireAuthoritative: true` and the extra
  /// round trip would be redundant.
  Future<bool> addToGlobalBookmarks(
    BookmarkItem item, {
    bool alreadyReconciled = false,
  }) async {
    try {
      if (!alreadyReconciled &&
          !await syncGlobalBookmarks(requireAuthoritative: true)) {
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

      final published = await _publishGlobalBookmarks([
        ..._globalBookmarks,
        item,
      ]);
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
      if (!alreadyReconciled &&
          !await syncGlobalBookmarks(requireAuthoritative: true)) {
        Log.warning(
          'Not removing from global bookmarks: could not reconcile with relay',
          name: 'BookmarkService',
          category: LogCategory.system,
        );
        return false;
      }

      final candidate = [..._globalBookmarks];
      if (!candidate.remove(item)) {
        Log.warning(
          'Item not found in global bookmarks: ${item.id}',
          name: 'BookmarkService',
          category: LogCategory.system,
        );
        return false;
      }

      final published = await _publishGlobalBookmarks(candidate);
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

  /// Publishes [candidate] as the user's kind 10003 and adopts it locally only
  /// once a relay has confirmed acceptance.
  ///
  /// Returns whether a relay accepted the event. On `false` nothing local has
  /// moved: memory and the [SharedPreferences] cache still hold the list this
  /// device last reconciled, so a failed save cannot leave a bookmark that
  /// exists only on this device until the next sync happens to wipe it.
  ///
  /// Acceptance means at least one `OK true`. [NostrClient.publishEvent] would
  /// only prove the frame was handed to a socket, and this result is what the
  /// share sheet turns into "Saved" — a relay-policy rejection has to be able
  /// to say the save did not stick. It is still breadth, not durability: the
  /// relay acknowledges from an in-memory queue and commits afterwards.
  Future<bool> _publishGlobalBookmarks(List<BookmarkItem> candidate) async {
    try {
      if (!_authService.isAuthenticated) {
        Log.warning(
          'Cannot publish bookmarks - user not authenticated',
          name: 'BookmarkService',
          category: LogCategory.system,
        );
        return false;
      }

      final event = await _authService.createAndSignEvent(
        kind: globalBookmarksKind,
        // NIP-51 reserves `content` for the encrypted private item array, so
        // it is either the ciphertext we read back or empty — never prose.
        content: _lastKnownRemoteContent,
        tags: [for (final item in candidate) item.toTag()],
      );

      if (event == null) return false;

      final outcome = await _nostrService.publishEventAwaitOk(event);
      if (!outcome.acceptedByAny) {
        Log.warning(
          'Relay did not accept global bookmarks: ${event.id} '
          '(${outcome.summary})',
          name: 'BookmarkService',
          category: LogCategory.system,
        );
        return false;
      }

      _globalBookmarks
        ..clear()
        ..addAll(candidate);
      await _saveBookmarksToSharedPreferences();

      Log.debug(
        'Published global bookmarks to Nostr: ${event.id} '
        '(${outcome.summary})',
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
