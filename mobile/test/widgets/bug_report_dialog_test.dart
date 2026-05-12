// ABOUTME: Widget tests for BugReportDialog user interface
// ABOUTME: Tests UI rendering, user interaction, and form validation

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show BugReportData;
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/services/bug_report_service.dart';
import 'package:openvine/widgets/bug_report_dialog.dart';

class _MockBugReportService extends Mock implements BugReportService {}

class _FakeBugReportData extends Fake implements BugReportData {}

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  setUpAll(() {
    registerFallbackValue(_FakeBugReportData());
  });

  group('BugReportDialog', () {
    late _MockBugReportService mockBugReportService;

    setUp(() {
      mockBugReportService = _MockBugReportService();
    });

    testWidgets('should display title and form fields', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BugReportDialog(bugReportService: mockBugReportService),
          ),
        ),
      );

      // Verify title
      expect(find.text(l10n.supportReportBug), findsOneWidget);

      // Verify all 4 text fields exist
      expect(find.byType(TextField), findsNWidgets(4));

      // Verify labels
      expect(find.text(l10n.supportSubjectRequiredLabel), findsOneWidget);
      expect(find.text(l10n.bugReportDescriptionRequiredLabel), findsOneWidget);
      expect(find.text(l10n.bugReportStepsLabel), findsOneWidget);
      expect(find.text(l10n.bugReportExpectedBehaviorLabel), findsOneWidget);
    });

    testWidgets('should have Send and Cancel buttons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BugReportDialog(bugReportService: mockBugReportService),
          ),
        ),
      );

      expect(find.text(l10n.bugReportSendReport), findsOneWidget);
      expect(find.text(l10n.commonCancel), findsOneWidget);
    });

    testWidgets('should disable Send button when required fields are empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BugReportDialog(bugReportService: mockBugReportService),
          ),
        ),
      );

      final sendButton = find.text(l10n.bugReportSendReport);
      expect(sendButton, findsOneWidget);

      // Button should be disabled when required fields are empty
      final button = tester.widget<ElevatedButton>(
        find.ancestor(of: sendButton, matching: find.byType(ElevatedButton)),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('should enable Send button when required fields are filled', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BugReportDialog(bugReportService: mockBugReportService),
          ),
        ),
      );

      // Fill in Subject (first TextField)
      await tester.enterText(find.byType(TextField).at(0), 'App crashed');
      await tester.pump();

      // Fill in Description (second TextField)
      await tester.enterText(
        find.byType(TextField).at(1),
        'App crashed on startup',
      );
      await tester.pump();

      final sendButton = find.text(l10n.bugReportSendReport);
      final button = tester.widget<ElevatedButton>(
        find.ancestor(of: sendButton, matching: find.byType(ElevatedButton)),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('should call collectDiagnostics on submit', (tester) async {
      final testReportData = BugReportData(
        reportId: 'test-123',
        userDescription: 'App crashed on startup',
        deviceInfo: {},
        appVersion: '1.0.0',
        recentLogs: [],
        errorCounts: {},
        timestamp: DateTime.now(),
      );

      when(
        () => mockBugReportService.collectDiagnostics(
          userDescription: any(named: 'userDescription'),
          currentScreen: any(named: 'currentScreen'),
          userPubkey: any(named: 'userPubkey'),
          additionalContext: any(named: 'additionalContext'),
        ),
      ).thenAnswer((_) async => testReportData);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BugReportDialog(bugReportService: mockBugReportService),
          ),
        ),
      );

      // Fill required fields
      await tester.enterText(find.byType(TextField).at(0), 'App crashed');
      await tester.pump();
      await tester.enterText(
        find.byType(TextField).at(1),
        'App crashed on startup',
      );
      await tester.pump();

      await tester.tap(find.text(l10n.bugReportSendReport));
      await tester.pump();

      verify(
        () => mockBugReportService.collectDiagnostics(
          userDescription: any(named: 'userDescription'),
          currentScreen: any(named: 'currentScreen'),
          userPubkey: any(named: 'userPubkey'),
          additionalContext: any(named: 'additionalContext'),
        ),
      ).called(1);
    });

    testWidgets('should show loading indicator while submitting', (
      tester,
    ) async {
      final testReportData = BugReportData(
        reportId: 'test-123',
        userDescription: 'App crashed on startup',
        deviceInfo: {},
        appVersion: '1.0.0',
        recentLogs: [],
        errorCounts: {},
        timestamp: DateTime.now(),
      );

      when(
        () => mockBugReportService.collectDiagnostics(
          userDescription: any(named: 'userDescription'),
          currentScreen: any(named: 'currentScreen'),
          userPubkey: any(named: 'userPubkey'),
          additionalContext: any(named: 'additionalContext'),
        ),
      ).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        return testReportData;
      });

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BugReportDialog(bugReportService: mockBugReportService),
          ),
        ),
      );

      // Fill required fields
      await tester.enterText(find.byType(TextField).at(0), 'App crashed');
      await tester.pump();
      await tester.enterText(
        find.byType(TextField).at(1),
        'App crashed on startup',
      );
      await tester.pump();

      await tester.tap(find.text(l10n.bugReportSendReport));
      await tester.pump();

      // Should show loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Complete the async operation
      await tester.pumpAndSettle();
    });

    testWidgets('should close dialog on Cancel', (tester) async {
      // GoRouter is needed so context.pop() (GoRouter extension) works.
      // showDialog is used so context.pop() pops the dialog route,
      // matching production usage.
      var dialogClosed = false;

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    await showDialog<void>(
                      context: context,
                      builder: (_) => BugReportDialog(
                        bugReportService: mockBugReportService,
                      ),
                    );
                    dialogClosed = true;
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text(l10n.supportReportBug), findsOneWidget);

      await tester.tap(find.text(l10n.commonCancel));
      await tester.pumpAndSettle();

      expect(dialogClosed, isTrue);
    });

    testWidgets('submits successfully with zero attachments', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BugReportDialog(bugReportService: mockBugReportService),
          ),
        ),
      );

      // Fill required fields
      await tester.enterText(find.byType(TextField).at(0), 'Test subject');
      await tester.enterText(find.byType(TextField).at(1), 'Test description');
      await tester.pump();

      // Verify Send button is enabled with zero attachments
      final sendButton = find.text(l10n.bugReportSendReport);
      final button = tester.widget<ElevatedButton>(
        find.ancestor(of: sendButton, matching: find.byType(ElevatedButton)),
      );
      expect(button.onPressed, isNotNull);
    });
  });
}
