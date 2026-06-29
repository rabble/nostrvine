// ABOUTME: Widget tests for BioField in the profile-setup form.
// ABOUTME: Covers the character counter for user input and programmatic load.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/profile_setup/widgets/bio_field.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group(BioField, () {
    late TextEditingController controller;

    setUp(() => controller = TextEditingController());
    tearDown(() => controller.dispose());

    Future<void> pump(WidgetTester tester) {
      return tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          home: Scaffold(body: BioField(controller: controller)),
        ),
      );
    }

    testWidgets('renders the localized label and empty counter', (
      tester,
    ) async {
      await pump(tester);
      expect(find.text(l10n.profileSetupBioLabel), findsOneWidget);
      expect(find.text('0/360'), findsOneWidget);
    });

    testWidgets('counter tracks user input', (tester) async {
      await pump(tester);
      await tester.enterText(find.byType(TextFormField), 'hello');
      await tester.pump();
      expect(find.text('5/360'), findsOneWidget);
    });

    testWidgets('counter tracks programmatic controller changes (load)', (
      tester,
    ) async {
      await pump(tester);
      controller.text = 'loaded bio';
      await tester.pump();
      expect(find.text('${'loaded bio'.length}/360'), findsOneWidget);
    });

    testWidgets('re-subscribes the counter when the controller is swapped', (
      tester,
    ) async {
      await pump(tester);

      final swapped = TextEditingController(text: 'abc');
      addTearDown(swapped.dispose);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          home: Scaffold(body: BioField(controller: swapped)),
        ),
      );
      await tester.pump();
      expect(find.text('3/360'), findsOneWidget);

      // Mutating the new controller drives the counter only if the listener
      // was re-bound in didUpdateWidget.
      swapped.text = 'abcdef';
      await tester.pump();
      expect(find.text('6/360'), findsOneWidget);
    });
  });
}
