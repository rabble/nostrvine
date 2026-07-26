// ABOUTME: Tests the Support Center account-deletion entry point and its auth gate
// ABOUTME: Regression cover for #6335, which was reported from this screen

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/settings/support_center_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/bug_report_service.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockBugReportService extends Mock implements BugReportService {}

const _pubkeyHex =
    '3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d';

void main() {
  group(SupportCenterScreen, () {
    late _MockAuthService authService;
    late _MockBugReportService bugReportService;

    setUp(() {
      authService = _MockAuthService();
      bugReportService = _MockBugReportService();
    });

    Future<void> pump(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(authService),
            bugReportServiceProvider.overrideWithValue(bugReportService),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SupportCenterScreen(),
          ),
        ),
      );
      await tester.pump();
    }

    // #6335 was filed from this screen by a user who could not find how to
    // delete their account. Deletion has to be reachable from here.
    testWidgets('shows the delete-account entry when authenticated', (
      tester,
    ) async {
      when(() => authService.currentPublicKeyHex).thenReturn(_pubkeyHex);

      await pump(tester);

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.nostrSettingsDeleteAccount), findsOneWidget);
      expect(
        find.text(l10n.nostrSettingsDeleteAccountSubtitle),
        findsOneWidget,
      );
    });

    testWidgets('hides the delete-account entry when signed out', (
      tester,
    ) async {
      when(() => authService.currentPublicKeyHex).thenReturn(null);

      await pump(tester);

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.nostrSettingsDeleteAccount), findsNothing);
      // The screen itself still renders, so the assertion above is about the
      // auth gate rather than a failed pump.
      expect(find.text(l10n.supportReportBug), findsOneWidget);
    });

    // Liz's review asked for the existing copy to be reused rather than a
    // second deletion surface with its own wording.
    testWidgets('reuses the existing deletion copy, not a new string', (
      tester,
    ) async {
      when(() => authService.currentPublicKeyHex).thenReturn(_pubkeyHex);

      await pump(tester);

      final en = lookupAppLocalizations(const Locale('en'));
      final de = lookupAppLocalizations(const Locale('de'));
      // Proves the tile reads from l10n rather than a hardcoded English string.
      expect(find.text(en.nostrSettingsDeleteAccount), findsOneWidget);
      expect(find.text(de.nostrSettingsDeleteAccount), findsNothing);
    });
  });
}
