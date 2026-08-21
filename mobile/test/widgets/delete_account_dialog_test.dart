// ABOUTME: Tests for the delete account confirmation sheet
// ABOUTME: Verifies that the DELETE confirmation is case-insensitive and trims whitespace

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/account_deletion_attempt.dart';
import 'package:openvine/repositories/account_deletion_recovery_repository.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/services/account_deletion_service.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:openvine/widgets/delete_account_confirmation.dart';
import 'package:openvine/widgets/delete_account_dialog.dart';

class _MockAccountDeletionService extends Mock
    implements AccountDeletionService {}

class _MockAuthService extends Mock implements AuthService {}

class _MockAccountDeletionRecoveryRepository extends Mock
    implements AccountDeletionRecoveryRepository {}

const _recoverableAttempt = AccountDeletionAttempt(
  id: 'attempt-id',
  status: AccountDeletionAttemptStatus.recoverable,
  username: 'alice',
);

const _completedAttempt = AccountDeletionAttempt(
  id: 'attempt-id',
  status: AccountDeletionAttemptStatus.completed,
  username: 'alice',
);

const _recoverableAttemptWithoutUsername = AccountDeletionAttempt(
  id: 'attempt-id',
  status: AccountDeletionAttemptStatus.recoverable,
);

const _completedAttemptWithoutUsername = AccountDeletionAttempt(
  id: 'attempt-id',
  status: AccountDeletionAttemptStatus.completed,
);

const _pubkeyHex =
    '3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d';

DeleteAccountConfirmation _deleteFallback() => DeleteAccountConfirmation(
  pubkeyHex: _pubkeyHex,
  displayName: 'Wild Otter 7',
  avatarUrl: null,
  handle: null,
);

DeleteAccountConfirmation _divineUsername() => DeleteAccountConfirmation(
  pubkeyHex: _pubkeyHex,
  displayName: 'Rabble',
  avatarUrl: null,
  handle: '@rabble.divine.video',
);

/// Minimal router wrapper so [context.pop()] works inside the sheet.
Widget _wrapWithRouter(Widget child) {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, state) => child),
      GoRoute(
        path: RoutePaths.supportCenter,
        builder: (_, state) =>
            const Scaffold(body: Text('Support destination')),
      ),
    ],
  );
  return MaterialApp.router(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    routerConfig: router,
  );
}

