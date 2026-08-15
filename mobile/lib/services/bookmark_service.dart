// ABOUTME: Service for the NIP-51 global bookmark list (kind 10003)
// ABOUTME: Reconciles with the relay before every read and every publish

import 'dart:async';
import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

/// Represents a bookmarked item
@immutable
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

  factory BookmarkItem.fromTag(List<String> tag) {
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

  factory BookmarkItem.fromJson(Map<String, dynamic> json) => BookmarkItem(
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
    this.failure,
  });

  /// Whether the change reconciled and a relay accepted the new list.
  final bool succeeded;

  /// Whether the video was bookmarked before the toggle, per the relay.
  final bool wasBookmarked;

  /// Whether the video is bookmarked now. Equals [wasBookmarked] when the
  /// toggle failed, since no relay accepted a new list.
  final bool isBookmarked;

  /// Why the toggle failed, or `null` when [succeeded] is true. Lets the UI
  /// tell "we could not reach the network" apart from publish-leg failures.
  final BookmarkToggleFailure? failure;
}

/// Why a bookmark mutation did not complete.
///
/// Deliberately does not name a member "offline": `noRelays` is also reported
/// for a disposed client, so [couldNotReachRelays] describes what was observed
/// rather than guessing at the device's connectivity.
enum BookmarkToggleFailure {
  /// No relay could be reached, so the current list could not be read.
  couldNotReachRelays,

  /// Relays were reachable but did not answer before the query deadline.
  timedOut,

  /// The list reconciled, but the new version was not published.
  publishDidNotComplete,

  /// There is no signed-in identity to read or publish as.
  notAuthenticated,

  /// The list carries NIP-51 private items this client could not read, so the
  /// current state is unknown and any write could disclose one of them.
  privateItemsUnreadable,

  /// Anything else, including an unexpected throw.
  unknown,
}

/// What this client managed to make of a kind-10003's `content`.
enum _PrivateItemsState {
  /// There is nothing encrypted to read.
  none,

  /// The private item array was decrypted and parsed.
  readable,

  /// `content` is non-empty but did not yield items — a deprecated NIP-04
  /// payload, a signer that declined, or malformed plaintext.
  ///
  /// Distinct from [none] on purpose: treating it as "no private items" is
  /// what lets the write path publish a public duplicate of an item it cannot
  /// see (#7136).
  unreadable,
}

/// The outcome of reading a kind-10003's `content`, returned rather than
/// stored so the caller can apply it without suspending mid-update.
class _PrivateItemsRead {
  const _PrivateItemsRead({required this.state, required this.tags});

  final _PrivateItemsState state;

  /// The decrypted array verbatim, not just the entries this client models.
  /// Re-encrypting from parsed items would silently drop another client's
  /// non-item tags and any tag position past the fourth.
  final List<List<String>> tags;
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

  /// The `content` Divine wrote into kind 10003 before it respected NIP-51's
  /// reservation of that field for the encrypted private-item array.
  ///
  /// Carrying an unrecognized `content` through is what protects another
  /// client's ciphertext, but this literal is Divine's own former output and
  /// is not ciphertext. Preserving it would republish the malformed value for
  /// exactly the users who already carry it — every account that saved a
  /// bookmark on an older build.
  static const String _legacyProseContent = 'Divine global bookmarks';

  /// The list's **public** items — the ones carried in `tags`.
  ///
  /// Kept separate from [_privateBookmarks] because this is the sole input to
  /// the published `tags`. A private item that leaked in here would be
  /// republished in the clear, which is the disclosure #7136 is about.
  final List<BookmarkItem> _globalBookmarks = [];

  /// The list's **private** items, decrypted from `content`.
  ///
  /// Never persisted. [SharedPreferences] is unencrypted, so caching these
  /// would move the user's private bookmarks into plaintext local storage —
  /// a disclosure of its own. They are re-read on every sync instead.
  final List<BookmarkItem> _privateBookmarks = [];

  /// [_privateBookmarks]' source array, kept verbatim so a re-encryption
  /// rewrites only the entry being removed. Never persisted, for the same
  /// reason [_privateBookmarks] is not.
  List<List<String>> _privateTags = const [];

  /// What became of the newest `content` we saw. Drives the write path's
  /// refusal to act on a list it cannot fully see.
  _PrivateItemsState _privateItemsState = _PrivateItemsState.none;

