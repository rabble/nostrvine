import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/config/build_identity.dart';

void main() {
  test('uses iOS identity from dart defines with production defaults', () {
    const expectedBundleId = String.fromEnvironment(
      'EXPECTED_IOS_BUNDLE_ID',
      defaultValue: 'co.openvine.app',
    );
    const expectedPushAppIdentifier = String.fromEnvironment(
      'EXPECTED_PUSH_APP_IDENTIFIER',
      defaultValue: expectedBundleId,
    );
    const expectedFirebaseAppId = String.fromEnvironment(
      'EXPECTED_FIREBASE_IOS_APP_ID',
      defaultValue: '1:972941478875:ios:f61272b3cf485df244b5fe',
    );

    expect(BuildIdentity.iosBundleId, equals(expectedBundleId));
    expect(BuildIdentity.pushAppIdentifier, equals(expectedPushAppIdentifier));
    expect(BuildIdentity.firebaseIosAppId, equals(expectedFirebaseAppId));
  });
}
