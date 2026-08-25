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
import 'package:openvine/widgets/delete_account_dialog.dart'
    hide executeAccountDeletion;
import 'package:openvine/widgets/delete_account_dialog.dart'
    as dialog_api
    show executeAccountDeletion;

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

_MockAccountDeletionRecoveryRepository _successfulRecoveryRepository() {
  final repository = _MockAccountDeletionRecoveryRepository();
  when(
    repository.prepare,
  ).thenAnswer((_) async => _recoverableAttemptWithoutUsername);
  when(
    () => repository.submit(
      attemptId: any(named: 'attemptId'),
      vanishEventId: any(named: 'vanishEventId'),
    ),
  ).thenAnswer((_) async => _completedAttemptWithoutUsername);
  return repository;
}

Future<void> executeAccountDeletion({
  required BuildContext context,
  required AccountDeletionService deletionService,
  required AuthService authService,
  AccountDeletionRecoveryRepository? deletionRecoveryRepository,
  bool burnUsername = false,
  ({String name, String canonical})? ownedUsername,
  String? confirmedPubkey,
  String screenName = 'AccountDeletion',
}) => dialog_api.executeAccountDeletion(
  context: context,
  deletionService: deletionService,
  authService: authService,
  deletionRecoveryRepository:
      deletionRecoveryRepository ?? _successfulRecoveryRepository(),
  burnUsername: burnUsername,
  ownedUsername: ownedUsername,
  confirmedPubkey: confirmedPubkey,
  screenName: screenName,
);

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
  // Same reason the sign-out redirect router is disposed below: an
  // undisposed GoRouter keeps listening past the end of the test inside the
  // merged VGV isolate. Most tests in this file go through this helper.
  addTearDown(router.dispose);
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

/// Mirrors production's global auth redirect: once the account is signed out
/// every route resolves to /welcome, so the route deletion was started from —
/// and its context — is torn down while the flow is still running.
class _SignOutRedirectNotifier extends ChangeNotifier {
  bool signedOut = false;

  void signOut() {
    signedOut = true;
    notifyListeners();
  }
}

const _callerScreenMarker = 'Caller screen';
const _welcomeLocation = '/welcome';
const _welcomeMarker = 'Welcome destination';

Future<BuildContext> _pumpSignOutRedirectApp(
  WidgetTester tester,
  _SignOutRedirectNotifier redirect,
) async {
  late BuildContext capturedContext;
  final router = GoRouter(
    refreshListenable: redirect,
    redirect: (_, state) =>
        redirect.signedOut && state.matchedLocation != _welcomeLocation
        ? _welcomeLocation
        : null,
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Builder(
          builder: (context) {
            capturedContext = context;
            return const Scaffold(body: SizedBox.shrink());
          },
        ),
      ),
      GoRoute(
        path: _welcomeLocation,
        builder: (_, _) => const Scaffold(body: Text(_welcomeMarker)),
      ),
    ],
  );
  // Ordered so the router drops its refreshListenable subscription before the
  // notifier it listens to is torn down: addTearDown runs last-registered
  // first. Without this the router outlives the test inside the merged VGV
  // isolate, still listening.
  addTearDown(redirect.dispose);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
  return capturedContext;
}

void _stubSuccessfulDeletion(
  _MockAccountDeletionService deletionService,
  _MockAuthService authService,
) {
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
    (_) async => (success: true, error: null, requiresReauthentication: false),
  );
}

