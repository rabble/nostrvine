import 'dart:convert';

import 'package:follow_repository/src/follow_sort_order.dart';
import 'package:meta/meta.dart';

/// A point-in-time snapshot of a user's followers.
///
/// Returned by `FollowRepository.watchMyFollowers` and used as the
/// cache payload for `CacheSync`.
@immutable
class FollowersSnapshot {
  const FollowersSnapshot({
    required this.pubkeys,
    required this.count,
    this.datedCount = 0,
  });

  /// Deserializes from a JSON string produced by [toJson].
  ///
  /// A payload written before [datedCount] existed restores with `0`, which
  /// reads as "nothing here is dated" — [FollowSortOrder.fromNewestFirst]
  /// then leaves the order alone until the next live fetch rewrites the entry.
  factory FollowersSnapshot.fromJson(String json) {
    final data = jsonDecode(json) as Map<String, dynamic>;
    final pubkeys = (data['pubkeys'] as List<dynamic>? ?? []).cast<String>();
    final count = data['count'] as int? ?? pubkeys.length;
    final datedCount = data['datedCount'] as int? ?? 0;
    return FollowersSnapshot(
      pubkeys: pubkeys,
      count: count,
      // A truncated or hand-edited payload must not hand out a prefix length
      // that runs past the list.
      datedCount: datedCount.clamp(0, pubkeys.length),
    );
  }

  /// Public keys of users who follow the current user, newest follower first.
  ///
  /// Ordering is decided by `FollowRepository` and preserved verbatim through
  /// the cache, so a restored snapshot lists followers in the same order it
  /// was stored in.
  final List<String> pubkeys;

  /// Authoritative follower count.
  ///
  /// May exceed `pubkeys.length` when relay result caps prevent
  /// downloading every follower.
  final int count;

  /// How many of the leading [pubkeys] carry a contact-list timestamp.
  ///
  /// `FollowRepository` sorts every dated follower ahead of every undated one,
  /// so `pubkeys.take(datedCount)` is exactly the dated prefix and the rest is
  /// the undated tail. Storing the boundary rather than the timestamps keeps
  /// the cached payload the same size it has always been.
  ///
  /// Hand this to [FollowSortOrder.fromNewestFirst] to re-order [pubkeys].
  final int datedCount;

  /// Serializes to a JSON string for cache storage.
  String toJson() => jsonEncode({
    'pubkeys': pubkeys,
    'count': count,
    'datedCount': datedCount,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FollowersSnapshot &&
          count == other.count &&
          datedCount == other.datedCount &&
          pubkeys.length == other.pubkeys.length &&
          _listEquals(pubkeys, other.pubkeys);

  @override
  int get hashCode => Object.hash(count, datedCount, Object.hashAll(pubkeys));

  @override
  String toString() =>
      'FollowersSnapshot(count: $count, pubkeys: ${pubkeys.length}, '
      'datedCount: $datedCount)';

  static bool _listEquals(List<String> a, List<String> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
