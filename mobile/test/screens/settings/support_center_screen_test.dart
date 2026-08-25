// ABOUTME: Tests the Support Center resource links and account-deletion auth gate
// ABOUTME: Regression cover for #6335, which was reported from this screen

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:openvine/services/support_email_composer.dart';
import 'package:openvine/services/zendesk_support_service.dart';
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
      ZendeskSupportService.resetForTesting();
      authService = _MockAuthService();
      bugReportService = _MockBugReportService();
      accountDeletionService = _MockAccountDeletionService();
      when(() => authService.currentPublicKeyHex).thenReturn(_pubkeyHex);
    });

    tearDown(ZendeskSupportService.resetForTesting);

    Future<void> pump(
      WidgetTester tester, {
      AuthState authState = AuthState.authenticated,
      Locale locale = const Locale('en'),
      SupportEmailCompose? composeEmail,
      Future<bool> Function()? openZendeskSupport,
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
            home: SupportCenterScreen(
              composeEmail: composeEmail,
              openZendeskSupport: openZendeskSupport,
            ),
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
    // #8112: the share sheet's Copy action copies EXTRA_TEXT on Android and
    // never the attached file, so copying needs its own path. These pin the
    // outcomes a user actually sees.
    group('copy logs', () {
      testWidgets('puts the built log text on the clipboard', (tester) async {
        const logText = 'OpenVine Comprehensive Log Export\nupload stalled';
        when(
          () => bugReportService.buildLogClipboardText(
            currentScreen: any(named: 'currentScreen'),
            userPubkey: any(named: 'userPubkey'),
          ),
        ).thenAnswer((_) async => logText);

        final clipboardWrites = <String>[];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              clipboardWrites.add((call.arguments as Map)['text'] as String);
            }
            if (call.method == 'Clipboard.getData') {
              return <String, dynamic>{'text': clipboardWrites.last};
            }
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );

        await pump(tester);
        await tester.tap(find.text(en.supportCopyLogs));
        await tester.pumpAndSettle();

        expect(clipboardWrites, equals([logText]));
        expect(find.text(en.supportLogsCopied), findsOneWidget);
      });

      // #8114: an empty buffer is the user's to fix by reproducing without
      // restarting, so it must not read as a generic failure.
      testWidgets('explains an empty buffer instead of reporting failure', (
        tester,
      ) async {
        when(
          () => bugReportService.buildLogClipboardText(
            currentScreen: any(named: 'currentScreen'),
            userPubkey: any(named: 'userPubkey'),
          ),
        ).thenAnswer((_) async => null);

        await pump(tester);
        await tester.tap(find.text(en.supportCopyLogs));
        await tester.pumpAndSettle();

        expect(find.text(en.supportNoLogsToExport), findsOneWidget);
        expect(find.text(en.supportCopyLogsFailed), findsNothing);
      });
    });

    group('save logs', () {
      Future<void> tapSaveLogs(
        WidgetTester tester,
        LogExportResult result,
      ) async {
        when(
          () => bugReportService.exportLogsToFile(
            currentScreen: any(named: 'currentScreen'),
            userPubkey: any(named: 'userPubkey'),
            sharePositionOrigin: any(named: 'sharePositionOrigin'),
          ),
        ).thenAnswer((_) async => result);

        await pump(tester);
        await tester.tap(find.text(en.supportSaveLogs));
        await tester.pumpAndSettle();
      }

      // #8113: share_plus returns `unavailable` on Android whenever it cannot
      // attach to an Activity, even though the sheet opened and the share may
      // well have completed. Reporting that as a failure is what told the
      // user log export was broken.
      testWidgets('does not report failure when the outcome is unknown', (
        tester,
      ) async {
        await tapSaveLogs(tester, const LogExportResult.unconfirmed());

        expect(find.text(en.supportExportLogsFailed), findsNothing);
        expect(find.text(en.supportExportLogsUnconfirmed), findsOneWidget);
      });

      testWidgets('stays silent when the user backs out', (tester) async {
        await tapSaveLogs(tester, const LogExportResult.cancelled());

        expect(find.text(en.supportExportLogsFailed), findsNothing);
        expect(find.text(en.supportExportLogsUnconfirmed), findsNothing);
        expect(find.text(en.supportNoLogsToExport), findsNothing);
      });

      testWidgets('explains an empty buffer rather than failing', (
        tester,
      ) async {
        await tapSaveLogs(tester, const LogExportResult.noLogs());

        expect(find.text(en.supportNoLogsToExport), findsOneWidget);
        expect(find.text(en.supportExportLogsFailed), findsNothing);
      });

      testWidgets('still reports a real failure', (tester) async {
        await tapSaveLogs(tester, const LogExportResult.failed());

        expect(find.text(en.supportExportLogsFailed), findsOneWidget);
      });
    });

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
      expect(find.text(en.supportTitle), findsOneWidget);
    });

    testWidgets('hides authenticated support forms when signed out', (
      tester,
    ) async {
      await pump(tester, authState: AuthState.unauthenticated);
      await scrollToBottom(tester);

      expect(find.text(en.supportReportBug), findsNothing);
      expect(find.text(en.supportRequestFeature), findsNothing);
    });

    testWidgets('opens email support when Zendesk is unavailable', (
      tester,
    ) async {
      String? capturedToEmail;
      String? capturedSubject;
      String? capturedBody;
      await pump(
        tester,
        authState: AuthState.unauthenticated,
        composeEmail:
            ({
              required String toEmail,
              required String subject,
              required String body,
              Rect? sharePositionOrigin,
            }) async {
              capturedToEmail = toEmail;
              capturedSubject = subject;
              capturedBody = body;
            },
      );

      await tester.tap(find.text(en.supportContactSupport));
      await tester.pumpAndSettle();

      expect(capturedToEmail, AppConstants.supportEmail);
      expect(capturedSubject, en.supportContactSupport);
      expect(capturedBody, contains(en.supportChatNotAvailable));
      expect(capturedBody, contains(en.supportContactSupportSubtitle));
    });

    testWidgets('falls back to email when Zendesk cannot open messages', (
      tester,
    ) async {
      var composed = false;
      await pump(
        tester,
        authState: AuthState.unauthenticated,
        openZendeskSupport: () async => false,
        composeEmail:
            ({
              required String toEmail,
              required String subject,
              required String body,
              Rect? sharePositionOrigin,
            }) async {
              composed = true;
            },
      );

      await tester.tap(find.text(en.supportContactSupport));
      await tester.pumpAndSettle();

      expect(composed, true);
    });

    testWidgets('shows an error when email support cannot open', (
      tester,
    ) async {
      await pump(
        tester,
        authState: AuthState.unauthenticated,
        composeEmail:
            ({
              required String toEmail,
              required String subject,
              required String body,
              Rect? sharePositionOrigin,
            }) async => throw Exception('compose failed'),
      );

      await tester.tap(find.text(en.supportContactSupport));
      await tester.pumpAndSettle();

      expect(
        find.text(en.authCouldNotOpenEmail(AppConstants.supportEmail)),
        findsOneWidget,
      );
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
        await scrollToBottom(tester);

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
        await scrollToBottom(tester);
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
        await scrollToBottom(tester);
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
        await scrollToBottom(tester);
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
