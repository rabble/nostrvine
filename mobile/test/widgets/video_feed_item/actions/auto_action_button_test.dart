// ABOUTME: Tests for the AutoActionButton widget.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/video_feed_item/actions/auto_action_button.dart';
import 'package:openvine/widgets/video_feed_item/actions/video_action_button.dart';

void main() {
  Widget buildSubject({
    required bool isEnabled,
    VoidCallback? onPressed,
    Locale? locale,
  }) {
    return MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: AutoActionButton(
          isEnabled: isEnabled,
          onPressed: onPressed ?? () {},
        ),
      ),
    );
  }

  group(AutoActionButton, () {
    testWidgets('renders a VideoActionButton with Auto caption', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(isEnabled: false));

      expect(find.byType(VideoActionButton), findsOneWidget);
      expect(find.text('Auto'), findsOneWidget);
    });

    testWidgets('uses enable semantics when disabled', (tester) async {
      await tester.pumpWidget(buildSubject(isEnabled: false));

      expect(find.bySemanticsLabel('Enable auto advance'), findsOneWidget);
    });

    testWidgets('uses disable semantics when enabled', (tester) async {
      await tester.pumpWidget(buildSubject(isEnabled: true));

      expect(find.bySemanticsLabel('Disable auto advance'), findsOneWidget);
    });

    testWidgets('renders translated semantics for Spanish locale', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(isEnabled: false, locale: const Locale('es')),
      );

      expect(
        find.bySemanticsLabel('Activar avance automático'),
        findsOneWidget,
      );
    });
  });
}
