import 'package:flutter/material.dart';
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
        final error = StateError('secure storage unavailable before unlock');

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

  group(DatabaseBootstrapFailureApp, () {
    testWidgets('shows a visible database startup failure screen', (
      tester,
    ) async {
      var closed = false;

      await tester.pumpWidget(
        DatabaseBootstrapFailureApp(
          error: StateError('secure storage unavailable'),
          stack: StackTrace.current,
          onCloseApp: () => closed = true,
        ),
      );

      expect(
        find.text("couldn't unlock your local database"),
        findsOneWidget,
      );
      expect(find.textContaining('Restart Divine'), findsOneWidget);
      expect(find.textContaining('Diagnostic:'), findsOneWidget);

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
      expect(
        shouldRepairLocalDatabaseCacheAfterBootstrapError(
          StateError('secure storage unavailable before unlock'),
        ),
        isFalse,
      );
    });
  });
}
