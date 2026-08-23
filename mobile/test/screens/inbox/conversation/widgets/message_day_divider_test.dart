// ABOUTME: Widget tests for MessageDayDivider — the DM timeline's
// ABOUTME: centered "Today" / date pill between calendar days.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/inbox/conversation/widgets/message_day_divider.dart';

void main() {
  Widget buildSubject(int unixSeconds) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: MessageDayDivider(unixSeconds: unixSeconds)),
    );
  }

  group(MessageDayDivider, () {
    testWidgets('renders localized "Today" for a same-day timestamp', (
      tester,
    ) async {
      final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await tester.pumpWidget(buildSubject(nowSeconds));

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.timeToday), findsOneWidget);
    });

    testWidgets('renders the redesign pill: surfaceContainerHigh, radius 8', (
      tester,
    ) async {
      final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await tester.pumpWidget(buildSubject(nowSeconds));

      final pill = tester.widget<Container>(
        find.byWidgetPredicate(
          (w) => w is Container && w.decoration is BoxDecoration,
        ),
      );
      final decoration = pill.decoration! as BoxDecoration;
      expect(decoration.color, VineTheme.surfaceContainerHigh);
      expect(decoration.borderRadius, BorderRadius.circular(8));
    });
  });
}
