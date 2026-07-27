// ABOUTME: Tests the Support Center account-deletion entry point and its auth gate
// ABOUTME: Regression cover for #6335, which was reported from this screen

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/settings/support_center_screen.dart';
import 'package:openvine/services/account_deletion_service.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/bug_report_service.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockBugReportService extends Mock implements BugReportService {}

class _MockAccountDeletionService extends Mock
    implements AccountDeletionService {}

const _pubkeyHex =
    '3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d';

void main() {
  group(SupportCenterScreen, () {
    late _MockAuthService authService;
    late _MockBugReportService bugReportService;
    late _MockAccountDeletionService accountDeletionService;
    final en = lookupAppLocalizations(const Locale('en'));

    setUp(() {
      authService = _MockAuthService();
      bugReportService = _MockBugReportService();
      accountDeletionService = _MockAccountDeletionService();
      when(() => authService.currentPublicKeyHex).thenReturn(_pubkeyHex);
    });

    Future<void> pump(
      WidgetTester tester, {
      AuthState authState = AuthState.authenticated,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(authService),
            currentAuthStateProvider.overrideWith((ref) => authState),
            bugReportServiceProvider.overrideWithValue(bugReportService),
            accountDeletionServiceProvider.overrideWithValue(
              accountDeletionService,
            ),
            // Null repository: the profile lookup and the burnable-handle
            // lookup behind the confirmation gate both resolve to null
            // without touching the network.
            profileRepositoryProvider.overrideWithValue(null),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SupportCenterScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    // #6335 was filed from this screen by a user who could not find how to
    // delete their account. Deletion has to be reachable from here.
    testWidgets('shows the delete-account entry when authenticated', (
      tester,
    ) async {
      await pump(tester);

      expect(find.text(en.nostrSettingsDeleteAccount), findsOneWidget);
      expect(find.text(en.nostrSettingsDeleteAccountSubtitle), findsOneWidget);

      // Proves the row reads from l10n rather than a hardcoded English
      // string: the same key in another locale must not be on screen.
      final de = lookupAppLocalizations(const Locale('de'));
      expect(find.text(de.nostrSettingsDeleteAccount), findsNothing);
    });

    testWidgets('hides the delete-account entry when signed out', (
      tester,
    ) async {
      await pump(tester, authState: AuthState.unauthenticated);

      expect(find.text(en.nostrSettingsDeleteAccount), findsNothing);
      // The screen itself still renders, so the assertion above is about the
      // auth gate rather than a failed pump.
      expect(find.text(en.supportReportBug), findsOneWidget);
    });

    // The row existing is not the feature; reaching the confirmation gate is.
    testWidgets('opens the deletion confirmation gate when tapped', (
      tester,
    ) async {
      await pump(tester);

      await tester.tap(find.text(en.nostrSettingsDeleteAccount));
      await tester.pumpAndSettle();

      expect(find.text(en.deleteAccountFinalConfirmationTitle), findsOneWidget);
      expect(find.text(en.deleteAccountConfirmDeletePrompt), findsOneWidget);
    });
  });
}
