// ABOUTME: Tests the FlutterSecureStorage-backed VaultKeyCache adapter.
// ABOUTME: Uses the sanctioned shared-channel override for secure storage.

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/creator_sync/secure_vault_key_cache.dart';

import '../../helpers/shared_channel_override.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(SecureVaultKeyCache, () {
    late Map<String, String> backingStore;
    late SecureVaultKeyCache cache;

    setUp(() {
      backingStore = {};

      const channel = MethodChannel(
        'plugins.it_nomads.com/flutter_secure_storage',
      );
      overrideSharedChannel(channel, (MethodCall call) async {
        switch (call.method) {
          case 'read':
            final key = call.arguments['key'] as String?;
            return backingStore[key];
          case 'write':
            final key = call.arguments['key'] as String?;
            final value = call.arguments['value'] as String?;
            if (key != null && value != null) {
              backingStore[key] = value;
            }
            return null;
          case 'delete':
            final key = call.arguments['key'] as String?;
            backingStore.remove(key);
            return null;
          default:
            return null;
        }
      });

      cache = SecureVaultKeyCache(const FlutterSecureStorage());
    });

    test('read returns null for a pubkey with no stored key', () async {
      expect(await cache.read('a' * 64), isNull);
    });

    test('write then read round-trips the base64 key', () async {
      await cache.write('a' * 64, 'base64-key-value');

      expect(await cache.read('a' * 64), equals('base64-key-value'));
    });

    test('keys stored for one account are invisible to another', () async {
      await cache.write('a' * 64, 'account-a-key');

      expect(await cache.read('b' * 64), isNull);
    });
  });
}
