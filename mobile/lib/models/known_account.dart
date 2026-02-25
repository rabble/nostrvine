// ABOUTME: Model for a previously used account identity
// ABOUTME: Stores pubkey, auth source, and timestamps for multi-account support

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:openvine/services/auth_service.dart' show AuthenticationSource;

/// Key used to persist the known accounts list in SharedPreferences.
const kKnownAccountsKey = 'known_accounts';

/// A previously used account identity.
///
/// Each entry tracks which [AuthenticationSource] was used to authenticate,
/// allowing the welcome screen to reconnect using the correct method.
@immutable
class KnownAccount extends Equatable {
  const KnownAccount({
    required this.pubkeyHex,
    required this.authSource,
    required this.addedAt,
    required this.lastUsedAt,
  });

  /// Creates a [KnownAccount] from a JSON map.
  factory KnownAccount.fromJson(Map<String, dynamic> json) {
    return KnownAccount(
      pubkeyHex: json['pubkeyHex'] as String,
      authSource: AuthenticationSource.fromCode(json['authSource'] as String?),
      addedAt: DateTime.parse(json['addedAt'] as String),
      lastUsedAt: DateTime.parse(json['lastUsedAt'] as String),
    );
  }

  /// Full 64-character hex public key.
  final String pubkeyHex;

  /// Which authentication method was used for this identity.
  final AuthenticationSource authSource;

  /// When this account was first registered in the known accounts list.
  final DateTime addedAt;

  /// When this account was last actively used (signed in).
  final DateTime lastUsedAt;

  /// Serializes this account to a JSON map.
  Map<String, dynamic> toJson() => {
    'pubkeyHex': pubkeyHex,
    'authSource': authSource.code,
    'addedAt': addedAt.toIso8601String(),
    'lastUsedAt': lastUsedAt.toIso8601String(),
  };

  /// Creates a copy with the given fields replaced.
  KnownAccount copyWith({
    AuthenticationSource? authSource,
    DateTime? lastUsedAt,
  }) {
    return KnownAccount(
      pubkeyHex: pubkeyHex,
      authSource: authSource ?? this.authSource,
      addedAt: addedAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
    );
  }

  /// Equality is based only on pubkey — same pubkey means same account.
  @override
  List<Object?> get props => [pubkeyHex];
}
