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

    test('keeps the prior keychain contract on macOS release', () {
      // Release builds are properly signed, so the data-protection keychain
      // stays enabled even on macOS. Asserting the full map locks the
      // no-regression contract: if the helper later set `accessibility`
      // (e.g. to mirror `nostr_key_manager`'s `first_unlock`) the App Store
      // keychain attributes would change silently and could orphan
      // already-stored keys for real users. #5563.
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      expect(
        appMacOsSecureStorageOptions(isDebug: false).toMap(),
        <String, String>{
          'accessibility': 'unlocked',
          'accountName': 'flutter_secure_storage_service',
          'synchronizable': 'false',
          'useDataProtectionKeyChain': 'true',
        },
      );
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
