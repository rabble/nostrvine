// ABOUTME: Unit tests for the profile image-picker platform routing helper.

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/screens/profile_setup/widgets/profile_image_picker.dart';

void main() {
  group('isDesktopImagePickerPlatform', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('returns false for mobile platforms', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(isDesktopImagePickerPlatform(), isFalse);
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(isDesktopImagePickerPlatform(), isFalse);
    });

    test('returns true for desktop platforms', () {
      for (final platform in const [
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.linux,
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        expect(isDesktopImagePickerPlatform(), isTrue, reason: '$platform');
      }
    });
  });
}
