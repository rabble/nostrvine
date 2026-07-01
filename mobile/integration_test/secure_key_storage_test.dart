// ABOUTME: Integration test for secure key storage that runs on actual device/simulator
// ABOUTME: Tests SecureKeyStorage and legacy-key migration on-device

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:patrol/patrol.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('migrateLegacyNostrKeys on Device', () {
    late SecureKeyStorage storage;

    setUp(() async {
      // Clear SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      storage = SecureKeyStorage();
      await storage.initialize();
      // Clear any key a prior/aborted run left in the device keychain so the
      // migration's hasKeys() guard can't spuriously short-circuit.
      await storage.deleteKeys();
    });

    tearDown(() async {
      await storage.deleteKeys();
      storage.dispose();
    });

    patrolTest('should migrate legacy keys from SharedPreferences', ($) async {
      // Set up legacy keys
      final privateKey = generatePrivateKey();
      final legacyKeyData = {
        'private': privateKey,
        'public': getPublicKey(privateKey),
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'version': 1,
      };

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('nostr_keypair', jsonEncode(legacyKeyData));
      await prefs.setInt('nostr_key_version', 1);

      // Migrate and verify
      await migrateLegacyNostrKeys(storage);
      expect(await storage.hasKeys(), isTrue);

      // Verify legacy keys are removed
      expect(prefs.getString('nostr_keypair'), isNull);
    });
  });

  group('SecureKeyStorage Integration Tests on Device', () {
    late SecureKeyStorage storageService;

    setUp(() async {
      storageService = SecureKeyStorage();
      await storageService.initialize();
    });

    tearDown(() {
      storageService.dispose();
    });

    patrolTest('should generate and store keys with platform security', (
      $,
    ) async {
      // Generate keys
      final keyContainer = await storageService.generateAndStoreKeys();
      expect(keyContainer, isNotNull);
      expect(keyContainer.npub, isNotEmpty);
      expect(keyContainer.publicKeyHex.length, equals(64));
      keyContainer.dispose();

      // Verify persistence
      expect(await storageService.hasKeys(), isTrue);

      // Retrieve keys
      final retrieved = await storageService.getKeyContainer();
      expect(retrieved, isNotNull);
      expect(retrieved!.npub, isNotEmpty);
      retrieved.dispose();
    });

    patrolTest('should delete keys securely', ($) async {
      // Generate and store keys
      final keyContainer = await storageService.generateAndStoreKeys();
      keyContainer.dispose();
      expect(await storageService.hasKeys(), isTrue);

      // Delete keys
      await storageService.deleteKeys();
      expect(await storageService.hasKeys(), isFalse);
    });
  });
}
