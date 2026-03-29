import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class NostrAppGrant {
  const NostrAppGrant({
    required this.userPubkey,
    required this.appId,
    required this.origin,
    required this.capability,
    required this.grantedAt,
  });

  factory NostrAppGrant.fromJson(Map<String, dynamic> json) {
    return NostrAppGrant(
      userPubkey: json['user_pubkey'] as String? ?? '',
      appId: json['app_id'] as String? ?? '',
      origin: json['origin'] as String? ?? '',
      capability: json['capability'] as String? ?? '',
      grantedAt:
          DateTime.tryParse(json['granted_at'] as String? ?? '')?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  final String userPubkey;
  final String appId;
  final String origin;
  final String capability;
  final DateTime grantedAt;

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

class NostrAppGrantStore {
  NostrAppGrantStore({required SharedPreferences sharedPreferences})
    : _sharedPreferences = sharedPreferences;

  static const String _storageKey = 'nostr_app_grants_v1';

  final SharedPreferences _sharedPreferences;

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

  Future<void> saveGrant({
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

    grants.add(
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
    } catch (_) {
      return const [];
    }
  }

  Future<void> _writeGrants(List<NostrAppGrant> grants) {
    return _sharedPreferences.setString(
      _storageKey,
      jsonEncode(grants.map((grant) => grant.toJson()).toList(growable: false)),
    );
  }
}
