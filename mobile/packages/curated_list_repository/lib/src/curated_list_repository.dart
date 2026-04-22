// ABOUTME(WIP): Repository for managing curated video list subscriptions.
// ABOUTME(WIP): Provides BehaviorSubject stream for reactive BLoC subscription,
// ABOUTME(WIP): read-only query methods, and in-memory state populated by the
// ABOUTME(WIP): Page layer. Persistence and relay sync come in later phases.

import 'package:curated_list_repository/src/curated_list_converter.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:rxdart/rxdart.dart';

/// NIP-51 kind for curated video lists.
const _curatedListKind = 30005;

/// Well-known d-tag for the user's default "My List".
const defaultListId = 'my_vine_list';

/// {@template curated_list_repository}
/// Repository for managing curated video list subscriptions.
///
/// Exposes a [subscribedListsStream] (BehaviorSubject) so that BLoCs can
/// reactively observe list changes, and provides read-only query methods
/// for lookups on subscribed lists.
///
/// The repository maintains in-memory state populated via [setSubscribedLists],
/// which is called by the Page layer to bridge from the current Riverpod
/// `CuratedListService`. When persistence and relay sync are added later,
/// [setSubscribedLists] will be replaced by internal loading.
/// {@endtemplate}
class CuratedListRepository {
  /// {@macro curated_list_repository}
  CuratedListRepository({
    required NostrClient nostrClient,
    required FunnelcakeApiClient funnelcakeApiClient,
  }) : _nostrClient = nostrClient,
       _funnelcakeApiClient = funnelcakeApiClient;

  final NostrClient _nostrClient;
  final FunnelcakeApiClient _funnelcakeApiClient;
  final Map<String, CuratedList> _subscribedLists = {};

  // BehaviorSubject replays last value to late subscribers, fixing race
  // condition where BLoC subscribes AFTER initial emission.
  final _subscribedListsSubject = BehaviorSubject<List<CuratedList>>.seeded(
    const [],
  );

  /// A stream of subscribed curated lists.
  ///
  /// Replays the last emitted value to new subscribers (BehaviorSubject).
  Stream<List<CuratedList>> get subscribedListsStream =>
      _subscribedListsSubject.stream;

  // ---------------------------------------------------------------------------
  // Mutation
  // ---------------------------------------------------------------------------

  /// Replaces the current subscribed lists with [lists].
  ///
  /// This is a **transitional bridge** that lets the Page layer push data
  /// from the legacy Riverpod `CuratedListService` into the repository so
  /// BLoCs can consume it via [subscribedListsStream].
  ///
  /// Each list is keyed by its [CuratedList.id].
  ///
  /// Emits the new list on [subscribedListsStream].
  // TODO(curated-list-migration): Remove once the repository owns its own
  // data loading (Phase 2 — persistence + relay sync). At that point,
  // internal CRUD methods and relay fetch will emit on the stream directly.
  void setSubscribedLists(List<CuratedList> lists) {
    _subscribedLists
      ..clear()
      ..addEntries(lists.map((list) => MapEntry(list.id, list)));
    _emitSubscribedLists();
  }

  // ---------------------------------------------------------------------------
  // Read-only queries
  // ---------------------------------------------------------------------------

  /// Returns video references from all subscribed lists, keyed by list ID.
  ///
  /// Each value is the list's [CuratedList.videoEventIds], which contains
  /// a mix of:
  /// - **Event IDs**: 64-character hex strings
  /// - **Addressable coordinates**: `kind:pubkey:d-tag` format
  ///
  /// Lists with empty [CuratedList.videoEventIds] are excluded.
  ///
  /// Returns an empty map when there are no subscribed lists.
  Map<String, List<String>> getSubscribedListVideoRefs() {
    final refs = <String, List<String>>{};
    for (final entry in _subscribedLists.entries) {
      if (entry.value.videoEventIds.isNotEmpty) {
        refs[entry.key] = List.unmodifiable(entry.value.videoEventIds);
      }
    }
    return Map.unmodifiable(refs);
  }

  /// Returns the subscribed list with the given [id], or `null` if not found.
  CuratedList? getListById(String id) => _subscribedLists[id];

