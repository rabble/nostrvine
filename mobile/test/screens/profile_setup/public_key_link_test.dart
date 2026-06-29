// ABOUTME: Widget tests for PublicKeyLink in the profile-setup form.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/profile_setup/widgets/public_key_link.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group(PublicKeyLink, () {
    testWidgets('renders the localized public-key link label', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          home: const Scaffold(body: PublicKeyLink()),
        ),
      );
      expect(find.text(l10n.profileEditPublicKeyLink), findsOneWidget);
      expect(find.byType(TextButton), findsOneWidget);
    });
  });
}
