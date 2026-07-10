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

    testWidgets('renders the transform button only when onTransform is set', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(const Locale('en'));

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: VideoEditorTimelineControls(
              onTransform: () {},
              onDone: () {},
            ),
          ),
        ),
      );

      expect(find.text(l10n.videoEditorTransformLabel), findsOneWidget);
    });

    testWidgets('invokes onTransform when the transform button is tapped', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(const Locale('en'));
      var transformCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: VideoEditorTimelineControls(
              onTransform: () => transformCount++,
              onDone: () {},
            ),
          ),
        ),
      );

      await tester.tap(
        find.bySemanticsLabel(
          l10n.videoEditorTransformSelectedClipSemanticLabel,
        ),
      );
      await tester.pump();

      expect(transformCount, equals(1));
    });

    testWidgets('keeps Split mounted but inert while isSplitting', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(const Locale('en'));
      var splitCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: VideoEditorTimelineControls(
              onSplit: () => splitCount++,
              isSplitting: true,
              onDone: () {},
            ),
          ),
        ),
      );

      // Still on screen (disabled, not removed)...
      expect(find.text(l10n.videoEditorSplitLabel), findsOneWidget);
      // ...but tapping it does nothing.
      await tester.tap(
        find.bySemanticsLabel(l10n.videoEditorSplitSelectedClipSemanticLabel),
      );
      await tester.pump();
      expect(splitCount, equals(0));
    });

    testWidgets('invokes onSplit when not splitting', (tester) async {
      final l10n = lookupAppLocalizations(const Locale('en'));
      var splitCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: VideoEditorTimelineControls(
              onSplit: () => splitCount++,
              onDone: () {},
            ),
          ),
        ),
      );

      await tester.tap(
        find.bySemanticsLabel(l10n.videoEditorSplitSelectedClipSemanticLabel),
      );
      await tester.pump();
      expect(splitCount, equals(1));
    });

    testWidgets('keeps Speed mounted but inert while isExtractingAudio', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(const Locale('en'));
      var speedCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: VideoEditorTimelineControls(
              onSpeed: () => speedCount++,
              isExtractingAudio: true,
              onDone: () {},
            ),
          ),
        ),
      );

      expect(find.text(l10n.videoEditorSpeedLabel), findsOneWidget);
      await tester.tap(
        find.bySemanticsLabel(l10n.videoEditorSetClipSpeedSemanticLabel),
      );
      await tester.pump();
      expect(speedCount, equals(0));
    });

    testWidgets('invokes onSpeed when not extracting audio', (tester) async {
      final l10n = lookupAppLocalizations(const Locale('en'));
      var speedCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: VideoEditorTimelineControls(
              onSpeed: () => speedCount++,
              onDone: () {},
            ),
          ),
        ),
      );

      await tester.tap(
        find.bySemanticsLabel(l10n.videoEditorSetClipSpeedSemanticLabel),
      );
      await tester.pump();
      expect(speedCount, equals(1));
    });
  });
}
