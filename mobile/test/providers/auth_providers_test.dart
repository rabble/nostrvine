// ABOUTME: Tests for authentication provider wiring.
// ABOUTME: Guards secure storage options that affect session persistence.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/providers/auth_providers.dart';

void main() {
  group('flutterSecureStorageProvider', () {
    test('keeps Android secure storage encrypted without reset-on-error', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final storage = container.read(flutterSecureStorageProvider);
      final androidOptions = storage.aOptions.toMap();

      expect(androidOptions['encryptedSharedPreferences'], 'true');
      expect(androidOptions['resetOnError'], 'false');
    });
  });
}
