import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(VineTheme, () {
    group('switchTheme', () {
      late SwitchThemeData switchTheme;

      setUp(() {
        switchTheme = VineTheme.theme.switchTheme;
      });

      test('thumbColor resolves to onSurfaceDisabled when not selected', () {
        final color = switchTheme.thumbColor!.resolve(<WidgetState>{});
        expect(color, equals(VineTheme.onSurfaceDisabled));
      });

      test('trackColor resolves to surfaceContainer when not selected', () {
        final color = switchTheme.trackColor!.resolve(<WidgetState>{});
        expect(color, equals(VineTheme.surfaceContainer));
      });

      test(
        'trackOutlineColor resolves to outlineVariant when not selected',
        () {
          final color = switchTheme.trackOutlineColor!.resolve(<WidgetState>{});
          expect(color, equals(VineTheme.outlineVariant));
        },
      );
    });
  });
}
