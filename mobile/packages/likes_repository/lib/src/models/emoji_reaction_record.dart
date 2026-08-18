// ABOUTME: Model representing the user's emoji reaction (Kind 7) record.
// ABOUTME: Stores the target/reaction event ID mapping plus the emoji,
// ABOUTME: needed for removal (Kind 5) and cap-at-one supersede.

import 'package:equatable/equatable.dart';

/// A record of the current user's emoji reaction on a Nostr event.
///
/// Mirrors `LikeRecord` for NIP-25 kind-7 reactions whose content is an
/// emoji rather than `+`/`-`. The [emoji] is kept so cap-at-one supersede
/// (a new emoji replaces the previous one) can tell whether a tap is a
/// removal or a replacement, and so the UI can highlight the user's own
/// chip.
class EmojiReactionRecord extends Equatable {
  /// Creates a new emoji reaction record.
  const EmojiReactionRecord({
    required this.targetEventId,
    required this.reactionEventId,
    required this.emoji,
    required this.createdAt,
    this.addressableId,
  });

  /// The event ID that was reacted to (e.g. a comment event ID).
  final String targetEventId;

  /// The Kind 7 reaction event ID created by the user.
  ///
  /// Needed to build the Kind 5 deletion event on removal.
  final String reactionEventId;

  /// The reaction's content — the emoji itself.
  final String emoji;

  /// When the reaction was created.
  final DateTime createdAt;

  /// Addressable coordinate (`kind:pubkey:d-tag`) of the target event, when
  /// the target is addressable (e.g. a Kind 34236 video reply). Null for
  /// non-addressable targets like Kind 1111 comments.
  final String? addressableId;

  @override
  List<Object?> get props => [
    targetEventId,
    reactionEventId,
    emoji,
    createdAt,
    addressableId,
  ];

  @override
  String toString() {
    return 'EmojiReactionRecord('
        'targetEventId: $targetEventId, '
        'reactionEventId: $reactionEventId, '
        'emoji: $emoji, '
        'createdAt: $createdAt, '
        'addressableId: $addressableId)';
  }
}
