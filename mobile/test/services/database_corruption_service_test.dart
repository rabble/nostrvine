import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/database_corruption_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

      test('notifies isCorrupted listeners', () {
        final service = build();
        var notifications = 0;
        service.isCorrupted.addListener(() => notifications++);

        service.report(Exception('malformed'), StackTrace.current);

        expect(notifications, equals(1));
      });

      test('persists the flag so the next launch salvages', () async {
        final service = build();

        service.report(Exception('malformed'), StackTrace.current);
        await pumpEventQueue();

        expect(
          prefs.getBool(DatabaseCorruptionService.pendingRecoveryKey),
          isTrue,
        );
        expect(build().hasPendingRecovery, isTrue);
      });

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
