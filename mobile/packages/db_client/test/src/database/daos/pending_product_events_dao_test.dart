// ABOUTME: Unit tests for PendingProductEventsDao durable analytics outbox.
// ABOUTME: Covers enqueue, retry filtering, status transitions, and cleanup.

import 'dart:io';

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late PendingProductEventsDao dao;
  late String tempDbPath;

  PendingProductEvent makeEvent({
    required String id,
    String eventName = 'screen_time',
    PendingProductEventStatus status = PendingProductEventStatus.pending,
    int attemptCount = 0,
    DateTime? createdAt,
    DateTime? nextAttemptAt,
    String? lastError,
  }) {
    return PendingProductEvent(
      id: id,
      eventName: eventName,
      payloadJson: '{"event_id":"$id","event_name":"$eventName"}',
      status: status,
      attemptCount: attemptCount,
      createdAt: createdAt ?? DateTime.utc(2026, 7),
      nextAttemptAt: nextAttemptAt,
      lastError: lastError,
    );
  }

  setUp(() async {
    final tempDir = Directory.systemTemp.createTempSync(
      'pending_product_events_test_',
    );
    tempDbPath = '${tempDir.path}/test.db';

    database = AppDatabase.test(NativeDatabase(File(tempDbPath)));
    dao = database.pendingProductEventsDao;
  });

  tearDown(() async {
    await database.close();
    final file = File(tempDbPath);
    if (file.existsSync()) {
      file.deleteSync();
    }
    final dir = Directory(tempDbPath).parent;
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  });

  group('PendingProductEventsDao', () {
    test('inserts a pending product event with idempotency id', () async {
      await dao.enqueue(makeEvent(id: 'event-a'));

      final fetched = await dao.getById('event-a');

      expect(fetched, isNotNull);
      expect(fetched!.id, 'event-a');
      expect(fetched.eventName, 'screen_time');
      expect(fetched.payloadJson, contains('"event_id":"event-a"'));
      expect(fetched.status, PendingProductEventStatus.pending);
      expect(fetched.attemptCount, 0);
      expect(fetched.nextAttemptAt, isNull);
      expect(fetched.lastError, isNull);
    });

    test('re-enqueueing the same event id preserves delivery state', () async {
      await dao.enqueue(makeEvent(id: 'event-a'));
      await dao.markPublishing('event-a');
      await dao.markFailed(
        'event-a',
        'timeout',
        nextAttemptAt: DateTime.utc(2026, 7, 1, 0, 0, 30),
      );

      await dao.enqueue(makeEvent(id: 'event-a'));

      final fetched = await dao.getById('event-a');
      expect(fetched!.status, PendingProductEventStatus.failed);
      expect(fetched.attemptCount, 1);
      expect(fetched.lastError, 'timeout');
      expect(
        fetched.nextAttemptAt!.isAtSameMomentAs(
          DateTime.utc(2026, 7, 1, 0, 0, 30),
        ),
        isTrue,
      );
    });

    test('returns retryable rows due now in created order', () async {
      await dao.enqueue(
        makeEvent(
          id: 'publishing',
          status: PendingProductEventStatus.publishing,
          createdAt: DateTime.utc(2026, 7),
        ),
      );
      await dao.enqueue(
        makeEvent(
          id: 'failed-old',
          status: PendingProductEventStatus.failed,
          nextAttemptAt: DateTime.utc(2026, 7, 1, 0, 0, 5),
          createdAt: DateTime.utc(2026, 7, 1, 0, 0, 1),
        ),
      );
      await dao.enqueue(
        makeEvent(
          id: 'pending-new',
          createdAt: DateTime.utc(2026, 7, 1, 0, 0, 2),
        ),
      );
      await dao.enqueue(
        makeEvent(
          id: 'not-yet',
          status: PendingProductEventStatus.failed,
          nextAttemptAt: DateTime.utc(2026, 7, 1, 0, 1),
          createdAt: DateTime.utc(2026, 7, 1, 0, 0, 3),
        ),
      );
      await dao.enqueue(
        makeEvent(
          id: 'exhausted',
          status: PendingProductEventStatus.failed,
          attemptCount: 5,
          createdAt: DateTime.utc(2026, 7, 1, 0, 0, 4),
        ),
      );

      final retryable = await dao.getRetryable(
        now: DateTime.utc(2026, 7, 1, 0, 0, 10),
        maxAttempts: 5,
        limit: 10,
      );

      expect(retryable.map((event) => event.id), ['failed-old', 'pending-new']);
    });

    test('markDeadLetter stops exhausted events from retrying', () async {
      await dao.enqueue(makeEvent(id: 'event-a'));

      final updated = await dao.markDeadLetter('event-a', 'too many attempts');

      expect(updated, isTrue);
      final fetched = await dao.getById('event-a');
      expect(fetched!.status, PendingProductEventStatus.deadLetter);
      expect(fetched.lastError, 'too many attempts');
    });

    test('resetPublishingToPending recovers only in-flight rows', () async {
      await dao.enqueue(
        makeEvent(
          id: 'publishing-a',
          status: PendingProductEventStatus.publishing,
        ),
      );
      await dao.enqueue(makeEvent(id: 'pending-a'));
      await dao.enqueue(
        makeEvent(id: 'failed-a', status: PendingProductEventStatus.failed),
      );
      await dao.enqueue(
        makeEvent(id: 'dead-a', status: PendingProductEventStatus.deadLetter),
      );

      final updated = await dao.resetPublishingToPending();

      expect(updated, 1);
      expect(
        (await dao.getById('publishing-a'))!.status,
        PendingProductEventStatus.pending,
      );
      expect(
        (await dao.getById('pending-a'))!.status,
        PendingProductEventStatus.pending,
      );
      expect(
        (await dao.getById('failed-a'))!.status,
        PendingProductEventStatus.failed,
      );
      expect(
        (await dao.getById('dead-a'))!.status,
        PendingProductEventStatus.deadLetter,
      );
    });
  });
}
