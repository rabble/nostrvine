import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('macOS media_kit embed verification', () {
    test('codesign build phase fails fast when Mpv.framework is missing', () {
      final projectFile = File('macos/Runner.xcodeproj/project.pbxproj');
      final contents = projectFile.readAsStringSync();

      expect(
        contents,
        contains('Mpv.framework/Mpv'),
        reason:
            'The Runner build phase should verify that Mpv.framework was '
            'embedded before macOS app launch.',
      );
    });

    test('Podfile keeps the media_kit verification script in sync', () {
      final podfile = File('macos/Podfile');
      final contents = podfile.readAsStringSync();

      expect(
        contents,
        contains('Mpv.framework/Mpv'),
        reason:
            'Podfile post_install should write the same Mpv.framework '
            'verification script for fresh CocoaPods installs.',
      );
    });
  });
}
