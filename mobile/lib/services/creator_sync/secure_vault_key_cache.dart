// ABOUTME: Stores the unwrapped sync vault key in platform secure storage.
// ABOUTME: Keyed per account so switching identities never leaks a key.

import 'package:creator_sync/creator_sync.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the vault key on-device via [FlutterSecureStorage].
class SecureVaultKeyCache implements VaultKeyCache {
  /// Creates a [SecureVaultKeyCache].
  SecureVaultKeyCache(this._storage);

  final FlutterSecureStorage _storage;

  static const String _keyPrefix = 'creator_sync_vault_key';

  @override
  Future<String?> read(String pubkeyHex) =>
      _storage.read(key: '${_keyPrefix}_$pubkeyHex');

  @override
  Future<void> write(String pubkeyHex, String base64Key) =>
      _storage.write(key: '${_keyPrefix}_$pubkeyHex', value: base64Key);
}
