// ABOUTME: Result model for the syncUserReactions operation.
// ABOUTME: Contains all data needed by the UI after syncing likes.

import 'package:equatable/equatable.dart';

/// Result of syncing user reactions from relays and local storage.
///
/// Contains all the data needed by the UI layer after a sync operation:
/// - [orderedEventIds]: Event IDs ordered by recency (most recent first)
/// - [eventIdToReactionId]: Map from target event ID to reaction event ID
///
/// The UI can derive `likedEventIds` as `orderedEventIds.toSet()` for O(1)
/// lookups.
class LikesSyncResult extends Equatable {
  /// Creates a new sync result.
  const LikesSyncResult({
    required this.orderedEventIds,
    required this.eventIdToReactionId,
  });

  /// Creates an empty sync result.
  const LikesSyncResult.empty()
    : orderedEventIds = const [],
      eventIdToReactionId = const {};

  /// Liked event IDs ordered by recency (most recently liked first).
  final List<String> orderedEventIds;

  /// Map from target event ID to the reaction event ID.
  ///
  /// The reaction event ID is needed for publishing Kind 5 deletion
  /// events when unliking.
  final Map<String, String> eventIdToReactionId;

  /// The number of liked events.
  int get count => orderedEventIds.length;

  /// Whether there are any likes.
  bool get isEmpty => orderedEventIds.isEmpty;

  @override
  List<Object?> get props => [orderedEventIds, eventIdToReactionId];
}
