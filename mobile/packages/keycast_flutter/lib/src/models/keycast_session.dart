// ABOUTME: Keycast session model with expiry tracking and persistence
// ABOUTME: Stores auth tokens, handles expiry checks, supports secure storage

import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../oauth/token_response.dart';

const _storageKey = 'keycast_session';

class KeycastSession {
  final String bunkerUrl;
  final String? accessToken;
  final DateTime? expiresAt;
  final String? scope;
  final String? userPubkey;
  /// Handle for silent re-authentication
  final String? authorizationHandle;

  const KeycastSession({
    required this.bunkerUrl,
    this.accessToken,
    this.expiresAt,
    this.scope,
    this.userPubkey,
    this.authorizationHandle,
  });

  factory KeycastSession.fromTokenResponse(TokenResponse response) {
    return KeycastSession(
      bunkerUrl: response.bunkerUrl,
      accessToken: response.accessToken,
      expiresAt: response.expiresIn > 0
          ? DateTime.now().add(Duration(seconds: response.expiresIn))
          : null,
      scope: response.scope,
      authorizationHandle: response.authorizationHandle,
    );
  }

  bool get isExpired =>
      expiresAt != null && DateTime.now().isAfter(expiresAt!);

  bool get hasRpcAccess => accessToken != null && !isExpired;

  KeycastSession copyWith({
    String? bunkerUrl,
    String? accessToken,
    DateTime? expiresAt,
    String? scope,
    String? userPubkey,
    String? authorizationHandle,
  }) {
    return KeycastSession(
      bunkerUrl: bunkerUrl ?? this.bunkerUrl,
      accessToken: accessToken ?? this.accessToken,
      expiresAt: expiresAt ?? this.expiresAt,
      scope: scope ?? this.scope,
      userPubkey: userPubkey ?? this.userPubkey,
      authorizationHandle: authorizationHandle ?? this.authorizationHandle,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bunker_url': bunkerUrl,
      'access_token': accessToken,
      'expires_at': expiresAt?.toIso8601String(),
      'scope': scope,
      'user_pubkey': userPubkey,
      'authorization_handle': authorizationHandle,
    };
  }

  factory KeycastSession.fromJson(Map<String, dynamic> json) {
    return KeycastSession(
      bunkerUrl: json['bunker_url'] as String,
      accessToken: json['access_token'] as String?,
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
      scope: json['scope'] as String?,
      userPubkey: json['user_pubkey'] as String?,
      authorizationHandle: json['authorization_handle'] as String?,
    );
  }

  Future<void> save([FlutterSecureStorage? storage]) async {
    final secureStorage = storage ?? const FlutterSecureStorage();
    await secureStorage.write(
      key: _storageKey,
      value: jsonEncode(toJson()),
    );
  }

  static Future<KeycastSession?> load([FlutterSecureStorage? storage]) async {
    final secureStorage = storage ?? const FlutterSecureStorage();
    final jsonString = await secureStorage.read(key: _storageKey);
    if (jsonString == null) {
      return null;
    }
    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return KeycastSession.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear([FlutterSecureStorage? storage]) async {
    final secureStorage = storage ?? const FlutterSecureStorage();
    await secureStorage.delete(key: _storageKey);
  }
}
