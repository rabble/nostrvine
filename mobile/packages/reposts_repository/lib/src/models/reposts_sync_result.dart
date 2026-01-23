// ABOUTME: Result model for the syncUserReposts operation.
// ABOUTME: Contains all data needed by the UI after syncing reposts.

import 'package:equatable/equatable.dart';

/// Result of syncing user reposts from relays and local storage.
///
/// Contains all the data needed by the UI layer after a sync operation:
/// - [orderedAddressableIds]: Addressable IDs ordered by recency
/// - [addressableIdToRepostId]: Map from addressable ID to repost event ID
///
/// The UI can derive `repostedAddressableIds` as
/// `orderedAddressableIds.toSet()` for O(1) lookups.
class RepostsSyncResult extends Equatable {
  /// Creates a new sync result.
  const RepostsSyncResult({
    required this.orderedAddressableIds,
    required this.addressableIdToRepostId,
  });

  /// Creates an empty sync result.
  const RepostsSyncResult.empty()
    : orderedAddressableIds = const [],
      addressableIdToRepostId = const {};

  /// Reposted addressable IDs ordered by recency.
  ///
  /// Most recently reposted first.
  ///
  /// Format: `34236:<author_pubkey>:<d-tag>`
  final List<String> orderedAddressableIds;

  /// Map from addressable ID to the repost event ID.
  ///
  /// The repost event ID is needed for publishing Kind 5 deletion
  /// events when unreposting.
  final Map<String, String> addressableIdToRepostId;

  /// The number of reposted events.
  int get count => orderedAddressableIds.length;

  /// Whether there are any reposts.
  bool get isEmpty => orderedAddressableIds.isEmpty;

  @override
  List<Object?> get props => [orderedAddressableIds, addressableIdToRepostId];
}
