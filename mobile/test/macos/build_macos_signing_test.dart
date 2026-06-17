import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('build_macos.sh signing guard', () {
    late String script;

    setUpAll(() {
      script = File('build_macos.sh').readAsStringSync();
    });

    test('debug builds use Xcode signing and provisioning', () {
      expect(
        script,
        contains('xcodebuild_signed_macos_app "debug"'),
        reason:
            'Debug builds must not rely on Flutter ad-hoc signing or bare '
            'manual codesign because Keychain-backed secure storage needs '
            'real entitlements and a matching provisioning profile.',
      );
      expect(
        script,
        contains('-allowProvisioningUpdates'),
        reason:
            'Xcode needs permission to create or refresh the Mac team '
            'provisioning profile for restricted entitlements.',
      );
      expect(script, contains('CODE_SIGNING_ALLOWED=YES'));
      expect(script, contains('CODE_SIGNING_REQUIRED=YES'));
      expect(script, contains(r'SYMROOT="$symroot"'));
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

    test('xcode signed debug app is verified for embedded provisioning', () {
      expect(
        script,
        contains(r'verify_macos_embedded_provisioning_profile "$app_path"'),
        reason:
            'A valid code signature alone is not enough. macOS AMFI rejects '
            'restricted entitlements at launch when no matching profile is '
            'embedded.',
      );
      expect(script, contains('embedded.provisionprofile'));
      expect(script, contains('embedded.mobileprovision'));
      expect(script, contains('Restricted entitlements will be rejected'));
    });
  });
}
