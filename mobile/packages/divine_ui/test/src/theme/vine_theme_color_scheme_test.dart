import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(VineTheme, () {
    // Material 3 ignores `primarySwatch`. Without an explicit `colorScheme`
    // the theme falls back to the M3 baseline, whose primary is a purple that
    // leaks onto every widget defaulting to `colorScheme.primary` — the bug
    // that surfaced as purple RefreshIndicators.
    group('colorScheme', () {
      test('dark primary is the brand green, not the Material 3 baseline', () {
        expect(VineTheme.theme.colorScheme.primary, VineTheme.vineGreen);
        expect(VineTheme.theme.colorScheme.onPrimary, VineTheme.onPrimary);
      });

      test('light primary is the brand green too', () {
        expect(VineTheme.lightTheme.colorScheme.primary, VineTheme.vineGreen);
        expect(VineTheme.lightTheme.colorScheme.onPrimary, VineTheme.onPrimary);
      });

      test('brightness still follows the requested mode', () {
        expect(VineTheme.theme.colorScheme.brightness, Brightness.dark);
        expect(VineTheme.lightTheme.colorScheme.brightness, Brightness.light);
      });
    });

    group('progressIndicatorTheme', () {
      test('bare progress indicators paint green in both modes', () {
        expect(
          VineTheme.theme.progressIndicatorTheme.color,
          VineTheme.vineGreen,
        );
        expect(
          VineTheme.lightTheme.progressIndicatorTheme.color,
          VineTheme.vineGreen,
        );
      });
    });
  });
}
