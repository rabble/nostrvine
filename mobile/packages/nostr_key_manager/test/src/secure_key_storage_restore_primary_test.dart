// ABOUTME: Tests SecureKeyStorage.restorePrimaryKeyContainer round-tripping the
// ABOUTME: cached container, which account-switch rollback always hands it.

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';

import '../test_setup.dart';

void main() {
  group('SecureKeyStorage.restorePrimaryKeyContainer', () {
    late SecureKeyStorage storage;

    setUp(() async {
      setupTestEnvironment();
      storage = SecureKeyStorage();
      await storage.initialize();
    });

    test('restores the container getKeyContainer just handed out', () async {
      // The account-switch rollback snapshots PRIMARY with getKeyContainer and
      // hands that same object back here. getKeyContainer returns the cached
      // container, so disposing the cache unconditionally destroyed the
      // snapshot and storeKey threw on its disposed private key — masking the
      // sign-in failure the caller was trying to surface.
      await storage.generateAndStoreKeys();
      final snapshot = await storage.getKeyContainer();
      expect(snapshot, isNotNull);

      await expectLater(
        storage.restorePrimaryKeyContainer(snapshot),
        completes,
      );

      expect(snapshot!.isDisposed, isFalse);
      final restored = await storage.getKeyContainer();
      expect(restored!.npub, equals(snapshot.npub));
    });

    test(
      'disposes the cached container when restoring a different one',
      () async {
        await storage.generateAndStoreKeys();
        final outgoing = await storage.getKeyContainer();
        final incoming = await SecureKeyContainer.generate();

        await storage.restorePrimaryKeyContainer(incoming);

        // Only the container being replaced is released.
        expect(outgoing!.isDisposed, isTrue);
        expect(incoming.isDisposed, isFalse);
        final restored = await storage.getKeyContainer();
        expect(restored!.npub, equals(incoming.npub));
      },
    );
  });
}
