// ABOUTME: Tests for the delete account confirmation dialog
// ABOUTME: Verifies that the DELETE confirmation is case-insensitive and trims whitespace

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/services/account_deletion_service.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:openvine/widgets/delete_account_confirmation.dart';
import 'package:openvine/widgets/delete_account_dialog.dart';
import 'package:profile_repository/profile_repository.dart';

class _MockAccountDeletionService extends Mock
    implements AccountDeletionService {}

class _MockAuthService extends Mock implements AuthService {}

class _MockProfileRepository extends Mock implements ProfileRepository {}

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

/// Minimal router wrapper so [context.pop()] works inside the dialog.
Widget _wrapWithRouter(Widget child) {
  final router = GoRouter(
    routes: [GoRoute(path: '/', builder: (_, state) => child)],
  );
  return MaterialApp.router(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    routerConfig: router,
  );
}

Future<void> _showDialog(
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
            onPressed: () => showDeleteAllContentWarningDialog(
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
  ElevatedButton,
  _englishL10n().deleteAccountDeleteAllContentButton,
);

Future<void> _tapBurnUsernameCheckbox(WidgetTester tester) async {
  await tester.drag(
    find.byType(SingleChildScrollView).first,
    const Offset(0, -160),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byType(Checkbox));
}

void main() {
  group('showDeleteAllContentWarningDialog – confirmation input', () {
    testWidgets('empty string keeps Delete button disabled', (tester) async {
      await _showDialog(tester);

      final l10n = _englishL10n();
      expect(find.text(l10n.deleteAccountWarningBody), findsOneWidget);
      expect(find.text(l10n.deleteAccountConfirmDeletePrompt), findsOneWidget);
      // Button should be disabled (onPressed == null → tapping does nothing)
      final button = tester.widget<ElevatedButton>(_deleteAllContentButton());
      expect(button.onPressed, isNull);
    });

    testWidgets('wrong word keeps Delete button disabled', (tester) async {
      await _showDialog(tester);

      await tester.enterText(find.byType(TextField), 'confirm');
      await tester.pump();

      final button = tester.widget<ElevatedButton>(_deleteAllContentButton());
      expect(button.onPressed, isNull);
    });

    testWidgets('exact uppercase DELETE enables the button', (tester) async {
      await _showDialog(tester);

      await tester.enterText(find.byType(TextField), 'DELETE');
      await tester.pump();

      final button = tester.widget<ElevatedButton>(_deleteAllContentButton());
      expect(button.onPressed, isNotNull);
    });

    testWidgets('lowercase delete enables the button', (tester) async {
      await _showDialog(tester);

      await tester.enterText(find.byType(TextField), 'delete');
      await tester.pump();

      final button = tester.widget<ElevatedButton>(_deleteAllContentButton());
      expect(button.onPressed, isNotNull);
    });

    testWidgets('mixed case Delete enables the button', (tester) async {
      await _showDialog(tester);

      await tester.enterText(find.byType(TextField), 'Delete');
      await tester.pump();

      final button = tester.widget<ElevatedButton>(_deleteAllContentButton());
      expect(button.onPressed, isNotNull);
    });

    testWidgets('DELETE with trailing whitespace enables the button', (
      tester,
    ) async {
      await _showDialog(tester);

      await tester.enterText(find.byType(TextField), 'DELETE ');
      await tester.pump();

      final button = tester.widget<ElevatedButton>(_deleteAllContentButton());
      expect(button.onPressed, isNotNull);
    });

    testWidgets('delete with leading whitespace enables the button', (
      tester,
    ) async {
      await _showDialog(tester);

      await tester.enterText(find.byType(TextField), ' delete');
      await tester.pump();

      final button = tester.widget<ElevatedButton>(_deleteAllContentButton());
      expect(button.onPressed, isNotNull);
    });

    testWidgets('tapping enabled button calls onConfirm', (tester) async {
      var called = false;
      await _showDialog(
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
      await _showDialog(tester);
      expect(find.byType(CheckboxListTile), findsNothing);
    });

    testWidgets('burn toggle is shown when a username is owned', (
      tester,
    ) async {
      await _showDialog(
        tester,
        ownedUsername: (name: 'Alice', canonical: 'alice'),
      );
      expect(find.byType(CheckboxListTile), findsOneWidget);
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
      await _showDialog(
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
      await _showDialog(
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

    testWidgets('dialog opens before the lookup resolves and reveals the '
        'toggle only once it completes', (tester) async {
      final completer = Completer<({String name, String canonical})?>();
      await tester.pumpWidget(
        _wrapWithRouter(
          Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                key: const Key('open'),
                onPressed: () => showDeleteAllContentWarningDialog(
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

      // Dialog is already open (lookup still pending) but no toggle yet.
      expect(_deleteAllContentButton(), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsNothing);

      completer.complete((name: 'Alice', canonical: 'alice'));
      await tester.pumpAndSettle();

      expect(find.byType(CheckboxListTile), findsOneWidget);
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
                onPressed: () => showDeleteAllContentWarningDialog(
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

      // Dialog is open with the lookup still pending, then the lookup fails.
      completer.completeError(Exception('lookup failed'));
      await tester.pumpAndSettle();

      expect(_deleteAllContentButton(), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('confirm passes the resolved handle back to onConfirm', (
      tester,
    ) async {
      ({String name, String canonical})? receivedOwned;
      var receivedBurn = false;
      await _showDialog(
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
      await _showDialog(tester, confirmation: _divineUsername());
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
      await _showDialog(tester, confirmation: _divineUsername());
      await tester.enterText(find.byType(TextField), 'DELETE');
      await tester.pump();
      final button = tester.widget<ElevatedButton>(_deleteAllContentButton());
      expect(button.onPressed, isNull);
    });

    testWidgets('typing the handle enables the button', (tester) async {
      await _showDialog(tester, confirmation: _divineUsername());
      await tester.enterText(find.byType(TextField), '@rabble.divine.video');
      await tester.pump();
      final button = tester.widget<ElevatedButton>(_deleteAllContentButton());
      expect(button.onPressed, isNotNull);
    });

    testWidgets('typing the handle without @ also enables the button', (
      tester,
    ) async {
      await _showDialog(tester, confirmation: _divineUsername());
      await tester.enterText(find.byType(TextField), 'rabble.divine.video');
      await tester.pump();
      final button = tester.widget<ElevatedButton>(_deleteAllContentButton());
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
      when(
        authService.deleteKeycastAccount,
      ).thenAnswer((_) async => (true, null));
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

    testWidgets('opted-in burn failure aborts deletion and shows error', (
      tester,
    ) async {
      final deletionService = _MockAccountDeletionService();
      final authService = _MockAuthService();
      // The pre-flight gate runs on every path; default it to ready so
      // these tests exercise the behaviour under test, not the gate.
      when(
        authService.checkAccountDeletionReadiness,
      ).thenAnswer((_) async => AccountDeletionReadiness.ready);
      final profileRepository = _MockProfileRepository();
      when(
        () => profileRepository.releaseUsername(name: any(named: 'name')),
      ).thenAnswer((_) async => const UsernameReleaseNotOwner());

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
        profileRepository: profileRepository,
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
      final profileRepository = _MockProfileRepository();
      when(
        () => profileRepository.releaseUsername(name: any(named: 'name')),
      ).thenAnswer((_) async => const UsernameReleaseSuccess());
      when(
        () => deletionService.deleteAccount(
          onProgress: any(named: 'onProgress'),
          expectedPubkey: any(named: 'expectedPubkey'),
        ),
      ).thenAnswer((_) async => DeleteAccountResult.createSuccess('event-id'));
      when(
        authService.deleteKeycastAccount,
      ).thenAnswer((_) async => (true, null));
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
        profileRepository: profileRepository,
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
      verify(() => profileRepository.releaseUsername(name: 'alice')).called(1);
    });

    testWidgets('does not release the username when burn is not opted in', (
      tester,
    ) async {
      final deletionService = _MockAccountDeletionService();
      final authService = _MockAuthService();
      // The pre-flight gate runs on every path; default it to ready so
      // these tests exercise the behaviour under test, not the gate.
      when(
        authService.checkAccountDeletionReadiness,
      ).thenAnswer((_) async => AccountDeletionReadiness.ready);
      final profileRepository = _MockProfileRepository();
      when(
        () => deletionService.deleteAccount(
          onProgress: any(named: 'onProgress'),
          expectedPubkey: any(named: 'expectedPubkey'),
        ),
      ).thenAnswer((_) async => DeleteAccountResult.createSuccess('event-id'));
      when(
        authService.deleteKeycastAccount,
      ).thenAnswer((_) async => (true, null));
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
        profileRepository: profileRepository,
        ownedUsername: (name: 'alice', canonical: 'alice'),
      );
      await tester.pumpAndSettle();

      verifyNever(
        () => profileRepository.releaseUsername(name: any(named: 'name')),
      );
    });

    testWidgets('opted-in burn aborts when profileRepository is null', (
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

      // profileRepository omitted (null): an opted-in burn must abort, not
      // delete.
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
        final profileRepository = _MockProfileRepository();
        when(
          () => profileRepository.releaseUsername(name: any(named: 'name')),
        ).thenAnswer((_) async => const UsernameReleaseSuccess());
        when(
          () => deletionService.deleteAccount(
            onProgress: any(named: 'onProgress'),
          ),
        ).thenAnswer((_) async => DeleteAccountResult.failure('relay down'));

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
          profileRepository: profileRepository,
          burnUsername: true,
          ownedUsername: (name: 'alice', canonical: 'alice'),
        );
        await tester.pumpAndSettle();

        expect(
          find.text(
            lookupAppLocalizations(
              const Locale('en'),
            ).deleteAccountBurnUsernameReleased('@alice.divine.video'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'discloses the release when keycast deletion fails after burn',
      (tester) async {
        final deletionService = _MockAccountDeletionService();
        final authService = _MockAuthService();
        // The pre-flight gate runs on every path; default it to ready so
        // these tests exercise the behaviour under test, not the gate.
        when(
          authService.checkAccountDeletionReadiness,
        ).thenAnswer((_) async => AccountDeletionReadiness.ready);
        final profileRepository = _MockProfileRepository();
        when(
          () => profileRepository.releaseUsername(name: any(named: 'name')),
        ).thenAnswer((_) async => const UsernameReleaseSuccess());
        when(
          () => deletionService.deleteAccount(
            onProgress: any(named: 'onProgress'),
          ),
        ).thenAnswer(
          (_) async => DeleteAccountResult.createSuccess('event-id'),
        );
        when(
          authService.deleteKeycastAccount,
        ).thenAnswer((_) async => (false, 'fk error'));
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
          profileRepository: profileRepository,
          burnUsername: true,
          ownedUsername: (name: 'alice', canonical: 'alice'),
        );
        await tester.pumpAndSettle();

        expect(
          find.text(
            lookupAppLocalizations(
              const Locale('en'),
            ).deleteAccountBurnUsernameReleased('@alice.divine.video'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'network-error release with name still owned aborts as failed',
      (tester) async {
        final deletionService = _MockAccountDeletionService();
        final authService = _MockAuthService();
        // The pre-flight gate runs on every path; default it to ready so
        // these tests exercise the behaviour under test, not the gate.
        when(
          authService.checkAccountDeletionReadiness,
        ).thenAnswer((_) async => AccountDeletionReadiness.ready);
        final profileRepository = _MockProfileRepository();
        when(
          () => profileRepository.releaseUsername(name: any(named: 'name')),
        ).thenAnswer((_) async => const UsernameReleaseNetworkError());
        when(() => authService.currentPublicKeyHex).thenReturn('abc');
        when(
          () => profileRepository.getUsernameByPubkey(
            pubkeyHex: any(named: 'pubkeyHex'),
          ),
        ).thenAnswer((_) async => (name: 'alice', canonical: 'alice'));

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
          profileRepository: profileRepository,
          burnUsername: true,
          ownedUsername: (name: 'alice', canonical: 'alice'),
        );
        await tester.pumpAndSettle();

        verifyNever(
          () => deletionService.deleteAccount(
            onProgress: any(named: 'onProgress'),
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
      },
    );

    testWidgets('network-error release we cannot resolve shows incomplete', (
      tester,
    ) async {
      final deletionService = _MockAccountDeletionService();
      final authService = _MockAuthService();
      // The pre-flight gate runs on every path; default it to ready so
      // these tests exercise the behaviour under test, not the gate.
      when(
        authService.checkAccountDeletionReadiness,
      ).thenAnswer((_) async => AccountDeletionReadiness.ready);
      final profileRepository = _MockProfileRepository();
      when(
        () => profileRepository.releaseUsername(name: any(named: 'name')),
      ).thenAnswer((_) async => const UsernameReleaseNetworkError());
      when(() => authService.currentPublicKeyHex).thenReturn('abc');
      when(
        () => profileRepository.getUsernameByPubkey(
          pubkeyHex: any(named: 'pubkeyHex'),
        ),
      ).thenAnswer((_) async => null);

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
        profileRepository: profileRepository,
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
          ).deleteAccountDeletionIncomplete,
        ),
        findsOneWidget,
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
      final profileRepository = _MockProfileRepository();

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
        profileRepository: profileRepository,
        burnUsername: true,
      );
      await tester.pumpAndSettle();

      verifyNever(
        () => deletionService.deleteAccount(
          onProgress: any(named: 'onProgress'),
          expectedPubkey: any(named: 'expectedPubkey'),
        ),
      );
      verifyNever(
        () => profileRepository.releaseUsername(name: any(named: 'name')),
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
      final profileRepository = _MockProfileRepository();
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
        profileRepository: profileRepository,
        burnUsername: true,
        ownedUsername: (name: 'rabble', canonical: 'rabble'),
        confirmedPubkey: _pubkeyHex,
      );
      await tester.pumpAndSettle();

      verifyNever(
        () => profileRepository.releaseUsername(name: any(named: 'name')),
      );
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
            'Signed-in account changed; deletion aborted',
            accountChanged: true,
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

    // THE regression test for #6335. Production published the irreversible
    // NIP-62 vanish and the kind-5 sweep, and only then asked Keycast to delete
    // the account — which refused with 403 for any user whose token had been
    // refreshed. 275 denials across 57 users in 30 days, 48 of whom never
    // completed: content broadcast for deletion, account still alive, still
    // signed in. Nothing destructive may run before the gate clears.
    testWidgets(
      'publishes nothing when the session cannot authorize deletion',
      (tester) async {
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
          () =>
              authService.signOut(deleteKeys: true, deleteLocalUserData: true),
        );

        // The user is told to sign in again, not that their network is at fault.
        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.text(l10n.deleteAccountReauthRequired), findsOneWidget);
        expect(
          find.text(l10n.deleteAccountServerDeletionFailed),
          findsNothing,
        );
      },
    );

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
      when(
        authService.deleteKeycastAccount,
      ).thenAnswer((_) async => (true, null));
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
