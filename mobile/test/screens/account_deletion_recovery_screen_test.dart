// ABOUTME: Widget tests for interrupted account-deletion recovery states.
// ABOUTME: Pins rollback, processing, and completed-deletion local cleanup.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart'
    show SecureKeyStorageException;
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/account_deletion_attempt.dart';
import 'package:openvine/providers/account_deletion_recovery_providers.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/repositories/account_deletion_recovery_repository.dart';
import 'package:openvine/screens/account_deletion_recovery_screen.dart';
import 'package:openvine/services/auth_service.dart';

class _MockRecoveryRepository extends Mock
    implements AccountDeletionRecoveryRepository {}

class _MockAuthService extends Mock implements AuthService {}

const _recoverable = AccountDeletionAttempt(
  id: 'attempt-id',
  status: AccountDeletionAttemptStatus.recoverable,
  username: 'alice',
);

Widget _app({
  required AccountDeletionAttempt attempt,
  required AccountDeletionRecoveryRepository repository,
  AuthService? authService,
}) {
  final router = GoRouter(
    initialLocation: AccountDeletionRecoveryScreen.path,
    routes: [
      GoRoute(
        path: AccountDeletionRecoveryScreen.path,
        builder: (_, _) => const AccountDeletionRecoveryScreen(),
      ),
      GoRoute(
        path: '/home/0',
        builder: (_, _) => const Scaffold(body: Text('Home')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      currentAccountDeletionAttemptProvider.overrideWith((_) async => attempt),
      accountDeletionRecoveryRepositoryProvider.overrideWithValue(repository),
      if (authService != null)
        authServiceProvider.overrideWithValue(authService),
    ],
    child: MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
}

void main() {
  testWidgets('recoverable attempt restores username and returns home', (
    tester,
  ) async {
    final repository = _MockRecoveryRepository();
    when(
      () => repository.cancel(attemptId: 'attempt-id'),
    ).thenAnswer(
      (_) async => const AccountDeletionAttempt(
        id: 'attempt-id',
        status: AccountDeletionAttemptStatus.cancelled,
        username: 'alice',
      ),
    );
    await tester.pumpWidget(
      _app(attempt: _recoverable, repository: repository),
    );
    await tester.pumpAndSettle();

    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(find.text(l10n.accountDeletionRecoveryBody), findsOneWidget);
    await tester.tap(
      find.widgetWithText(DivineButton, l10n.accountDeletionRestoreUsername),
    );
    await tester.pumpAndSettle();

    verify(() => repository.cancel(attemptId: 'attempt-id')).called(1);
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('preparing attempt finishes its handshake before rollback', (
    tester,
  ) async {
    final repository = _MockRecoveryRepository();
    when(
      () => repository.prepare(username: 'alice'),
    ).thenAnswer((_) async => _recoverable);
    when(
      () => repository.cancel(attemptId: 'attempt-id'),
    ).thenAnswer(
      (_) async => const AccountDeletionAttempt(
        id: 'attempt-id',
        status: AccountDeletionAttemptStatus.cancelled,
        username: 'alice',
      ),
    );
    await tester.pumpWidget(
      _app(
        attempt: const AccountDeletionAttempt(
          id: 'attempt-id',
          status: AccountDeletionAttemptStatus.preparing,
          username: 'alice',
        ),
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();

    final l10n = lookupAppLocalizations(const Locale('en'));
    await tester.tap(
      find.widgetWithText(DivineButton, l10n.accountDeletionRestoreUsername),
    );
    await tester.pumpAndSettle();

    verify(() => repository.prepare(username: 'alice')).called(1);
    verify(() => repository.cancel(attemptId: 'attempt-id')).called(1);
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('processing attempt cannot be rolled back from the screen', (
    tester,
  ) async {
    final repository = _MockRecoveryRepository();
    await tester.pumpWidget(
      _app(
        attempt: const AccountDeletionAttempt(
          id: 'attempt-id',
          status: AccountDeletionAttemptStatus.processing,
        ),
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();

    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(find.text(l10n.accountDeletionFinishingBody), findsOneWidget);
    expect(
      find.widgetWithText(DivineButton, l10n.accountDeletionRestoreUsername),
      findsNothing,
    );
  });

  testWidgets(
    'failed local cleanup after a completed deletion says what actually failed',
    (tester) async {
      final repository = _MockRecoveryRepository();
      final authService = _MockAuthService();
      when(
        () => authService.signOut(
          deleteKeys: true,
          deleteLocalUserData: true,
        ),
      ).thenThrow(const SecureKeyStorageException('keychain locked'));
      await tester.pumpWidget(
        _app(
          attempt: const AccountDeletionAttempt(
            id: 'attempt-id',
            status: AccountDeletionAttemptStatus.completed,
            username: 'alice',
          ),
          repository: repository,
          authService: authService,
        ),
      );
      // Not pumpAndSettle: the completed branch shows a progress indicator,
      // which never settles.
      await tester.pump();
      await tester.pump();

      // The server already deleted the account, so nothing here may offer to
      // restore a username or imply the account survived.
      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.accountDeletionRecoveryFailed), findsNothing);
      expect(find.text(l10n.deleteAccountKeyDeletionWarning), findsOneWidget);
    },
  );

  testWidgets('completed deletion removes local credentials', (tester) async {
    final repository = _MockRecoveryRepository();
    final authService = _MockAuthService();
    when(
      () => authService.signOut(
        deleteKeys: true,
        deleteLocalUserData: true,
      ),
    ).thenAnswer((_) async {});
    await tester.pumpWidget(
      _app(
        attempt: const AccountDeletionAttempt(
          id: 'attempt-id',
          status: AccountDeletionAttemptStatus.completed,
        ),
        repository: repository,
        authService: authService,
      ),
    );
    await tester.pump();

    verify(
      () => authService.signOut(
        deleteKeys: true,
        deleteLocalUserData: true,
      ),
    ).called(1);
  });
}
