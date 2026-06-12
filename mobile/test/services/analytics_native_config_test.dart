import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('native analytics config', () {
    test('disables Firebase automatic screen reporting on iOS', () {
      final plist = File('ios/Runner/Info.plist').readAsStringSync();

      expect(
        plist,
        matches(
          RegExp(
            r'<key>\s*FirebaseAutomaticScreenReportingEnabled\s*</key>\s*'
            r'<false\s*/>',
          ),
        ),
      );
    });

    test('disables Firebase automatic screen reporting on Android', () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      final applicationBlock = RegExp(
        r'<application\b[\s\S]*?</application>',
      ).firstMatch(manifest);

      expect(
        applicationBlock,
        isNotNull,
        reason: 'AndroidManifest.xml must contain an <application> block.',
      );

      final disablesAutomaticScreenReporting = RegExp(
        r'<meta-data\b'
        r'(?=[^>]*\bandroid:name\s*=\s*"google_analytics_automatic_screen_reporting_enabled")'
        r'(?=[^>]*\bandroid:value\s*=\s*"false")'
        r'[^>]*/\s*>',
        multiLine: true,
      );

      expect(
        applicationBlock!.group(0),
        matches(disablesAutomaticScreenReporting),
      );
    });
  });
}
