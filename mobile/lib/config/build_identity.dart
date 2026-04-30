// ABOUTME: Centralizes build-time app identity for production and QA slot builds.
// ABOUTME: Values default to production and can be overridden by CI dart-defines.

class BuildIdentity {
  static const iosBundleId = String.fromEnvironment(
    'IOS_BUNDLE_ID',
    defaultValue: 'co.openvine.app',
  );

  static const pushAppIdentifier = String.fromEnvironment(
    'PUSH_APP_IDENTIFIER',
    defaultValue: iosBundleId,
  );

  static const firebaseIosAppId = String.fromEnvironment(
    'FIREBASE_IOS_APP_ID',
    defaultValue: '1:972941478875:ios:f61272b3cf485df244b5fe',
  );
}
