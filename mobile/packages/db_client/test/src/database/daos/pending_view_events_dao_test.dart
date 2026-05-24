// ABOUTME: Unit tests for PendingViewEventsDao durable view-event outbox.
// ABOUTME: Covers enqueue, retry filtering, status transitions, and cleanup.

import 'dart:io';

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late PendingViewEventsDao dao;
  late String tempDbPath;

  const userA =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
  const userB =
      'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210';
  const videoIdA =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const authorPubkey =
      'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

  PendingViewEvent makeEvent({
    required String id,
    String userPubkey = userA,
    String videoId = videoIdA,
    PendingViewEventStatus status = PendingViewEventStatus.pending,
    int retryCount = 0,
    DateTime? createdAt,
    DateTime? lastAttemptAt,
    String? lastError,
  }) {
    return PendingViewEvent(
      id: id,
      videoId: videoId,
      videoPubkey: authorPubkey,
      videoVineId: 'vine-$id',
      userPubkey: userPubkey,
      watchDurationMs: 2500,
      totalDurationMs: 6000,
      loopCount: 1,
      trafficSource: 'home',
      sourceDetail: 'following',
      status: status,
      retryCount: retryCount,
      lastError: lastError,
      lastAttemptAt: lastAttemptAt,
      createdAt: createdAt ?? DateTime.utc(2026, 5),
    );
  }

  setUp(() async {
    final tempDir = Directory.systemTemp.createTempSync(
      'pending_view_events_test_',
    );
    tempDbPath = '${tempDir.path}/test.db';

    database = AppDatabase.test(NativeDatabase(File(tempDbPath)));
    dao = database.pendingViewEventsDao;
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

  group('PendingViewEventsDao', () {
    group('enqueue', () {
      test('inserts a pending view event with all publish fields', () async {
        await dao.enqueue(makeEvent(id: 'view-a'));

        final fetched = await dao.getById('view-a');

        expect(fetched, isNotNull);
        expect(fetched!.status, PendingViewEventStatus.pending);
        expect(fetched.videoId, videoIdA);
        expect(fetched.videoPubkey, authorPubkey);
        expect(fetched.videoVineId, 'vine-view-a');
        expect(fetched.userPubkey, userA);
        expect(fetched.watchDurationMs, 2500);
        expect(fetched.totalDurationMs, 6000);
        expect(fetched.loopCount, 1);
        expect(fetched.trafficSource, 'home');
        expect(fetched.sourceDetail, 'following');
        expect(fetched.retryCount, 0);
        expect(fetched.lastError, isNull);
        expect(fetched.lastAttemptAt, isNull);
      });

      test('re-enqueueing the same id preserves delivery state', () async {
        await dao.enqueue(makeEvent(id: 'view-a'));
        await dao.markPublishing('view-a');
        await dao.markFailed('view-a', 'relay timeout');

        await dao.enqueue(makeEvent(id: 'view-a'));

        final fetched = await dao.getById('view-a');
        expect(fetched!.status, PendingViewEventStatus.failed);
        expect(fetched.retryCount, 1);
        expect(fetched.lastError, 'relay timeout');
        expect(fetched.lastAttemptAt, isNotNull);
      });
    });

    group('status updates', () {
      test(
        'markPublishing moves row to publishing and records attempt time',
        () async {
          await dao.enqueue(makeEvent(id: 'view-a'));

          final before = DateTime.now();
          final updated = await dao.markPublishing('view-a');
          final after = DateTime.now();

          expect(updated, isTrue);
          final fetched = await dao.getById('view-a');
          expect(fetched!.status, PendingViewEventStatus.publishing);
          expect(fetched.lastAttemptAt, isNotNull);
          expect(
            fetched.lastAttemptAt!.isAfter(
              before.subtract(const Duration(seconds: 2)),
            ),
            isTrue,
          );
          expect(
            fetched.lastAttemptAt!.isBefore(
              after.add(const Duration(seconds: 2)),
            ),
            isTrue,
          );
        },
      );

      test('markFailed records error and increments retry count', () async {
        await dao.enqueue(makeEvent(id: 'view-a'));

        final updated = await dao.markFailed('view-a', 'relay rejected');

        expect(updated, isTrue);
        final fetched = await dao.getById('view-a');
        expect(fetched!.status, PendingViewEventStatus.failed);
        expect(fetched.retryCount, 1);
        expect(fetched.lastError, 'relay rejected');
        expect(fetched.lastAttemptAt, isNotNull);
      });

      test('returns false when updating a missing row', () async {
        expect(await dao.markPublishing('missing'), isFalse);
        expect(await dao.markFailed('missing', 'no row'), isFalse);
      });
    });

    group('getRetryableForUser', () {
      test(
        'returns retryable pending, failed, and exhausted rows oldest first',
        () async {
          await dao.enqueue(
            makeEvent(
              id: 'publishing',
              status: PendingViewEventStatus.publishing,
              createdAt: DateTime.utc(2026, 5),
            ),
          );
          await dao.enqueue(
            makeEvent(
              id: 'failed-old',
              status: PendingViewEventStatus.failed,
              retryCount: 2,
              createdAt: DateTime.utc(2026, 5, 2),
            ),
          );
          await dao.enqueue(
            makeEvent(
              id: 'pending-new',
              createdAt: DateTime.utc(2026, 5, 3),
            ),
          );
          await dao.enqueue(
            makeEvent(
              id: 'exhausted',
              status: PendingViewEventStatus.failed,
              retryCount: 5,
              createdAt: DateTime.utc(2026, 5, 4),
            ),
          );
          await dao.enqueue(
            makeEvent(
              id: 'other-user',
              userPubkey: userB,
              createdAt: DateTime.utc(2026, 5, 5),
            ),
          );

          final retryable = await dao.getRetryableForUser(
            userPubkey: userA,
            maxRetries: 5,
          );

          expect(retryable.map((event) => event.id), [
            'failed-old',
            'pending-new',
            'exhausted',
          ]);
        },
      );
    });

    group('resetPublishingToPending', () {
      test(
        'resets interrupted publishing rows for the selected user',
        () async {
          await dao.enqueue(
            makeEvent(
              id: 'publishing-a',
              status: PendingViewEventStatus.publishing,
            ),
          );
          await dao.enqueue(makeEvent(id: 'pending-a'));
          await dao.enqueue(
            makeEvent(
              id: 'publishing-b',
              userPubkey: userB,
              status: PendingViewEventStatus.publishing,
            ),
          );

          final reset = await dao.resetPublishingToPending(userA);

          expect(reset, 1);
          expect(
            (await dao.getById('publishing-a'))!.status,
            PendingViewEventStatus.pending,
          );
          expect(
            (await dao.getById('pending-a'))!.status,
            PendingViewEventStatus.pending,
          );
          expect(
            (await dao.getById('publishing-b'))!.status,
            PendingViewEventStatus.publishing,
          );
        },
      );
    });

    group('deleteById', () {
      test('removes the row after publish success', () async {
        await dao.enqueue(makeEvent(id: 'view-a'));

        final deleted = await dao.deleteById('view-a');

        expect(deleted, 1);
        expect(await dao.getById('view-a'), isNull);
      });
    });
  });
}
