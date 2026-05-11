import 'dart:convert';

import 'package:meta/meta.dart';

/// A point-in-time snapshot of a user's followers.
///
/// Returned by [FollowRepository.watchMyFollowers] and used as the
/// cache payload for [CacheSync].
@immutable
class FollowersSnapshot {
  const FollowersSnapshot({required this.pubkeys, required this.count});

  /// Public keys of users who follow the current user.
  final List<String> pubkeys;

  /// Authoritative follower count.
  ///
  /// May exceed [pubkeys.length] when relay result caps prevent
  /// downloading every follower.
  final int count;

  /// Deserializes from a JSON string produced by [toJson].
  static FollowersSnapshot fromJson(String json) {
    final data = jsonDecode(json) as Map<String, dynamic>;
    final pubkeys = (data['pubkeys'] as List<dynamic>? ?? []).cast<String>();
    final count = data['count'] as int? ?? pubkeys.length;
    return FollowersSnapshot(pubkeys: pubkeys, count: count);
  }

  /// Serializes to a JSON string for cache storage.
  String toJson() => jsonEncode({'pubkeys': pubkeys, 'count': count});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FollowersSnapshot &&
          count == other.count &&
          pubkeys.length == other.pubkeys.length &&
          _listEquals(pubkeys, other.pubkeys);

  @override
  int get hashCode => Object.hash(count, Object.hashAll(pubkeys));

  @override
  String toString() =>
      'FollowersSnapshot(count: $count, pubkeys: ${pubkeys.length})';

  static bool _listEquals(List<String> a, List<String> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
