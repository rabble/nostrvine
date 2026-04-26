// ABOUTME: Widget tests for VideoEditorToolbar.
// ABOUTME: Verifies close/done actions and center content rendering.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/video_editor/video_editor_toolbar.dart';

void main() {
  group(VideoEditorToolbar, () {
    Widget buildWidget({
      required VoidCallback onClose,
      VoidCallback? onDone,
      Widget? center,
    }) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: VideoEditorToolbar(
            onClose: onClose,
            onDone: onDone,
            center: center,
          ),
        ),
      );
    }

    testWidgets('renders close and done semantics', (tester) async {
      await tester.pumpWidget(buildWidget(onClose: () {}, onDone: () {}));

      expect(find.bySemanticsLabel('Close'), findsOneWidget);
      expect(find.bySemanticsLabel('Done'), findsOneWidget);
    });

    testWidgets('calls onClose when close button is tapped', (tester) async {
      var closeTapped = false;

      await tester.pumpWidget(
        buildWidget(onClose: () => closeTapped = true, onDone: () {}),
      );

      await tester.tap(find.bySemanticsLabel('Close'));
      await tester.pump();

      expect(closeTapped, isTrue);
    });

    testWidgets('calls onDone when done button is tapped', (tester) async {
      var doneTapped = false;

      await tester.pumpWidget(
        buildWidget(onClose: () {}, onDone: () => doneTapped = true),
      );

      await tester.tap(find.bySemanticsLabel('Done'));
      await tester.pump();

      expect(doneTapped, isTrue);
    });

    testWidgets('renders center widget when provided', (tester) async {
      await tester.pumpWidget(
        buildWidget(
          onClose: () {},
          onDone: () {},
          center: const Text('Center Content'),
        ),
      );

      expect(find.text('Center Content'), findsOneWidget);
    });
  });
}
