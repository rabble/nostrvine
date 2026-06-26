import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/secure_storage_options.dart';

void main() {
  group('appMacOsSecureStorageOptions', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    bool usesDataProtectionKeyChain() =>
        appMacOsSecureStorageOptions().toMap()['useDataProtectionKeyChain'] ==
        'true';

    test('falls back to the file-based keychain on macOS debug', () {
      // Tests run in debug mode, so this exercises the macOS-debug branch that
      // would otherwise hit OSStatus -34018 (errSecMissingEntitlement). #5563.
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      expect(usesDataProtectionKeyChain(), isFalse);
    });

    test('keeps the data-protection keychain on iOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(usesDataProtectionKeyChain(), isTrue);
    });

    test('keeps the data-protection keychain on Android', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(usesDataProtectionKeyChain(), isTrue);
    });
  });
}
