// ABOUTME: Tests for the delete account confirmation dialog
// ABOUTME: Verifies that the DELETE confirmation is case-insensitive and trims whitespace

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/services/account_deletion_service.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:openvine/widgets/delete_account_dialog.dart';
import 'package:profile_repository/profile_repository.dart';

class _MockAccountDeletionService extends Mock
    implements AccountDeletionService {}

class _MockAuthService extends Mock implements AuthService {}

class _MockProfileRepository extends Mock implements ProfileRepository {}

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
  void Function({required bool burnUsername})? onConfirm,
  String? ownedUsername,
}) async {
  await tester.pumpWidget(
    _wrapWithRouter(
      Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            key: const Key('open'),
            onPressed: () => showDeleteAllContentWarningDialog(
              context: context,
              ownedUsername: ownedUsername,
              onConfirm: onConfirm ?? ({required bool burnUsername}) {},
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
        onConfirm: ({required bool burnUsername}) => called = true,
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
      await _showDialog(tester, ownedUsername: 'alice');
      expect(find.byType(CheckboxListTile), findsOneWidget);
    });

    testWidgets('checking burn toggle passes burnUsername true on confirm', (
      tester,
    ) async {
      bool? received;
      await _showDialog(
        tester,
        ownedUsername: 'alice',
        onConfirm: ({required bool burnUsername}) => received = burnUsername,
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
        ownedUsername: 'alice',
        onConfirm: ({required bool burnUsername}) => received = burnUsername,
      );

      await tester.enterText(find.byType(TextField), 'delete');
      await tester.pump();
      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Delete All Content'),
      );
      await tester.pumpAndSettle();

      expect(received, isFalse);
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
        ownedUsername: 'alice',
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
        ownedUsername: 'alice',
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
        ownedUsername: 'alice',
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
        ownedUsername: 'alice',
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
  });
}