/// Collects what the deletion flow hands to screen readers.
List<Object?> _captureAnnouncements(WidgetTester tester) {
  final announced = <Object?>[];
  tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
    SystemChannels.accessibility,
    (message) async {
      if (message is Map && message['type'] == 'announce') {
        announced.add((message['data'] as Map?)?['message']);
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(
          SystemChannels.accessibility,
          null,
        ),
  );
  return announced;
}

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

    testWidgets(
      'confirms a successful deletion on the screen the redirect lands on',
      (tester) async {
        final deletionService = _MockAccountDeletionService();
        final authService = _MockAuthService();
        final redirect = _SignOutRedirectNotifier();
        _stubSuccessfulDeletion(deletionService, authService);
        // Holds sign-out open while the redirect runs, so the route deletion
        // was started from is gone before signOut returns — the device
        // timeline in #6450.
        final signOutGate = Completer<void>();
        when(
          () =>
              authService.signOut(deleteKeys: true, deleteLocalUserData: true),
        ).thenAnswer((_) async {
          redirect.signOut();
          await signOutGate.future;
        });
        final announced = _captureAnnouncements(tester);

        final capturedContext = await _pumpSignOutRedirectApp(tester, redirect);
        final deletion = executeAccountDeletion(
          context: capturedContext,
          deletionService: deletionService,
          authService: authService,
        );
        await tester.pumpAndSettle();
        expect(find.text(_welcomeMarker), findsOneWidget);

        signOutGate.complete();
        await deletion;
        await tester.pumpAndSettle();

        final l10n = _englishL10n();
        expect(find.text(l10n.deleteAccountSuccess), findsOneWidget);
        expect(announced, contains(l10n.deleteAccountSuccess));
      },
    );

    testWidgets(
      'leaves the redirect destination standing when the sheet is already gone',
      (tester) async {
        final deletionService = _MockAccountDeletionService();
        final authService = _MockAuthService();
        final redirect = _SignOutRedirectNotifier();
        _stubSuccessfulDeletion(deletionService, authService);
        final signOutGate = Completer<void>();
        when(
          () =>
              authService.signOut(deleteKeys: true, deleteLocalUserData: true),
        ).thenAnswer((_) async {
          redirect.signOut();
          await signOutGate.future;
        });

        final capturedContext = await _pumpSignOutRedirectApp(tester, redirect);
        final deletion = executeAccountDeletion(
          context: capturedContext,
          deletionService: deletionService,
          authService: authService,
        );
        // Stop one frame past the redirect, with the outgoing route still
        // animating away: the caller context is then still mounted when
        // sign-out returns, which is what a device reaches whenever the
        // sign-out work blocks frames. Dismissing the progress sheet by
        // popping the navigator took the freshly installed /welcome page
        // with it, leaving the app with no page at all.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));
        expect(
          capturedContext.mounted,
          isTrue,
          reason:
              'the scenario needs the caller still mounted after the '
              'redirect',
        );

        signOutGate.complete();
        await deletion;
        await tester.pumpAndSettle();

        expect(find.text(_welcomeMarker), findsOneWidget);
        expect(
          find.text(_englishL10n().deleteAccountSuccess),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'takes down its own sheet and leaves the screen under it standing',
      (tester) async {
        final deletionService = _MockAccountDeletionService();
        final authService = _MockAuthService();
        when(
          authService.checkAccountDeletionReadiness,
        ).thenAnswer((_) async => AccountDeletionReadiness.ready);
        // Held open so a frame can run while the sheet is up. Every other
        // test here finishes the deletion inside one microtask turn, so the
        // sheet is dismissed before it has ever built — and the dismissal
        // never reaches the route it captured.
        final deletionGate = Completer<DeleteAccountResult>();
        when(
          () => deletionService.deleteAccount(
            onProgress: any(named: 'onProgress'),
            expectedPubkey: any(named: 'expectedPubkey'),
          ),
        ).thenAnswer((_) => deletionGate.future);

        late BuildContext capturedContext;
        await tester.pumpWidget(
          _wrapWithRouter(
            Builder(
              builder: (context) {
                capturedContext = context;
                return const Scaffold(body: Text(_callerScreenMarker));
              },
            ),
          ),
        );

        final deletion = executeAccountDeletion(
          context: capturedContext,
          deletionService: deletionService,
          authService: authService,
        );
        // Not pumpAndSettle: the sheet's progress indicator never goes quiet.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(VineBottomSheet), findsOneWidget);

        deletionGate.complete(
          DeleteAccountResult.failure(
            DeleteAccountFailureReason.vanishNotConfirmed,
          ),
        );
        await deletion;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.byType(VineBottomSheet), findsNothing);
        expect(find.text(_callerScreenMarker), findsOneWidget);
        expect(
          find.text(_englishL10n().accountDeletionCancelAttemptBody),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'keeps the caller screen when the sheet is closed by system back',
      (tester) async {
        final deletionService = _MockAccountDeletionService();
        final authService = _MockAuthService();
        when(
          authService.checkAccountDeletionReadiness,
        ).thenAnswer((_) async => AccountDeletionReadiness.ready);
        final deletionGate = Completer<DeleteAccountResult>();
        when(
          () => deletionService.deleteAccount(
            onProgress: any(named: 'onProgress'),
            expectedPubkey: any(named: 'expectedPubkey'),
          ),
        ).thenAnswer((_) => deletionGate.future);

        late BuildContext capturedContext;
        await tester.pumpWidget(
          _wrapWithRouter(
            Builder(
              builder: (context) {
                capturedContext = context;
                return const Scaffold(body: Text(_callerScreenMarker));
              },
            ),
          ),
        );

        final deletion = executeAccountDeletion(
          context: capturedContext,
          deletionService: deletionService,
          authService: authService,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(VineBottomSheet), findsOneWidget);

        // Nothing stops an Android back press from closing the progress
        // sheet: it carries no PopScope, and isDismissible/enableDrag only
        // govern the barrier and the drag.
        await tester.binding.handlePopRoute();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(VineBottomSheet), findsNothing);

        deletionGate.complete(
          DeleteAccountResult.failure(
            DeleteAccountFailureReason.vanishNotConfirmed,
          ),
        );
        await deletion;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // The sheet is already gone, so there is nothing left to dismiss.
        expect(find.text(_callerScreenMarker), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

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

    testWidgets('username preparation failure keeps username guidance', (
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
      ).thenThrow(
        const AccountDeletionRecoveryException(
          'name server rejected request',
          stage: AccountDeletionRecoveryStage.usernamePreparation,
          statusCode: 409,
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

    testWidgets('coordinator outage explains deletion is unavailable', (
      tester,
    ) async {
      final deletionService = _MockAccountDeletionService();
      final authService = _MockAuthService();
      final recoveryRepository = _MockAccountDeletionRecoveryRepository();
      when(
        authService.checkAccountDeletionReadiness,
      ).thenAnswer((_) async => AccountDeletionReadiness.ready);
      when(recoveryRepository.prepare).thenThrow(
        const AccountDeletionRecoveryException(
          'Deletion attempt request failed (404)',
          stage: AccountDeletionRecoveryStage.coordinatorAttempt,
          statusCode: 404,
          indicatesMissingCoordinatorRoute: true,
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
      );
      await tester.pumpAndSettle();

      final l10n = _englishL10n();
      expect(find.text(l10n.deleteAccountDeletionUnavailable), findsOneWidget);
      expect(find.text(l10n.deleteAccountDeletionIncomplete), findsNothing);
      expect(find.text(l10n.deleteAccountBurnUsernameFailed), findsNothing);
      verifyNever(
        () => deletionService.deleteAccount(
          onProgress: any(named: 'onProgress'),
          expectedPubkey: any(named: 'expectedPubkey'),
        ),
      );
    });

    testWidgets(
      'an absent coordinator ignores burn option when choosing guidance',
      (tester) async {
        final deletionService = _MockAccountDeletionService();
        final authService = _MockAuthService();
        final recoveryRepository = _MockAccountDeletionRecoveryRepository();
        when(
          authService.checkAccountDeletionReadiness,
        ).thenAnswer((_) async => AccountDeletionReadiness.ready);
        when(() => recoveryRepository.prepare(username: 'alice')).thenThrow(
          const AccountDeletionRecoveryException(
            'Deletion attempt request failed (404)',
            stage: AccountDeletionRecoveryStage.coordinatorAttempt,
            statusCode: 404,
            indicatesMissingCoordinatorRoute: true,
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

        final l10n = _englishL10n();
        expect(
          find.text(l10n.deleteAccountDeletionUnavailable),
          findsOneWidget,
        );
        expect(find.text(l10n.deleteAccountBurnUsernameFailed), findsNothing);
        expect(find.text(l10n.deleteAccountDeletionIncomplete), findsNothing);
        verifyNever(
          () => deletionService.deleteAccount(
            onProgress: any(named: 'onProgress'),
            expectedPubkey: any(named: 'expectedPubkey'),
          ),
        );
      },
    );

    testWidgets('a transient coordinator failure keeps neutral guidance', (
      tester,
    ) async {
      final deletionService = _MockAccountDeletionService();
      final authService = _MockAuthService();
      final recoveryRepository = _MockAccountDeletionRecoveryRepository();
      when(
        authService.checkAccountDeletionReadiness,
      ).thenAnswer((_) async => AccountDeletionReadiness.ready);
      when(recoveryRepository.prepare).thenThrow(
        const AccountDeletionRecoveryException(
          'Deletion attempt request failed (503)',
          code: 'coordinator_unavailable',
          stage: AccountDeletionRecoveryStage.coordinatorAttempt,
          statusCode: 503,
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
      );
      await tester.pumpAndSettle();

      final l10n = _englishL10n();
      expect(find.text(l10n.deleteAccountDeletionIncomplete), findsOneWidget);
      expect(find.text(l10n.deleteAccountDeletionUnavailable), findsNothing);
      expect(find.text(l10n.deleteAccountBurnUsernameFailed), findsNothing);
      verifyNever(
        () => deletionService.deleteAccount(
          onProgress: any(named: 'onProgress'),
          expectedPubkey: any(named: 'expectedPubkey'),
        ),
      );
    });

    testWidgets('a coordinator without username support says to uncheck it', (
      tester,
    ) async {
      final deletionService = _MockAccountDeletionService();
      final authService = _MockAuthService();
      final recoveryRepository = _MockAccountDeletionRecoveryRepository();
      when(
        authService.checkAccountDeletionReadiness,
      ).thenAnswer((_) async => AccountDeletionReadiness.ready);
      // The coordinator answers this only for a username-bearing attempt, and
      // a username-free deletion succeeds against the same server — so the
      // 503 here has to keep the uncheck guidance rather than read as an
      // outage nothing can fix.
      when(() => recoveryRepository.prepare(username: 'alice')).thenThrow(
        const AccountDeletionRecoveryException(
          'Deletion attempt request failed (503)',
          code: 'username_recovery_unavailable',
          stage: AccountDeletionRecoveryStage.coordinatorAttempt,
          statusCode: 503,
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

      final l10n = _englishL10n();
      expect(find.text(l10n.deleteAccountBurnUsernameFailed), findsOneWidget);
      expect(find.text(l10n.deleteAccountDeletionUnavailable), findsNothing);
      expect(find.text(l10n.deleteAccountDeletionIncomplete), findsNothing);
      verifyNever(
        () => deletionService.deleteAccount(
          onProgress: any(named: 'onProgress'),
          expectedPubkey: any(named: 'expectedPubkey'),
        ),
      );
    });

    testWidgets('ambiguous post-username failure keeps neutral guidance', (
      tester,
    ) async {
      final deletionService = _MockAccountDeletionService();
      final authService = _MockAuthService();
      final recoveryRepository = _MockAccountDeletionRecoveryRepository();
      when(
        authService.checkAccountDeletionReadiness,
      ).thenAnswer((_) async => AccountDeletionReadiness.ready);
      when(() => recoveryRepository.prepare(username: 'alice')).thenThrow(
        const AccountDeletionRecoveryException(
          'Username confirmation request failed',
          stage: AccountDeletionRecoveryStage.coordinatorUsernameConfirmation,
          statusCode: 503,
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

      final l10n = _englishL10n();
      expect(find.text(l10n.deleteAccountDeletionIncomplete), findsOneWidget);
      expect(find.text(l10n.deleteAccountDeletionUnavailable), findsNothing);
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
      final recoveryRepository = _MockAccountDeletionRecoveryRepository();
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
        deletionRecoveryRepository: recoveryRepository,
        burnUsername: true,
      );
      await tester.pumpAndSettle();

      verifyNever(
        () => deletionService.deleteAccount(
          onProgress: any(named: 'onProgress'),
          expectedPubkey: any(named: 'expectedPubkey'),
        ),
      );
      final l10n = _englishL10n();
      expect(find.text(l10n.deleteAccountBurnUsernameFailed), findsOneWidget);
      expect(find.text(l10n.deleteAccountDeletionUnavailable), findsNothing);
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
          find.text(l10n.accountDeletionCancelAttemptBody),
          findsOneWidget,
        );
        verifyNever(authService.deleteKeycastAccount);
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
