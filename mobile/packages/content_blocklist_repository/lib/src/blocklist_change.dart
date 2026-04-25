// ABOUTME: Granular blocklist change events emitted on the changes stream
// ABOUTME: Subscribers (e.g. VideoEventService) react per-pubkey on additions

import 'package:flutter/foundation.dart';

/// Type of blocklist mutation. Used by [BlocklistChange.op] so subscribers
/// can decide whether the change should hide content
/// (any "added" op) or restore it (any "removed" op).
enum BlocklistOp {
  /// We blocked someone — added to our runtime blocklist.
  blocked,

  /// We unblocked someone — removed from our runtime blocklist.
  unblocked,

  /// Someone muted us — added to the mutual-mute set.
  muted,

  /// Someone unmuted us — removed from the mutual-mute set.
  unmuted,

  /// Someone blocked us — added to the blocked-by-others set.
  blockedUs,

  /// Someone unblocked us — removed from the blocked-by-others set.
  unblockedUs,
}

/// A granular change to the blocklist composition.
///
/// Emitted on `ContentBlocklistRepository.changes` whenever the user (or
/// remote sync) modifies which pubkeys are blocked / muted / blocking-us.
/// Subscribers can react per-pubkey rather than reading whole-state
/// snapshots and diffing them.
@immutable
class BlocklistChange {
  /// Creates a [BlocklistChange] for [pubkey] with mutation [op].
  const BlocklistChange({required this.pubkey, required this.op});

  /// The pubkey (hex) the change applies to.
  final String pubkey;

  /// What kind of change occurred.
  final BlocklistOp op;

  /// `true` when the change adds the pubkey to a hide-bucket — the
  /// signal that downstream caches should drop content from this author.
  /// `false` when the change removes the pubkey, restoring visibility on
  /// the next pagination.
  bool get isAddition => switch (op) {
    BlocklistOp.blocked || BlocklistOp.muted || BlocklistOp.blockedUs => true,
    BlocklistOp.unblocked ||
    BlocklistOp.unmuted ||
    BlocklistOp.unblockedUs => false,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BlocklistChange && other.pubkey == pubkey && other.op == op;

  @override
  int get hashCode => Object.hash(pubkey, op);

  @override
  String toString() => 'BlocklistChange(pubkey: $pubkey, op: $op)';
}
