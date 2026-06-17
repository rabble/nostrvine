import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('build_macos.sh signing guard', () {
    late String script;

    setUpAll(() {
      script = File('build_macos.sh').readAsStringSync();
    });

    test('debug builds are explicitly signed with expanded entitlements', () {
      expect(
        script,
        contains(r'sign_macos_app "$DEBUG_APP_PATH" "debug"'),
        reason:
            'Debug builds must not rely on Flutter ad-hoc signing because '
            'Keychain-backed secure storage needs real entitlements.',
      );
      expect(
        script,
        contains('expand_macos_entitlements'),
        reason:
            'The entitlements plist contains Xcode build-setting placeholders '
            'that must be expanded before manual codesign.',
      );
      expect(script, contains(r'$(AppIdentifierPrefix)'));
      expect(script, contains(r'$(CFBundleIdentifier)'));
    });

    test('release build output is signed before archiving', () {
      expect(
        script,
        contains(r'sign_macos_app "$RELEASE_APP_PATH" "release"'),
        reason:
            'The standalone release .app produced by flutter build macos '
            'should have the same keychain entitlements as the archived app.',
      );
    });

    test('signed app is verified for non-ad-hoc keychain entitlements', () {
      expect(
        script,
        contains('verify_macos_keychain_entitlements'),
        reason:
            'The script should fail fast if codesign produced an app that '
            'will hit OSStatus -34018 at runtime.',
      );
      expect(script, contains('Signature=adhoc'));
      expect(script, contains('TeamIdentifier=not set'));
      expect(script, contains('keychain-access-groups'));
    });
  });
}
