// ABOUTME: Widget tests for the account status screen: the appeal and exit
// ABOUTME: paths appear for a restricted account and not for a healthy one.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/account_enforcement_status.dart';
import 'package:openvine/providers/account_enforcement_providers.dart';
import 'package:openvine/screens/settings/account_status_screen.dart';

Future<void> _pumpWith(WidgetTester tester, AccountEnforcementKind kind) async {
  // Tall surface: the body is a ListView, which only builds what fits, and the
  // longer enforcement copy would otherwise push the appeal and exit buttons
  // outside the built viewport.
  tester.view.physicalSize = const Size(1080, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        accountEnforcementStatusProvider.overrideWith(
          (ref) async => AccountEnforcementStatus(kind: kind),
        ),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AccountStatusScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group('AccountStatusScreen', () {
    testWidgets('a suspended account is offered the appeal and exit paths', (
      tester,
    ) async {
      await _pumpWith(tester, AccountEnforcementKind.suspended);

      expect(find.text(l10n.accountStatusSuspendedHeading), findsOneWidget);
      expect(find.text(l10n.accountStatusContactSupport), findsOneWidget);
      expect(find.text(l10n.accountStatusMoveAccount), findsOneWidget);
      expect(
        find.text(l10n.accountStatusKeysUnaffectedHeading),
        findsOneWidget,
      );
    });

    testWidgets('a banned account is offered the appeal and exit paths', (
      tester,
    ) async {
      await _pumpWith(tester, AccountEnforcementKind.banned);

      expect(find.text(l10n.accountStatusBannedHeading), findsOneWidget);
      expect(find.text(l10n.accountStatusContactSupport), findsOneWidget);
    });

    testWidgets('an unrecognized restriction still gets the appeal path', (
      tester,
    ) async {
      // The fail-closed state must not lose the way to contest it.
      await _pumpWith(tester, AccountEnforcementKind.restricted);

      expect(find.text(l10n.accountStatusContactSupport), findsOneWidget);
    });

    testWidgets('a healthy account sees no appeal or exit path', (
      tester,
    ) async {
      await _pumpWith(tester, AccountEnforcementKind.none);

      expect(find.text(l10n.accountStatusOkHeading), findsOneWidget);
      expect(find.text(l10n.accountStatusContactSupport), findsNothing);
      expect(find.text(l10n.accountStatusMoveAccount), findsNothing);
    });

    testWidgets('unknown offers a retry', (tester) async {
      await _pumpWith(tester, AccountEnforcementKind.unknown);

      expect(find.text(l10n.accountStatusUnknownHeading), findsOneWidget);
      expect(find.text(l10n.accountStatusRetry), findsOneWidget);
    });

    testWidgets('opening the screen refetches an already-cached status', (
      tester,
    ) async {
      // Settings keeps the provider alive underneath, so without this the
      // screen would render whatever was cached before the user was
      // suspended. Deleting the initState refetch must turn this red.
      var call = 0;
      final container = ProviderContainer(
        overrides: [
          accountEnforcementStatusProvider.overrideWith((ref) async {
            call++;
            return const AccountEnforcementStatus(
              kind: AccountEnforcementKind.none,
            );
          }),
        ],
      );
      addTearDown(container.dispose);

      // Resolve it once, as Settings would, so a value is already cached.
      final sub = container.listen(
        accountEnforcementStatusProvider,
        (_, _) {},
      );
      await container.read(accountEnforcementStatusProvider.future);
      expect(call, 1);
      addTearDown(sub.close);

      tester.view.physicalSize = const Size(1080, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: AccountStatusScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        call,
        2,
        reason: 'opening the screen must re-read, not serve the cached answer',
      );
    });

    testWidgets('a refresh shows loading, never the previous answer', (
      tester,
    ) async {
      // Riverpod's `when` defaults to skipLoadingOnRefresh: true, which renders
      // the PREVIOUS value while a refresh is in flight. On this screen that
      // means an account suspended after Settings resolved "none" would read
      // "in good standing", with no appeal or exit path, until the refetch
      // lands. Showing a spinner is the honest answer while we do not know.
      var call = 0;
      final pending = Completer<AccountEnforcementStatus>();
      final container = ProviderContainer(
        overrides: [
          accountEnforcementStatusProvider.overrideWith((ref) {
            call++;
            if (call == 1) {
              return Future.value(
                const AccountEnforcementStatus(
                  kind: AccountEnforcementKind.none,
                ),
              );
            }
            return pending.future;
          }),
        ],
      );
      addTearDown(container.dispose);

      tester.view.physicalSize = const Size(1080, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: AccountStatusScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(l10n.accountStatusOkHeading), findsOneWidget);

      container.invalidate(accountEnforcementStatusProvider);
      await tester.pump();

      expect(
        find.text(l10n.accountStatusOkHeading),
        findsNothing,
        reason: 'a stale answer must not survive a refresh',
      );
    });

    testWidgets('a self-custody account is told so, with no futile retry', (
      tester,
    ) async {
      // Retrying can never resolve this, so offering it would be a lie.
      await _pumpWith(tester, AccountEnforcementKind.noAccountState);

      expect(
        find.text(l10n.accountStatusNoAccountStateHeading),
        findsOneWidget,
      );
      expect(find.text(l10n.accountStatusRetry), findsNothing);
    });
  });
}
