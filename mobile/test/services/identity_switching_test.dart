// ABOUTME: Tests for identity switching and multiple account management
// ABOUTME: Verifies key storage, switching, and backup functionality

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:openvine/services/key_storage_service.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/utils/nostr_encoding.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('Identity Switching Tests', () {
    late KeyStorageService keyStorageService;
    late AuthService authService;

    setUp(() async {
      // Initialize SharedPreferences with test values
      SharedPreferences.setMockInitialValues({});
      
      keyStorageService = KeyStorageService();
      authService = AuthService(keyStorage: keyStorageService);
      
      await keyStorageService.initialize();
      await authService.initialize();
    });

    test('Should create and save initial identity', () async {
      // Create a new identity
      final result = await authService.createNewIdentity();
      
      expect(result.success, isTrue);
      expect(result.keyPair, isNotNull);
      expect(result.errorMessage, isNull);
      
      // Verify it's stored
      final hasKeys = await keyStorageService.hasKeys();
      expect(hasKeys, isTrue);
      
      final storedKeyPair = await keyStorageService.getKeyPair();
      expect(storedKeyPair, isNotNull);
      expect(storedKeyPair!.npub, equals(result.keyPair!.npub));
    });

    test('Should save current identity before switching', () async {
      // Create initial identity
      final initialResult = await authService.createNewIdentity();
      expect(initialResult.success, isTrue);
      
      final initialNpub = initialResult.keyPair!.npub;
      final initialNsec = initialResult.keyPair!.nsec;
      
      // Save the current identity
      await keyStorageService.storeIdentityKeyPair(
        initialNpub, 
        initialResult.keyPair!
      );
      
      // Verify it was saved
      final savedIdentity = await keyStorageService.getIdentityKeyPair(initialNpub);
      expect(savedIdentity, isNotNull);
      expect(savedIdentity!.npub, equals(initialNpub));
      expect(savedIdentity.nsec, equals(initialNsec));
    });

    test('Should import new identity from nsec', () async {
      // Create initial identity
      final initialResult = await authService.createNewIdentity();
      expect(initialResult.success, isTrue);
      
      final initialNpub = initialResult.keyPair!.npub;
      
      // Generate a different test nsec
      final testKeyPair = NostrKeyPair.generate();
      final testNsec = testKeyPair.nsec;
      
      // Save current identity
      await keyStorageService.storeIdentityKeyPair(
        initialNpub,
        initialResult.keyPair!
      );
      
      // Import new identity
      final importResult = await authService.importFromNsec(testNsec);
      
      expect(importResult.success, isTrue);
      expect(importResult.keyPair, isNotNull);
      expect(importResult.keyPair!.nsec, equals(testNsec));
      
      // Verify the new identity is active
      final activeKeyPair = await keyStorageService.getKeyPair();
      expect(activeKeyPair!.nsec, equals(testNsec));
      
      // Verify the old identity is still saved
      final savedInitial = await keyStorageService.getIdentityKeyPair(initialNpub);
      expect(savedInitial, isNotNull);
      expect(savedInitial!.npub, equals(initialNpub));
    });

    test('Should switch between saved identities', () async {
      // Create two identities
      final identity1 = NostrKeyPair.generate();
      final identity2 = NostrKeyPair.generate();
      
      // Store first identity as active
      await keyStorageService.storeKeyPair(identity1);
      
      // Save both identities
      await keyStorageService.storeIdentityKeyPair(identity1.npub, identity1);
      await keyStorageService.storeIdentityKeyPair(identity2.npub, identity2);
      
      // Verify first identity is active
      var activeKeyPair = await keyStorageService.getKeyPair();
      expect(activeKeyPair!.npub, equals(identity1.npub));
      
      // Switch to second identity
      final switchResult = await keyStorageService.switchToIdentity(identity2.npub);
      expect(switchResult, isTrue);
      
      // Verify second identity is now active
      activeKeyPair = await keyStorageService.getKeyPair();
      expect(activeKeyPair!.npub, equals(identity2.npub));
      
      // Switch back to first identity
      final switchBackResult = await keyStorageService.switchToIdentity(identity1.npub);
      expect(switchBackResult, isTrue);
      
      // Verify first identity is active again
      activeKeyPair = await keyStorageService.getKeyPair();
      expect(activeKeyPair!.npub, equals(identity1.npub));
    });

    test('Should handle invalid nsec import gracefully', () async {
      // Try to import invalid nsec
      const invalidNsec = 'nsec1invalid';
      
      final result = await authService.importFromNsec(invalidNsec);
      
      expect(result.success, isFalse);
      expect(result.errorMessage, isNotNull);
      expect(result.errorMessage, contains('Invalid nsec format'));
    });

    test('Should not lose identities after app restart', () async {
      // Create and save multiple identities
      final identity1 = NostrKeyPair.generate();
      final identity2 = NostrKeyPair.generate();
      
      await keyStorageService.storeKeyPair(identity1);
      await keyStorageService.storeIdentityKeyPair(identity1.npub, identity1);
      await keyStorageService.storeIdentityKeyPair(identity2.npub, identity2);
      
      // Simulate app restart by creating new instances
      final newKeyStorageService = KeyStorageService();
      await newKeyStorageService.initialize();
      
      // Verify saved identities are still accessible
      final savedIdentity1 = await newKeyStorageService.getIdentityKeyPair(identity1.npub);
      final savedIdentity2 = await newKeyStorageService.getIdentityKeyPair(identity2.npub);
      
      expect(savedIdentity1, isNotNull);
      expect(savedIdentity1!.npub, equals(identity1.npub));
      expect(savedIdentity2, isNotNull);
      expect(savedIdentity2!.npub, equals(identity2.npub));
      
      // Verify active identity is preserved
      final activeKeyPair = await newKeyStorageService.getKeyPair();
      expect(activeKeyPair!.npub, equals(identity1.npub));
    });

    test('Should maintain key security during switching', () async {
      // Create identity with known keys
      const testPrivateKeyHex = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
      final testKeyPair = NostrKeyPair.fromPrivateKey(testPrivateKeyHex);
      
      // Store the identity
      await keyStorageService.storeKeyPair(testKeyPair);
      await keyStorageService.storeIdentityKeyPair(testKeyPair.npub, testKeyPair);
      
      // Create another identity
      final newIdentity = NostrKeyPair.generate();
      await keyStorageService.storeKeyPair(newIdentity);
      
      // Switch back to test identity
      await keyStorageService.switchToIdentity(testKeyPair.npub);
      
      // Verify the private key is still correct
      final retrievedKeyPair = await keyStorageService.getKeyPair();
      expect(retrievedKeyPair!.privateKeyHex, equals(testPrivateKeyHex));
      
      // Verify we can sign with the key
      final privateKeyForSigning = await keyStorageService.getPrivateKeyForSigning();
      expect(privateKeyForSigning, equals(testPrivateKeyHex));
    });
  });
}