Future<void> _showSheet(
  WidgetTester tester, {
  DeleteAccountConfirmation? confirmation,
  void Function({
    required bool burnUsername,
    ({String name, String canonical})? ownedUsername,
  })?
  onConfirm,
  ({String name, String canonical})? ownedUsername,
}) async {
  await tester.pumpWidget(
    _wrapWithRouter(
      Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            key: const Key('open'),
            onPressed: () => showDeleteAllContentWarningSheet(
              context: context,
              confirmation: confirmation ?? _deleteFallback(),
              ownedUsernameFuture: Future.value(ownedUsername),
              onConfirm:
                  onConfirm ??
                  ({
                    required bool burnUsername,
                    ({String name, String canonical})? ownedUsername,
                  }) {},
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('open')));
  await tester.pumpAndSettle();
}

AppLocalizations _englishL10n() => lookupAppLocalizations(const Locale('en'));

Finder _deleteAllContentButton() => find.widgetWithText(
  DivineButton,
  _englishL10n().deleteAccountDeleteAllContentButton,
);

Finder _deleteSheetCancelButton() =>
    find.widgetWithText(DivineButton, _englishL10n().commonCancel);

Future<void> _tapBurnUsernameCheckbox(WidgetTester tester) async {
  final tile = find.byType(DivineRowCheckbox);
  await tester.ensureVisible(tile);
  await tester.pumpAndSettle();
  await tester.tap(tile);
}

void main() {
  group('showRemoveKeysWarningSheet', () {
    // Written by the sheet's future, which only completes after the sheet
    // closes — so the tests read it once they have settled.
    bool? result;

    Future<void> openSheet(WidgetTester tester) async {
      result = null;
      await tester.pumpWidget(
        _wrapWithRouter(
          Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                key: const Key('open'),
                onPressed: () async {
                  result = await showRemoveKeysWarningSheet(context);
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
    }

    testWidgets('returns true after confirming', (tester) async {
      await openSheet(tester);
      final l10n = _englishL10n();

      expect(find.text(l10n.deleteAccountRemoveKeysTitle), findsOneWidget);

      await tester.tap(find.text(l10n.deleteAccountRemoveKeysConfirm));
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });

    testWidgets('returns false after cancelling', (tester) async {
      await openSheet(tester);

      await tester.tap(find.text(_englishL10n().commonCancel));
      await tester.pumpAndSettle();

      expect(result, isFalse);
    });

    // Dismissing is the only path that reaches the `?? false` default, and the
    // dialog this replaced was barrierDismissible: false — so the path is new.
    // If the default ever flips, a stray barrier tap deletes the keys.
    testWidgets('returns false when dismissed without choosing', (
      tester,
    ) async {
      await openSheet(tester);

      // System back rather than a barrier tap: it dismisses without touching
      // either button regardless of how tall the sheet renders, so the test
      // pins the default instead of the sheet's layout.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(
        find.text(_englishL10n().deleteAccountRemoveKeysTitle),
        findsNothing,
      );
      expect(result, isFalse);
    });
  });

  group('showDeleteAllContentWarningSheet – confirmation input', () {
    // The red title is the destructive-action signal the pre-sheet dialog
    // carried; inheriting the sheet header's default style silently drops it.
    testWidgets('renders the final-confirmation title in the error colour', (
      tester,
    ) async {
      await _showSheet(tester);

      final l10n = _englishL10n();
      final title = tester.widget<Text>(
        find.text(l10n.deleteAccountFinalConfirmationTitle),
      );
      expect(title.style?.color, equals(VineTheme.error));
    });

    testWidgets('empty string keeps Delete button disabled', (tester) async {
      await _showSheet(tester);

      final l10n = _englishL10n();
      expect(find.text(l10n.deleteAccountWarningBody), findsOneWidget);
      expect(find.text(l10n.deleteAccountConfirmDeletePrompt), findsOneWidget);
      // Button should be disabled (onPressed == null → tapping does nothing)
      final button = tester.widget<DivineButton>(_deleteAllContentButton());
      expect(button.onPressed, isNull);
    });

    // The actions belong to the sheet's pinned footer, not to the scrolling
    // form — otherwise they drift off screen while reading the warning.
    testWidgets('keeps the actions out of the scrollable form', (tester) async {
      await _showSheet(tester);

      expect(
        find.descendant(
          of: find.byType(SingleChildScrollView).first,
          matching: _deleteAllContentButton(),
        ),
        findsNothing,
      );
    });

    // The form has to scroll through the sheet's own controller, otherwise
    // dragging it down no longer collapses and dismisses the sheet.
    testWidgets('dismisses the sheet when the form is dragged down', (
      tester,
    ) async {
      // Force the form to overflow the sheet regardless of font warm-up, so
      // the inner scroll view always has extent to consume the drag.
      tester.view.physicalSize = const Size(400, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _showSheet(tester);

      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, 600),
      );
      await tester.pumpAndSettle();

      expect(_deleteAllContentButton(), findsNothing);
    });

    // The sheet documents that dismissing cancels. Typing the token arms the
    // destructive action, so the case worth pinning is dismissing *after* it
    // is armed: nothing may reach the caller.
    testWidgets('dismissing after typing the token does not confirm', (
      tester,
    ) async {
      var confirmCalls = 0;
      await _showSheet(
        tester,
        onConfirm:
            ({
              required bool burnUsername,
              ({String name, String canonical})? ownedUsername,
            }) => confirmCalls++,
      );

      await tester.enterText(find.byType(TextField), 'DELETE');
      await tester.pump();
      expect(
        tester.widget<DivineButton>(_deleteAllContentButton()).onPressed,
        isNotNull,
      );

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(_deleteAllContentButton(), findsNothing);
      expect(confirmCalls, isZero);
    });

    testWidgets('tapping Cancel after typing the token does not confirm', (
      tester,
    ) async {
      var confirmCalls = 0;
      await _showSheet(
        tester,
        onConfirm:
            ({
              required bool burnUsername,
              ({String name, String canonical})? ownedUsername,
            }) => confirmCalls++,
      );

      await tester.enterText(find.byType(TextField), 'DELETE');
      await tester.pump();
      expect(
        tester.widget<DivineButton>(_deleteAllContentButton()).onPressed,
        isNotNull,
      );

      await tester.tap(_deleteSheetCancelButton());
      await tester.pumpAndSettle();

      expect(_deleteAllContentButton(), findsNothing);
      expect(confirmCalls, isZero);
    });

    testWidgets('wrong word keeps Delete button disabled', (tester) async {
      await _showSheet(tester);

      await tester.enterText(find.byType(TextField), 'confirm');
      await tester.pump();

      final button = tester.widget<DivineButton>(_deleteAllContentButton());
      expect(button.onPressed, isNull);
    });

    testWidgets('exact uppercase DELETE enables the button', (tester) async {
      await _showSheet(tester);

      await tester.enterText(find.byType(TextField), 'DELETE');
      await tester.pump();

      final button = tester.widget<DivineButton>(_deleteAllContentButton());
      expect(button.onPressed, isNotNull);
    });

    testWidgets('lowercase delete enables the button', (tester) async {
      await _showSheet(tester);

      await tester.enterText(find.byType(TextField), 'delete');
      await tester.pump();

      final button = tester.widget<DivineButton>(_deleteAllContentButton());
      expect(button.onPressed, isNotNull);
    });

    testWidgets('mixed case Delete enables the button', (tester) async {
      await _showSheet(tester);

      await tester.enterText(find.byType(TextField), 'Delete');
      await tester.pump();

      final button = tester.widget<DivineButton>(_deleteAllContentButton());
      expect(button.onPressed, isNotNull);
    });

    testWidgets('DELETE with trailing whitespace enables the button', (
      tester,
    ) async {
      await _showSheet(tester);

      await tester.enterText(find.byType(TextField), 'DELETE ');
      await tester.pump();

      final button = tester.widget<DivineButton>(_deleteAllContentButton());
      expect(button.onPressed, isNotNull);
    });

    testWidgets('delete with leading whitespace enables the button', (
      tester,
    ) async {
      await _showSheet(tester);

      await tester.enterText(find.byType(TextField), ' delete');
      await tester.pump();

      final button = tester.widget<DivineButton>(_deleteAllContentButton());
      expect(button.onPressed, isNotNull);
    });

    testWidgets('tapping enabled button calls onConfirm', (tester) async {
      var called = false;
      await _showSheet(
        tester,
        onConfirm:
            ({
              required bool burnUsername,
              ({String name, String canonical})? ownedUsername,
            }) => called = true,
      );

      await tester.enterText(find.byType(TextField), 'delete');
      await tester.pump();

      await tester.tap(_deleteAllContentButton());
      await tester.pumpAndSettle();

      expect(called, isTrue);
    });

    testWidgets('burn toggle is hidden when no username is owned', (
      tester,
    ) async {
      await _showSheet(tester);
      expect(find.byType(DivineRowCheckbox), findsNothing);
    });

    testWidgets('burn toggle is shown when a username is owned', (
      tester,
    ) async {
      await _showSheet(
        tester,
        ownedUsername: (name: 'Alice', canonical: 'alice'),
      );
      expect(find.byType(DivineRowCheckbox), findsOneWidget);
      // Pin the consent label naming the exact handle (display form, not
      // canonical) so swapping the interpolated variable can't slip through.
      expect(
        find.text(
          lookupAppLocalizations(
            const Locale('en'),
          ).deleteAccountBurnUsernameToggle('@Alice.divine.video'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('checking burn toggle passes burnUsername true on confirm', (
      tester,
    ) async {
      bool? received;
      await _showSheet(
        tester,
        ownedUsername: (name: 'alice', canonical: 'alice'),
        onConfirm:
            ({
              required bool burnUsername,
              ({String name, String canonical})? ownedUsername,
            }) => received = burnUsername,
      );

      await _tapBurnUsernameCheckbox(tester);
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'delete');
      await tester.pump();
      await tester.tap(_deleteAllContentButton());
      await tester.pumpAndSettle();

      expect(received, isTrue);
    });

    testWidgets('leaving burn toggle unchecked passes burnUsername false', (
      tester,
    ) async {
      bool? received;
      await _showSheet(
        tester,
        ownedUsername: (name: 'alice', canonical: 'alice'),
        onConfirm:
            ({
              required bool burnUsername,
              ({String name, String canonical})? ownedUsername,
            }) => received = burnUsername,
      );

      await tester.enterText(find.byType(TextField), 'delete');
      await tester.pump();
      await tester.tap(_deleteAllContentButton());
      await tester.pumpAndSettle();

      expect(received, isFalse);
    });

    testWidgets('sheet opens before the lookup resolves and reveals the '
        'toggle only once it completes', (tester) async {
      final completer = Completer<({String name, String canonical})?>();
      await tester.pumpWidget(
        _wrapWithRouter(
          Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                key: const Key('open'),
                onPressed: () => showDeleteAllContentWarningSheet(
                  context: context,
                  confirmation: _deleteFallback(),
                  ownedUsernameFuture: completer.future,
                  onConfirm:
                      ({
                        required bool burnUsername,
                        ({String name, String canonical})? ownedUsername,
                      }) {},
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();

      // Sheet is already open (lookup still pending) but no toggle yet.
      expect(_deleteAllContentButton(), findsOneWidget);
      expect(find.byType(DivineRowCheckbox), findsNothing);

      completer.complete((name: 'Alice', canonical: 'alice'));
      await tester.pumpAndSettle();

      expect(find.byType(DivineRowCheckbox), findsOneWidget);
    });

    testWidgets('a failed lookup leaves the toggle hidden without crashing', (
      tester,
    ) async {
      final completer = Completer<({String name, String canonical})?>();
      await tester.pumpWidget(
        _wrapWithRouter(
          Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                key: const Key('open'),
                onPressed: () => showDeleteAllContentWarningSheet(
                  context: context,
                  confirmation: _deleteFallback(),
                  ownedUsernameFuture: completer.future,
                  onConfirm:
                      ({
                        required bool burnUsername,
                        ({String name, String canonical})? ownedUsername,
                      }) {},
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();

      // Sheet is open with the lookup still pending, then the lookup fails.
      completer.completeError(Exception('lookup failed'));
      await tester.pumpAndSettle();

      expect(_deleteAllContentButton(), findsOneWidget);
      expect(find.byType(DivineRowCheckbox), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('confirm passes the resolved handle back to onConfirm', (
      tester,
    ) async {
      ({String name, String canonical})? receivedOwned;
      var receivedBurn = false;
      await _showSheet(
        tester,
        ownedUsername: (name: 'Alice', canonical: 'alice'),
        onConfirm:
            ({
              required bool burnUsername,
              ({String name, String canonical})? ownedUsername,
            }) {
              receivedBurn = burnUsername;
              receivedOwned = ownedUsername;
            },
      );

      await _tapBurnUsernameCheckbox(tester);
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'delete');
      await tester.pump();
      await tester.tap(_deleteAllContentButton());
      await tester.pumpAndSettle();

      expect(receivedBurn, isTrue);
      expect(receivedOwned, (name: 'Alice', canonical: 'alice'));
    });

    testWidgets('shows the identity (name + handle) and username prompt', (
      tester,
    ) async {
      await _showSheet(tester, confirmation: _divineUsername());
      expect(find.text('Rabble'), findsOneWidget);
      expect(find.text('@rabble.divine.video'), findsWidgets);
      expect(
        find.text(
          lookupAppLocalizations(
            const Locale('en'),
          ).deleteAccountConfirmUsernamePrompt,
        ),
        findsOneWidget,
      );
    });

    testWidgets('typing DELETE does not enable the button for a username', (
      tester,
    ) async {
      await _showSheet(tester, confirmation: _divineUsername());
      await tester.enterText(find.byType(TextField), 'DELETE');
      await tester.pump();
      final button = tester.widget<DivineButton>(_deleteAllContentButton());
      expect(button.onPressed, isNull);
    });

    testWidgets('typing the handle enables the button', (tester) async {
      await _showSheet(tester, confirmation: _divineUsername());
      await tester.enterText(find.byType(TextField), '@rabble.divine.video');
      await tester.pump();
      final button = tester.widget<DivineButton>(_deleteAllContentButton());
      expect(button.onPressed, isNotNull);
    });

    testWidgets('typing the handle without @ also enables the button', (
      tester,
    ) async {
      await _showSheet(tester, confirmation: _divineUsername());
      await tester.enterText(find.byType(TextField), 'rabble.divine.video');
      await tester.pump();
      final button = tester.widget<DivineButton>(_deleteAllContentButton());
      expect(button.onPressed, isNotNull);
    });
  });

  group('executeAccountDeletion', () {
    testWidgets(
      'localizes relay confirmation failure without surfacing raw service text',
      (tester) async {
        final deletionService = _MockAccountDeletionService();
        final authService = _MockAuthService();
        when(
          authService.checkAccountDeletionReadiness,
        ).thenAnswer((_) async => AccountDeletionReadiness.ready);
        when(
          () => deletionService.deleteAccount(
            onProgress: any(named: 'onProgress'),
            expectedPubkey: any(named: 'expectedPubkey'),
          ),
        ).thenAnswer(
          (_) async => DeleteAccountResult.failure(
            DeleteAccountFailureReason.vanishNotConfirmed,
            diagnosticError: 'Failed to publish deletion request to relays',
          ),
        );

        late BuildContext capturedContext;
        await tester.pumpWidget(
          _wrapWithRouter(
            Builder(
              builder: (context) {
                capturedContext = context;
                return const Scaffold(body: SizedBox.shrink());
              },
            ),
          ),
        );

        await executeAccountDeletion(
          context: capturedContext,
          deletionService: deletionService,
          authService: authService,
        );
        await tester.pumpAndSettle();

        final l10n = _englishL10n();
        expect(
          find.text(l10n.deleteAccountRelayConfirmationFailed),
          findsOneWidget,
        );
        expect(
          find.text('Failed to publish deletion request to relays'),
          findsNothing,
        );
        expect(
          find.text(l10n.deleteAccountContentDeletionFailed),
          findsNothing,
        );
      },
    );

    testWidgets('explains when an account restriction blocks deletion', (
      tester,
    ) async {
      final deletionService = _MockAccountDeletionService();
      final authService = _MockAuthService();
      when(
        authService.checkAccountDeletionReadiness,
      ).thenAnswer((_) async => AccountDeletionReadiness.ready);
      when(
        () => deletionService.deleteAccount(
          onProgress: any(named: 'onProgress'),
          expectedPubkey: any(named: 'expectedPubkey'),
        ),
      ).thenAnswer(
        (_) async => DeleteAccountResult.failure(
          DeleteAccountFailureReason.accountRestricted,
        ),
      );
      late BuildContext capturedContext;
      await tester.pumpWidget(
        _wrapWithRouter(
          Builder(
            builder: (context) {
              capturedContext = context;
              return const Scaffold(body: SizedBox.shrink());
            },
          ),
        ),
      );

      await executeAccountDeletion(
        context: capturedContext,
        deletionService: deletionService,
        authService: authService,
      );
      await tester.pumpAndSettle();

      expect(
        find.text(_englishL10n().deleteAccountAccountRestricted),
        findsOneWidget,
      );

      await tester.tap(find.text(_englishL10n().supportContactSupport));
      await tester.pumpAndSettle();

      expect(find.text('Support destination'), findsOneWidget);
    });

    testWidgets('shows failure when local data cleanup fails after sign-out', (
      tester,
    ) async {
      final deletionService = _MockAccountDeletionService();
      final authService = _MockAuthService();
      // The pre-flight gate runs on every path; default it to ready so
      // these tests exercise the behaviour under test, not the gate.
      when(
        authService.checkAccountDeletionReadiness,
      ).thenAnswer((_) async => AccountDeletionReadiness.ready);
      when(
        () => deletionService.deleteAccount(
          onProgress: any(named: 'onProgress'),
          expectedPubkey: any(named: 'expectedPubkey'),
        ),
      ).thenAnswer((_) async => DeleteAccountResult.createSuccess('event-id'));
      when(authService.deleteKeycastAccount).thenAnswer(
        (_) async =>
            (success: true, error: null, requiresReauthentication: false),
      );
      when(
        () => authService.signOut(deleteKeys: true, deleteLocalUserData: true),
      ).thenThrow(
        const UserDataCleanupException(
          'Signed out but local user data cleanup failed',
        ),
      );

      late BuildContext capturedContext;
      await tester.pumpWidget(
        _wrapWithRouter(
          Builder(
            builder: (context) {
              capturedContext = context;
              return const Scaffold(body: SizedBox.shrink());
            },
          ),
        ),
      );

      await executeAccountDeletion(
        context: capturedContext,
        deletionService: deletionService,
        authService: authService,
      );
      await tester.pumpAndSettle();

      final l10n = _englishL10n();
      expect(
        find.text(l10n.deleteAccountLocalDataDeletionFailed),
        findsOneWidget,
      );
      expect(find.text(l10n.deleteAccountSuccess), findsNothing);
    });

    testWidgets('opted-in burn aborts when recovery is unavailable', (
      tester,
    ) async {
      final deletionService = _MockAccountDeletionService();
      final authService = _MockAuthService();
      // The pre-flight gate runs on every path; default it to ready so
      // these tests exercise the behaviour under test, not the gate.
      when(
        authService.checkAccountDeletionReadiness,
      ).thenAnswer((_) async => AccountDeletionReadiness.ready);
      late BuildContext capturedContext;
      await tester.pumpWidget(
        _wrapWithRouter(
          Builder(
            builder: (context) {
              capturedContext = context;
              return const Scaffold(body: SizedBox.shrink());
            },
          ),
        ),
      );

      await executeAccountDeletion(
        context: capturedContext,
        deletionService: deletionService,
        authService: authService,
        burnUsername: true,
        ownedUsername: (name: 'alice', canonical: 'alice'),
      );
      await tester.pumpAndSettle();

      verifyNever(
        () => deletionService.deleteAccount(
          onProgress: any(named: 'onProgress'),
          expectedPubkey: any(named: 'expectedPubkey'),
        ),
      );
      expect(
        find.text(
          lookupAppLocalizations(
            const Locale('en'),
          ).deleteAccountBurnUsernameFailed,
        ),
        findsOneWidget,
      );
    });

    testWidgets('opted-in burn success proceeds with deletion', (tester) async {
      final deletionService = _MockAccountDeletionService();
      final authService = _MockAuthService();
      // The pre-flight gate runs on every path; default it to ready so
      // these tests exercise the behaviour under test, not the gate.
      when(
        authService.checkAccountDeletionReadiness,
      ).thenAnswer((_) async => AccountDeletionReadiness.ready);
      final recoveryRepository = _MockAccountDeletionRecoveryRepository();
      when(
        () => recoveryRepository.prepare(username: any(named: 'username')),
      ).thenAnswer((_) async => _recoverableAttempt);
      when(
        () => recoveryRepository.submit(
          attemptId: any(named: 'attemptId'),
          vanishEventId: any(named: 'vanishEventId'),
        ),
      ).thenAnswer((_) async => _completedAttempt);
      when(
        () => deletionService.deleteAccount(
          onProgress: any(named: 'onProgress'),
          expectedPubkey: any(named: 'expectedPubkey'),
        ),
      ).thenAnswer((_) async => DeleteAccountResult.createSuccess('event-id'));
      when(authService.deleteKeycastAccount).thenAnswer(
        (_) async =>
            (success: true, error: null, requiresReauthentication: false),
      );
      when(
        () => authService.signOut(deleteKeys: true, deleteLocalUserData: true),
      ).thenAnswer((_) async {});

      late BuildContext capturedContext;
      await tester.pumpWidget(
        _wrapWithRouter(
          Builder(
            builder: (context) {
              capturedContext = context;
              return const Scaffold(body: SizedBox.shrink());
            },
          ),
        ),
      );

      await executeAccountDeletion(
        context: capturedContext,
        deletionService: deletionService,
        authService: authService,
        deletionRecoveryRepository: recoveryRepository,
        burnUsername: true,
        ownedUsername: (name: 'alice', canonical: 'alice'),
      );
      await tester.pumpAndSettle();

      verify(
        () => deletionService.deleteAccount(
          onProgress: any(named: 'onProgress'),
          expectedPubkey: any(named: 'expectedPubkey'),
        ),
      ).called(1);
      verify(() => recoveryRepository.prepare(username: 'alice')).called(1);
      verify(
        () => recoveryRepository.submit(
          attemptId: 'attempt-id',
          vanishEventId: 'event-id',
        ),
      ).called(1);
      verifyNever(authService.deleteKeycastAccount);
    });

    testWidgets('does not release the username when burn is not opted in', (
      tester,
    ) async {
      final deletionService = _MockAccountDeletionService();
      final authService = _MockAuthService();
      final recoveryRepository = _MockAccountDeletionRecoveryRepository();
      // The pre-flight gate runs on every path; default it to ready so
      // these tests exercise the behaviour under test, not the gate.
      when(
        authService.checkAccountDeletionReadiness,
      ).thenAnswer((_) async => AccountDeletionReadiness.ready);
      when(
        () => deletionService.deleteAccount(
          onProgress: any(named: 'onProgress'),
          expectedPubkey: any(named: 'expectedPubkey'),
        ),
      ).thenAnswer((_) async => DeleteAccountResult.createSuccess('event-id'));
      when(authService.deleteKeycastAccount).thenAnswer(
        (_) async =>
            (success: true, error: null, requiresReauthentication: false),
      );
      when(
        () => authService.signOut(deleteKeys: true, deleteLocalUserData: true),
      ).thenAnswer((_) async {});
      when(
        recoveryRepository.prepare,
      ).thenAnswer((_) async => _recoverableAttemptWithoutUsername);
      when(
        () => recoveryRepository.submit(
          attemptId: 'attempt-id',
          vanishEventId: 'event-id',
        ),
      ).thenAnswer((_) async => _completedAttemptWithoutUsername);

      late BuildContext capturedContext;
      await tester.pumpWidget(
        _wrapWithRouter(
          Builder(
            builder: (context) {
              capturedContext = context;
              return const Scaffold(body: SizedBox.shrink());
            },
          ),
        ),
      );

      await executeAccountDeletion(
        context: capturedContext,
        deletionService: deletionService,
        authService: authService,
        deletionRecoveryRepository: recoveryRepository,
        ownedUsername: (name: 'alice', canonical: 'alice'),
      );
      await tester.pumpAndSettle();

      verify(recoveryRepository.prepare).called(1);
      verifyNever(() => recoveryRepository.prepare(username: 'alice'));
      verify(
        () => recoveryRepository.submit(
          attemptId: 'attempt-id',
          vanishEventId: 'event-id',
        ),
      ).called(1);
    });

    testWidgets('opted-in burn aborts when recovery repository is null', (
      tester,
    ) async {
      final deletionService = _MockAccountDeletionService();
      final authService = _MockAuthService();
      // The pre-flight gate runs on every path; default it to ready so
      // these tests exercise the behaviour under test, not the gate.
      when(
        authService.checkAccountDeletionReadiness,
      ).thenAnswer((_) async => AccountDeletionReadiness.ready);

      late BuildContext capturedContext;
      await tester.pumpWidget(
        _wrapWithRouter(
          Builder(
            builder: (context) {
              capturedContext = context;
              return const Scaffold(body: SizedBox.shrink());
            },
          ),
        ),
      );

      // Recovery repository omitted: an opted-in release must abort.
      await executeAccountDeletion(
        context: capturedContext,
        deletionService: deletionService,
        authService: authService,
        burnUsername: true,
        ownedUsername: (name: 'alice', canonical: 'alice'),
      );
      await tester.pumpAndSettle();

      verifyNever(
        () => deletionService.deleteAccount(
          onProgress: any(named: 'onProgress'),
          expectedPubkey: any(named: 'expectedPubkey'),
        ),
      );
      expect(
        find.text(
          lookupAppLocalizations(
            const Locale('en'),
          ).deleteAccountBurnUsernameFailed,
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'discloses the release when content deletion fails after burn',
      (tester) async {
        final deletionService = _MockAccountDeletionService();
        final authService = _MockAuthService();
        // The pre-flight gate runs on every path; default it to ready so
        // these tests exercise the behaviour under test, not the gate.
        when(
          authService.checkAccountDeletionReadiness,
        ).thenAnswer((_) async => AccountDeletionReadiness.ready);
        final recoveryRepository = _MockAccountDeletionRecoveryRepository();
        when(
          () => recoveryRepository.prepare(username: any(named: 'username')),
        ).thenAnswer((_) async => _recoverableAttempt);
        when(
          () => deletionService.deleteAccount(
            onProgress: any(named: 'onProgress'),
          ),
        ).thenAnswer(
          (_) async => DeleteAccountResult.failure(
            DeleteAccountFailureReason.vanishNotConfirmed,
            diagnosticError: 'relay down',
          ),
        );

        late BuildContext capturedContext;
        await tester.pumpWidget(
          _wrapWithRouter(
            Builder(
              builder: (context) {
                capturedContext = context;
                return const Scaffold(body: SizedBox.shrink());
              },
            ),
          ),
        );

        await executeAccountDeletion(
          context: capturedContext,
          deletionService: deletionService,
          authService: authService,
          deletionRecoveryRepository: recoveryRepository,
          burnUsername: true,
          ownedUsername: (name: 'alice', canonical: 'alice'),
        );
        await tester.pumpAndSettle();

        expect(
          find.text(
            lookupAppLocalizations(
              const Locale('en'),
            ).accountDeletionRecoveryBody,
          ),
          findsOneWidget,
        );
      },
    );

    // These two pin a deliberate design decision, not an implementation
    // detail. From review on #6335: "the current behavior intentionally blocks
    // sign-out for registered users if Keycast account deletion fails."
    //
    // The reason it matters: if a divineOAuth user is signed out locally while
    // their Keycast account survives, they can log straight back into an
    // account they believe they deleted. Blocking sign-out keeps them in a
    // state that is at least honest about having failed.
    //
    // Until now that behaviour was guarded by nothing. The only assertion of it
    // lived in a `skip: true` group in account_deletion_flow_test.dart, and as
    // written (`signOut(deleteKeys: true)`) it did not match the call shape
    // production uses, so it could not have failed even if revived.
    //
    // The guard is `!keycastSuccess && authService.isRegistered`. Both halves
    // are load-bearing, so both are pinned: the first test proves registered
    // users are held back, the second proves everyone else is not. Dropping the
    // `&& isRegistered` conjunct would permanently stop every anonymous,
    // imported-nsec, amber and bunker user from deleting their own content —
    // `oauthClientProvider` is non-nullable, so they all reach
    // `getSessionOrRefresh()`, have no refresh token, and get `(false, …)` too.
    testWidgets(
      'does not sign out a registered user when keycast deletion fails',
      (tester) async {
        final deletionService = _MockAccountDeletionService();
        final authService = _MockAuthService();
        when(
          authService.checkAccountDeletionReadiness,
        ).thenAnswer((_) async => AccountDeletionReadiness.ready);
        when(
          () => deletionService.deleteAccount(
            onProgress: any(named: 'onProgress'),
            expectedPubkey: any(named: 'expectedPubkey'),
          ),
        ).thenAnswer(
          (_) async => DeleteAccountResult.createSuccess('event-id'),
        );
        // Content deletion succeeded; the server-side account deletion did
        // not, and not for a credential reason — keycast answers a genuine
        // database failure with 503, which sets no reauth flag (#7875).
        when(authService.deleteKeycastAccount).thenAnswer(
          (_) async => (
            success: false,
            error: 'Server error (503). Please try again later.',
            requiresReauthentication: false,
          ),
        );
        when(() => authService.isRegistered).thenReturn(true);
        when(
          () =>
              authService.signOut(deleteKeys: true, deleteLocalUserData: true),
        ).thenAnswer((_) async {});

        late BuildContext capturedContext;
        await tester.pumpWidget(
          _wrapWithRouter(
            Builder(
              builder: (context) {
                capturedContext = context;
                return const Scaffold(body: SizedBox.shrink());
              },
            ),
          ),
        );

        await executeAccountDeletion(
          context: capturedContext,
          deletionService: deletionService,
          authService: authService,
        );
        await tester.pumpAndSettle();

        // The invariant. Asserted with the exact call shape production uses —
        // a looser matcher would pass vacuously.
        verifyNever(
          () =>
              authService.signOut(deleteKeys: true, deleteLocalUserData: true),
        );

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(
          find.text(l10n.deleteAccountServerDeletionFailed),
          findsOneWidget,
        );
        // Not the success message, and not the pre-flight message — this
        // failure happened after publishing, so the gate is not involved.
        expect(find.text(l10n.deleteAccountSuccess), findsNothing);
        expect(find.text(l10n.deleteAccountReauthRequired), findsNothing);
        // #7875: a 503 is not a credential problem, so the user must not be
        // sent to a re-login that cannot clear it.
        expect(
          find.text(l10n.deleteAccountServerDeletionRequiresReauth),
          findsNothing,
        );
      },
    );

    // A credential refusal from keycast arrives *after* the vanish and the
    // kind-5 sweep have been published and confirmed by a relay, so the copy
    // may not repeat the pre-flight message — `deleteAccountReauthRequired`
    // ends with "Nothing has been deleted yet", which is false here and cannot
    // be walked back once a NIP-62 vanish is on third-party relays. It also may
    // not blame the connection, because retrying the same credential fails
    // identically.
    //
    // The failure is recognised from the typed flag, not the message: keycast
    // answers this 403 with its own prose ("requires the Divine app or web
    // login with your private key"), which shares no phrase with anything the
    // client could match against.
    testWidgets(
      'tells a registered user to sign in again without claiming nothing '
      'was deleted',
      (tester) async {
        final deletionService = _MockAccountDeletionService();
        final authService = _MockAuthService();
        when(
          authService.checkAccountDeletionReadiness,
        ).thenAnswer((_) async => AccountDeletionReadiness.ready);
        when(
          () => deletionService.deleteAccount(
            onProgress: any(named: 'onProgress'),
            expectedPubkey: any(named: 'expectedPubkey'),
          ),
        ).thenAnswer(
          (_) async => DeleteAccountResult.createSuccess('event-id'),
        );
        when(authService.deleteKeycastAccount).thenAnswer(
          (_) async => (
            success: false,
            error:
                'Account deletion requires the Divine app or web login with '
                'your private key',
            requiresReauthentication: true,
          ),
        );
        when(() => authService.isRegistered).thenReturn(true);
        when(
          () =>
              authService.signOut(deleteKeys: true, deleteLocalUserData: true),
        ).thenAnswer((_) async {});

        late BuildContext capturedContext;
        await tester.pumpWidget(
          _wrapWithRouter(
            Builder(
              builder: (context) {
                capturedContext = context;
                return const Scaffold(body: SizedBox.shrink());
              },
            ),
          ),
        );

        await executeAccountDeletion(
          context: capturedContext,
          deletionService: deletionService,
          authService: authService,
        );
        await tester.pumpAndSettle();

        verifyNever(
          () =>
              authService.signOut(deleteKeys: true, deleteLocalUserData: true),
        );

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(
          find.text(l10n.deleteAccountServerDeletionRequiresReauth),
          findsOneWidget,
        );
        // Not the retry copy: a refused credential fails identically on the
        // next attempt, so "try again" is the wrong instruction here.
        expect(find.text(l10n.deleteAccountServerDeletionFailed), findsNothing);
        // Not the pre-flight copy, which claims nothing has been deleted.
        expect(find.text(l10n.deleteAccountReauthRequired), findsNothing);
        expect(find.text(l10n.deleteAccountSuccess), findsNothing);
      },
    );

    testWidgets(
      'still signs out a non-registered user when keycast deletion fails',
      (tester) async {
        final deletionService = _MockAccountDeletionService();
        final authService = _MockAuthService();
        when(
          authService.checkAccountDeletionReadiness,
        ).thenAnswer((_) async => AccountDeletionReadiness.ready);
        when(
          () => deletionService.deleteAccount(
            onProgress: any(named: 'onProgress'),
            expectedPubkey: any(named: 'expectedPubkey'),
          ),
        ).thenAnswer(
          (_) async => DeleteAccountResult.createSuccess('event-id'),
        );
        // Every non-OAuth user reaches this call and fails it: there is no
        // Keycast session to use, so a failure here is expected and benign.
        when(authService.deleteKeycastAccount).thenAnswer(
          (_) async => (
            success: false,
            error: 'no keycast session',
            requiresReauthentication: false,
          ),
        );
        when(() => authService.isRegistered).thenReturn(false);
        when(
          () =>
              authService.signOut(deleteKeys: true, deleteLocalUserData: true),
        ).thenAnswer((_) async {});

        late BuildContext capturedContext;
        await tester.pumpWidget(
          _wrapWithRouter(
            Builder(
              builder: (context) {
                capturedContext = context;
                return const Scaffold(body: SizedBox.shrink());
              },
            ),
          ),
        );

        await executeAccountDeletion(
          context: capturedContext,
          deletionService: deletionService,
          authService: authService,
        );
        await tester.pumpAndSettle();

        // They are not held back — they have no server-side account to strand.
        verify(
          () =>
              authService.signOut(deleteKeys: true, deleteLocalUserData: true),
        ).called(1);

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.text(l10n.deleteAccountSuccess), findsOneWidget);
        expect(find.text(l10n.deleteAccountServerDeletionFailed), findsNothing);
      },
    );

    testWidgets(
      'keeps recovery available while the coordinator is processing',
      (tester) async {
        final deletionService = _MockAccountDeletionService();
        final authService = _MockAuthService();
        // The pre-flight gate runs on every path; default it to ready so
        // these tests exercise the behaviour under test, not the gate.
        when(
          authService.checkAccountDeletionReadiness,
        ).thenAnswer((_) async => AccountDeletionReadiness.ready);
        final recoveryRepository = _MockAccountDeletionRecoveryRepository();
        when(
          () => recoveryRepository.prepare(username: any(named: 'username')),
        ).thenAnswer((_) async => _recoverableAttempt);
        when(
          () => recoveryRepository.submit(
            attemptId: any(named: 'attemptId'),
            vanishEventId: any(named: 'vanishEventId'),
          ),
        ).thenAnswer(
          (_) async => const AccountDeletionAttempt(
            id: 'attempt-id',
            status: AccountDeletionAttemptStatus.processing,
            username: 'alice',
          ),
        );
        when(
          () => deletionService.deleteAccount(
            onProgress: any(named: 'onProgress'),
          ),
        ).thenAnswer(
          (_) async => DeleteAccountResult.createSuccess('event-id'),
        );
        when(authService.deleteKeycastAccount).thenAnswer(
          (_) async => (
            success: false,
            error: 'fk error',
            requiresReauthentication: false,
          ),
        );
        when(() => authService.isRegistered).thenReturn(true);

        late BuildContext capturedContext;
        await tester.pumpWidget(
          _wrapWithRouter(
            Builder(
              builder: (context) {
                capturedContext = context;
                return const Scaffold(body: SizedBox.shrink());
              },
            ),
          ),
        );

        await executeAccountDeletion(
          context: capturedContext,
          deletionService: deletionService,
          authService: authService,
          deletionRecoveryRepository: recoveryRepository,
          burnUsername: true,
          ownedUsername: (name: 'alice', canonical: 'alice'),
        );
        await tester.pumpAndSettle();

        expect(
          find.text(
            lookupAppLocalizations(
              const Locale('en'),
            ).accountDeletionFinishingBody,
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            lookupAppLocalizations(
              const Locale('en'),
            ).accountDeletionRestoreUsername,
          ),
          findsNothing,
        );
      },
    );

    testWidgets('prepare network failure aborts before relay deletion', (
      tester,
    ) async {
      final deletionService = _MockAccountDeletionService();
      final authService = _MockAuthService();
      // The pre-flight gate runs on every path; default it to ready so
      // these tests exercise the behaviour under test, not the gate.
      when(
        authService.checkAccountDeletionReadiness,
      ).thenAnswer((_) async => AccountDeletionReadiness.ready);
      final recoveryRepository = _MockAccountDeletionRecoveryRepository();
      when(
        () => recoveryRepository.prepare(username: any(named: 'username')),
      ).thenThrow(const AccountDeletionRecoveryException('connection lost'));

      late BuildContext capturedContext;
      await tester.pumpWidget(
        _wrapWithRouter(
          Builder(
            builder: (context) {
              capturedContext = context;
              return const Scaffold(body: SizedBox.shrink());
            },
          ),
        ),
      );

      await executeAccountDeletion(
        context: capturedContext,
        deletionService: deletionService,
        authService: authService,
        deletionRecoveryRepository: recoveryRepository,
        burnUsername: true,
        ownedUsername: (name: 'alice', canonical: 'alice'),
      );
      await tester.pumpAndSettle();

      verifyNever(
        () => deletionService.deleteAccount(
          onProgress: any(named: 'onProgress'),
          expectedPubkey: any(named: 'expectedPubkey'),
        ),
      );
      expect(
        find.text(
          lookupAppLocalizations(
            const Locale('en'),
          ).deleteAccountBurnUsernameFailed,
        ),
        findsOneWidget,
      );
    });

    testWidgets('coordinator outage uses generic copy without a username', (
      tester,
    ) async {
      final deletionService = _MockAccountDeletionService();
      final authService = _MockAuthService();
      final recoveryRepository = _MockAccountDeletionRecoveryRepository();
      when(
        authService.checkAccountDeletionReadiness,
      ).thenAnswer((_) async => AccountDeletionReadiness.ready);
      when(recoveryRepository.prepare).thenThrow(
        const AccountDeletionRecoveryException('connection lost'),
      );

      late BuildContext capturedContext;
      await tester.pumpWidget(
        _wrapWithRouter(
          Builder(
            builder: (context) {
              capturedContext = context;
              return const Scaffold(body: SizedBox.shrink());
            },
          ),
        ),
      );

      await executeAccountDeletion(
        context: capturedContext,
        deletionService: deletionService,
        authService: authService,
        deletionRecoveryRepository: recoveryRepository,
      );
      await tester.pumpAndSettle();

      final l10n = _englishL10n();
      expect(find.text(l10n.deleteAccountDeletionIncomplete), findsOneWidget);
      expect(find.text(l10n.deleteAccountBurnUsernameFailed), findsNothing);
      verifyNever(
        () => deletionService.deleteAccount(
          onProgress: any(named: 'onProgress'),
          expectedPubkey: any(named: 'expectedPubkey'),
        ),
      );
    });

    testWidgets('opted-in burn aborts when no username is owned', (
      tester,
    ) async {
      final deletionService = _MockAccountDeletionService();
      final authService = _MockAuthService();
      // The pre-flight gate runs on every path; default it to ready so
      // these tests exercise the behaviour under test, not the gate.
      when(
        authService.checkAccountDeletionReadiness,
      ).thenAnswer((_) async => AccountDeletionReadiness.ready);

      late BuildContext capturedContext;
      await tester.pumpWidget(
        _wrapWithRouter(
          Builder(
            builder: (context) {
              capturedContext = context;
              return const Scaffold(body: SizedBox.shrink());
            },
          ),
        ),
      );

      // Opted in (burnUsername: true) but ownedUsername omitted (null): the
      // burn cannot be honored, so deletion must abort, not proceed.
      await executeAccountDeletion(
        context: capturedContext,
        deletionService: deletionService,
        authService: authService,
        burnUsername: true,
      );
      await tester.pumpAndSettle();

      verifyNever(
        () => deletionService.deleteAccount(
          onProgress: any(named: 'onProgress'),
          expectedPubkey: any(named: 'expectedPubkey'),
        ),
      );
    });

    testWidgets('aborts before burn when the account changed', (tester) async {
      final deletionService = _MockAccountDeletionService();
      final authService = _MockAuthService();
      // The pre-flight gate runs on every path; default it to ready so
      // these tests exercise the behaviour under test, not the gate.
      when(
        authService.checkAccountDeletionReadiness,
      ).thenAnswer((_) async => AccountDeletionReadiness.ready);
      when(
        () => authService.currentPublicKeyHex,
      ).thenReturn('now_a_different_pk');

      final announcements = <Map<Object?, Object?>>[];
      tester.binding.defaultBinaryMessenger
          .setMockDecodedMessageHandler<Object?>(SystemChannels.accessibility, (
            Object? message,
          ) async {
            if (message is Map) announcements.add(message);
            return null;
          });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockDecodedMessageHandler<Object?>(
              SystemChannels.accessibility,
              null,
            ),
      );

      late BuildContext capturedContext;
      await tester.pumpWidget(
        _wrapWithRouter(
          Builder(
            builder: (context) {
              capturedContext = context;
              return const Scaffold(body: SizedBox.shrink());
            },
          ),
        ),
      );

      await executeAccountDeletion(
        context: capturedContext,
        deletionService: deletionService,
        authService: authService,
        burnUsername: true,
        ownedUsername: (name: 'rabble', canonical: 'rabble'),
        confirmedPubkey: _pubkeyHex,
      );
      await tester.pumpAndSettle();

      verifyNever(
        () => deletionService.deleteAccount(
          onProgress: any(named: 'onProgress'),
          expectedPubkey: any(named: 'expectedPubkey'),
        ),
      );
      expect(
        find.text(
          lookupAppLocalizations(
            const Locale('en'),
          ).deleteAccountAccountChanged,
        ),
        findsOneWidget,
      );

      // The abort outcome is spoken to screen-reader users, not just shown.
      final announced = announcements
          .where((message) => message['type'] == 'announce')
          .map((message) => (message['data'] as Map?)?['message'])
          .toList();
      expect(
        announced,
        contains(
          lookupAppLocalizations(
            const Locale('en'),
          ).deleteAccountAccountChanged,
        ),
      );
    });

    testWidgets(
      'localizes the account-changed outcome when the service reports it',
      (tester) async {
        final deletionService = _MockAccountDeletionService();
        final authService = _MockAuthService();
        // The pre-flight gate runs on every path; default it to ready so
        // these tests exercise the behaviour under test, not the gate.
        when(
          authService.checkAccountDeletionReadiness,
        ).thenAnswer((_) async => AccountDeletionReadiness.ready);
        // UI pre-check passes (signer still matches), but the service reports a
        // mid-flight switch — the UI must localize, not surface the raw string.
        when(() => authService.currentPublicKeyHex).thenReturn(_pubkeyHex);
        when(
          () => deletionService.deleteAccount(
            onProgress: any(named: 'onProgress'),
            expectedPubkey: any(named: 'expectedPubkey'),
          ),
        ).thenAnswer(
          (_) async => DeleteAccountResult.failure(
            DeleteAccountFailureReason.accountChanged,
            diagnosticError: 'Signed-in account changed; deletion aborted',
          ),
        );

        late BuildContext capturedContext;
        await tester.pumpWidget(
          _wrapWithRouter(
            Builder(
              builder: (context) {
                capturedContext = context;
                return const Scaffold(body: SizedBox.shrink());
              },
            ),
          ),
        );

        await executeAccountDeletion(
          context: capturedContext,
          deletionService: deletionService,
          authService: authService,
          confirmedPubkey: _pubkeyHex,
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.text(l10n.deleteAccountAccountChanged), findsOneWidget);
        // The raw service string must never reach the user.
        expect(
          find.text('Signed-in account changed; deletion aborted'),
          findsNothing,
        );
      },
    );

    testWidgets(
      'acknowledges a confirmed vanish when the account changes afterward',
      (tester) async {
        final deletionService = _MockAccountDeletionService();
        final authService = _MockAuthService();
        when(
          authService.checkAccountDeletionReadiness,
        ).thenAnswer((_) async => AccountDeletionReadiness.ready);
        when(() => authService.currentPublicKeyHex).thenReturn(_pubkeyHex);
        when(
          () => deletionService.deleteAccount(
            onProgress: any(named: 'onProgress'),
            expectedPubkey: any(named: 'expectedPubkey'),
          ),
        ).thenAnswer(
          (_) async => DeleteAccountResult.failure(
            DeleteAccountFailureReason.accountChangedAfterDeletion,
            diagnosticError:
                'Signed-in account changed after vanish confirmation',
          ),
        );

        late BuildContext capturedContext;
        await tester.pumpWidget(
          _wrapWithRouter(
            Builder(
              builder: (context) {
                capturedContext = context;
                return const Scaffold(body: SizedBox.shrink());
              },
            ),
          ),
        );

        await executeAccountDeletion(
          context: capturedContext,
          deletionService: deletionService,
          authService: authService,
          confirmedPubkey: _pubkeyHex,
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(
          find.text(l10n.deleteAccountAccountChangedAfterDeletion),
          findsOneWidget,
        );
        expect(find.text(l10n.deleteAccountAccountChanged), findsNothing);
        verifyNever(authService.deleteKeycastAccount);
      },
    );

    testWidgets(
      'stops cleanup when the account changes as deletion returns success',
      (tester) async {
        final deletionService = _MockAccountDeletionService();
        final authService = _MockAuthService();
        var currentPubkey = _pubkeyHex;
        when(
          authService.checkAccountDeletionReadiness,
        ).thenAnswer((_) async => AccountDeletionReadiness.ready);
        when(
          () => authService.currentPublicKeyHex,
        ).thenAnswer((_) => currentPubkey);
        when(
          () => deletionService.deleteAccount(
            onProgress: any(named: 'onProgress'),
            expectedPubkey: any(named: 'expectedPubkey'),
          ),
        ).thenAnswer((_) async {
          currentPubkey = 'a_different_pubkey_than_confirmed';
          return DeleteAccountResult.createSuccess('event-id');
        });

        late BuildContext capturedContext;
        await tester.pumpWidget(
          _wrapWithRouter(
            Builder(
              builder: (context) {
                capturedContext = context;
                return const Scaffold(body: SizedBox.shrink());
              },
            ),
          ),
        );

        await executeAccountDeletion(
          context: capturedContext,
          deletionService: deletionService,
          authService: authService,
          confirmedPubkey: _pubkeyHex,
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(
          find.text(l10n.deleteAccountAccountChangedAfterDeletion),
          findsOneWidget,
        );
        verifyNever(authService.deleteKeycastAccount);
        verifyNever(
          () =>
              authService.signOut(deleteKeys: true, deleteLocalUserData: true),
        );
      },
    );

    testWidgets('does not sign out a new account after Keycast cleanup', (
      tester,
    ) async {
      final deletionService = _MockAccountDeletionService();
      final authService = _MockAuthService();
      var currentPubkey = _pubkeyHex;
      when(
        authService.checkAccountDeletionReadiness,
      ).thenAnswer((_) async => AccountDeletionReadiness.ready);
      when(
        () => authService.currentPublicKeyHex,
      ).thenAnswer((_) => currentPubkey);
      when(
        () => deletionService.deleteAccount(
          onProgress: any(named: 'onProgress'),
          expectedPubkey: any(named: 'expectedPubkey'),
        ),
      ).thenAnswer((_) async => DeleteAccountResult.createSuccess('event-id'));
      when(authService.deleteKeycastAccount).thenAnswer((_) async {
        currentPubkey = 'a_different_pubkey_than_confirmed';
        return (success: true, error: null, requiresReauthentication: false);
      });

      late BuildContext capturedContext;
      await tester.pumpWidget(
        _wrapWithRouter(
          Builder(
            builder: (context) {
              capturedContext = context;
              return const Scaffold(body: SizedBox.shrink());
            },
          ),
        ),
      );

      await executeAccountDeletion(
        context: capturedContext,
        deletionService: deletionService,
        authService: authService,
        confirmedPubkey: _pubkeyHex,
      );
      await tester.pumpAndSettle();

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(
        find.text(l10n.deleteAccountAccountChangedAfterDeletion),
        findsOneWidget,
      );
      verify(authService.deleteKeycastAccount).called(1);
      verifyNever(
        () => authService.signOut(deleteKeys: true, deleteLocalUserData: true),
      );
    });

    testWidgets(
      'uses partial-deletion copy when a failed Keycast call switches account',
      (tester) async {
        final deletionService = _MockAccountDeletionService();
        final authService = _MockAuthService();
        var currentPubkey = _pubkeyHex;
        when(
          authService.checkAccountDeletionReadiness,
        ).thenAnswer((_) async => AccountDeletionReadiness.ready);
        when(
          () => authService.currentPublicKeyHex,
        ).thenAnswer((_) => currentPubkey);
        when(() => authService.isRegistered).thenReturn(true);
        when(
          () => deletionService.deleteAccount(
            onProgress: any(named: 'onProgress'),
            expectedPubkey: any(named: 'expectedPubkey'),
          ),
        ).thenAnswer(
          (_) async => DeleteAccountResult.createSuccess('event-id'),
        );
        when(authService.deleteKeycastAccount).thenAnswer((_) async {
          currentPubkey = 'a_different_pubkey_than_confirmed';
          return (
            success: false,
            error: 'server refused',
            requiresReauthentication: false,
          );
        });

        late BuildContext capturedContext;
        await tester.pumpWidget(
          _wrapWithRouter(
            Builder(
              builder: (context) {
                capturedContext = context;
                return const Scaffold(body: SizedBox.shrink());
              },
            ),
          ),
        );

        await executeAccountDeletion(
          context: capturedContext,
          deletionService: deletionService,
          authService: authService,
          confirmedPubkey: _pubkeyHex,
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(
          find.text(l10n.deleteAccountAccountChangedAfterDeletion),
          findsOneWidget,
        );
        expect(find.text(l10n.deleteAccountServerDeletionFailed), findsNothing);
        verifyNever(
          () =>
              authService.signOut(deleteKeys: true, deleteLocalUserData: true),
        );
      },
    );

    // THE regression test for #6335. Production published the irreversible
    // NIP-62 vanish and the kind-5 sweep, and only then asked Keycast to delete
    // the account — which refused with 403 for any user whose token had been
    // refreshed. 275 denials across 57 users in 30 days, 48 of whom never
    // completed: content broadcast for deletion, account still alive, still
    // signed in. Nothing destructive may run before the gate clears.
    testWidgets('publishes nothing when the session cannot authorize deletion', (
      tester,
    ) async {
      final deletionService = _MockAccountDeletionService();
      final authService = _MockAuthService();
      when(authService.checkAccountDeletionReadiness).thenAnswer(
        (_) async => AccountDeletionReadiness.requiresReauthentication,
      );
      when(() => authService.currentPublicKeyHex).thenReturn(_pubkeyHex);

      late BuildContext capturedContext;
      await tester.pumpWidget(
        _wrapWithRouter(
          Builder(
            builder: (context) {
              capturedContext = context;
              return const Scaffold(body: SizedBox.shrink());
            },
          ),
        ),
      );

      await executeAccountDeletion(
        context: capturedContext,
        deletionService: deletionService,
        authService: authService,
        confirmedPubkey: _pubkeyHex,
      );
      await tester.pumpAndSettle();

      // Nothing irreversible was attempted.
      verifyNever(
        () => deletionService.deleteAccount(
          onProgress: any(named: 'onProgress'),
          expectedPubkey: any(named: 'expectedPubkey'),
        ),
      );
      verifyNever(authService.deleteKeycastAccount);
      verifyNever(
        () => authService.signOut(deleteKeys: true, deleteLocalUserData: true),
      );

      // The user is told to sign in again, and never the post-publish copy that
      // reports deletion requests as already sent.
      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.deleteAccountReauthRequired), findsOneWidget);
      expect(find.text(l10n.deleteAccountServerDeletionFailed), findsNothing);
    });

    testWidgets('proceeds when confirmedPubkey matches the current account', (
      tester,
    ) async {
      final deletionService = _MockAccountDeletionService();
      final authService = _MockAuthService();
      // The pre-flight gate runs on every path; default it to ready so
      // these tests exercise the behaviour under test, not the gate.
      when(
        authService.checkAccountDeletionReadiness,
      ).thenAnswer((_) async => AccountDeletionReadiness.ready);
      when(() => authService.currentPublicKeyHex).thenReturn(_pubkeyHex);
      when(
        () => deletionService.deleteAccount(
          onProgress: any(named: 'onProgress'),
          expectedPubkey: any(named: 'expectedPubkey'),
        ),
      ).thenAnswer((_) async => DeleteAccountResult.createSuccess('event-id'));
      when(authService.deleteKeycastAccount).thenAnswer(
        (_) async =>
            (success: true, error: null, requiresReauthentication: false),
      );
      when(
        () => authService.signOut(deleteKeys: true, deleteLocalUserData: true),
      ).thenAnswer((_) async {});

      late BuildContext capturedContext;
      await tester.pumpWidget(
        _wrapWithRouter(
          Builder(
            builder: (context) {
              capturedContext = context;
              return const Scaffold(body: SizedBox.shrink());
            },
          ),
        ),
      );

      await executeAccountDeletion(
        context: capturedContext,
        deletionService: deletionService,
        authService: authService,
        confirmedPubkey: _pubkeyHex,
      );
      await tester.pumpAndSettle();

      verify(
        () => deletionService.deleteAccount(
          onProgress: any(named: 'onProgress'),
          expectedPubkey: any(named: 'expectedPubkey'),
        ),
      ).called(1);
    });
  });
}
