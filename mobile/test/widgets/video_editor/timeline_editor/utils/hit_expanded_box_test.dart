// ABOUTME: Widget tests for HitExpandedBox.
// ABOUTME: Verifies expanded horizontal hit-test behavior.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/utils/hit_expanded_box.dart';

void main() {
  group(HitExpandedBox, () {
    testWidgets('applies expansion values to render object', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SizedBox(
            width: 60,
            height: 30,
            child: HitExpandedBox(
              expandLeft: 20,
              expandRight: 12,
              child: SizedBox.expand(),
            ),
          ),
        ),
      );

      final renderObject =
          tester.renderObject(find.byType(HitExpandedBox))
              as RenderHitExpandedBox;

      expect(renderObject.expandLeft, equals(20));
      expect(renderObject.expandRight, equals(12));
    });

    testWidgets('updates render object on rebuild', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SizedBox(
            width: 60,
            height: 30,
            child: HitExpandedBox(
              expandLeft: 10,
              expandRight: 5,
              child: SizedBox.expand(),
            ),
          ),
        ),
      );

      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SizedBox(
            width: 60,
            height: 30,
            child: HitExpandedBox(
              expandLeft: 30,
              expandRight: 18,
              child: SizedBox.expand(),
            ),
          ),
        ),
      );

      final renderObject =
          tester.renderObject(find.byType(HitExpandedBox))
              as RenderHitExpandedBox;

      expect(renderObject.expandLeft, equals(30));
      expect(renderObject.expandRight, equals(18));
    });
  });
}
