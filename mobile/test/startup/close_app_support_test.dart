import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/startup/close_app_support.dart';

void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  for (final platform in TargetPlatform.values) {
    test('only Android can close the app ($platform)', () {
      debugDefaultTargetPlatformOverride = platform;

      expect(platformCanCloseApp, platform == TargetPlatform.android);
    });
  }
}