  /// The `content` of the newest kind-10003 we have seen for this user.
  ///
  /// NIP-51 reserves `.content` for the NIP-44-encrypted private item array.
  /// Carried through untouched whenever the private items are not the thing
  /// being changed, so a public-item write can never disturb them — except for
  /// [_legacyProseContent], which is Divine's own malformed output and is
  /// dropped rather than propagated.
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

  /// Every bookmark on the list — public items first, then private ones.
  ///
  /// A set literal, so an item held both publicly and privately appears once
  /// ([BookmarkItem] compares on type and id).
  List<BookmarkItem> get globalBookmarks =>
      List.unmodifiable({..._globalBookmarks, ..._privateBookmarks});

  /// Whether the list carries private items this client could not read.
  ///
  /// While true the bookmark state is genuinely unknown: callers must not
  /// render "not saved", and the write path refuses rather than publishing a
  /// public copy of an item it cannot see.
  bool get hasUnreadablePrivateItems =>
      _privateItemsState == _PrivateItemsState.unreadable;

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
  Future<bool> syncGlobalBookmarks({bool requireAuthoritative = false}) async =>
      // Equality to success, never `!= someFailure`: a blacklist would let any
      // failure member added later fall through as "reconciled" and publish
      // kind 10003 from an inconclusive read — the #6966 regression.
      await _syncGlobalBookmarks(requireAuthoritative: requireAuthoritative) ==
      null;

