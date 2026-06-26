import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/secure_storage_options.dart';

void main() {
  group('appMacOsSecureStorageOptions', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    bool usesDataProtectionKeyChain({required bool isDebug}) =>
        appMacOsSecureStorageOptions(
          isDebug: isDebug,
        ).toMap()['useDataProtectionKeyChain'] ==
        'true';

    test('falls back to the file-based keychain on macOS debug', () {
      // The macOS-debug branch is the one that would otherwise hit OSStatus
      // -34018 (errSecMissingEntitlement). #5563.
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      expect(usesDataProtectionKeyChain(isDebug: true), isFalse);
    });

    test('keeps the data-protection keychain on macOS release', () {
      // Release builds are properly signed, so the data-protection keychain
      // stays enabled even on macOS.
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      expect(usesDataProtectionKeyChain(isDebug: false), isTrue);
    });

    test('keeps the data-protection keychain on iOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(usesDataProtectionKeyChain(isDebug: true), isTrue);
    });

    test('keeps the data-protection keychain on Android', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(usesDataProtectionKeyChain(isDebug: true), isTrue);
    });
  });
}
