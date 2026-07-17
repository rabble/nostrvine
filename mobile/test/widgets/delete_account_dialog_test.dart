// ABOUTME: Tests for the delete account confirmation dialog
// ABOUTME: Verifies that the DELETE confirmation is case-insensitive and trims whitespace

import 'dart:async';

import 'package:flutter/material.dart';
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

void main() {
  group('showDeleteAllContentWarningDialog – confirmation input', () {
    testWidgets('empty string keeps Delete button disabled', (tester) async {
      await _showDialog(tester);

      expect(
        find.text(
          lookupAppLocalizations(
            const Locale('en'),
          ).deleteAccountConfirmDeletePrompt,
        ),
        findsOneWidget,
      );
      // Button should be disabled (onPressed == null → tapping does nothing)
      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Delete All Content'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('wrong word keeps Delete button disabled', (tester) async {
      await _showDialog(tester);

      await tester.enterText(find.byType(TextField), 'confirm');
      await tester.pump();

      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Delete All Content'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('exact uppercase DELETE enables the button', (tester) async {
      await _showDialog(tester);

      await tester.enterText(find.byType(TextField), 'DELETE');
      await tester.pump();

      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Delete All Content'),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('lowercase delete enables the button', (tester) async {
      await _showDialog(tester);

      await tester.enterText(find.byType(TextField), 'delete');
      await tester.pump();

      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Delete All Content'),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('mixed case Delete enables the button', (tester) async {
      await _showDialog(tester);

      await tester.enterText(find.byType(TextField), 'Delete');
      await tester.pump();

      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Delete All Content'),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('DELETE with trailing whitespace enables the button', (
      tester,
    ) async {
      await _showDialog(tester);

      await tester.enterText(find.byType(TextField), 'DELETE ');
      await tester.pump();

      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Delete All Content'),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('delete with leading whitespace enables the button', (
      tester,
    ) async {
      await _showDialog(tester);

      await tester.enterText(find.byType(TextField), ' delete');
      await tester.pump();

      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Delete All Content'),
      );
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

      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Delete All Content'),
      );
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

      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'delete');
      await tester.pump();
      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Delete All Content'),
      );
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
      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Delete All Content'),
      );
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
      expect(
        find.widgetWithText(ElevatedButton, 'Delete All Content'),
        findsOneWidget,
      );
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

      expect(
        find.widgetWithText(ElevatedButton, 'Delete All Content'),
        findsOneWidget,
      );
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

      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'delete');
      await tester.pump();
      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Delete All Content'),
      );
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
      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Delete All Content'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('typing the handle enables the button', (tester) async {
      await _showDialog(tester, confirmation: _divineUsername());
      await tester.enterText(find.byType(TextField), '@rabble.divine.video');
      await tester.pump();
      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Delete All Content'),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('typing the handle without @ also enables the button', (
      tester,
    ) async {
      await _showDialog(tester, confirmation: _divineUsername());
      await tester.enterText(find.byType(TextField), 'rabble.divine.video');
      await tester.pump();
      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Delete All Content'),
      );
      expect(button.onPressed, isNotNull);
    });
  });

  group('executeAccountDeletion', () {
    testWidgets('shows failure when local data cleanup fails after sign-out', (
      tester,
    ) async {
      final deletionService = _MockAccountDeletionService();
      final authService = _MockAuthService();
      when(
        () =>
            deletionService.deleteAccount(onProgress: any(named: 'onProgress')),
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

      expect(
        find.text(
          'Account deleted and signed out, but some local data could not be '
          'removed from this device.',
        ),
        findsOneWidget,
      );
      expect(find.text('Your account has been deleted'), findsNothing);
    });

    testWidgets('opted-in burn failure aborts deletion and shows error', (
      tester,
    ) async {
      final deletionService = _MockAccountDeletionService();
      final authService = _MockAuthService();
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
        () =>
            deletionService.deleteAccount(onProgress: any(named: 'onProgress')),
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
      final profileRepository = _MockProfileRepository();
      when(
        () => profileRepository.releaseUsername(name: any(named: 'name')),
      ).thenAnswer((_) async => const UsernameReleaseSuccess());
      when(
        () =>
            deletionService.deleteAccount(onProgress: any(named: 'onProgress')),
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
        () =>
            deletionService.deleteAccount(onProgress: any(named: 'onProgress')),
      ).called(1);
      verify(
        () => profileRepository.releaseUsername(name: 'alice'),
      ).called(1);
    });

    testWidgets('does not release the username when burn is not opted in', (
      tester,
    ) async {
      final deletionService = _MockAccountDeletionService();
      final authService = _MockAuthService();
      final profileRepository = _MockProfileRepository();
      when(
        () =>
            deletionService.deleteAccount(onProgress: any(named: 'onProgress')),
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
        () =>
            deletionService.deleteAccount(onProgress: any(named: 'onProgress')),
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
      (
        tester,
      ) async {
        final deletionService = _MockAccountDeletionService();
        final authService = _MockAuthService();
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
      (
        tester,
      ) async {
        final deletionService = _MockAccountDeletionService();
        final authService = _MockAuthService();
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
      (
        tester,
      ) async {
        final deletionService = _MockAccountDeletionService();
        final authService = _MockAuthService();
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
        () =>
            deletionService.deleteAccount(onProgress: any(named: 'onProgress')),
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
        () =>
            deletionService.deleteAccount(onProgress: any(named: 'onProgress')),
      );
      verifyNever(
        () => profileRepository.releaseUsername(name: any(named: 'name')),
      );
    });

    testWidgets('aborts before burn when the account changed', (tester) async {
      final deletionService = _MockAccountDeletionService();
      final authService = _MockAuthService();
      final profileRepository = _MockProfileRepository();
      when(
        () => authService.currentPublicKeyHex,
      ).thenReturn('now_a_different_pk');

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
        () =>
            deletionService.deleteAccount(onProgress: any(named: 'onProgress')),
      );
      expect(
        find.text(
          lookupAppLocalizations(
            const Locale('en'),
          ).deleteAccountAccountChanged,
        ),
        findsOneWidget,
      );
    });

    testWidgets('proceeds when confirmedPubkey matches the current account', (
      tester,
    ) async {
      final deletionService = _MockAccountDeletionService();
      final authService = _MockAuthService();
      when(() => authService.currentPublicKeyHex).thenReturn(_pubkeyHex);
      when(
        () =>
            deletionService.deleteAccount(onProgress: any(named: 'onProgress')),
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
        () =>
            deletionService.deleteAccount(onProgress: any(named: 'onProgress')),
      ).called(1);
    });
  });
}