  /// [syncGlobalBookmarks], but reporting *why* it failed.
  ///
  /// Returns `null` on success. Only [toggleVideoInGlobalBookmarks] needs the
  /// reason, so the public surface stays a bool.
  Future<BookmarkToggleFailure?> _syncGlobalBookmarks({
    required bool requireAuthoritative,
  }) async {
    final pubkey = _authService.currentPublicKeyHex;
    if (!_authService.isAuthenticated || pubkey == null) {
      Log.warning(
        'Skipping bookmark sync - user not authenticated',
        name: 'BookmarkService',
        category: LogCategory.system,
      );
      return BookmarkToggleFailure.notAuthenticated;
    }

    try {
      final read = await _readRemoteGlobalBookmarks(
        pubkey,
        requireAuthoritative: requireAuthoritative,
      );
      var events = read.events;
      if (events == null) return read.failure ?? BookmarkToggleFailure.unknown;
      var answeredAuthoritatively = requireAuthoritative;

      if (events.isEmpty && !requireAuthoritative && _mustConfirmAbsence) {
        // Only *some* relay said the list does not exist, and the settle
        // window's latency trade cannot afford to be wrong about that one
        // answer: it is indistinguishable from a relay that stayed mute. Left
        // unchecked it either tells a user with bookmarks that they have none
        // — the reinstall #6627 is about, where the cache is empty too — or
        // overwrites the snapshot Saved falls back to offline. Confirm it
        // against every relay before believing it.
        final confirmation = await _readRemoteGlobalBookmarks(
          pubkey,
          requireAuthoritative: true,
        );
        events = confirmation.events;
        if (events == null) {
          Log.warning(
            'Empty bookmark answer not confirmed by every relay - keeping '
            'the ${globalBookmarks.length} bookmarks this device has',
            name: 'BookmarkService',
            category: LogCategory.system,
          );
          return confirmation.failure ?? BookmarkToggleFailure.unknown;
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
        _privateBookmarks.clear();
        _privateTags = const [];
        _privateItemsState = _PrivateItemsState.none;
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
        await _adoptGlobalBookmarksFromEvent(newestFirst.first);
      }

      await _saveBookmarksToSharedPreferences();

      Log.info(
        'Synced ${globalBookmarks.length} global bookmarks from relay '
        '(${_privateBookmarks.length} private)',
        name: 'BookmarkService',
        category: LogCategory.system,
      );
      return null;
    } catch (e) {
      Log.error(
        'Failed to sync global bookmarks from relay: $e',
        name: 'BookmarkService',
        category: LogCategory.system,
      );
      return BookmarkToggleFailure.unknown;
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
  Future<({List<Event>? events, BookmarkToggleFailure? failure})>
  _readRemoteGlobalBookmarks(
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
      // A device with no reachable relay sets *both* flags, so noRelays has to
      // be tested first or offline would always report as a timeout.
      return (
        events: null,
        failure: result.noRelays
            ? BookmarkToggleFailure.couldNotReachRelays
            : BookmarkToggleFailure.timedOut,
      );
    }

    return (
      events: result.events
          .where((event) => event.kind == globalBookmarksKind)
          .toList(),
      failure: null,
    );
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
    final failure = await _syncGlobalBookmarks(requireAuthoritative: true);
    final wasBookmarked = isVideoBookmarkedGlobally(videoEventId);

    if (failure != null) {
      return BookmarkToggleResult(
        succeeded: false,
        wasBookmarked: wasBookmarked,
        isBookmarked: wasBookmarked,
        failure: failure,
      );
    }

    // The list reconciled, but part of it stayed encrypted. Either direction
    // would be a guess: adding could publish an item already held privately,
    // and removing could report "Removed" for one that survives in `content`.
    if (hasUnreadablePrivateItems) {
      return BookmarkToggleResult(
        succeeded: false,
        wasBookmarked: wasBookmarked,
        isBookmarked: wasBookmarked,
        failure: BookmarkToggleFailure.privateItemsUnreadable,
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
      // The read already reconciled, so anything failing past this point is
      // the publish leg: auth disappeared, signing failed, relay OK never came
      // back true, or the publish path threw.
      failure: succeeded ? null : BookmarkToggleFailure.publishDidNotComplete,
    );
  }

  /// Add an item to global bookmarks.
  ///
  /// **For tests only.** Production code should use
  /// [toggleVideoInGlobalBookmarks] which handles reconciliation internally.
  ///
  /// Reconciles with the relay first and refuses to publish if that fails, so
  /// a device whose cache is empty (fresh install, second device) cannot
  /// replace the user's list with a one-item one.
  ///
  /// [alreadyReconciled] is an internal implementation detail and must not be
  /// used from production code — it is exposed for testing flexibility only.
  @visibleForTesting
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

      if (hasUnreadablePrivateItems) {
        Log.warning(
          'Not adding to global bookmarks: the list has private items this '
          'client could not read, so a public tag could disclose one',
          name: 'BookmarkService',
          category: LogCategory.system,
        );
        return false;
      }

      // Already bookmarked either way. Adding a public tag for an item held
      // privately would publish a bookmark the user chose to keep encrypted.
      if (_globalBookmarks.contains(item) || _privateBookmarks.contains(item)) {
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
  /// **For tests only.** Production code should use
  /// [toggleVideoInGlobalBookmarks] which handles reconciliation internally.
  ///
  /// Reconciles with the relay first for the same reason as
  /// [addToGlobalBookmarks] — the republished list must be the user's real
  /// one minus [item], not this device's cache minus [item].
  ///
  /// [alreadyReconciled] is an internal implementation detail and must not be
  /// used from production code — it is exposed for testing flexibility only.
  @visibleForTesting
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

      if (hasUnreadablePrivateItems) {
        Log.warning(
          'Not removing from global bookmarks: the list has private items this '
          'client could not read, so the result could not be reported honestly',
          name: 'BookmarkService',
          category: LogCategory.system,
        );
        return false;
      }

      // A private item is removed from the encrypted array. Dropping only a
      // public copy would report "Removed" while every conforming client still
      // shows it bookmarked (#7136) — and the reverse is just as untrue, so an
      // item the pre-fix leak left in *both* halves loses both. `removeWhere`
      // rather than `remove`, which drops only the first of a duplicate pair.
      if (_privateBookmarks.contains(item)) {
        final privateCandidate = [..._privateTags]
          ..removeWhere(
            (tag) =>
                tag.length >= 2 && tag[0] == item.type && tag[1] == item.id,
          );
        final published = await _publishGlobalBookmarks(
          [..._globalBookmarks]..removeWhere((candidate) => candidate == item),
          privateCandidate: privateCandidate,
        );
        if (!published) return false;

        Log.info(
          'Removed private item from global bookmarks: ${item.id}',
          name: 'BookmarkService',
          category: LogCategory.system,
        );
        return true;
      }

      // `removeWhere` for the same reason the private path uses it: another
      // client is free to write the same tag twice, and `List.remove` would
      // drop one copy and republish the other while reporting "Removed".
      final candidate = [..._globalBookmarks]
        ..removeWhere((existing) => existing == item);
      if (candidate.length == _globalBookmarks.length) {
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

  /// Check if an item is in global bookmarks, public or private.
  ///
  /// Consulting only the public tags is what made a privately-bookmarked video
  /// read as unsaved, and then let a save publish it in the clear (#7136).
  bool isInGlobalBookmarks(String itemId, String type) {
    bool matches(BookmarkItem item) => item.id == itemId && item.type == type;
    return _globalBookmarks.any(matches) || _privateBookmarks.any(matches);
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
  /// Pass [privateCandidate] only when the private items are the thing being
  /// changed; it is re-encrypted and replaces `content`. Leaving it null keeps
  /// the ciphertext byte-for-byte, which is what makes a public-item write
  /// incapable of disturbing another client's private bookmarks.
  Future<bool> _publishGlobalBookmarks(
    List<BookmarkItem> candidate, {
    List<List<String>>? privateCandidate,
  }) async {
    try {
      if (!_authService.isAuthenticated) {
        Log.warning(
          'Cannot publish bookmarks - user not authenticated',
          name: 'BookmarkService',
          category: LogCategory.system,
        );
        return false;
      }

      // NIP-51 reserves `content` for the encrypted private item array, so it
      // is either ciphertext or empty — never prose.
      final String content;
      if (privateCandidate == null) {
        content = _lastKnownRemoteContent;
      } else {
        final encrypted = await _encryptPrivateItems(privateCandidate);
        if (encrypted == null) return false;
        content = encrypted;
      }

      final event = await _authService.createAndSignEvent(
        kind: globalBookmarksKind,
        content: content,
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
      if (privateCandidate != null) {
        _privateTags = privateCandidate;
        _privateBookmarks
          ..clear()
          ..addAll(_itemsFromTags(privateCandidate));
        _lastKnownRemoteContent = content;
        _privateItemsState = privateCandidate.isEmpty
            ? _PrivateItemsState.none
            : _PrivateItemsState.readable;
      }
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

  /// Encrypts [items] as the NIP-51 private array, or `null` if the payload
  /// could not be produced **or did not read back**.
  ///
  /// The verification round trip is the point. Kind 10003 is replaceable, so a
  /// re-encryption that silently produced the wrong bytes would destroy
  /// private bookmarks this client cannot reconstruct. Everything else keeps
  /// carrying the original ciphertext untouched.
  Future<String?> _encryptPrivateItems(List<List<String>> items) async {
    // A list with no private items left carries no payload at all, rather than
    // the ciphertext of an empty array.
    if (items.isEmpty) return '';

    final pubkey = _authService.currentPublicKeyHex;
    final identity = _authService.currentIdentity;
    if (pubkey == null || identity == null) return null;

    final plaintext = jsonEncode(items);
    try {
      final ciphertext = await identity.nip44Encrypt(pubkey, plaintext);
      if (ciphertext == null || ciphertext.isEmpty) {
        Log.warning(
          'Signer returned no ciphertext for the private bookmark items',
          name: 'BookmarkService',
          category: LogCategory.system,
        );
        return null;
      }

      if (await identity.nip44Decrypt(pubkey, ciphertext) != plaintext) {
        Log.error(
          'Re-encrypted private bookmark items did not read back - '
          'refusing to publish',
          name: 'BookmarkService',
          category: LogCategory.system,
        );
        return null;
      }
      return ciphertext;
    } catch (e) {
      Log.error(
        'Failed to encrypt private bookmark items: $e',
        name: 'BookmarkService',
        category: LogCategory.system,
      );
      return null;
    }
  }

  // === NOSTR LOADING ===

  /// Replace the in-memory lists with the contents of a kind-10003 [event].
  ///
  /// Reads both halves NIP-51 defines: the public items in `tags`, and the
  /// private items in `content` — a stringified tag array encrypted to the
  /// author's own key. The ciphertext is still captured verbatim so a
  /// public-item write can republish it untouched.
  ///
  /// Nothing here mutates state until every await has resolved. Decryption
  /// suspends, and syncs are not serialized (#7163), so a `clear()` before the
  /// await and an `addAll` after it would let two adopts interleave into a
  /// duplicated item — which `List.remove` then only half removes, leaving the
  /// relay holding a bookmark the user was told was gone.
  Future<void> _adoptGlobalBookmarksFromEvent(Event event) async {
    final content = event.content == _legacyProseContent ? '' : event.content;
    final private = await _readPrivateItems(content);

    _lastKnownRemoteContent = content;
    _globalBookmarks
      ..clear()
      ..addAll(_itemsFromTags(event.tags));
    _privateTags = private.tags;
    _privateBookmarks
      ..clear()
      ..addAll(_itemsFromTags(private.tags));
    _privateItemsState = private.state;
  }

  /// The bookmark items among [tags], in order.
  static List<BookmarkItem> _itemsFromTags(List<List<String>> tags) => [
    for (final tag in tags)
      if (tag.length >= 2 && ['e', 'a', 't', 'r'].contains(tag[0]))
        BookmarkItem.fromTag(tag),
  ];

  /// Decrypts [content] into private items, and reports what happened.
  ///
  /// Returns the items rather than storing them, so the caller can apply the
  /// whole read in one synchronous step.
  ///
  /// NIP-51 encrypts private items to the author's own key, so this needs only
  /// the signer this device already has — every identity that can publish a
  /// bookmark can also decrypt one.
  Future<_PrivateItemsRead> _readPrivateItems(String content) async {
    const unreadable = _PrivateItemsRead(
      state: _PrivateItemsState.unreadable,
      tags: [],
    );

    if (content.isEmpty) {
      return const _PrivateItemsRead(state: _PrivateItemsState.none, tags: []);
    }

    // NIP-51 deprecated NIP-04 for this field and tells clients to detect it by
    // the `iv` marker. Divine does not read that scheme; reporting it as
    // unreadable is what stops the write path from guessing "not bookmarked".
    if (content.contains('?iv=')) {
      Log.warning(
        'Bookmark list uses the deprecated NIP-04 private-item scheme - '
        'private items left unread',
        name: 'BookmarkService',
        category: LogCategory.system,
      );
      return unreadable;
    }

    final pubkey = _authService.currentPublicKeyHex;
    final identity = _authService.currentIdentity;
    if (pubkey == null || identity == null) return unreadable;

    try {
      final plaintext = await identity.nip44Decrypt(pubkey, content);
      if (plaintext == null) {
        Log.warning(
          'Signer could not decrypt the private bookmark items',
          name: 'BookmarkService',
          category: LogCategory.system,
        );
        return unreadable;
      }

      final tags = _tagsFromPrivatePayload(plaintext);
      if (tags == null) return unreadable;

      Log.debug(
        'Read ${_itemsFromTags(tags).length} private bookmark items',
        name: 'BookmarkService',
        category: LogCategory.system,
      );
      return _PrivateItemsRead(state: _PrivateItemsState.readable, tags: tags);
    } catch (e) {
      Log.error(
        'Failed to read private bookmark items: $e',
        name: 'BookmarkService',
        category: LogCategory.system,
      );
      return unreadable;
    }
  }

  /// Parses a NIP-51 private payload — a stringified tag array — or `null`
  /// when it is not one.
  static List<List<String>>? _tagsFromPrivatePayload(String plaintext) {
    try {
      final decoded = jsonDecode(plaintext);
      if (decoded is! List) return null;

      final tags = <List<String>>[];
      for (final entry in decoded) {
        if (entry is! List) return null;
        // Rejected rather than filtered. Dropping a non-string would shift
        // every position after it — `['e', id, null, petname]` re-encrypts as
        // `['e', id, petname]`, promoting the label to the relay hint — and
        // silently rewriting an entry is exactly what carrying the array
        // verbatim exists to prevent.
        if (entry.any((value) => value is! String)) return null;
        tags.add([for (final value in entry) value as String]);
      }
      return tags;
    } catch (_) {
      return null;
    }
  }

  // === STORAGE ===

  /// Load bookmarks from SharedPreferences cache (fast startup)
  void _loadBookmarksFromSharedPreferences() {
    // Load global bookmarks
    final globalBookmarksJson = _prefs.getString(globalBookmarksStorageKey);
    if (globalBookmarksJson != null) {
      try {
        final bookmarksData = jsonDecode(globalBookmarksJson) as List<dynamic>;
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
