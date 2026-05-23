// ABOUTME: Unit tests for durable view-event retry sweeping.
// ABOUTME: Verifies queued views publish, fail, back off, and terminally drop.

import 'dart:async';
import 'dart:io';

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/services/view_event_publisher.dart';
import 'package:openvine/services/view_event_retry_service.dart';

class _MockViewEventPublisher extends Mock implements ViewEventPublisher {}

class _FakeVideoEvent extends Fake implements VideoEvent {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeVideoEvent());
    registerFallbackValue(ViewTrafficSource.unknown);
  });

  group(ViewEventRetryService, () {
    late AppDatabase database;
    late PendingViewEventsDao dao;
    late _MockViewEventPublisher publisher;
    late String tempDbPath;
    late DateTime now;

    const userPubkey =
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
    const videoPubkey =
        'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210';

    PendingViewEvent makeEvent({
      required String id,
      PendingViewEventStatus status = PendingViewEventStatus.pending,
      int watchDurationMs = 2500,
      int retryCount = 0,
      DateTime? lastAttemptAt,
      String eventVideoPubkey = videoPubkey,
    }) {
      return PendingViewEvent(
        id: id,
        videoId: 'video-$id',
        videoPubkey: eventVideoPubkey,
        videoVineId: 'vine-$id',
        userPubkey: userPubkey,
        watchDurationMs: watchDurationMs,
        totalDurationMs: 6000,
        loopCount: 1,
        trafficSource: 'home',
        sourceDetail: 'following',
        status: status,
        retryCount: retryCount,
        lastAttemptAt: lastAttemptAt,
        createdAt: DateTime.utc(2026, 5),
      );
    }

    ViewEventRetryService makeService({Stream<bool>? foregroundStream}) {
      return ViewEventRetryService(
        viewEventPublisher: publisher,
        pendingViewEventsDao: dao,
        userPubkey: userPubkey,
        appForegroundStream: foregroundStream ?? const Stream<bool>.empty(),
        now: () => now,
      );
    }

    setUp(() {
      final tempDir = Directory.systemTemp.createTempSync(
        'view_event_retry_service_test_',
      );
      tempDbPath = '${tempDir.path}/test.db';
      database = AppDatabase.test(NativeDatabase(File(tempDbPath)));
      dao = database.pendingViewEventsDao;
      publisher = _MockViewEventPublisher();
      now = DateTime.utc(2026, 5, 23, 12);

      when(
        () => publisher.publishViewEvent(
          video: any(named: 'video'),
          startSeconds: any(named: 'startSeconds'),
          endSeconds: any(named: 'endSeconds'),
          source: any(named: 'source'),
          sourceDetail: any(named: 'sourceDetail'),
          loopCount: any(named: 'loopCount'),
        ),
      ).thenAnswer((_) async => true);
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

    test('publishes retryable view and deletes it after success', () async {
      await dao.enqueue(makeEvent(id: 'view-a'));
      final service = makeService();

      await service.sweep();

      expect(await dao.getById('view-a'), isNull);
      final captured = verify(
        () => publisher.publishViewEvent(
          video: captureAny(named: 'video'),
          startSeconds: captureAny(named: 'startSeconds'),
          endSeconds: captureAny(named: 'endSeconds'),
          source: captureAny(named: 'source'),
          sourceDetail: captureAny(named: 'sourceDetail'),
          loopCount: captureAny(named: 'loopCount'),
        ),
      ).captured;
      final video = captured[0] as VideoEvent;
      expect(video.id, 'video-view-a');
      expect(video.pubkey, videoPubkey);
      expect(video.vineId, 'vine-view-a');
      expect(captured[1], 0);
      expect(captured[2], 2);
      expect(captured[3], ViewTrafficSource.home);
      expect(captured[4], 'following');
      expect(captured[5], 1);
    });

    test(
      'marks row failed and increments retry count after publish failure',
      () async {
        when(
          () => publisher.publishViewEvent(
            video: any(named: 'video'),
            startSeconds: any(named: 'startSeconds'),
            endSeconds: any(named: 'endSeconds'),
            source: any(named: 'source'),
            sourceDetail: any(named: 'sourceDetail'),
            loopCount: any(named: 'loopCount'),
          ),
        ).thenAnswer((_) async => false);
        await dao.enqueue(makeEvent(id: 'view-a'));
        final service = makeService();

        await service.sweep();

        final failed = await dao.getById('view-a');
        expect(failed, isNotNull);
        expect(failed!.status, PendingViewEventStatus.failed);
        expect(failed.retryCount, 1);
        expect(failed.lastError, 'publish returned false');
        expect(failed.lastAttemptAt, isNotNull);
      },
    );

    test('skips failed rows whose retry backoff has not elapsed', () async {
      await dao.enqueue(
        makeEvent(
          id: 'view-a',
          status: PendingViewEventStatus.failed,
          retryCount: 2,
          lastAttemptAt: now.subtract(const Duration(seconds: 1)),
        ),
      );
      final service = makeService();

      await service.sweep();

      verifyNever(
        () => publisher.publishViewEvent(
          video: any(named: 'video'),
          startSeconds: any(named: 'startSeconds'),
          endSeconds: any(named: 'endSeconds'),
          source: any(named: 'source'),
          sourceDetail: any(named: 'sourceDetail'),
          loopCount: any(named: 'loopCount'),
        ),
      );
      final skipped = await dao.getById('view-a');
      expect(skipped!.status, PendingViewEventStatus.failed);
      expect(skipped.retryCount, 2);
    });

    test(
      'retries high-retry failed rows after capped backoff elapses',
      () async {
        await dao.enqueue(
          makeEvent(
            id: 'view-a',
            status: PendingViewEventStatus.failed,
            retryCount: 7,
            lastAttemptAt: now.subtract(const Duration(minutes: 6)),
          ),
        );
        final service = makeService();

        await service.sweep();

        expect(await dao.getById('view-a'), isNull);
        verify(
          () => publisher.publishViewEvent(
            video: any(named: 'video'),
            startSeconds: any(named: 'startSeconds'),
            endSeconds: any(named: 'endSeconds'),
            source: any(named: 'source'),
            sourceDetail: any(named: 'sourceDetail'),
            loopCount: any(named: 'loopCount'),
          ),
        ).called(1);
      },
    );

    test(
      'skips high-retry failed rows before capped backoff elapses',
      () async {
        await dao.enqueue(
          makeEvent(
            id: 'view-a',
            status: PendingViewEventStatus.failed,
            retryCount: 7,
            lastAttemptAt: now.subtract(const Duration(minutes: 4)),
          ),
        );
        final service = makeService();

        await service.sweep();

        verifyNever(
          () => publisher.publishViewEvent(
            video: any(named: 'video'),
            startSeconds: any(named: 'startSeconds'),
            endSeconds: any(named: 'endSeconds'),
            source: any(named: 'source'),
            sourceDetail: any(named: 'sourceDetail'),
            loopCount: any(named: 'loopCount'),
          ),
        );
        final skipped = await dao.getById('view-a');
        expect(skipped!.retryCount, 7);
      },
    );

    test(
      'deletes terminal self-views and sub-second rows without publishing',
      () async {
        await dao.enqueue(
          makeEvent(
            id: 'self-view',
            eventVideoPubkey: userPubkey,
          ),
        );
        await dao.enqueue(
          makeEvent(
            id: 'short-view',
            watchDurationMs: 999,
          ),
        );
        final service = makeService();

        await service.sweep();

        expect(await dao.getById('self-view'), isNull);
        expect(await dao.getById('short-view'), isNull);
        verifyNever(
          () => publisher.publishViewEvent(
            video: any(named: 'video'),
            startSeconds: any(named: 'startSeconds'),
            endSeconds: any(named: 'endSeconds'),
            source: any(named: 'source'),
            sourceDetail: any(named: 'sourceDetail'),
            loopCount: any(named: 'loopCount'),
          ),
        );
      },
    );

    test(
      'initialize resets interrupted publishing rows and sweeps on foreground',
      () async {
        final foregroundController = StreamController<bool>();
        addTearDown(foregroundController.close);
        await dao.enqueue(
          makeEvent(id: 'view-a', status: PendingViewEventStatus.publishing),
        );
        final service = makeService(
          foregroundStream: foregroundController.stream,
        );
        addTearDown(service.dispose);

        await service.initialize();
        foregroundController.add(true);
        await Future<void>.delayed(Duration.zero);

        expect(await dao.getById('view-a'), isNull);
        verify(
          () => publisher.publishViewEvent(
            video: any(named: 'video'),
            startSeconds: any(named: 'startSeconds'),
            endSeconds: any(named: 'endSeconds'),
            source: any(named: 'source'),
            sourceDetail: any(named: 'sourceDetail'),
            loopCount: any(named: 'loopCount'),
          ),
        ).called(1);
      },
    );
  });
}
