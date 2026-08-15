// ABOUTME: Pins the appearance default that unset and invalid values resolve to.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/features/appearance/models/appearance_mode.dart';

void main() {
  group(AppearanceMode, () {
    test('defaults to Dark', () {
      // Every other appearance test asserts against defaultAppearanceMode, so
      // this is the only place that fails if the default flips back to System
      // or Light — the exact regression #7545 is about.
      expect(defaultAppearanceMode, AppearanceMode.dark);
    });
  });
}
