// ABOUTME: Widget tests for the special profile checkmark badge.
// ABOUTME: Covers the badge's accessible label and explanation dialog.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/special_profile_checkmark.dart';

Widget _buildSubject() {
  // The explanation sheet is pause-aware, so it reads the overlay-visibility
  // notifier off the enclosing ProviderScope.
  return const ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Center(child: SpecialProfileCheckmark())),
    ),
  );
}

void main() {
  testWidgets('renders an accessible tappable checkmark', (tester) async {
    await tester.pumpWidget(_buildSubject());
    final l10n = lookupAppLocalizations(const Locale('en'));

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.button == true &&
            widget.properties.label == l10n.profileBadgeCheckmarkTitle &&
            widget.properties.hint == l10n.profileBadgeCheckmarkSemanticHint,
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (w) => w is DivineIcon && w.icon == DivineIconName.check,
      ),
      findsOneWidget,
    );
  });

  testWidgets('explains checkmark meaning when tapped', (tester) async {
    await tester.pumpWidget(_buildSubject());
    final l10n = lookupAppLocalizations(const Locale('en'));

    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is DivineIcon && w.icon == DivineIconName.check,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(l10n.profileBadgeCheckmarkTitle), findsWidgets);
    expect(find.text(l10n.profileBadgeCheckmarkBody), findsOneWidget);
    expect(find.text(l10n.commonClose), findsOneWidget);
  });
}
