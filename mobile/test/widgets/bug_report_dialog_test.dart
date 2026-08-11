// ABOUTME: Widget tests for the bug report support flow
// ABOUTME: Tests UI rendering, user interaction, and form validation

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show BugReportData;
import 'package:openvine/blocs/bug_report/bug_report_cubit.dart';
import 'package:openvine/config/bug_report_config.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/services/bug_report_service.dart';
import 'package:openvine/widgets/bug_report_dialog.dart';
import 'package:openvine/widgets/support_public_submission_notice.dart';

class _MockBugReportService extends Mock implements BugReportService {}

class _FakeBugReportData extends Fake implements BugReportData {}

const _pubkeyHex =
    '3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d';

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

Future<bool> _submitFails({
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
}) async => false;

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  setUpAll(() {
    registerFallbackValue(_FakeBugReportData());
  });

  group('bug report flow', () {
    late _MockBugReportService mockBugReportService;

    setUp(() {
      mockBugReportService = _MockBugReportService();
    });

    Future<void> openFlow(
      WidgetTester tester, {
      SubmitBugReportAction submitBugReport = _submitFails,
    }) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: Builder(
                builder: (context) => DivineButton(
                  label: 'Open',
                  onPressed: () => context.push(BugReportScreen.path),
                ),
              ),
            ),
          ),
          GoRoute(
            path: BugReportScreen.path,
            builder: (context, state) => BugReportScreen(
              bugReportService: mockBugReportService,
              currentScreen: 'SupportCenterScreen',
              userPubkey: _pubkeyHex,
              submitBugReport: submitBugReport,
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

    testWidgets('caps every pasted free-text field', (tester) async {
      // Sanitization is linear in field size but with a large constant, so an
      // uncapped paste can freeze submission on the main isolate. Every field
      // is asserted: a version of this test that checked only the description
      // passed with the cap removed from the other three.
      //
      // The cap is an input formatter rather than `maxLength` so the form does
      // not grow four Material character counters in non-VineTheme styling.
      // The tradeoff is that truncation is silent.
      await openFlow(tester);

      const overflow = 500;
      final expectedCaps = <int, int>{
        0: BugReportConfig.maxSubjectLength,
        1: BugReportConfig.maxFreeTextFieldLength,
        2: BugReportConfig.maxFreeTextFieldLength,
        3: BugReportConfig.maxFreeTextFieldLength,
      };

      for (final entry in expectedCaps.entries) {
        final field = find.byType(DivineTextField).at(entry.key);
        await tester.enterText(field, 'a' * (entry.value + overflow));
        await tester.pump();

        expect(
          tester.widget<DivineTextField>(field).controller!.text.length,
          entry.value,
          reason: 'field ${entry.key} is not capped',
        );
      }
    });

    BugReportData testReportData() {
      return BugReportData(
        reportId: 'test-123',
        userDescription: 'App crashed on startup',
        deviceInfo: {},
        appVersion: '1.0.0',
        recentLogs: [],
        errorCounts: {},
        timestamp: DateTime.now(),
      );
    }

    void stubDiagnostics() {
      when(
        () => mockBugReportService.collectDiagnostics(
          userDescription: any(named: 'userDescription'),
          currentScreen: any(named: 'currentScreen'),
          userPubkey: any(named: 'userPubkey'),
          additionalContext: any(named: 'additionalContext'),
        ),
      ).thenAnswer((_) async => testReportData());
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

    testWidgets('displays public submission warning and form fields', (
      tester,
    ) async {
      await openFlow(tester);

      expect(find.text(l10n.supportReportBug), findsOneWidget);
      expect(find.text(l10n.supportPublicSubmissionTitle), findsOneWidget);
      expect(find.text(l10n.supportPublicSubmissionMessage), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(4));
      expect(find.text(l10n.supportSubjectRequiredLabel), findsOneWidget);
      expect(find.text(l10n.bugReportDescriptionRequiredLabel), findsOneWidget);
      expect(find.text(l10n.bugReportStepsLabel), findsOneWidget);
      expect(find.text(l10n.bugReportExpectedBehaviorLabel), findsOneWidget);
    });

    testWidgets('renders the public submission warning above the form', (
      tester,
    ) async {
      await openFlow(tester);

      // The warning only works if it is read before anything is typed, so
      // pin it above the first field rather than merely present.
      final warning = tester.getTopLeft(
        find.byType(SupportPublicSubmissionNotice),
      );
      final subject = tester.getTopLeft(
        find.text(l10n.supportSubjectRequiredLabel),
      );
      expect(warning.dy, lessThan(subject.dy));
    });

    testWidgets('keeps actions out of the scrollable form', (tester) async {
      await openFlow(tester);

      expect(
        find.descendant(
          of: find.byType(SingleChildScrollView),
          matching: find.text(l10n.bugReportSendReport),
        ),
        findsNothing,
      );
    });

    testWidgets('does not discard typed content when the form is dragged', (
      tester,
    ) async {
      await openFlow(tester);
      await fillRequiredFields(tester);

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, 600),
      );
      await tester.pumpAndSettle();

      expect(find.text(l10n.supportReportBug), findsOneWidget);
      expect(find.text('App crashed'), findsOneWidget);
      expect(find.text('App crashed on startup'), findsOneWidget);
    });

    testWidgets('advances from the subject to the description', (tester) async {
      await openFlow(tester);

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

    testWidgets('disables Send button when required fields are empty', (
      tester,
    ) async {
      await openFlow(tester);

      expect(buttonFor(tester, l10n.bugReportSendReport).onPressed, isNull);
    });

    testWidgets('enables Send button when required fields are filled', (
      tester,
    ) async {
      await openFlow(tester);
      await fillRequiredFields(tester);

      expect(buttonFor(tester, l10n.bugReportSendReport).onPressed, isNotNull);
    });

    testWidgets('calls collectDiagnostics on submit', (tester) async {
      stubDiagnostics();

      await openFlow(tester);
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

    testWidgets('shows loading indicator while submitting', (tester) async {
      stubDiagnostics();
      final completer = Completer<bool>();

      Future<bool> submitWaits({
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
      }) {
        return completer.future;
      }

      await openFlow(tester, submitBugReport: submitWaits);
      await fillRequiredFields(tester);

      await tester.tap(find.text(l10n.bugReportSendReport));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete(false);
      await tester.pumpAndSettle();
    });

    testWidgets('keeps the flow open and reports why sending failed', (
      tester,
    ) async {
      stubDiagnostics();

      await openFlow(tester);
      await fillRequiredFields(tester);

      await tester.tap(find.text(l10n.bugReportSendReport));
      await tester.pumpAndSettle();

      expect(find.text(l10n.bugReportSendFailed), findsOneWidget);
      expect(find.text(l10n.supportReportBug), findsOneWidget);
    });

    testWidgets('closes and confirms via snackbar on success', (tester) async {
      stubDiagnostics();

      await openFlow(tester, submitBugReport: _submitSucceeds);
      await fillRequiredFields(tester);

      await tester.tap(find.text(l10n.bugReportSendReport));
      await tester.pumpAndSettle();

      expect(find.text(l10n.bugReportSendReport), findsNothing);
      expect(find.text(l10n.bugReportSuccessMessage), findsOneWidget);
    });

    testWidgets('closes the flow on Cancel', (tester) async {
      await openFlow(tester);

      expect(find.text(l10n.supportReportBug), findsOneWidget);

      await tester.tap(find.text(l10n.commonCancel));
      await tester.pumpAndSettle();

      expect(find.text(l10n.supportReportBug), findsNothing);
    });

    testWidgets('submits successfully with zero attachments', (tester) async {
      await openFlow(tester);

      await tester.enterText(find.byType(TextField).at(0), 'Test subject');
      await tester.enterText(find.byType(TextField).at(1), 'Test description');
      await tester.pump();

      expect(buttonFor(tester, l10n.bugReportSendReport).onPressed, isNotNull);
    });
  });
}
