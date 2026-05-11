import 'dart:convert';

import 'package:meta/meta.dart';

/// A point-in-time snapshot of a user's following list.
///
/// Used as the cache payload for [CacheSync] in both
/// [MyFollowingBloc] (stream-based) and [OthersFollowingBloc] (one-shot).
@immutable
class FollowingSnapshot {
  const FollowingSnapshot({required this.pubkeys, required this.count});

  /// Public keys of users this user is following.
  final List<String> pubkeys;

  /// Authoritative following count.
  ///
  /// May exceed [pubkeys.length] when relay result caps prevent
  /// downloading every followed user.
  final int count;

  /// Deserializes from a JSON string produced by [toJson].
  static FollowingSnapshot fromJson(String json) {
    final data = jsonDecode(json) as Map<String, dynamic>;
    final pubkeys = (data['pubkeys'] as List<dynamic>? ?? []).cast<String>();
    final count = data['count'] as int? ?? pubkeys.length;
    return FollowingSnapshot(pubkeys: pubkeys, count: count);
  }

  /// Serializes to a JSON string for cache storage.
  String toJson() => jsonEncode({'pubkeys': pubkeys, 'count': count});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FollowingSnapshot &&
          count == other.count &&
          pubkeys.length == other.pubkeys.length &&
          _listEquals(pubkeys, other.pubkeys);

  @override
  int get hashCode => Object.hash(count, Object.hashAll(pubkeys));

  @override
  String toString() =>
      'FollowingSnapshot(count: $count, pubkeys: ${pubkeys.length})';

  static bool _listEquals(List<String> a, List<String> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
