// ABOUTME: Widget tests for the feature request bottom sheet user interface
// ABOUTME: Tests UI rendering, user interaction, and form validation

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/feature_request/feature_request_cubit.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/feature_request_dialog.dart';
import 'package:openvine/widgets/support_form_scope.dart';

/// Stands in for `ZendeskSupportService.createFeatureRequest` so the success
/// path is reachable without a configured Zendesk.
Future<bool> _submitSucceeds({
  required String subject,
  required String description,
  required String usefulness,
  required String whenToUse,
  String? userPubkey,
}) async => true;

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group('feature request sheet', () {
    /// Opens the sheet the way production does — through
    /// [showFeatureRequestSheet] — so the header, the pinned footer and
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
                  onPressed: () => showFeatureRequestSheet(context),
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
      await tester.enterText(find.byType(TextField).at(0), 'Dark mode toggle');
      await tester.enterText(
        find.byType(TextField).at(1),
        'Let me switch themes from settings',
      );
      await tester.pump();
    }

    testWidgets('should display title and form fields', (tester) async {
      await openSheet(tester);

      // The title lives in the bottom sheet header.
      expect(find.text(l10n.supportRequestFeature), findsOneWidget);

      expect(find.byType(TextField), findsNWidgets(4));

      expect(find.text(l10n.supportSubjectRequiredLabel), findsOneWidget);
      expect(
        find.text(l10n.featureRequestDescriptionRequiredLabel),
        findsOneWidget,
      );
      expect(find.text(l10n.featureRequestUsefulnessLabel), findsOneWidget);
      expect(find.text(l10n.featureRequestWhenLabel), findsOneWidget);
    });

    testWidgets('should have Send and Cancel buttons', (tester) async {
      await openSheet(tester);

      expect(find.text(l10n.featureRequestSendRequest), findsOneWidget);
      expect(find.text(l10n.commonCancel), findsOneWidget);
    });

    // The actions belong to the sheet's pinned footer, not to the scrolling
    // form — otherwise they drift off screen while filling in the request.
    testWidgets('keeps the actions out of the scrollable form', (tester) async {
      await openSheet(tester);

      expect(
        find.descendant(
          of: find.byType(SingleChildScrollView),
          matching: find.text(l10n.featureRequestSendRequest),
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

      expect(find.text(l10n.supportRequestFeature), findsNothing);
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

      expect(
        buttonFor(tester, l10n.featureRequestSendRequest).onPressed,
        isNull,
      );
    });

    testWidgets('should enable Send button when required fields are filled', (
      tester,
    ) async {
      await openSheet(tester);
      await fillRequiredFields(tester);

      expect(
        buttonFor(tester, l10n.featureRequestSendRequest).onPressed,
        isNotNull,
      );
    });

    // The opposite of the success path: the sheet stays open so the request
    // can be retried, and says why it failed.
    testWidgets('keeps the sheet open and reports why sending failed', (
      tester,
    ) async {
      await openSheet(tester);
      await fillRequiredFields(tester);

      // Zendesk is not configured in tests, so submission fails.
      await tester.tap(find.text(l10n.featureRequestSendRequest));
      await tester.pumpAndSettle();

      expect(find.text(l10n.featureRequestSendFailed), findsOneWidget);
      expect(find.text(l10n.supportRequestFeature), findsOneWidget);
    });

    // Success leaves no trace in the sheet: it closes and the confirmation
    // is handed to the screen behind it.
    testWidgets('closes and confirms via snackbar on success', (tester) async {
      // Disposed by the SupportFormScope below when the route pops.
      final fields = FeatureRequestFields();
      fields.subject.text = 'Dark mode toggle';
      fields.description.text = 'Let me switch themes from settings';

      final cubit = FeatureRequestCubit(
        submitFeatureRequest: _submitSucceeds,
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
                  onPressed: () => context.push('/request'),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/request',
            builder: (context, state) => Scaffold(
              body: SupportFormScope<FeatureRequestFields>(
                create: () => fields,
                child: BlocProvider<FeatureRequestCubit>.value(
                  value: cubit,
                  child: const FeatureRequestActions(),
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

      await tester.tap(find.text(l10n.featureRequestSendRequest));
      await tester.pumpAndSettle();

      expect(find.text(l10n.featureRequestSendRequest), findsNothing);
      expect(find.text(l10n.featureRequestSuccessMessage), findsOneWidget);
    });

    testWidgets('should close the sheet on Cancel', (tester) async {
      await openSheet(tester);

      expect(find.text(l10n.supportRequestFeature), findsOneWidget);

      await tester.tap(find.text(l10n.commonCancel));
      await tester.pumpAndSettle();

      expect(find.text(l10n.supportRequestFeature), findsNothing);
    });
  });
}
