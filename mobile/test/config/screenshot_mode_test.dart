// ABOUTME: Tests for screenshot-mode launch configuration parsing.
// ABOUTME: Covers native launch-env values without requiring dart-defines.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/config/screenshot_mode.dart';

void main() {
  group('ScreenshotMode.parseLaunchConfig', () {
    test('treats null and empty routes as no route override', () {
      expect(
        ScreenshotMode.parseLaunchConfig(
          route: null,
          seedClips: null,
        ).initialRoute,
        isNull,
      );
      expect(
        ScreenshotMode.parseLaunchConfig(
          route: '',
          seedClips: null,
        ).initialRoute,
        isNull,
      );
    });

    test('keeps a non-empty route override', () {
      expect(
        ScreenshotMode.parseLaunchConfig(
          route: '/video-recorder',
          seedClips: null,
        ).initialRoute,
        '/video-recorder',
      );
    });

    test('only enables clip seeding when the value is exactly 1', () {
      expect(
        ScreenshotMode.parseLaunchConfig(route: null, seedClips: '1').seedClips,
        isTrue,
      );
      expect(
        ScreenshotMode.parseLaunchConfig(
          route: null,
          seedClips: 'true',
        ).seedClips,
        isFalse,
      );
      expect(
        ScreenshotMode.parseLaunchConfig(route: null, seedClips: '').seedClips,
        isFalse,
      );
      expect(
        ScreenshotMode.parseLaunchConfig(
          route: null,
          seedClips: null,
        ).seedClips,
        isFalse,
      );
    });
  });
}
