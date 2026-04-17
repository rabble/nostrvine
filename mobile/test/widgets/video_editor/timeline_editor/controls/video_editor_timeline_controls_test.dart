// ABOUTME: Widget tests for VideoEditorTimelineControls.
// ABOUTME: Verifies optional buttons and callback invocation.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_timeline_controls.dart';

void main() {
  group(VideoEditorTimelineControls, () {
    testWidgets('renders done and configured optional controls', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: VideoEditorTimelineControls(
              onDelete: () {},
              onDuplicated: () {},
              onDone: () {},
            ),
          ),
        ),
      );

      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('Duplicate'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('Edit'), findsNothing);
      expect(find.text('Split'), findsNothing);
    });

    testWidgets('triggers button callbacks', (tester) async {
      var doneCount = 0;
      var deleteCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: VideoEditorTimelineControls(
              onDelete: () => deleteCount++,
              onDone: () => doneCount++,
            ),
          ),
        ),
      );

      final buttons = find.byType(DivineIconButton);
      expect(buttons, findsNWidgets(2));

      await tester.tap(buttons.first);
      await tester.tap(buttons.last);
      await tester.pump();

      expect(deleteCount, equals(1));
      expect(doneCount, equals(1));
    });
  });
}
