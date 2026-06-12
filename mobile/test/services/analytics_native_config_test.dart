import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('native analytics config', () {
    test('disables Firebase automatic screen reporting on iOS', () {
      final plist = File('ios/Runner/Info.plist').readAsStringSync();

      expect(plist, contains('FirebaseAutomaticScreenReportingEnabled'));
      expect(plist, contains('<false/>'));
    });

    test('disables Firebase automatic screen reporting on Android', () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();

      expect(
        manifest,
        contains('google_analytics_automatic_screen_reporting_enabled'),
      );
      expect(manifest, contains('android:value="false"'));
    });
  });
}
