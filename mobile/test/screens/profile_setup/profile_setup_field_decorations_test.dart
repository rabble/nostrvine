// ABOUTME: Tests the shared profile-setup field border and hint resolvers
// ABOUTME: against both appearance palettes.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/screens/profile_setup/widgets/profile_setup_field_decorations.dart';

void main() {
  group('profileFieldBorderOf', () {
    Future<UnderlineInputBorder> resolve(
      WidgetTester tester, {
      ThemeData? theme,
    }) async {
      late UnderlineInputBorder border;
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                border = profileFieldBorderOf(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      return border;
    }

    testWidgets('uses an edge that survives the light background', (
      tester,
    ) async {
      final border = await resolve(tester, theme: VineTheme.lightTheme);

      // The fields have no fill, so the underline sits on the screen's
      // `surfaceContainerHigh`. `outlineMuted` is 1.00:1 against it.
      expect(border.borderSide.color, VineTheme.lightColors.outline);
      expect(
        border.borderSide.color,
        isNot(VineTheme.lightColors.outlineMuted),
      );
    });

    testWidgets('keeps the dark neutral edge in dark mode', (tester) async {
      final border = await resolve(tester, theme: VineTheme.theme);

      expect(border.borderSide.color, VineTheme.neutral10);
    });
  });
}
