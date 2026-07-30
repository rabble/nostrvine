// ABOUTME: Tests that the shared animation-picker chip marks its selected
// ABOUTME: state visibly in both appearance modes.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/animation_picker_components.dart';

void main() {
  group(AnimationPickerChip, () {
    Future<void> pumpChip(
      WidgetTester tester, {
      required bool selected,
      ThemeData? theme,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AnimationPickerChip(
              selected: selected,
              onTap: () {},
              semanticLabel: 'Curve 1',
              child: const SizedBox(width: 28, height: 18),
            ),
          ),
        ),
      );
    }

    BoxDecoration decorationOf(WidgetTester tester) =>
        tester.widget<DecoratedBox>(find.byType(DecoratedBox).first).decoration
            as BoxDecoration;

    testWidgets('marks the selected chip with a readable border in light '
        'mode', (tester) async {
      await pumpChip(tester, selected: true, theme: VineTheme.lightTheme);

      final decoration = decorationOf(tester);
      expect(decoration.color, VineTheme.lightColors.primaryContainer);
      // `outline` would sit at 1.37:1 against the unselected chip's border,
      // and the two fills are 1.001:1 apart, so nothing else marks the state.
      expect(
        (decoration.border! as Border).top.color,
        VineTheme.lightColors.onSurface,
      );
    });

    testWidgets(
      'leaves the unselected chip on the muted border in light mode',
      (
        tester,
      ) async {
        await pumpChip(tester, selected: false, theme: VineTheme.lightTheme);

        final decoration = decorationOf(tester);
        expect(decoration.color, VineTheme.lightColors.containerLow);
        expect(
          (decoration.border! as Border).top.color,
          VineTheme.lightColors.outlineMuted,
        );
      },
    );

    testWidgets('keeps the accent border in dark mode', (tester) async {
      await pumpChip(tester, selected: true, theme: VineTheme.theme);

      expect(
        (decorationOf(tester).border! as Border).top.color,
        VineTheme.primary,
      );
    });
  });
}
