import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('staging app identity', () {
    test('iOS debug build cannot replace the production app', () {
      final project = File(
        'ios/Runner.xcodeproj/project.pbxproj',
      ).readAsStringSync();

      expect(
        project,
        contains('PRODUCT_BUNDLE_IDENTIFIER = co.openvine.app.staging;'),
      );
      expect(
        project,
        contains(
          'PRODUCT_BUNDLE_IDENTIFIER = '
          'co.openvine.app.staging.NotificationServiceExtension;',
        ),
      );
      expect(
        project,
        contains(
          'PRODUCT_BUNDLE_IDENTIFIER = '
          'co.openvine.app.staging.CameraQuickActionWidget;',
        ),
      );
      expect(
        project,
        contains('APP_DISPLAY_NAME = "Divine Staging";'),
      );
      expect(
        File('ios/Runner/Info.plist').readAsStringSync(),
        contains(r'<string>$(APP_DISPLAY_NAME)</string>'),
      );
    });

    test('iOS debug signing does not reuse production capabilities', () {
      final project = File(
        'ios/Runner.xcodeproj/project.pbxproj',
      ).readAsStringSync();

      for (final path in const [
        'Runner/RunnerDebug.entitlements',
        'NotificationServiceExtension/NotificationServiceExtensionDebug.entitlements',
        'CameraQuickActionWidget/CameraQuickActionWidgetDebug.entitlements',
      ]) {
        expect(project, contains('CODE_SIGN_ENTITLEMENTS = $path;'));

        final entitlements = File('ios/$path').readAsStringSync();
        expect(entitlements, isNot(contains('group.co.openvine.app')));
        expect(entitlements, isNot(contains('associated-domains')));
        expect(entitlements, isNot(contains('aps-environment')));
      }
    });

    test('Android debug build cannot replace the production app', () {
      final gradle = File('android/app/build.gradle.kts').readAsStringSync();
      final firebaseConfig = File(
        'android/app/google-services.json',
      ).readAsStringSync();
      final debugManifest = File(
        'android/app/src/debug/AndroidManifest.xml',
      ).readAsStringSync();

      expect(gradle, contains('applicationIdSuffix = ".staging"'));
      expect(debugManifest, contains('android:label="Divine Staging"'));
      expect(firebaseConfig, contains('co.openvine.app.staging'));
      expect(
        firebaseConfig,
        contains('1:972941478875:android:56ca239b8c04ca6044b5fe'),
      );
    });

    test('debug builds use the registered staging Firebase apps', () {
      final project = File(
        'ios/Runner.xcodeproj/project.pbxproj',
      ).readAsStringSync();
      final stagingPlist = File(
        'ios/Runner/GoogleService-Info-Debug.plist',
      ).readAsStringSync();
      final firebaseOptions = File(
        'lib/firebase_options.dart',
      ).readAsStringSync();

      expect(project, contains('GoogleService-Info-Debug.plist'));
      expect(stagingPlist, contains('co.openvine.app.staging'));
      expect(
        stagingPlist,
        contains('1:972941478875:ios:2e044bbc68923a1844b5fe'),
      );
      expect(
        firebaseOptions,
        contains('kDebugMode ? androidStaging : android'),
      );
      expect(firebaseOptions, contains('kDebugMode ? iosStaging : ios'));
    });
  });
}
