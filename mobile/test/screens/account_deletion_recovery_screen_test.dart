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
import 'package:openvine/services/user_data_cleanup_service.dart';

class _MockRecoveryRepository extends Mock
    implements AccountDeletionRecoveryRepository {}

class _MockAuthService extends Mock implements AuthService {}

const _recoverable = AccountDeletionAttempt(
  id: 'attempt-id',
  status: AccountDeletionAttemptStatus.recoverable,
  username: 'alice',
  usernameExpiresAt: 1787450400,
);

Widget _app({
  required AccountDeletionAttempt attempt,
  required AccountDeletionRecoveryRepository repository,
  AuthService? authService,
  Stream<AccountDeletionAttempt?>? attempts,
  Stream<AccountDeletionAttempt?> Function()? attemptsBuilder,
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
      pollingAccountDeletionAttemptProvider.overrideWith(
        (_) => attemptsBuilder?.call() ?? attempts ?? Stream.value(attempt),
      ),
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
  setUpAll(() {
    registerFallbackValue(_recoverable);
  });

  testWidgets('recoverable attempt restores username and returns home', (
    tester,
  ) async {
    final repository = _MockRecoveryRepository();
    when(() => repository.cancelAndWait(attemptId: 'attempt-id')).thenAnswer(
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
    expect(find.textContaining('reserved for you until'), findsOneWidget);
    await tester.tap(
      find.widgetWithText(DivineButton, l10n.accountDeletionRestoreUsername),
    );
    await tester.pumpAndSettle();

    verify(() => repository.cancelAndWait(attemptId: 'attempt-id')).called(1);
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('preparing attempt finishes its handshake before rollback', (
    tester,
  ) async {
    final repository = _MockRecoveryRepository();
    when(
      () => repository.resumePreparation(any()),
    ).thenAnswer((_) async => _recoverable);
    when(() => repository.cancelAndWait(attemptId: 'attempt-id')).thenAnswer(
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

    verify(
      () => repository.resumePreparation(
        const AccountDeletionAttempt(
          id: 'attempt-id',
          status: AccountDeletionAttemptStatus.preparing,
          username: 'alice',
        ),
      ),
    ).called(1);
    verify(() => repository.cancelAndWait(attemptId: 'attempt-id')).called(1);
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('cancelling attempt polls without re-preparing username', (
    tester,
  ) async {
    final repository = _MockRecoveryRepository();
    await tester.pumpWidget(
      _app(
        attempt: const AccountDeletionAttempt(
          id: 'attempt-id',
          status: AccountDeletionAttemptStatus.preparing,
          operation: AccountDeletionAttemptOperation.cancelling,
          username: 'alice',
        ),
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();

    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(find.text(l10n.accountDeletionCancellingBody), findsOneWidget);
    expect(find.text(l10n.accountDeletionFinishingBody), findsNothing);
    expect(
      find.widgetWithText(DivineButton, l10n.accountDeletionRestoreUsername),
      findsNothing,
    );
    expect(
      find.widgetWithText(DivineButton, l10n.commonRetry),
      findsOneWidget,
    );
    verifyNever(() => repository.resumePreparation(any()));
  });

  testWidgets('cancellation-after-commit refreshes into processing', (
    tester,
  ) async {
    final repository = _MockRecoveryRepository();
    when(
      () => repository.cancelAndWait(attemptId: 'attempt-id'),
    ).thenThrow(
      const AccountDeletionRecoveryException(
        'server text',
        code: 'cancellation_after_commit',
      ),
    );
    var providerBuilds = 0;
    await tester.pumpWidget(
      _app(
        attempt: _recoverable,
        attemptsBuilder: () {
          providerBuilds++;
          return Stream.value(
            providerBuilds == 1
                ? _recoverable
                : const AccountDeletionAttempt(
                    id: 'attempt-id',
                    status: AccountDeletionAttemptStatus.processing,
                  ),
          );
        },
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();

    final l10n = lookupAppLocalizations(const Locale('en'));
    await tester.tap(
      find.widgetWithText(DivineButton, l10n.accountDeletionRestoreUsername),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text(l10n.accountDeletionFinishingBody), findsOneWidget);
    expect(find.textContaining('server text'), findsNothing);
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

  testWidgets('processing attempt auto-advances to completed cleanup', (
    tester,
  ) async {
    final repository = _MockRecoveryRepository();
    final authService = _MockAuthService();
    when(
      () => authService.signOut(deleteKeys: true, deleteLocalUserData: true),
    ).thenAnswer((_) async {});
    await tester.pumpWidget(
      _app(
        attempt: const AccountDeletionAttempt(
          id: 'attempt-id',
          status: AccountDeletionAttemptStatus.processing,
        ),
        attempts: Stream.fromIterable(const [
          AccountDeletionAttempt(
            id: 'attempt-id',
            status: AccountDeletionAttemptStatus.processing,
          ),
          AccountDeletionAttempt(
            id: 'attempt-id',
            status: AccountDeletionAttemptStatus.completed,
          ),
        ]),
        repository: repository,
        authService: authService,
      ),
    );
    await tester.pump();
    await tester.pump();

    verify(
      () => authService.signOut(deleteKeys: true, deleteLocalUserData: true),
    ).called(1);
  });

  testWidgets(
    'failed local cleanup after a completed deletion says what actually failed',
    (tester) async {
      final repository = _MockRecoveryRepository();
      final authService = _MockAuthService();
      when(
        () => authService.signOut(deleteKeys: true, deleteLocalUserData: true),
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
      () => authService.signOut(deleteKeys: true, deleteLocalUserData: true),
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
      () => authService.signOut(deleteKeys: true, deleteLocalUserData: true),
    ).called(1);
  });

  testWidgets('preparing attempt without username cancels by existing id', (
    tester,
  ) async {
    final repository = _MockRecoveryRepository();
    when(() => repository.cancelAndWait(attemptId: 'attempt-id')).thenAnswer(
      (_) async => const AccountDeletionAttempt(
        id: 'attempt-id',
        status: AccountDeletionAttemptStatus.cancelled,
      ),
    );
    await tester.pumpWidget(
      _app(
        attempt: const AccountDeletionAttempt(
          id: 'attempt-id',
          status: AccountDeletionAttemptStatus.preparing,
        ),
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();

    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(find.text(l10n.accountDeletionCancelAttemptBody), findsOneWidget);
    await tester.tap(
      find.widgetWithText(DivineButton, l10n.accountDeletionCancelAttempt),
    );
    await tester.pumpAndSettle();

    verifyNever(() => repository.prepare(username: any(named: 'username')));
    verifyNever(() => repository.resumePreparation(any()));
    verify(() => repository.cancelAndWait(attemptId: 'attempt-id')).called(1);
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('terminal failure offers support and non-destructive sign out', (
    tester,
  ) async {
    final repository = _MockRecoveryRepository();
    final authService = _MockAuthService();
    when(authService.signOut).thenAnswer((_) async {});
    await tester.pumpWidget(
      _app(
        attempt: const AccountDeletionAttempt(
          id: 'attempt-id',
          status: AccountDeletionAttemptStatus.terminalFailure,
          failureCode: 'coordinator_failed',
          failureMessage: 'Deletion could not be completed safely.',
        ),
        repository: repository,
        authService: authService,
      ),
    );
    await tester.pumpAndSettle();

    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(
      find.textContaining('Deletion could not be completed safely.'),
      findsNothing,
    );
    expect(find.textContaining('coordinator_failed'), findsNothing);
    expect(find.text(l10n.accountDeletionTerminalFailureBody), findsOneWidget);
    expect(
      find.widgetWithText(DivineButton, l10n.supportContactSupport),
      findsOneWidget,
    );
    await tester.tap(
      find.widgetWithText(DivineButton, l10n.accountDeletionSignOut),
    );
    await tester.pump();

    verify(authService.signOut).called(1);
  });

  testWidgets('completed cleanup failure says deletion already happened', (
    tester,
  ) async {
    final repository = _MockRecoveryRepository();
    final authService = _MockAuthService();
    when(
      () => authService.signOut(deleteKeys: true, deleteLocalUserData: true),
    ).thenThrow(const UserDataCleanupException('cleanup failed'));
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
    await tester.pumpAndSettle();

    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(
      find.text(l10n.deleteAccountLocalDataDeletionFailed),
      findsOneWidget,
    );
    expect(find.text(l10n.accountDeletionRecoveryFailed), findsNothing);
  });
}
