// ABOUTME: Widget tests for the bug report bottom sheet user interface
// ABOUTME: Tests UI rendering, user interaction, and form validation

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show BugReportData;
import 'package:openvine/blocs/bug_report/bug_report_cubit.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/services/bug_report_service.dart';
import 'package:openvine/widgets/bug_report_dialog.dart';
import 'package:openvine/widgets/support_form_scope.dart';

class _MockBugReportService extends Mock implements BugReportService {}

class _FakeBugReportData extends Fake implements BugReportData {}

/// Stands in for `ZendeskSupportService.createStructuredBugReport` so the
/// success path is reachable without a configured Zendesk.
Future<bool> _submitSucceeds({
  required String subject,
  required String description,
  required String reportId,
  required String appVersion,
  required Map<String, dynamic> deviceInfo,
  String? stepsToReproduce,
  String? expectedBehavior,
  String? currentScreen,
  String? userPubkey,
  Map<String, int>? errorCounts,
  String? logsSummary,
  List<String>? attachmentPaths,
}) async => true;

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  setUpAll(() {
    registerFallbackValue(_FakeBugReportData());
  });

  group('bug report sheet', () {
    late _MockBugReportService mockBugReportService;

    setUp(() {
      mockBugReportService = _MockBugReportService();
    });

    /// Opens the sheet the way production does — through
    /// [showBugReportSheet] — so the header, the pinned footer and
    /// `context.pop()` behave as they do in the app.
    Future<void> openSheet(WidgetTester tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: Builder(
                builder: (context) => DivineButton(
                  label: 'Open',
                  onPressed: () => showBugReportSheet(
                    context,
                    bugReportService: mockBugReportService,
                  ),
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
    }

    DivineButton buttonFor(WidgetTester tester, String label) {
      return tester.widget<DivineButton>(
        find.ancestor(
          of: find.text(label),
          matching: find.byType(DivineButton),
        ),
      );
    }

    Future<void> fillRequiredFields(WidgetTester tester) async {
      await tester.enterText(find.byType(TextField).at(0), 'App crashed');
      await tester.enterText(
        find.byType(TextField).at(1),
        'App crashed on startup',
      );
      await tester.pump();
    }

    testWidgets('should display title and form fields', (tester) async {
      await openSheet(tester);

      // The title lives in the bottom sheet header.
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
      await openSheet(tester);

      expect(find.text(l10n.bugReportSendReport), findsOneWidget);
      expect(find.text(l10n.commonCancel), findsOneWidget);
    });

    // The actions belong to the sheet's pinned footer, not to the scrolling
    // form — otherwise they drift off screen while filling in the report.
    testWidgets('keeps the actions out of the scrollable form', (tester) async {
      await openSheet(tester);

      expect(
        find.descendant(
          of: find.byType(SingleChildScrollView),
          matching: find.text(l10n.bugReportSendReport),
        ),
        findsNothing,
      );
    });

    // The form has to scroll through the sheet's own controller, otherwise
    // dragging it down no longer collapses and dismisses the sheet.
    testWidgets('dismisses the sheet when the form is dragged down', (
      tester,
    ) async {
      await openSheet(tester);

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, 600),
      );
      await tester.pumpAndSettle();

      expect(find.text(l10n.supportReportBug), findsNothing);
    });

    // The subject is the only single-line field, so it is the only one whose
    // action key can advance the form — the rest insert a newline. Widget
    // tests cannot render an IME, so the offered action is asserted directly.
    testWidgets('advances from the subject to the description', (tester) async {
      await openSheet(tester);

      final subject = tester.widget<TextField>(find.byType(TextField).first);
      expect(subject.textInputAction, TextInputAction.next);

      await tester.tap(find.byType(TextField).first);
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();

      final fields = tester.widgetList<EditableText>(find.byType(EditableText));
      expect(fields.elementAt(1).focusNode.hasFocus, isTrue);
      expect(fields.first.focusNode.hasFocus, isFalse);
    });

    testWidgets('should disable Send button when required fields are empty', (
      tester,
    ) async {
      await openSheet(tester);

      expect(buttonFor(tester, l10n.bugReportSendReport).onPressed, isNull);
    });

    testWidgets('should enable Send button when required fields are filled', (
      tester,
    ) async {
      await openSheet(tester);
      await fillRequiredFields(tester);

      expect(buttonFor(tester, l10n.bugReportSendReport).onPressed, isNotNull);
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

      await openSheet(tester);
      await fillRequiredFields(tester);

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

      await openSheet(tester);
      await fillRequiredFields(tester);

      await tester.tap(find.text(l10n.bugReportSendReport));
      await tester.pump();

      // The send button swaps its leading slot for a spinner while in flight.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Complete the async operation
      await tester.pumpAndSettle();
    });

    // The opposite of the success path: the sheet stays open so the report
    // can be retried, and says why it failed.
    testWidgets('keeps the sheet open and reports why sending failed', (
      tester,
    ) async {
      when(
        () => mockBugReportService.collectDiagnostics(
          userDescription: any(named: 'userDescription'),
          currentScreen: any(named: 'currentScreen'),
          userPubkey: any(named: 'userPubkey'),
          additionalContext: any(named: 'additionalContext'),
        ),
      ).thenAnswer(
        (_) async => BugReportData(
          reportId: 'test-123',
          userDescription: 'App crashed on startup',
          deviceInfo: {},
          appVersion: '1.0.0',
          recentLogs: [],
          errorCounts: {},
          timestamp: DateTime.now(),
        ),
      );

      await openSheet(tester);
      await fillRequiredFields(tester);

      // Zendesk is not configured in tests, so submission fails.
      await tester.tap(find.text(l10n.bugReportSendReport));
      await tester.pumpAndSettle();

      expect(find.text(l10n.bugReportSendFailed), findsOneWidget);
      expect(find.text(l10n.supportReportBug), findsOneWidget);
    });

    // Success leaves no trace in the sheet: it closes and the confirmation
    // is handed to the screen behind it.
    testWidgets('closes and confirms via snackbar on success', (tester) async {
      when(
        () => mockBugReportService.collectDiagnostics(
          userDescription: any(named: 'userDescription'),
          currentScreen: any(named: 'currentScreen'),
          userPubkey: any(named: 'userPubkey'),
          additionalContext: any(named: 'additionalContext'),
        ),
      ).thenAnswer(
        (_) async => BugReportData(
          reportId: 'test-123',
          userDescription: 'App crashed on startup',
          deviceInfo: {},
          appVersion: '1.0.0',
          recentLogs: [],
          errorCounts: {},
          timestamp: DateTime.now(),
        ),
      );

      // Disposed by the SupportFormScope below when the route pops.
      final fields = BugReportFields();
      fields.subject.text = 'App crashed';
      fields.description.text = 'App crashed on startup';

      final cubit = BugReportCubit(
        bugReportService: mockBugReportService,
        buildLogsSummary: buildLogsSummary,
        submitBugReport: _submitSucceeds,
      );
      addTearDown(cubit.close);

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: Builder(
                builder: (context) => DivineButton(
                  label: 'Open',
                  onPressed: () => context.push('/report'),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/report',
            builder: (context, state) => Scaffold(
              body: SupportFormScope<BugReportFields>(
                create: () => fields,
                child: BlocProvider<BugReportCubit>.value(
                  value: cubit,
                  child: const BugReportActions(),
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

      await tester.tap(find.text(l10n.bugReportSendReport));
      await tester.pumpAndSettle();

      expect(find.text(l10n.bugReportSendReport), findsNothing);
      expect(find.text(l10n.bugReportSuccessMessage), findsOneWidget);
    });

    testWidgets('should close the sheet on Cancel', (tester) async {
      await openSheet(tester);

      expect(find.text(l10n.supportReportBug), findsOneWidget);

      await tester.tap(find.text(l10n.commonCancel));
      await tester.pumpAndSettle();

      expect(find.text(l10n.supportReportBug), findsNothing);
    });

    testWidgets('submits successfully with zero attachments', (tester) async {
      await openSheet(tester);

      await tester.enterText(find.byType(TextField).at(0), 'Test subject');
      await tester.enterText(find.byType(TextField).at(1), 'Test description');
      await tester.pump();

      // Verify Send button is enabled with zero attachments
      expect(buttonFor(tester, l10n.bugReportSendReport).onPressed, isNotNull);
    });
  });
}
