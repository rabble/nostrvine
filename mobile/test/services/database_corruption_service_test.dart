import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/services/database_corruption_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockSharedPreferences extends Mock implements SharedPreferences {}

void main() {
  group(DatabaseCorruptionService, () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    DatabaseCorruptionService build({
      Future<void> Function(Object error, StackTrace stack)? recordError,
    }) {
      final service = DatabaseCorruptionService(
        preferences: prefs,
        recordError: recordError,
      );
      addTearDown(service.dispose);
      return service;
    }

    group('report', () {
      test('flips isCorrupted so the UI can prompt for a restart', () {
        final service = build();
        expect(service.isCorrupted.value, isFalse);

        service.report(Exception('malformed'), StackTrace.current);

        expect(service.isCorrupted.value, isTrue);
      });

      test('persists the flag so the next launch salvages', () async {
        final service = build();

        service.report(Exception('malformed'), StackTrace.current);
        await service.recoveryPersisted;

        expect(
          prefs.getBool(DatabaseCorruptionService.pendingRecoveryKey),
          isTrue,
        );
        expect(build().hasPendingRecovery, isTrue);
      });

      test('recoveryPersisted resolves only once the flag is written', () async {
        final service = build();
        service.report(Exception('malformed'), StackTrace.current);

        // The restart prompt gates its close button on this future, so it must
        // not resolve while the write that makes recovery possible is still in
        // flight — closing early would strand the user on the same database.
        await service.recoveryPersisted;

        expect(build().hasPendingRecovery, isTrue);
      });

      test(
        'recoveryPersisted resolves immediately before any report',
        () async {
          await build().recoveryPersisted.timeout(const Duration(seconds: 1));
        },
      );

      test('reports the error once, not per failing statement', () async {
        final reported = <Object>[];
        final service = build(
          recordError: (error, _) async => reported.add(error),
        );

        // A corrupt database throws from many statements in a row.
        service.report(Exception('first'), StackTrace.current);
        service.report(Exception('second'), StackTrace.current);
        service.report(Exception('third'), StackTrace.current);
        await pumpEventQueue();

        expect(reported, hasLength(1));
        expect(reported.single.toString(), contains('first'));
      });

      test('retries a refused flag write before giving up', () async {
        final failing = _MockSharedPreferences();
        var attempts = 0;
        when(() => failing.setBool(any(), any())).thenAnswer((_) async {
          attempts += 1;
          // setBool reports a refused write by returning false rather than
          // throwing, and report() drops every later corruption report, so an
          // unnoticed false would leave the next launch with no reason to
          // salvage.
          return attempts > 1;
        });
        final service = DatabaseCorruptionService(preferences: failing);
        addTearDown(service.dispose);

        service.report(Exception('malformed'), StackTrace.current);
        await service.recoveryPersisted;

        expect(attempts, equals(2));
      });

      test(
        'releases the restart prompt when the flag write keeps failing',
        () async {
          final failing = _MockSharedPreferences();
          when(
            () => failing.setBool(any(), any()),
          ).thenThrow(Exception('disk full'));
          final service = DatabaseCorruptionService(preferences: failing);
          addTearDown(service.dispose);

          service.report(Exception('malformed'), StackTrace.current);

          // The button waits on this future. If a doomed write left it pending
          // the user would be locked in a session that cannot recover at all.
          await service.recoveryPersisted.timeout(const Duration(seconds: 1));
          expect(service.isCorrupted.value, isTrue);
        },
      );

      test('does not throw when reporting the non-fatal fails', () async {
        final service = build(
          recordError: (_, _) async => throw Exception('crashlytics down'),
        );

        service.report(Exception('malformed'), StackTrace.current);
        await pumpEventQueue();

        // The database is already broken; telemetry must not make it worse by
        // throwing into whichever query tripped the corruption.
        expect(service.isCorrupted.value, isTrue);
        expect(
          prefs.getBool(DatabaseCorruptionService.pendingRecoveryKey),
          isTrue,
        );
      });
    });

    group('hasPendingRecovery', () {
      test('is false on a healthy install', () {
        expect(build().hasPendingRecovery, isFalse);
      });

      test('survives into a new service instance', () async {
        SharedPreferences.setMockInitialValues({
          DatabaseCorruptionService.pendingRecoveryKey: true,
        });
        prefs = await SharedPreferences.getInstance();

        expect(build().hasPendingRecovery, isTrue);
      });
    });

    group('clearPendingRecovery', () {
      test(
        'clears the flag so recovery does not repeat every launch',
        () async {
          SharedPreferences.setMockInitialValues({
            DatabaseCorruptionService.pendingRecoveryKey: true,
          });
          prefs = await SharedPreferences.getInstance();
          final service = build();

          await service.clearPendingRecovery();

          expect(service.hasPendingRecovery, isFalse);
        },
      );
    });
  });
}
