// ABOUTME: Model representing a user's like (Kind 7 reaction) record.
// ABOUTME: Stores the mapping between target event and reaction event IDs
// ABOUTME: needed for unlike (deletion) operations.

import 'package:equatable/equatable.dart';

/// A record of a user's like on a Nostr event.
///
/// This model stores the essential mapping between:
/// - [targetEventId]: The event that was liked (e.g., a video)
/// - [reactionEventId]: The Kind 7 reaction event created when liking
///
/// The [reactionEventId] is required for unlikes, which must reference
/// the original reaction event in a Kind 5 deletion event.
class LikeRecord extends Equatable {
  /// Creates a new like record.
  const LikeRecord({
    required this.targetEventId,
    required this.reactionEventId,
    required this.createdAt,
  });

  /// The event ID that was liked (e.g., video event ID).
  final String targetEventId;

  /// The Kind 7 reaction event ID created by the user.
  ///
  /// This ID is needed to create a Kind 5 deletion event for unlikes.
  final String reactionEventId;

  /// When the like was created.
  final DateTime createdAt;

  /// Creates a copy of this record with the given fields replaced.
  LikeRecord copyWith({
    String? targetEventId,
    String? reactionEventId,
    DateTime? createdAt,
  }) {
    return LikeRecord(
      targetEventId: targetEventId ?? this.targetEventId,
      reactionEventId: reactionEventId ?? this.reactionEventId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [targetEventId, reactionEventId, createdAt];

  @override
  String toString() {
    return 'LikeRecord('
        'targetEventId: $targetEventId, '
        'reactionEventId: $reactionEventId, '
        'createdAt: $createdAt)';
  }
}
