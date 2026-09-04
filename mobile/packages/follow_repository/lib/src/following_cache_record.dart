// ABOUTME: Versioned codec for the following-list SharedPreferences cache.
// ABOUTME: Keeps repository and app bootstrap readers on one storage contract.

import 'dart:convert';

/// The SharedPreferences record used to bootstrap the signed-in user's
/// following list before the repository is available.
final class FollowingCacheRecord {
  FollowingCacheRecord({
    required List<String> pubkeys,
    this.createdAt,
    this.eventId,
    this.needsMigration = false,
  }) : pubkeys = List.unmodifiable(pubkeys);

  /// Decode both the legacy bare-array format and the current envelope.
  factory FollowingCacheRecord.decode(String encoded) {
    final decoded = jsonDecode(encoded);
    if (decoded is List) {
      return FollowingCacheRecord(
        pubkeys: decoded.cast<String>(),
        needsMigration: true,
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Following cache must be a list or object');
    }

    final rawPubkeys = decoded['pubkeys'];
    if (rawPubkeys is! List) {
      throw const FormatException('Following cache is missing pubkeys');
    }

    return FollowingCacheRecord(
      pubkeys: rawPubkeys.cast<String>(),
      createdAt: decoded['created_at'] as int?,
      eventId: decoded['id'] as String?,
      needsMigration: decoded['v'] != currentVersion,
    );
  }

  /// Schema version written by current clients.
  static const currentVersion = 2;

  /// SharedPreferences key for [pubkey].
  static String storageKey(String pubkey) => 'following_list_$pubkey';

  final List<String> pubkeys;
  final int? createdAt;
  final String? eventId;

  /// Whether reading this record should rewrite it in the current format.
  final bool needsMigration;

  /// Encode the current versioned envelope.
  String encode() => jsonEncode({
    'v': currentVersion,
    'created_at': createdAt,
    'id': eventId,
    'pubkeys': pubkeys,
  });
}
