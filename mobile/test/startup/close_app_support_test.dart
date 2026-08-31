import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/startup/close_app_support.dart';

void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  group('platformCanCloseApp', () {
    for (final platform in TargetPlatform.values) {
      test('reports close support for $platform', () {
        debugDefaultTargetPlatformOverride = platform;

        expect(
          platformCanCloseApp,
          const {
            TargetPlatform.android,
            TargetPlatform.linux,
            TargetPlatform.macOS,
          }.contains(platform),
        );
      });
    }
  });
}
