// ABOUTME: One-time migration of legacy Nostr keys into SecureKeyStorage.

import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:nostr_key_manager/src/secure_key_storage.dart';
import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:nostr_sdk/nip19/nip19.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _log = Logger('migrateLegacyNostrKeys');

/// SharedPreferences key holding the pre-secure-storage keypair JSON.
const String _legacyKeyPairKey = 'nostr_keypair';

/// SharedPreferences key holding the legacy key-format version marker.
const String _legacyKeyVersionKey = 'nostr_key_version';

/// Migrates a pre-secure-storage Nostr keypair into [storage].
///
/// Builds prior to the secure-storage cutover persisted the identity key as a
/// `{"private": ..., "public": ...}` JSON blob under `nostr_keypair` in
/// SharedPreferences. This one-time migration moves such a key into hardware-
/// backed [SecureKeyStorage] and removes the legacy entries once moved.
///
/// This must run once at startup, before the auth layer reads the primary key.
///
/// No-ops when [storage] already holds a primary key (so it can never clobber a
/// legitimately-present key — [SecureKeyStorage.importFromNsec] archives and
/// overwrites the primary slot) or when no legacy key is present. Migration
/// failures are logged and swallowed so the user can regenerate or re-import
/// rather than being blocked at startup.
Future<void> migrateLegacyNostrKeys(SecureKeyStorage storage) async {
  try {
    await storage.initialize();

    // Guard: never migrate over an existing primary key.
    if (await storage.hasKeys()) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final existingKeyData = prefs.getString(_legacyKeyPairKey);
    if (existingKeyData == null) {
      return;
    }

    _log.warning(
      'Found legacy keys in SharedPreferences, migrating to secure storage...',
    );

    try {
      final keyData = jsonDecode(existingKeyData) as Map<String, dynamic>;
      final privateKey = keyData['private'] as String?;
      final publicKey = keyData['public'] as String?;

      if (privateKey != null &&
          publicKey != null &&
          keyIsValid(privateKey) &&
          keyIsValid(publicKey)) {
        final nsec = Nip19.encodePrivateKey(privateKey);
        final secureContainer = await storage.importFromNsec(nsec);
        secureContainer.dispose();

        await prefs.remove(_legacyKeyPairKey);
        await prefs.remove(_legacyKeyVersionKey);

        _log.info('Successfully migrated legacy keys to secure storage');
      }
    } on Exception catch (e) {
      // Don't rethrow — allow the user to regenerate if migration fails.
      _log.severe('Failed to migrate legacy keys: $e');
    }
  } on Exception catch (e) {
    _log.severe('Error checking for legacy keys: $e');
  }
}
