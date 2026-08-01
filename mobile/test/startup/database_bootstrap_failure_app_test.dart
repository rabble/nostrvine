import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/database_encryption_bootstrap.dart';
import 'package:openvine/startup/database_bootstrap_failure_app.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  group('resolveDatabaseBootstrapForAppStart', () {
    test('returns the cipher key without rendering failure UI', () async {
      var removedSplash = false;
      Widget? renderedApp;

      final result = await resolveDatabaseBootstrapForAppStart(
        resolveCipherKey: () async => 'a' * 64,
        removeNativeSplash: () => removedSplash = true,
        runApp: (app) => renderedApp = app,
      );

      expect(result.didRenderFailureApp, isFalse);
      expect(result.cipherKey, equals('a' * 64));
      expect(removedSplash, isFalse);
      expect(renderedApp, isNull);
    });

    test(
      'renders a visible failure app and removes native splash on error',
      () async {
        var removedSplash = false;
        Widget? renderedApp;
        final error = StateError('secure storage unavailable');

        final result = await resolveDatabaseBootstrapForAppStart(
          resolveCipherKey: () async => throw error,
          removeNativeSplash: () => removedSplash = true,
          runApp: (app) => renderedApp = app,
        );

        expect(result.didRenderFailureApp, isTrue);
        expect(result.cipherKey, isNull);
        expect(removedSplash, isTrue);
        expect(renderedApp, isA<DatabaseBootstrapFailureApp>());
      },
    );

    test(
      'repairs local database cache and retries before rendering failure UI',
      () async {
        var removedSplash = false;
        Widget? renderedApp;
        var attempts = 0;
        var repaired = false;
        final error = StateError('database bootstrap failed');

        final result = await resolveDatabaseBootstrapForAppStart(
          resolveCipherKey: () async {
            attempts += 1;
            if (attempts == 1) throw error;
            return 'b' * 64;
          },
          repairLocalDatabaseCache: (error, stack) async {
            repaired = true;
          },
          shouldRepairLocalDatabaseCache: (_) => true,
          removeNativeSplash: () => removedSplash = true,
          runApp: (app) => renderedApp = app,
        );

        expect(result.didRenderFailureApp, isFalse);
        expect(result.cipherKey, equals('b' * 64));
        expect(attempts, equals(2));
        expect(repaired, isTrue);
        expect(removedSplash, isFalse);
        expect(renderedApp, isNull);
      },
    );

    test(
      'renders failure UI only after automatic repair retry fails',
      () async {
        var removedSplash = false;
        Widget? renderedApp;
        var attempts = 0;
        var repaired = false;

        final result = await resolveDatabaseBootstrapForAppStart(
          resolveCipherKey: () async {
            attempts += 1;
            throw StateError('database bootstrap failed $attempts');
          },
          repairLocalDatabaseCache: (error, stack) async {
            repaired = true;
          },
          shouldRepairLocalDatabaseCache: (_) => true,
          removeNativeSplash: () => removedSplash = true,
          runApp: (app) => renderedApp = app,
        );

        expect(result.didRenderFailureApp, isTrue);
        expect(result.cipherKey, isNull);
        expect(attempts, equals(2));
        expect(repaired, isTrue);
        expect(removedSplash, isTrue);
        expect(renderedApp, isA<DatabaseBootstrapFailureApp>());
      },
    );

    test(
      'does not repair when the bootstrap error is not repairable',
      () async {
        var removedSplash = false;
        Widget? renderedApp;
        var attempts = 0;
        var repaired = false;
        final error = StateError('SQLCipher is not linked');

        final result = await resolveDatabaseBootstrapForAppStart(
          resolveCipherKey: () async {
            attempts += 1;
            throw error;
          },
          repairLocalDatabaseCache: (error, stack) async {
            repaired = true;
          },
          shouldRepairLocalDatabaseCache: (_) => false,
          removeNativeSplash: () => removedSplash = true,
          runApp: (app) => renderedApp = app,
        );

        expect(result.didRenderFailureApp, isTrue);
        expect(result.cipherKey, isNull);
        expect(attempts, equals(1));
        expect(repaired, isFalse);
        expect(removedSplash, isTrue);
        expect(renderedApp, isA<DatabaseBootstrapFailureApp>());
      },
    );

    test(
      'does not implicitly repair when no repair predicate is provided',
      () async {
        var removedSplash = false;
        Widget? renderedApp;
        var attempts = 0;
        var repaired = false;
        final error = SqliteException(
          extendedResultCode: 26,
          message: 'file is not a database',
        );

        final result = await resolveDatabaseBootstrapForAppStart(
          resolveCipherKey: () async {
            attempts += 1;
            throw error;
          },
          repairLocalDatabaseCache: (error, stack) async {
            repaired = true;
          },
          removeNativeSplash: () => removedSplash = true,
          runApp: (app) => renderedApp = app,
        );

        expect(result.didRenderFailureApp, isTrue);
        expect(attempts, equals(1));
        expect(repaired, isFalse);
        expect(removedSplash, isTrue);
        expect(renderedApp, isA<DatabaseBootstrapFailureApp>());
      },
    );

    test(
      'does not repair secure-storage failures',
      () async {
        var removedSplash = false;
        Widget? renderedApp;
        var attempts = 0;
        var repaired = false;
        final error = DatabaseCipherStorageUnavailableException(
          _lockedKeychainFailure(),
        );

        final result = await resolveDatabaseBootstrapForAppStart(
          resolveCipherKey: () async {
            attempts += 1;
            throw error;
          },
          repairLocalDatabaseCache: (error, stack) async {
            repaired = true;
          },
          shouldRepairLocalDatabaseCache:
              shouldRepairLocalDatabaseCacheAfterBootstrapError,
          removeNativeSplash: () => removedSplash = true,
          runApp: (app) => renderedApp = app,
        );

        expect(result.didRenderFailureApp, isTrue);
        expect(attempts, equals(1));
        expect(repaired, isFalse);
        expect(removedSplash, isTrue);
        expect(renderedApp, isA<DatabaseBootstrapFailureApp>());
      },
    );

    test(
      'repairs allowlisted sqlite corruption failures',
      () async {
        var removedSplash = false;
        Widget? renderedApp;
        var attempts = 0;
        var repaired = false;

        final result = await resolveDatabaseBootstrapForAppStart(
          resolveCipherKey: () async {
            attempts += 1;
            if (attempts == 1) {
              throw SqliteException(
                extendedResultCode: 26,
                message: 'file is not a database',
              );
            }
            return 'c' * 64;
          },
          repairLocalDatabaseCache: (error, stack) async {
            repaired = true;
          },
          shouldRepairLocalDatabaseCache:
              shouldRepairLocalDatabaseCacheAfterBootstrapError,
          removeNativeSplash: () => removedSplash = true,
          runApp: (app) => renderedApp = app,
        );

        expect(result.didRenderFailureApp, isFalse);
        expect(result.cipherKey, equals('c' * 64));
        expect(attempts, equals(2));
        expect(repaired, isTrue);
        expect(removedSplash, isFalse);
        expect(renderedApp, isNull);
      },
    );
  });

  group('resolveDatabaseBootstrapForAppStart reset wiring', () {
    test('hands the reset hook to the failure app', () async {
      Widget? renderedApp;
      Future<void> reset() async {}

      await resolveDatabaseBootstrapForAppStart(
        resolveCipherKey: () async => throw StateError('bootstrap failed'),
        resetLocalDatabase: reset,
        removeNativeSplash: () {},
        runApp: (app) => renderedApp = app,
      );

      expect(
        (renderedApp! as DatabaseBootstrapFailureApp).onResetLocalDatabase,
        same(reset),
      );
    });
  });

  group(DatabaseBootstrapFailureApp, () {
    testWidgets('shows a visible database startup failure screen', (
      tester,
    ) async {
      var closed = false;

      await tester.pumpWidget(
        DatabaseBootstrapFailureApp(
          error: DatabaseCipherStorageUnavailableException(
            _lockedKeychainFailure(),
          ),
          stack: StackTrace.current,
          onCloseApp: () => closed = true,
        ),
      );

      expect(
        find.text("couldn't unlock your local database"),
        findsOneWidget,
      );
      expect(find.textContaining('Restart Divine'), findsOneWidget);
      // The rendered code is what a support report is triaged from, so pin the
      // value rather than just the label.
      expect(find.text('Diagnostic: db-secure-storage'), findsOneWidget);

      await tester.tap(find.text('close Divine'));
      expect(closed, isTrue);
    });

    test('classifies cipher availability failures for release diagnostics', () {
      expect(
        databaseBootstrapDiagnosticCode(
          DatabaseCipherUnavailableError(),
        ),
        equals('db-cipher-unavailable'),
      );
    });

    test('classifies an unreachable keystore as a secure-storage failure', () {
      expect(
        databaseBootstrapDiagnosticCode(
          DatabaseCipherStorageUnavailableException(_lockedKeychainFailure()),
        ),
        equals('db-secure-storage'),
      );
    });

    test('classifies a key that no longer opens the database', () {
      expect(
        databaseBootstrapDiagnosticCode(
          SqliteException(
            extendedResultCode: 26,
            message: 'file is not a database',
          ),
        ),
        equals('db-cipher-mismatch'),
      );
    });

    test('falls back to the catch-all for unrecognized failures', () {
      expect(
        databaseBootstrapDiagnosticCode(StateError('something else entirely')),
        equals('db-bootstrap-failed'),
      );
    });

    testWidgets('offers no reset when the caller supplies no hook', (
      tester,
    ) async {
      await tester.pumpWidget(
        DatabaseBootstrapFailureApp(
          error: StateError('something else entirely'),
          stack: StackTrace.current,
        ),
      );

      expect(find.text('reset local database'), findsNothing);
    });

    testWidgets('offers no reset for a locked keystore', (tester) async {
      // The database is intact here and the reset would delete the key that
      // opens it. Offering the button would be worse than offering nothing.
      await tester.pumpWidget(
        DatabaseBootstrapFailureApp(
          error: DatabaseCipherStorageUnavailableException(
            _lockedKeychainFailure(),
          ),
          stack: StackTrace.current,
          onResetLocalDatabase: () async {},
        ),
      );

      expect(find.text('Diagnostic: db-secure-storage'), findsOneWidget);
      expect(find.text('reset local database'), findsNothing);
    });

    testWidgets('drops the unlock-and-restart advice when a reset is offered', (
      tester,
    ) async {
      // Telling the user to restart after unlocking is the fix for the
      // keystore case only, and misleading next to a reset button.
      await tester.pumpWidget(
        DatabaseBootstrapFailureApp(
          error: StateError('something else entirely'),
          stack: StackTrace.current,
          onResetLocalDatabase: () async {},
        ),
      );

      expect(
        find.textContaining('Restart Divine after unlocking'),
        findsNothing,
      );
      expect(
        find.textContaining("A restart won't fix this one"),
        findsOneWidget,
      );
    });

    testWidgets('resets and closes once the user confirms', (tester) async {
      var resets = 0;
      var closed = false;

      await tester.pumpWidget(
        DatabaseBootstrapFailureApp(
          error: StateError('something else entirely'),
          stack: StackTrace.current,
          onCloseApp: () => closed = true,
          onResetLocalDatabase: () async => resets++,
        ),
      );

      await tester.tap(find.text('reset local database'));
      await tester.pump();

      expect(find.text('reset your local database?'), findsOneWidget);
      expect(find.textContaining('Your account stays'), findsOneWidget);
      expect(resets, isZero, reason: 'confirmation must gate the wipe');

      await tester.tap(find.text('reset and close'));
      await tester.pump();

      expect(resets, equals(1));
      expect(closed, isTrue);
    });

    testWidgets('returns to the failure screen on cancel', (tester) async {
      var resets = 0;

      await tester.pumpWidget(
        DatabaseBootstrapFailureApp(
          error: StateError('something else entirely'),
          stack: StackTrace.current,
          onResetLocalDatabase: () async => resets++,
        ),
      );

      await tester.tap(find.text('reset local database'));
      await tester.pump();
      await tester.tap(find.text('cancel'));
      await tester.pump();

      expect(find.text("couldn't unlock your local database"), findsOneWidget);
      expect(resets, isZero);
    });

    testWidgets('stays put and reports when the reset itself fails', (
      tester,
    ) async {
      var closed = false;

      await tester.pumpWidget(
        DatabaseBootstrapFailureApp(
          error: StateError('something else entirely'),
          stack: StackTrace.current,
          onCloseApp: () => closed = true,
          onResetLocalDatabase: () async =>
              throw StateError('keystore delete failed'),
        ),
      );

      await tester.tap(find.text('reset local database'));
      await tester.pump();
      await tester.tap(find.text('reset and close'));
      await tester.pump();

      expect(find.textContaining("That didn't work"), findsOneWidget);
      expect(
        closed,
        isFalse,
        reason: 'closing would claim a reset that never happened',
      );
    });

    testWidgets('lands on a terminal step when the app cannot close itself', (
      tester,
    ) async {
      // SystemNavigator.pop cannot end the process on iOS, so without this
      // step a successful reset leaves a spinner behind two disabled buttons.
      var closes = 0;

      await tester.pumpWidget(
        DatabaseBootstrapFailureApp(
          error: StateError('something else entirely'),
          stack: StackTrace.current,
          onCloseApp: () => closes++,
          onResetLocalDatabase: () async {},
        ),
      );

      await tester.tap(find.text('reset local database'));
      await tester.pump();
      await tester.tap(find.text('reset and close'));
      await tester.pump();

      expect(find.text('local database reset'), findsOneWidget);
      expect(find.text('reset and close'), findsNothing);
      expect(closes, equals(1));

      await tester.tap(find.text('close Divine'));
      expect(
        closes,
        equals(2),
        reason: 'the terminal step still needs a live way out',
      );
    });

    testWidgets('reports a reset that hangs instead of spinning forever', (
      tester,
    ) async {
      await tester.pumpWidget(
        DatabaseBootstrapFailureApp(
          error: StateError('something else entirely'),
          stack: StackTrace.current,
          onResetLocalDatabase: () => Completer<void>().future,
        ),
      );

      await tester.tap(find.text('reset local database'));
      await tester.pump();
      await tester.tap(find.text('reset and close'));
      await tester.pump(const Duration(seconds: 16));

      expect(find.textContaining("That didn't work"), findsOneWidget);

      await tester.tap(find.text('cancel'));
      await tester.pump();
      expect(
        find.text("couldn't unlock your local database"),
        findsOneWidget,
        reason: 'a wedged platform call must not disable the way back',
      );
    });

    testWidgets('drops a stale failure banner when the step is re-entered', (
      tester,
    ) async {
      await tester.pumpWidget(
        DatabaseBootstrapFailureApp(
          error: StateError('something else entirely'),
          stack: StackTrace.current,
          onResetLocalDatabase: () async => throw StateError('nope'),
        ),
      );

      await tester.tap(find.text('reset local database'));
      await tester.pump();
      await tester.tap(find.text('reset and close'));
      await tester.pump();
      expect(find.textContaining("That didn't work"), findsOneWidget);

      await tester.tap(find.text('cancel'));
      await tester.pump();
      await tester.tap(find.text('reset local database'));
      await tester.pump();

      expect(
        find.textContaining("That didn't work"),
        findsNothing,
        reason: 'the banner belongs to an attempt, not to the step',
      );
    });
  });

  group(DatabaseBootstrapDiagnosis, () {
    test('allows a reset only where the database is already unusable', () {
      expect(
        DatabaseBootstrapDiagnosis.values
            .where((d) => d.allowsLocalDatabaseReset)
            .toSet(),
        equals({
          DatabaseBootstrapDiagnosis.cipherMismatch,
          DatabaseBootstrapDiagnosis.bootstrapFailed,
        }),
      );
    });
  });

  group('shouldRepairLocalDatabaseCacheAfterBootstrapError', () {
    test('allowlists sqlite not-a-database and corruption errors', () {
      expect(
        shouldRepairLocalDatabaseCacheAfterBootstrapError(
          SqliteException(
            extendedResultCode: 26,
            message: 'file is not a database',
          ),
        ),
        isTrue,
      );
      expect(
        shouldRepairLocalDatabaseCacheAfterBootstrapError(
          SqliteException(
            extendedResultCode: 11,
            message: 'database disk image is malformed',
          ),
        ),
        isTrue,
      );
    });

    test('excludes cipher linkage and secure-storage failures', () {
      expect(
        shouldRepairLocalDatabaseCacheAfterBootstrapError(
          DatabaseCipherUnavailableError(),
        ),
        isFalse,
      );
      // Repairing deletes the cipher key. The database behind a locked keychain
      // is intact, so clearing it would turn a restart-and-retry into
      // permanent loss of every local-only draft and clip.
      expect(
        shouldRepairLocalDatabaseCacheAfterBootstrapError(
          DatabaseCipherStorageUnavailableException(_lockedKeychainFailure()),
        ),
        isFalse,
      );
    });
  });
}

/// What `flutter_secure_storage` raises when the Keychain refuses a read on a
/// still-locked device: a platform status code and no prose, which is why
/// classifying this case by message never matched.
PlatformException _lockedKeychainFailure() => PlatformException(
  code: 'Unexpected security result code',
  message: 'Code: -25308, Message: User interaction is not allowed.',
);
