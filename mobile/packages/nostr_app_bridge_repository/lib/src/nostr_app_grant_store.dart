import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// A single persisted permission grant.
class NostrAppGrant {
  /// Creates a grant record.
  const NostrAppGrant({
    required this.userPubkey,
    required this.appId,
    required this.origin,
    required this.capability,
    required this.grantedAt,
  });

  /// Deserializes from JSON.
  factory NostrAppGrant.fromJson(Map<String, dynamic> json) {
    return NostrAppGrant(
      userPubkey: json['user_pubkey'] as String? ?? '',
      appId: json['app_id'] as String? ?? '',
      origin: json['origin'] as String? ?? '',
      capability: json['capability'] as String? ?? '',
      grantedAt:
          DateTime.tryParse(
            json['granted_at'] as String? ?? '',
          )?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  /// The hex public key of the user who granted permission.
  final String userPubkey;

  /// The stable app identifier (slug).
  final String appId;

  /// The origin that was granted access.
  final String origin;

  /// The capability string (e.g. `signEvent:1`).
  final String capability;

  /// When the grant was recorded.
  final DateTime grantedAt;

  /// Serializes to JSON.
  Map<String, dynamic> toJson() {
    return {
      'user_pubkey': userPubkey,
      'app_id': appId,
      'origin': origin,
      'capability': capability,
      'granted_at': grantedAt.toUtc().toIso8601String(),
    };
  }
}

/// Persists and queries user-granted NIP-07 permissions.
class NostrAppGrantStore {
  /// Creates a grant store backed by [SharedPreferences].
  NostrAppGrantStore({
    required SharedPreferences sharedPreferences,
  }) : _sharedPreferences = sharedPreferences;

  static const String _storageKey = 'nostr_app_grants_v1';

  final SharedPreferences _sharedPreferences;

  /// Lists grants, optionally filtered by user or app.
  List<NostrAppGrant> listGrants({
    String? userPubkey,
    String? appId,
  }) {
    return _readGrants()
        .where((grant) {
          if (userPubkey != null && grant.userPubkey != userPubkey) {
            return false;
          }
          if (appId != null && grant.appId != appId) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  /// Returns whether a matching grant exists.
  bool hasGrant({
    required String userPubkey,
    required String appId,
    required String origin,
    required String capability,
  }) {
    return _readGrants().any(
      (grant) =>
          grant.userPubkey == userPubkey &&
          grant.appId == appId &&
          grant.origin == origin &&
          grant.capability == capability,
    );
  }

  /// Saves (upserts) a grant.
  Future<void> saveGrant({
    required String userPubkey,
    required String appId,
    required String origin,
    required String capability,
  }) async {
    final grants =
        _readGrants()
            .where(
              (grant) =>
                  !(grant.userPubkey == userPubkey &&
                      grant.appId == appId &&
                      grant.origin == origin &&
                      grant.capability == capability),
            )
            .toList()
          ..add(
            NostrAppGrant(
              userPubkey: userPubkey,
              appId: appId,
              origin: origin,
              capability: capability,
              grantedAt: DateTime.now().toUtc(),
            ),
          );

    await _writeGrants(grants);
  }

  /// Revokes a single grant.
  Future<void> revokeGrant({
    required String userPubkey,
    required String appId,
    required String origin,
    required String capability,
  }) async {
    final grants = _readGrants()
        .where(
          (grant) =>
              !(grant.userPubkey == userPubkey &&
                  grant.appId == appId &&
                  grant.origin == origin &&
                  grant.capability == capability),
        )
        .toList();
    await _writeGrants(grants);
  }

  /// Revokes all grants for a given user + app combination.
  Future<void> revokeAppGrants({
    required String userPubkey,
    required String appId,
  }) async {
    final grants = _readGrants()
        .where(
          (grant) => !(grant.userPubkey == userPubkey && grant.appId == appId),
        )
        .toList();
    await _writeGrants(grants);
  }

  List<NostrAppGrant> _readGrants() {
    final raw = _sharedPreferences.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      return const [];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const [];
      }

      return decoded
          .whereType<Map<String, dynamic>>()
          .map(NostrAppGrant.fromJson)
          .where(
            (grant) =>
                grant.userPubkey.isNotEmpty &&
                grant.appId.isNotEmpty &&
                grant.origin.isNotEmpty &&
                grant.capability.isNotEmpty,
          )
          .toList(growable: false);
    } on Object {
      return const [];
    }
  }

  Future<void> _writeGrants(List<NostrAppGrant> grants) {
    return _sharedPreferences.setString(
      _storageKey,
      jsonEncode(
        grants.map((grant) => grant.toJson()).toList(growable: false),
      ),
    );
  }
}
