// ABOUTME: Tests the Support Center resource links and account-deletion auth gate
// ABOUTME: Regression cover for #6335, which was reported from this screen

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/settings/support_center_screen.dart';
import 'package:openvine/services/account_deletion_service.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/bug_report_service.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../../helpers/url_launcher_test_double.dart';

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
      Locale locale = const Locale('en'),
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
            profileReadRepositoryProvider.overrideWithValue(null),
          ],
          child: MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const SupportCenterScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    // The list is taller than the 600px test viewport, and ListView does not
    // build rows it cannot show. Anything below the fold has to be scrolled
    // to before it can be found — which is what a real user does too.
    Future<void> scrollToBottom(WidgetTester tester) async {
      await tester.drag(find.byType(ListView), const Offset(0, -2000));
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
    });

    // Rendering in another locale is what proves the row reads from l10n.
    // Asserting the German string is absent from an English render passes
    // whether or not the row is hardcoded.
    testWidgets('translates the delete-account entry with the locale', (
      tester,
    ) async {
      await pump(tester, locale: const Locale('de'));

      final de = lookupAppLocalizations(const Locale('de'));
      expect(find.text(de.nostrSettingsDeleteAccount), findsOneWidget);
      expect(find.text(de.nostrSettingsDeleteAccountSubtitle), findsOneWidget);
      expect(find.text(en.nostrSettingsDeleteAccount), findsNothing);
    });

    // #6335 is a discoverability bug: the row is on this screen because a
    // user could not find deletion. Two rows added above it in #7852 pushed
    // it off the smallest phone Divine still supports, so pin the viewport.
    testWidgets('keeps the delete-account entry on screen at 375x667', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await pump(tester);

      final row = find.text(en.nostrSettingsDeleteAccount);
      expect(row, findsOneWidget);
      expect(tester.getRect(row).bottom, lessThan(667));
    });

    testWidgets('hides the delete-account entry when signed out', (
      tester,
    ) async {
      await pump(tester, authState: AuthState.unauthenticated);
      // Scroll first so "not found" means absent, not merely below the fold.
      await scrollToBottom(tester);

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

    group('family and kids resource links', () {
      // Placement is the requirement, not just presence: both rows sit
      // between FAQ and ProofMode.
      testWidgets('render between the FAQ and ProofMode rows', (tester) async {
        // Tall enough that every row is laid out at once: ListView does not
        // build what it cannot show, and scrolling to reach ProofMode would
        // push FAQ back off the top.
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await pump(tester);

        double topOf(String label) => tester.getTopLeft(find.text(label)).dy;

        expect(topOf(en.supportFaq), lessThan(topOf(en.supportFamily)));
        expect(topOf(en.supportFamily), lessThan(topOf(en.supportKids)));
        expect(topOf(en.supportKids), lessThan(topOf(en.supportProofMode)));
      });

      testWidgets('read their subtitles from l10n', (tester) async {
        await pump(tester);

        expect(find.text(en.supportFamilySubtitle), findsOneWidget);
        expect(find.text(en.supportKidsSubtitle), findsOneWidget);
      });

      // Rendering the same screen in another locale is what proves the
      // subtitles come from l10n: a hardcoded English literal would not
      // change with the locale, and asserting the German string is absent
      // from an English render would pass either way.
      testWidgets('translate their subtitles when the locale changes', (
        tester,
      ) async {
        await pump(tester, locale: const Locale('de'));

        final de = lookupAppLocalizations(const Locale('de'));
        expect(find.text(de.supportFamilySubtitle), findsOneWidget);
        expect(find.text(de.supportKidsSubtitle), findsOneWidget);
        expect(find.text(en.supportFamilySubtitle), findsNothing);
        expect(find.text(en.supportKidsSubtitle), findsNothing);
      });

      testWidgets('open the Divine Family page', (tester) async {
        final launcher = UrlLauncherTestDouble();
        final originalPlatform = UrlLauncherPlatform.instance;
        UrlLauncherPlatform.instance = launcher;
        addTearDown(() => UrlLauncherPlatform.instance = originalPlatform);

        await pump(tester);
        await tester.tap(find.text(en.supportFamily));
        await tester.pumpAndSettle();

        expect(
          launcher.launched.map((call) => call.url),
          equals([AppConstants.familyResourcesUrl]),
        );
      });

      testWidgets('open the Divine Kids page', (tester) async {
        final launcher = UrlLauncherTestDouble();
        final originalPlatform = UrlLauncherPlatform.instance;
        UrlLauncherPlatform.instance = launcher;
        addTearDown(() => UrlLauncherPlatform.instance = originalPlatform);

        await pump(tester);
        await tester.tap(find.text(en.supportKids));
        await tester.pumpAndSettle();

        expect(
          launcher.launched.map((call) => call.url),
          equals([AppConstants.kidsPolicyUrl]),
        );
      });
    });
  });
}
