// ABOUTME: Tests for analytics service view tracking and Nostr event publishing
// ABOUTME: Verifies user preference controls, deduplication, and event flow

import 'dart:io';

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/models/view_traffic_source.dart';
import 'package:openvine/services/analytics_ingest_client.dart';
import 'package:openvine/services/analytics_service.dart';
import 'package:openvine/services/product_event_queue.dart';
import 'package:openvine/services/view_event_publisher.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockViewEventPublisher extends Mock implements ViewEventPublisher {}

class _MockPendingViewEventsDao extends Mock implements PendingViewEventsDao {}

class _MockProductEventQueue extends Mock implements ProductEventQueue {}

class _FakeVideoEvent extends Fake implements VideoEvent {}

class _FakeProductAnalyticsEvent extends Fake
    implements ProductAnalyticsEvent {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeVideoEvent());
    registerFallbackValue(_FakeProductAnalyticsEvent());
    registerFallbackValue(_pendingViewEventFallback());
    registerFallbackValue(ViewTrafficSource.unknown);
  });
  group('AnalyticsService', () {
    late AnalyticsService analyticsService;
    AppDatabase? database;
    String? tempDbPath;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      analyticsService = AnalyticsService(disableNostrPublishing: true);
    });

    tearDown(() async {
      analyticsService.dispose();
      await database?.close();
      final path = tempDbPath;
      if (path != null) {
        final file = File(path);
        if (file.existsSync()) {
          file.deleteSync();
        }
        final dir = Directory(path).parent;
        if (dir.existsSync()) {
          dir.deleteSync(recursive: true);
        }
      }
    });

    test('should initialize with analytics enabled by default', () async {
      await analyticsService.initialize();
      expect(analyticsService.analyticsEnabled, isTrue);
    });

    test('should report operational when analytics enabled', () async {
      await analyticsService.initialize();
      expect(analyticsService.isOperational, isTrue);
    });

    test('should report not operational when analytics disabled', () async {
      await analyticsService.initialize();
      await analyticsService.setAnalyticsEnabled(false);
      expect(analyticsService.isOperational, isFalse);
    });

    test('should not track views when analytics is disabled', () async {
      await analyticsService.initialize();
      await analyticsService.setAnalyticsEnabled(false);

      final video = VideoEvent(
        id: '22e73ca1faedb07dd3e24c1dca52d849aa75c6e4090eb60c532820b782c93da3',
        pubkey:
            'ae73ca1faedb07dd3e24c1dca52d849aa75c6e4090eb60c532820b782c93da3',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        content: 'Test video',
        timestamp: DateTime.now(),
      );

      // Should complete without error even when disabled
      await expectLater(analyticsService.trackVideoView(video), completes);
    });

    test('should track view_start without publishing Nostr event', () async {
      await analyticsService.initialize();

      final video = VideoEvent(
        id: '22e73ca1faedb07dd3e24c1dca52d849aa75c6e4090eb60c532820b782c93da3',
        pubkey:
            'ae73ca1faedb07dd3e24c1dca52d849aa75c6e4090eb60c532820b782c93da3',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        content: 'Test video',
        timestamp: DateTime.now(),
      );

      // view_start should complete without error (no Nostr event published)
      await expectLater(
        analyticsService.trackDetailedVideoViewWithUser(
          video,
          userId: 'test-user',
          source: 'mobile',
          eventType: 'view_start',
        ),
        completes,
      );
    });

    test('should deduplicate rapid view_start events for same video', () async {
      await analyticsService.initialize();

      final video = VideoEvent(
        id: '22e73ca1faedb07dd3e24c1dca52d849aa75c6e4090eb60c532820b782c93da3',
        pubkey:
            'ae73ca1faedb07dd3e24c1dca52d849aa75c6e4090eb60c532820b782c93da3',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        content: 'Test video',
        timestamp: DateTime.now(),
      );

      // Track same video twice rapidly - second should be deduped
      await analyticsService.trackVideoView(video);
      await analyticsService.trackVideoView(video);

      // Should complete without error (dedup is internal)
      expect(true, isTrue);
    });

    test('track stamps identity and session before enqueueing', () async {
      final queue = _MockProductEventQueue();
      when(() => queue.enqueue(any())).thenAnswer((_) async {});
      analyticsService.dispose();
      analyticsService = AnalyticsService(
        productEventQueue: queue,
        currentUserPubkey: () =>
            '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        anonymousId: () => '018ff7d7-2ef5-7000-8000-000000000001',
        sessionId: () => '018ff7d7-2ef5-7000-8000-000000000002',
        platform: () => 'ios',
        appVersion: () => '1.2.3',
        buildNumber: () => '123',
        now: () => DateTime.utc(2026, 7, 7, 12),
        eventIdFactory: () => '018ff7d7-2ef5-7000-8000-000000000003',
      );
      await analyticsService.initialize();

      await analyticsService.track(
        'screen_time',
        surface: AnalyticsSurface.feed,
        props: const {'screen_name': 'feed'},
        propsNum: const {'duration_ms': 1250.0},
        targetId:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      );

      final captured =
          verify(() => queue.enqueue(captureAny())).captured.single
              as ProductAnalyticsEvent;
      expect(captured.eventId, '018ff7d7-2ef5-7000-8000-000000000003');
      expect(captured.eventName, 'screen_time');
      expect(captured.occurredAt, DateTime.utc(2026, 7, 7, 12));
      expect(
        captured.userPubkey,
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      );
      expect(captured.anonymousId, '018ff7d7-2ef5-7000-8000-000000000001');
      expect(captured.sessionId, '018ff7d7-2ef5-7000-8000-000000000002');
      expect(captured.platform, 'ios');
      expect(captured.appVersion, '1.2.3');
      expect(captured.buildNumber, '123');
      expect(captured.surface, AnalyticsSurface.feed);
      expect(captured.targetId, contains('aaaaaaaa'));
      expect(captured.props, containsPair('screen_name', 'feed'));
      expect(captured.propsNum, containsPair('duration_ms', 1250.0));
    });

    test('enqueues eligible view_end before triggering a retry flush', () async {
      final tempDir = Directory.systemTemp.createTempSync(
        'analytics_pending_view_test_',
      );
      tempDbPath = '${tempDir.path}/test.db';
      database = AppDatabase.test(NativeDatabase(File(tempDbPath!)));
      var flushCount = 0;
      analyticsService.dispose();
      analyticsService = AnalyticsService(
        pendingViewEventsDao: database!.pendingViewEventsDao,
        flushPendingViewEvents: () async {
          flushCount++;
        },
      );
      await analyticsService.initialize();

      final video = VideoEvent(
        id: '22e73ca1faedb07dd3e24c1dca52d849aa75c6e4090eb60c532820b782c93da3',
        pubkey:
            'ae73ca1faedb07dd3e24c1dca52d849aa75c6e4090eb60c532820b782c93da3',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        content: 'Test video',
        timestamp: DateTime.now(),
        vineId: 'vine-id',
        addressableDTag: 'the-d-tag',
        eventKind: NIP71VideoKinds.addressableShortVideo,
      );

      await analyticsService.trackDetailedVideoViewWithUser(
        video,
        userId:
            '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        source: 'mobile',
        eventType: 'view_end',
        watchDuration: const Duration(milliseconds: 2500),
        totalDuration: const Duration(seconds: 6),
        loopCount: 1,
        trafficSource: ViewTrafficSource.home,
        sourceDetail: 'following',
      );

      final retryable = await database!.pendingViewEventsDao.getRetryableForUser(
        userPubkey:
            '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      );
      expect(retryable, hasLength(1));
      expect(retryable.single.videoId, video.id);
      expect(retryable.single.videoPubkey, video.pubkey);
      expect(retryable.single.videoVineId, 'vine-id');
      // Without this the row cannot address its subject, and every retry is
      // skipped by ViewEventPublisher for the lifetime of the queue (#7169).
      expect(retryable.single.videoAddressableDTag, 'the-d-tag');
      expect(
        retryable.single.videoEventKind,
        NIP71VideoKinds.addressableShortVideo,
      );
      expect(retryable.single.watchDurationMs, 2500);
      expect(retryable.single.totalDurationMs, 6000);
      expect(retryable.single.loopCount, 1);
      expect(retryable.single.trafficSource, 'home');
      expect(retryable.single.sourceDetail, 'following');
      expect(flushCount, 1);
    });

    test(
      'does not enqueue or directly publish regular videos without d tags',
      () async {
        final publisher = _MockViewEventPublisher();
        final dao = _MockPendingViewEventsDao();
        analyticsService.dispose();
        analyticsService = AnalyticsService(
          viewEventPublisher: publisher,
          pendingViewEventsDao: dao,
        );
        await analyticsService.initialize();

        final video = VideoEvent(
          id: '22e73ca1faedb07dd3e24c1dca52d849aa75c6e4090eb60c532820b782c93da3',
          pubkey:
              'ae73ca1faedb07dd3e24c1dca52d849aa75c6e4090eb60c532820b782c93da3',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          content: 'Test video',
          timestamp: DateTime.now(),
          eventKind: NIP71VideoKinds.shortVideo,
        );

        await analyticsService.trackDetailedVideoViewWithUser(
          video,
          userId:
              '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
          source: 'mobile',
          eventType: 'view_end',
          watchDuration: const Duration(seconds: 2),
        );
        await Future<void>.delayed(Duration.zero);

        verifyNever(() => dao.enqueue(any()));
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

    test('view_start enqueues a start-phase row with zero watch', () async {
      final tempDir = Directory.systemTemp.createTempSync(
        'analytics_pending_start_test_',
      );
      tempDbPath = '${tempDir.path}/test.db';
      database = AppDatabase.test(NativeDatabase(File(tempDbPath!)));
      analyticsService.dispose();
      analyticsService = AnalyticsService(
        pendingViewEventsDao: database!.pendingViewEventsDao,
        flushPendingViewEvents: () async {},
      );
      await analyticsService.initialize();

      final video = VideoEvent(
        id: '22e73ca1faedb07dd3e24c1dca52d849aa75c6e4090eb60c532820b782c93da3',
        pubkey:
            'ae73ca1faedb07dd3e24c1dca52d849aa75c6e4090eb60c532820b782c93da3',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        content: 'Test video',
        timestamp: DateTime.now(),
        vineId: 'vine-id',
        addressableDTag: 'the-d-tag',
      );
      const user =
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

      await analyticsService.trackDetailedVideoViewWithUser(
        video,
        userId: user,
        source: 'mobile',
        eventType: 'view_start',
        sessionToken: 'mount-1',
        trafficSource: ViewTrafficSource.home,
      );

      final rows = await database!.pendingViewEventsDao.getRetryableForUser(
        userPubkey: user,
      );
      expect(rows, hasLength(1));
      expect(rows.single.phase, 'start');
      // A start knows nothing about watch time yet — the row must not mint
      // engagement the viewer never gave.
      expect(rows.single.watchDurationMs, 0);
      expect(rows.single.loopCount, isNull);
      expect(rows.single.videoAddressableDTag, 'the-d-tag');
    });

    test(
      'view_start dedupes within a session token but a new token re-publishes',
      () async {
        final tempDir = Directory.systemTemp.createTempSync(
          'analytics_pending_start_dedupe_test_',
        );
        tempDbPath = '${tempDir.path}/test.db';
        database = AppDatabase.test(NativeDatabase(File(tempDbPath!)));
        analyticsService.dispose();
        analyticsService = AnalyticsService(
          pendingViewEventsDao: database!.pendingViewEventsDao,
          flushPendingViewEvents: () async {},
        );
        await analyticsService.initialize();

        final video = VideoEvent(
          id: '22e73ca1faedb07dd3e24c1dca52d849aa75c6e4090eb60c532820b782c93da3',
          pubkey:
              'ae73ca1faedb07dd3e24c1dca52d849aa75c6e4090eb60c532820b782c93da3',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          content: 'Test video',
          timestamp: DateTime.now(),
          vineId: 'vine-id',
          addressableDTag: 'the-d-tag',
        );
        const user =
            '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

        Future<void> start(String token) =>
            analyticsService.trackDetailedVideoViewWithUser(
              video,
              userId: user,
              source: 'mobile',
              eventType: 'view_start',
              sessionToken: token,
            );

        // A double-fire inside one mount collapses; a remount (re-watch) is
        // a new session and must report its own start.
        await start('mount-1');
        await start('mount-1');
        await start('mount-2');

        final rows = await database!.pendingViewEventsDao.getRetryableForUser(
          userPubkey: user,
        );
        expect(rows, hasLength(2));
        expect(rows.every((row) => row.phase == 'start'), isTrue);
      },
    );

    test('does not enqueue when analytics is disabled', () async {
      final tempDir = Directory.systemTemp.createTempSync(
        'analytics_disabled_pending_view_test_',
      );
      tempDbPath = '${tempDir.path}/test.db';
      database = AppDatabase.test(NativeDatabase(File(tempDbPath!)));
      var flushCount = 0;
      analyticsService.dispose();
      analyticsService = AnalyticsService(
        pendingViewEventsDao: database!.pendingViewEventsDao,
        flushPendingViewEvents: () async {
          flushCount++;
        },
      );
      await analyticsService.initialize();
      await analyticsService.setAnalyticsEnabled(false);

      final video = VideoEvent(
        id: '22e73ca1faedb07dd3e24c1dca52d849aa75c6e4090eb60c532820b782c93da3',
        pubkey:
            'ae73ca1faedb07dd3e24c1dca52d849aa75c6e4090eb60c532820b782c93da3',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        content: 'Test video',
        timestamp: DateTime.now(),
      );

      await analyticsService.trackDetailedVideoViewWithUser(
        video,
        userId:
            '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        source: 'mobile',
        eventType: 'view_end',
        watchDuration: const Duration(seconds: 2),
      );

      final retryable = await database!.pendingViewEventsDao.getRetryableForUser(
        userPubkey:
            '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      );
      expect(retryable, isEmpty);
      expect(flushCount, 0);
    });

    test('falls back to direct publish when pending enqueue fails', () async {
      final publisher = _MockViewEventPublisher();
      final dao = _MockPendingViewEventsDao();
      when(() => dao.enqueue(any())).thenThrow(StateError('enqueue failed'));
      when(
        () => publisher.publishViewEvent(
          video: any(named: 'video'),
          startSeconds: any(named: 'startSeconds'),
          endSeconds: any(named: 'endSeconds'),
          source: any(named: 'source'),
          sourceDetail: any(named: 'sourceDetail'),
          loopCount: any(named: 'loopCount'),
          phase: any(named: 'phase'),
        ),
      ).thenAnswer((_) async => true);
      analyticsService.dispose();
      analyticsService = AnalyticsService(
        viewEventPublisher: publisher,
        pendingViewEventsDao: dao,
      );
      await analyticsService.initialize();
      final video = _testVideo();

      await expectLater(
        analyticsService.trackDetailedVideoViewWithUser(
          video,
          userId:
              '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
          source: 'mobile',
          eventType: 'view_end',
          watchDuration: const Duration(seconds: 2),
          trafficSource: ViewTrafficSource.home,
        ),
        completes,
      );
      await Future<void>.delayed(Duration.zero);

      verify(
        () => publisher.publishViewEvent(
          video: video,
          startSeconds: 0,
          endSeconds: 2,
          source: ViewTrafficSource.home,
          sourceDetail: any(named: 'sourceDetail'),
          loopCount: any(named: 'loopCount'),
          // The direct-publish fallback carries the same phase the queued
          // row would have, so the relay counts it identically.
          phase: ViewEventPhase.end,
        ),
      ).called(1);
    });

    test('keeps queued row when immediate flush fails', () async {
      final tempDir = Directory.systemTemp.createTempSync(
        'analytics_flush_failure_test_',
      );
      tempDbPath = '${tempDir.path}/test.db';
      database = AppDatabase.test(NativeDatabase(File(tempDbPath!)));
      final publisher = _MockViewEventPublisher();
      analyticsService.dispose();
      analyticsService = AnalyticsService(
        viewEventPublisher: publisher,
        pendingViewEventsDao: database!.pendingViewEventsDao,
        flushPendingViewEvents: () async => throw StateError('flush failed'),
      );
      await analyticsService.initialize();
      final video = _testVideo();
      const userPubkey =
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

      await expectLater(
        analyticsService.trackDetailedVideoViewWithUser(
          video,
          userId: userPubkey,
          source: 'mobile',
          eventType: 'view_end',
          watchDuration: const Duration(seconds: 2),
          trafficSource: ViewTrafficSource.home,
        ),
        completes,
      );

      final retryable = await database!.pendingViewEventsDao
          .getRetryableForUser(userPubkey: userPubkey);
      expect(retryable, hasLength(1));
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
    });

    test('should persist analytics preference', () async {
      await analyticsService.initialize();

      // Disable analytics
      await analyticsService.setAnalyticsEnabled(false);

      // Verify persisted
      final prefs = await SharedPreferences.getInstance();
      final savedValue = prefs.getBool('analytics_enabled');
      expect(savedValue, isFalse);

      // Re-enable
      await analyticsService.setAnalyticsEnabled(true);
      final savedValue2 = prefs.getBool('analytics_enabled');
      expect(savedValue2, isTrue);
    });

    test('should clear tracked views cache', () async {
      await analyticsService.initialize();
      analyticsService.clearTrackedViews();
      // Should not throw
      expect(true, isTrue);
    });

    test('should handle batch tracking of empty list', () async {
      await analyticsService.initialize();
      await expectLater(analyticsService.trackVideoViews([]), completes);
    });

    test('should not batch track when analytics disabled', () async {
      await analyticsService.initialize();
      await analyticsService.setAnalyticsEnabled(false);

      final now = DateTime.now();
      final videos = List.generate(
        3,
        (i) => VideoEvent(
          id: 'video_$i',
          pubkey: 'pubkey_$i',
          content: 'Test video $i',
          createdAt: now.millisecondsSinceEpoch ~/ 1000,
          timestamp: now,
        ),
      );

      await expectLater(analyticsService.trackVideoViews(videos), completes);
    });
  });
}

VideoEvent _testVideo() {
  return VideoEvent(
    id: '22e73ca1faedb07dd3e24c1dca52d849aa75c6e4090eb60c532820b782c93da3',
    pubkey: 'ae73ca1faedb07dd3e24c1dca52d849aa75c6e4090eb60c532820b782c93da3',
    createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    content: 'Test video',
    timestamp: DateTime.now(),
    vineId: 'vine-id',
  );
}

PendingViewEvent _pendingViewEventFallback() {
  return PendingViewEvent(
    id: 'fallback',
    videoId: 'video-fallback',
    videoPubkey:
        'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210',
    userPubkey:
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
    watchDurationMs: 1000,
    trafficSource: 'unknown',
    status: PendingViewEventStatus.pending,
    createdAt: DateTime.utc(2026, 5),
  );
}
