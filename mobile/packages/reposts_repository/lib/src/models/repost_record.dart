// ABOUTME: Model representing a user's repost (Kind 16) record.
// ABOUTME: Stores the mapping between addressable ID and repost event ID
// ABOUTME: needed for unrepost (deletion) operations.

import 'package:equatable/equatable.dart';

/// A record of a user's repost of a Nostr video event.
///
/// This model stores the essential mapping between:
/// - [addressableId]: The addressable reference to the video
///   (format: `34236:pubkey:d-tag`)
/// - [repostEventId]: The Kind 16 repost event created when reposting
///
/// The [repostEventId] is required for unreposts, which must reference
/// the original repost event in a Kind 5 deletion event.
class RepostRecord extends Equatable {
  /// Creates a new repost record.
  const RepostRecord({
    required this.addressableId,
    required this.repostEventId,
    required this.originalAuthorPubkey,
    required this.createdAt,
  });

  /// The addressable ID of the video that was reposted.
  ///
  /// Format: `34236:<author_pubkey>:<d-tag>`
  final String addressableId;

  /// The Kind 16 repost event ID created by the user.
  ///
  /// This ID is needed to create a Kind 5 deletion event for unreposts.
  final String repostEventId;

  /// The public key of the original video author.
  final String originalAuthorPubkey;

  /// When the repost was created.
  final DateTime createdAt;

  /// Creates a copy of this record with the given fields replaced.
  RepostRecord copyWith({
    String? addressableId,
    String? repostEventId,
    String? originalAuthorPubkey,
    DateTime? createdAt,
  }) {
    return RepostRecord(
      addressableId: addressableId ?? this.addressableId,
      repostEventId: repostEventId ?? this.repostEventId,
      originalAuthorPubkey: originalAuthorPubkey ?? this.originalAuthorPubkey,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
    addressableId,
    repostEventId,
    originalAuthorPubkey,
    createdAt,
  ];

  @override
  String toString() {
    return 'RepostRecord('
        'addressableId: $addressableId, '
        'repostEventId: $repostEventId, '
        'originalAuthorPubkey: $originalAuthorPubkey, '
        'createdAt: $createdAt)';
  }
}
