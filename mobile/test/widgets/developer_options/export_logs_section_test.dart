// ABOUTME: Tests the developer-options Export Logs row and its outcome copy
// ABOUTME: Regression cover for #8113 and #8114, moved here from #8127

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/bug_report_service.dart';
import 'package:openvine/widgets/developer_options/export_logs_section.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockBugReportService extends Mock implements BugReportService {}

const _pubkeyHex =
    '3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d';

void main() {
  group(ExportLogsSection, () {
    late _MockAuthService authService;
    late _MockBugReportService bugReportService;
    final en = lookupAppLocalizations(const Locale('en'));

    setUp(() {
      authService = _MockAuthService();
      bugReportService = _MockBugReportService();
      when(() => authService.currentPublicKeyHex).thenReturn(_pubkeyHex);
    });

    Future<void> pump(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(authService),
            bugReportServiceProvider.overrideWithValue(bugReportService),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ListView(children: const [ExportLogsSection()]),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> tapExportLogs(
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
      await tester.tap(find.text(en.devOptionsExportLogs));
      await tester.pumpAndSettle();
    }

    group('renders', () {
      testWidgets('reads its title and subtitle from l10n', (tester) async {
        await pump(tester);

        expect(find.text(en.devOptionsExportLogs), findsOneWidget);
        expect(find.text(en.devOptionsExportLogsSubtitle), findsOneWidget);
      });
    });

    group('interactions', () {
      testWidgets('exports with the signed-in pubkey and this screen', (
        tester,
      ) async {
        await tapExportLogs(tester, const LogExportResult.shared());

        verify(
          () => bugReportService.exportLogsToFile(
            currentScreen: 'DeveloperOptionsScreen',
            userPubkey: _pubkeyHex,
            sharePositionOrigin: any(named: 'sharePositionOrigin'),
          ),
        ).called(1);
      });

      // #8113: share_plus returns `unavailable` on Android whenever it cannot
      // attach to an Activity, even though the sheet opened and the share may
      // well have completed. Reporting that as a failure is what told the
      // user log export was broken.
      testWidgets('does not report failure when the outcome is unknown', (
        tester,
      ) async {
        await tapExportLogs(tester, const LogExportResult.unconfirmed());

        expect(find.text(en.supportExportLogsFailed), findsNothing);
        expect(find.text(en.supportExportLogsUnconfirmed), findsOneWidget);
      });

      testWidgets('stays silent when the user backs out', (tester) async {
        await tapExportLogs(tester, const LogExportResult.cancelled());

        expect(find.text(en.supportExportLogsFailed), findsNothing);
        expect(find.text(en.supportExportLogsUnconfirmed), findsNothing);
        expect(find.text(en.supportNoLogsToExport), findsNothing);
      });

      // #8114: the buffer is memory-only, so a crash or force-quit empties
      // it — exactly when the user needs to be told to reproduce first
      // rather than conclude export is broken.
      testWidgets('explains an empty buffer rather than failing', (
        tester,
      ) async {
        await tapExportLogs(tester, const LogExportResult.noLogs());

        expect(find.text(en.supportNoLogsToExport), findsOneWidget);
        expect(find.text(en.supportExportLogsFailed), findsNothing);
      });

      testWidgets('still reports a real failure', (tester) async {
        await tapExportLogs(tester, const LogExportResult.failed());

        expect(find.text(en.supportExportLogsFailed), findsOneWidget);
      });

      testWidgets('offers to reveal a saved file', (tester) async {
        when(
          () => bugReportService.revealExportedFile(any()),
        ).thenAnswer((_) async {});

        await tapExportLogs(
          tester,
          const LogExportResult.saved('/tmp/divine_logs.txt'),
        );

        expect(
          find.text(en.supportLogsSavedTo('/tmp/divine_logs.txt')),
          findsOneWidget,
        );

        await tester.tap(find.text(en.supportRevealLogsAction));
        await tester.pumpAndSettle();

        verify(
          () => bugReportService.revealExportedFile('/tmp/divine_logs.txt'),
        ).called(1);
      });
    });
  });
}
