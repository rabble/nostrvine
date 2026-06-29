// ABOUTME: Widget tests for DisplayNameField in the profile-setup form.
// ABOUTME: Covers label rendering and controller binding.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/profile_setup/widgets/display_name_field.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group(DisplayNameField, () {
    late TextEditingController controller;
    late FocusNode focusNode;

    setUp(() {
      controller = TextEditingController();
      focusNode = FocusNode();
    });

    tearDown(() {
      controller.dispose();
      focusNode.dispose();
    });

    Future<void> pump(WidgetTester tester) {
      return tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          home: Scaffold(
            body: DisplayNameField(
              controller: controller,
              focusNode: focusNode,
            ),
          ),
        ),
      );
    }

    testWidgets('renders the localized label and hint', (tester) async {
      await pump(tester);
      expect(find.text(l10n.profileSetupDisplayNameLabel), findsOneWidget);
      expect(find.text(l10n.profileSetupDisplayNameHint), findsOneWidget);
    });

    testWidgets('typing updates the bound controller', (tester) async {
      await pump(tester);
      await tester.enterText(find.byType(TextFormField), 'Alice');
      expect(controller.text, 'Alice');
    });
  });
}