  /// Returns an unmodifiable snapshot of all subscribed lists.
  List<CuratedList> getSubscribedLists() =>
      List.unmodifiable(_subscribedLists.values.toList());

  /// Whether the user is subscribed to the list with [listId].
  bool isSubscribedToList(String listId) =>
      _subscribedLists.containsKey(listId);

  /// Whether [videoEventId] is in the subscribed list with [listId].
  ///
  /// Returns `false` if the list does not exist.
  bool isVideoInList(String listId, String videoEventId) {
    final list = _subscribedLists[listId];
    return list?.videoEventIds.contains(videoEventId) ?? false;
  }

  /// Whether the user's default "My List" is among the subscribed lists.
  bool hasDefaultList() => _subscribedLists.containsKey(defaultListId);

  /// Returns the user's default "My List", or `null` if not subscribed.
  CuratedList? getDefaultList() => _subscribedLists[defaultListId];

  /// Searches subscribed public lists by [query] against name, description,
  /// and tags (case-insensitive).
  ///
  /// Returns an empty list when [query] is blank.
  List<CuratedList> searchLists(String query) {
    if (query.trim().isEmpty) return [];

    final lowerQuery = query.toLowerCase();
    return _subscribedLists.values
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

  /// Returns subscribed public lists that contain the given [tag].
  List<CuratedList> getListsByTag(String tag) {
    return _subscribedLists.values
        .where(
          (list) => list.isPublic && list.tags.contains(tag.toLowerCase()),
        )
        .toList();
  }

  /// Returns all unique tags across subscribed public lists, sorted
  /// alphabetically.
  List<String> getAllTags() {
    final allTags = <String>{};
    for (final list in _subscribedLists.values) {
      if (list.isPublic) {
        allTags.addAll(list.tags);
      }
    }
    return allTags.toList()..sort();
  }

  /// Returns all subscribed lists that contain [videoEventId].
  List<CuratedList> getListsContainingVideo(String videoEventId) {
    return _subscribedLists.values
        .where((list) => list.videoEventIds.contains(videoEventId))
        .toList();
  }

  /// Returns video IDs from the list with [listId], ordered according to the
  /// list's [PlayOrder].
  ///
  /// Returns an empty list if the list does not exist.
  List<String> getOrderedVideoIds(String listId) {
    final list = _subscribedLists[listId];
    if (list == null) return [];

    return switch (list.playOrder) {
      PlayOrder.chronological => List.of(list.videoEventIds),
      PlayOrder.reverse => list.videoEventIds.reversed.toList(),
      PlayOrder.manual => List.of(list.videoEventIds),
      PlayOrder.shuffle => (List.of(list.videoEventIds)..shuffle()),
    };
  }

  /// Returns a human-readable summary of which subscribed lists contain
  /// [videoEventId].
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

  // ---------------------------------------------------------------------------
  // Relay search
  // ---------------------------------------------------------------------------

  /// Queries Nostr relays for curated lists matching [query] without
  /// resolving thumbnails.
  Future<List<CuratedList>> _queryListsFromRelays({
    required String query,
    int limit = 50,
    Set<String>? excludeIds,
  }) async {
    if (query.trim().isEmpty) return [];

    final lowerQuery = query.toLowerCase();
    final excluded = excludeIds ?? const {};

    final events = await _nostrClient.queryEvents(
      [
        Filter(kinds: [_curatedListKind], limit: limit),
      ],
    );

    final seen = <String, CuratedList>{};
    for (final event in events) {
      final list = CuratedListConverter.fromEvent(event);
      if (list == null) continue;
      if (excluded.contains(list.id)) continue;
      if (!list.isPublic) continue;
      if (list.videoEventIds.isEmpty) continue;

      // Client-side query filter
      final matches =
          list.name.toLowerCase().contains(lowerQuery) ||
          (list.description?.toLowerCase().contains(lowerQuery) ?? false) ||
          list.tags.any((tag) => tag.toLowerCase().contains(lowerQuery));
      if (!matches) continue;

      // Dedup by d-tag, keep newest
      final existing = seen[list.id];
      if (existing != null && existing.updatedAt.isAfter(list.updatedAt)) {
        continue;
      }
      seen[list.id] = list;
    }

    return seen.values.toList();
  }

  /// Searches both local subscribed lists and relay lists for [query].
  ///
  /// Yields results progressively so the UI can render list names immediately
  /// while thumbnails resolve in the background:
  ///
  /// 1. Local matches (no thumbnails)
  /// 2. Local matches with thumbnails resolved
  /// 3. Local + relay matches merged (relay items without thumbnails)
  /// 4. Fully enriched (relay thumbnails resolved)
  ///
  /// Deduplicates by list ID.
  Stream<List<CuratedList>> searchAllLists(
    String query, {
    int maxThumbnails = 5,
  }) async* {
    if (query.trim().isEmpty) return;

    final localResults = searchLists(query);
    final merged = <String, CuratedList>{
      for (final list in localResults) list.id: list,
    };

    // Yield 1: local results immediately (no thumbnails)
    yield List.unmodifiable(merged.values.toList());

    // Yield 2: local results with thumbnails resolved
    final enrichedLocal = await _resolveAllThumbnails(
      merged.values.toList(),
      maxThumbnails: maxThumbnails,
    );
    merged
      ..clear()
      ..addEntries(enrichedLocal.map((l) => MapEntry(l.id, l)));
    yield List.unmodifiable(merged.values.toList());

    // Yield 3: relay results merged (no thumbnails on new items)
    final relayResults = await _queryListsFromRelays(
      query: query,
      excludeIds: merged.keys.toSet(),
    );
    for (final list in relayResults) {
      merged[list.id] = list;
    }
    yield List.unmodifiable(merged.values.toList());

    // Yield 4: relay thumbnails resolved
    final enrichedRelay = await _resolveAllThumbnails(
      relayResults,
      maxThumbnails: maxThumbnails,
    );
    for (final list in enrichedRelay) {
      merged[list.id] = list;
    }
    yield List.unmodifiable(merged.values.toList());
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Releases resources held by this repository.
  ///
  /// Idempotent — safe to call multiple times.
  Future<void> dispose() async {
    if (!_subscribedListsSubject.isClosed) {
      await _subscribedListsSubject.close();
    }
  }

  // ---------------------------------------------------------------------------
  // Thumbnail resolution
  // ---------------------------------------------------------------------------

  /// Regular expression matching a 64-character lowercase hex string
  /// (Nostr event ID). Non-matching entries are addressable coordinates.
  static final _hexEventIdPattern = RegExp(r'^[0-9a-f]{64}$');

  /// Resolves thumbnail URLs for a batch of [lists] concurrently.
  ///
  /// Each list gets up to [maxThumbnails] thumbnail URLs populated from
  /// its [CuratedList.videoEventIds]. Resolution is best-effort — lists
  /// that fail silently keep their original (empty) thumbnailUrls.
  Future<List<CuratedList>> _resolveAllThumbnails(
    List<CuratedList> lists, {
    required int maxThumbnails,
  }) async {
    final futures = lists.map(
      (list) => _resolveThumbnails(list, maxThumbnails: maxThumbnails),
    );
    return Future.wait(futures);
  }

  /// Resolves up to [maxThumbnails] thumbnail URLs for a single [list].
  ///
  /// Strategy per video reference:
  /// 1. Hex event ID → try FunnelCake API (`getVideoStats`), use
  ///    `VideoStats.thumbnail`.
  /// 2. If FunnelCake fails or returns empty → fall back to Nostr relay
  ///    query, parse as `VideoEvent`, use `effectiveThumbnailUrl`.
  /// 3. Addressable coordinate → query relay with appropriate filter,
  ///    parse as `VideoEvent`, use `effectiveThumbnailUrl`.
  /// 4. If all fail → skip (becomes a placeholder in the UI).
  ///
  /// Returns the list with [CuratedList.thumbnailUrls] populated.
  Future<CuratedList> _resolveThumbnails(
    CuratedList list, {
    required int maxThumbnails,
  }) async {
    if (list.videoEventIds.isEmpty) return list;

    final candidates = list.videoEventIds.take(maxThumbnails).toList();

    // Phase 1: Try FunnelCake for each hex ID (parallel HTTP calls).
    final fcResults = await Future.wait(
      candidates.map(_tryFunnelcake),
    );

    // Phase 2: Collect refs needing relay fallback, batch into one query.
    final needsRelay = <String>[];
    for (var i = 0; i < candidates.length; i++) {
      if (fcResults[i] == null) {
        needsRelay.add(candidates[i]);
      }
    }

    final relayThumbnails = await _batchRelayThumbnails(needsRelay);

    // Merge results in candidate order.
    final urls = <String>[];
    for (var i = 0; i < candidates.length; i++) {
      final url = fcResults[i] ?? relayThumbnails[candidates[i]];
      if (url != null) urls.add(url);
    }

    return list.copyWith(thumbnailUrls: urls);
  }

  /// Tries FunnelCake API for a hex event ID.
  ///
  /// Returns the thumbnail URL, or `null` if [videoRef] is not a hex ID
  /// or FunnelCake has no result.
  Future<String?> _tryFunnelcake(String videoRef) async {
    if (!_hexEventIdPattern.hasMatch(videoRef)) return null;
    try {
      final stats = await _funnelcakeApiClient.getVideoStats(videoRef);
      if (stats != null && stats.thumbnail.isNotEmpty) {
        return stats.thumbnail;
      }
    } on Exception {
      // Fall through to relay fallback.
    }
    return null;
  }

  /// Resolves relay-side thumbnail URLs for a batch of video references.
  ///
  /// Batches all relay lookups into a single `queryEvents` call: hex IDs
  /// go into one `Filter(ids: [...])` and addressable coordinates become
  /// individual filters in the same request.
  ///
  /// Returns a map from video ref → thumbnail URL for refs that resolved.
  Future<Map<String, String?>> _batchRelayThumbnails(
    List<String> refs,
  ) async {
    if (refs.isEmpty) return {};

    final hexIds = <String>[];
    final coordRefs = <String>[];
    final coordFilters = <Filter>[];

    for (final ref in refs) {
      if (_hexEventIdPattern.hasMatch(ref)) {
        hexIds.add(ref);
      } else {
        final filter = _buildAddressableFilter(ref);
        if (filter != null) {
          coordRefs.add(ref);
          coordFilters.add(filter);
        }
      }
    }

    final filters = <Filter>[
      if (hexIds.isNotEmpty) Filter(ids: hexIds),
      ...coordFilters,
    ];

    if (filters.isEmpty) return {};

    List<Event> events;
    try {
      events = await _nostrClient.queryEvents(filters);
    } on Exception {
      return {};
    }

    final results = <String, String?>{};

    for (final event in events) {
      try {
        final videoEvent = VideoEvent.fromNostrEvent(
          event,
          permissive: true,
        );
        final thumb = videoEvent.effectiveThumbnailUrl;
        if (thumb == null) continue;

        // Match hex IDs by event ID.
        if (hexIds.contains(event.id)) {
          results[event.id] = thumb;
          continue;
        }

        // Match addressable coords by reconstructing the coordinate.
        for (final ref in coordRefs) {
          final parts = ref.split(':');
          if (parts.length >= 3 &&
              int.tryParse(parts[0]) == event.kind &&
              parts[1] == event.pubkey) {
            results[ref] = thumb;
            break;
          }
        }
      } on Object {
        // Skip unparseable events (e.g. non-video kinds throw
        // ArgumentError from VideoEvent.fromNostrEvent).
        continue;
      }
    }

    return results;
  }

  /// Builds a [Filter] for an addressable coordinate (`kind:pubkey:d-tag`).
  ///
  /// Returns `null` if the coordinate format is invalid.
  static Filter? _buildAddressableFilter(String coordinate) {
    final parts = coordinate.split(':');
    if (parts.length < 3) return null;

    final kind = int.tryParse(parts[0]);
    if (kind == null) return null;

    final pubkey = parts[1];
    final dTag = parts.sublist(2).join(':');

    return Filter(
      kinds: [kind],
      authors: [pubkey],
      d: [dTag],
      limit: 1,
    );
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  void _emitSubscribedLists() {
    if (!_subscribedListsSubject.isClosed) {
      _subscribedListsSubject.add(
        List.unmodifiable(_subscribedLists.values.toList()),
      );
    }
  }
}
