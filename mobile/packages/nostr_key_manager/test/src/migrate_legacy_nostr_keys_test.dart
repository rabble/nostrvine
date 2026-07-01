// ABOUTME: Unit tests for the legacy-key migration into SecureKeyStorage.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_setup.dart';

void main() {
  group('migrateLegacyNostrKeys', () {
    late SecureKeyStorage storage;

    setUp(() {
      setupTestEnvironment();
      storage = SecureKeyStorage();
    });

    String legacyBlob(String privateKey) => jsonEncode({
      'private': privateKey,
      'public': getPublicKey(privateKey),
      'created_at': 1700000000000,
      'version': 1,
    });

    test('does nothing when no legacy key is present', () async {
      await migrateLegacyNostrKeys(storage);

      expect(await storage.hasKeys(), isFalse);
    });

    test('migrates a legacy key and removes the legacy prefs', () async {
      SharedPreferences.setMockInitialValues({
        'nostr_keypair': legacyBlob(generatePrivateKey()),
        'nostr_key_version': 1,
      });

      await migrateLegacyNostrKeys(storage);

      expect(await storage.hasKeys(), isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('nostr_keypair'), isNull);
      expect(prefs.getInt('nostr_key_version'), isNull);
    });

    test('skips migration when secure storage already holds a key', () async {
      // A different legacy key sits in prefs; it must not overwrite the
      // existing primary.
      SharedPreferences.setMockInitialValues({
        'nostr_keypair': legacyBlob(generatePrivateKey()),
        'nostr_key_version': 1,
      });

      final existing = await storage.generateAndStoreKeys();
      final existingNpub = existing.npub;
      existing.dispose();

      await migrateLegacyNostrKeys(storage);

      final current = await storage.getKeyContainer();
      expect(current, isNotNull);
      expect(current!.npub, equals(existingNpub));
      current.dispose();

      // Legacy prefs are left untouched since migration short-circuited.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('nostr_keypair'), isNotNull);
    });

    test('swallows malformed legacy data without migrating', () async {
      SharedPreferences.setMockInitialValues({
        'nostr_keypair': 'not-valid-json',
      });

      await migrateLegacyNostrKeys(storage);

      expect(await storage.hasKeys(), isFalse);
    });

    test('ignores a legacy blob with an invalid private key', () async {
      SharedPreferences.setMockInitialValues({
        'nostr_keypair': jsonEncode({
          'private': 'tooshort',
          'public': 'alsoinvalid',
        }),
      });

      await migrateLegacyNostrKeys(storage);

      expect(await storage.hasKeys(), isFalse);
    });
  });
}
