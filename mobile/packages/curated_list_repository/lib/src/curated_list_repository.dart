// ABOUTME: Repository for managing curated video list subscriptions.
// ABOUTME: Provides subscribed list data to VideoFeedBloc for home feed
// ABOUTME: merging. Currently uses in-memory state populated by the
// ABOUTME: Page layer; will add persistence and relay sync later.

import 'package:models/models.dart';

/// {@template curated_list_repository}
/// Repository for managing curated video list subscriptions.
///
/// Provides the minimum interface needed for the `VideoFeedBloc` to merge
/// subscribed list videos into the home feed:
/// - [getSubscribedListVideoRefs] returns video references keyed by list ID
/// - [getListById] returns list metadata for UI attribution
///
/// The repository maintains in-memory state populated via [setSubscribedLists],
/// which is called by the Page layer to bridge from the current Riverpod
/// `CuratedListService`. When persistence and relay sync are added later,
/// [setSubscribedLists] will be replaced by internal loading.
/// {@endtemplate}
class CuratedListRepository {
  /// {@macro curated_list_repository}
  CuratedListRepository();

  final Map<String, CuratedList> _subscribedLists = {};

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

  /// Replaces the current subscribed lists with [lists].
  ///
  /// Called by the Page layer to sync data from the current Riverpod
  /// `CuratedListService`. Each list is keyed by its [CuratedList.id].
  void setSubscribedLists(List<CuratedList> lists) {
    _subscribedLists
      ..clear()
      ..addEntries(lists.map((list) => MapEntry(list.id, list)));
  }
}
