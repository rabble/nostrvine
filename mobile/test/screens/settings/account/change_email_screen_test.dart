// ABOUTME: Widget tests for ChangeEmailView
// ABOUTME: Covers the current address, refusal copy, and the confirmation panel

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/change_email/change_email_cubit.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/repositories/account_credentials_repository.dart';
import 'package:openvine/screens/settings/account/change_email_screen.dart';

class _MockAccountCredentialsRepository extends Mock
    implements AccountCredentialsRepository {}

void main() {
  group(ChangeEmailView, () {
    late _MockAccountCredentialsRepository repository;
    final l10n = lookupAppLocalizations(const Locale('en'));

    setUp(() {
      repository = _MockAccountCredentialsRepository();
      when(() => repository.fetchAccountStatus()).thenAnswer(
        (_) async => const KeycastAccountStatus(
          email: 'old@example.com',
          emailVerified: true,
          publicKey: 'abc',
          verifiedMinor: false,
        ),
      );
    });

    void stubResult(ChangeEmailResult result) {
      when(
        () => repository.changeEmail(
          newEmail: any(named: 'newEmail'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => result);
    }

    Widget buildSubject() {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: VineTheme.theme,
        home: BlocProvider<ChangeEmailCubit>(
          create: (_) =>
              ChangeEmailCubit(repository: repository)..loadCurrentEmail(),
          child: const ChangeEmailView(),
        ),
      );
    }

    Future<void> fillForm(
      WidgetTester tester, {
      String email = 'new@example.com',
      String password = 'hunter2',
    }) async {
      await tester.enterText(
        find.widgetWithText(DivineAuthTextField, l10n.changeEmailNewLabel),
        email,
      );
      await tester.enterText(
        find.widgetWithText(DivineAuthTextField, l10n.changeEmailPasswordLabel),
        password,
      );
      await tester.pump();
    }

    testWidgets('shows the address Keycast has on file', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(
        find.text(l10n.changeEmailCurrentAddress('old@example.com')),
        findsOneWidget,
      );
    });

    testWidgets('refuses the address already on the account', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await fillForm(tester, email: 'old@example.com');
      await tester.tap(
        find.widgetWithText(DivineButton, l10n.changeEmailSubmit),
      );
      await tester.pump();

      expect(find.text(l10n.changeEmailSameAsCurrent), findsOneWidget);
      verifyNever(
        () => repository.changeEmail(
          newEmail: any(named: 'newEmail'),
          password: any(named: 'password'),
        ),
      );
    });

    testWidgets('keeps a wrong password on the screen', (tester) async {
      stubResult(ChangeEmailResult.failure(ChangeEmailFailure.wrongPassword));
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await fillForm(tester, password: 'wrong');
      await tester.tap(
        find.widgetWithText(DivineButton, l10n.changeEmailSubmit),
      );
      await tester.pumpAndSettle();

      expect(find.text(l10n.changeEmailWrongPassword), findsOneWidget);
      expect(
        find.widgetWithText(DivineButton, l10n.changeEmailSubmit),
        findsOneWidget,
      );
    });

    testWidgets('says the change still needs both confirmations', (
      tester,
    ) async {
      stubResult(ChangeEmailResult.success());
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await fillForm(tester);
      await tester.tap(
        find.widgetWithText(DivineButton, l10n.changeEmailSubmit),
      );
      await tester.pumpAndSettle();

      expect(find.text(l10n.changeEmailSentTitle), findsOneWidget);
      expect(
        find.text(l10n.changeEmailSentMessage('new@example.com')),
        findsOneWidget,
      );
      // The form is gone: nothing here invites a second send.
      expect(
        find.widgetWithText(DivineButton, l10n.changeEmailSubmit),
        findsNothing,
      );
    });
  });
}
