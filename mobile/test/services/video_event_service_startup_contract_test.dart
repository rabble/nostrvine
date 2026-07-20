import 'dart:async';

import 'package:db_client/db_client.dart' hide Filter;
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/services/event_router.dart';
import 'package:openvine/services/performance_monitoring_service.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:profile_repository/profile_repository.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockSubscriptionManager extends Mock implements SubscriptionManager {}

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockAppDatabase extends Mock implements AppDatabase {}

class _MockNostrEventsDao extends Mock implements NostrEventsDao {}

class _FakeFilter extends Fake implements Filter {}

class _RecordingPerformanceMonitor implements PerformanceTraceMonitor {
  final startedTraces = <String>[];
  final stoppedTraces = <String>[];
  final metrics = <String, Map<String, int>>{};
  final attributes = <String, Map<String, String>>{};

  @override
  void incrementMetric(String traceName, String metricName, int value) {
    metrics.putIfAbsent(traceName, () => {})[metricName] =
        (metrics[traceName]?[metricName] ?? 0) + value;
  }

  @override
  void putAttribute(String traceName, String attribute, String value) {
    attributes.putIfAbsent(traceName, () => {})[attribute] = value;
  }

  @override
  void setMetric(String traceName, String metricName, int value) {
    metrics.putIfAbsent(traceName, () => {})[metricName] = value;
  }

  @override
  Future<void> startTrace(String traceName) async {
    startedTraces.add(traceName);
  }

  @override
  Future<void> stopTrace(String traceName) async {
    stoppedTraces.add(traceName);
  }

  @override
  PerformanceTrace startOperationTrace(String traceName) =>
      // VideoEventService uses the name-keyed trace API, not the handle API.
      throw UnimplementedError();
}

/// Asserts a feed-load trace was started once, stopped exactly once, and closed
/// with the expected first-wins [completion] label and [eventCount] metric.
///
/// The "exactly once" check on [stoppedTraces] is what enforces the trace
/// completion guard's idempotency: if a later completion path leaked past the
/// `traceCompleted` guard it would append a second stop (and overwrite the
/// completion attribute), failing this helper.
void _expectSingleCompletion(
  _RecordingPerformanceMonitor monitor, {
  required String traceName,
  required String completion,
  required int eventCount,
}) {
  expect(monitor.startedTraces, contains(traceName));
  expect(
    monitor.stoppedTraces.where((t) => t == traceName).length,
    1,
    reason: 'trace $traceName must be stopped exactly once (first-wins guard)',
  );
  expect(monitor.metrics[traceName]?['event_count'], eventCount);
  expect(monitor.attributes[traceName]?['completion'], completion);
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeFilter());
    registerFallbackValue(<Filter>[]);
    registerFallbackValue(<Event>[]);
  });

  group('VideoEventService startup contract', () {
    late _MockNostrClient mockNostrService;
    late _MockSubscriptionManager mockSubscriptionManager;
    late _MockProfileRepository mockProfileRepository;
    late _MockAppDatabase mockDatabase;
    late _MockNostrEventsDao mockNostrEventsDao;
    late StreamController<Event> relayController;
    late VideoEventService videoEventService;
    late Completer<Map<String, UserProfile>> batchFetchCompleter;
    late _RecordingPerformanceMonitor performanceMonitor;
    late void Function()? relayEose;

    setUp(() {
      mockNostrService = _MockNostrClient();
      mockSubscriptionManager = _MockSubscriptionManager();
      mockProfileRepository = _MockProfileRepository();
      mockDatabase = _MockAppDatabase();
      mockNostrEventsDao = _MockNostrEventsDao();
      relayController = StreamController<Event>.broadcast();
      batchFetchCompleter = Completer<Map<String, UserProfile>>();
      performanceMonitor = _RecordingPerformanceMonitor();
      relayEose = null;

      when(() => mockNostrService.isInitialized).thenReturn(true);
      when(() => mockNostrService.connectedRelayCount).thenReturn(1);
      when(
        () => mockNostrService.subscribe(any(), onEose: any(named: 'onEose')),
      ).thenAnswer((invocation) {
        relayEose = invocation.namedArguments[#onEose] as void Function()?;
        return relayController.stream;
      });

      when(() => mockDatabase.nostrEventsDao).thenReturn(mockNostrEventsDao);
      when(
        () => mockNostrEventsDao.getEventsByFilter(
          any(),
          sortBy: any(named: 'sortBy'),
        ),
      ).thenAnswer((_) async => [_cachedVideoEvent()]);
      when(
        () => mockNostrEventsDao.upsertEventsBatch(
          any(),
          expireAt: any(named: 'expireAt'),
        ),
      ).thenAnswer((_) async {});

      when(
        () => mockProfileRepository.fetchBatchProfiles(
          pubkeys: any(named: 'pubkeys'),
        ),
      ).thenAnswer((_) => batchFetchCompleter.future);

      videoEventService = VideoEventService(
        mockNostrService,
        subscriptionManager: mockSubscriptionManager,
        profileRepository: mockProfileRepository,
        eventRouter: EventRouter(mockDatabase),
        performanceMonitor: performanceMonitor,
      );
    });

    tearDown(() async {
      if (!batchFetchCompleter.isCompleted) {
        batchFetchCompleter.complete(<String, UserProfile>{});
      }
      // Cancel the stream subscription and clear params BEFORE closing the
      // controller, so onDone never fires and no 5s reconnection Timer leaks
      // into later suites in the merged VGV isolate.
      await videoEventService.unsubscribeFromVideoFeed();
      if (!relayController.isClosed) {
        await relayController.close();
      }
    });

    // Configures the cache DAO to return no cached events, so the relay
    // completion paths — not the 'cache' path — win the trace.
    void withEmptyCache() {
      when(
        () => mockNostrEventsDao.getEventsByFilter(
          any(),
          sortBy: any(named: 'sortBy'),
        ),
      ).thenAnswer((_) async => const <Event>[]);
    }

    test(
      'returns after cached events without waiting for batch profile hydration',
      () async {
        await videoEventService
            .subscribeToVideoFeed(subscriptionType: SubscriptionType.discovery)
            .timeout(const Duration(milliseconds: 100));

        expect(videoEventService.discoveryVideos, isNotEmpty);
        verify(
          () => mockProfileRepository.fetchBatchProfiles(pubkeys: ['a' * 64]),
        ).called(1);
        verify(
          () => mockNostrService.subscribe(any(), onEose: any(named: 'onEose')),
        ).called(1);
      },
    );

    group('feed-load trace completion', () {
      test('cache: cached events populate the feed', () async {
        await videoEventService
            .subscribeToVideoFeed(
              subscriptionType: SubscriptionType.profile,
              authors: ['a' * 64],
            )
            .timeout(const Duration(milliseconds: 100));

        _expectSingleCompletion(
          performanceMonitor,
          traceName: 'feed_load_profile',
          completion: 'cache',
          eventCount: 1,
        );
      });

      test('eose_empty: relay completes with no events', () async {
        withEmptyCache();

        await videoEventService
            .subscribeToVideoFeed(
              subscriptionType: SubscriptionType.profile,
              authors: ['a' * 64],
            )
            .timeout(const Duration(milliseconds: 100));

        relayEose!();

        _expectSingleCompletion(
          performanceMonitor,
          traceName: 'feed_load_profile',
          completion: 'eose_empty',
          eventCount: 0,
        );
      });

      test('first_relay_event: first relay event arrives', () async {
        withEmptyCache();

        await videoEventService
            .subscribeToVideoFeed(
              subscriptionType: SubscriptionType.profile,
              authors: ['a' * 64],
            )
            .timeout(const Duration(milliseconds: 100));

        relayController.add(_relayVideoEvent());
        await pumpEventQueue();

        _expectSingleCompletion(
          performanceMonitor,
          traceName: 'feed_load_profile',
          completion: 'first_relay_event',
          eventCount: 1,
        );
      });

      test('error: relay stream errors before any completion', () async {
        withEmptyCache();

        await videoEventService
            .subscribeToVideoFeed(
              subscriptionType: SubscriptionType.profile,
              authors: ['a' * 64],
            )
            .timeout(const Duration(milliseconds: 100));

        relayController.addError(Exception('relay boom'));
        await pumpEventQueue();

        _expectSingleCompletion(
          performanceMonitor,
          traceName: 'feed_load_profile',
          completion: 'error',
          eventCount: 0,
        );
      });

      test('done: relay stream closes before any completion', () async {
        withEmptyCache();

        // Non-persistent type: onDone cleans up instead of scheduling a
        // reconnection timer, keeping the test timer-clean.
        await videoEventService
            .subscribeToVideoFeed(subscriptionType: SubscriptionType.search)
            .timeout(const Duration(milliseconds: 100));

        await relayController.close();

        _expectSingleCompletion(
          performanceMonitor,
          traceName: 'feed_load_search',
          completion: 'done',
          eventCount: 0,
        );
      });

      test('timeout: no events and no EOSE within the timeout window', () {
        withEmptyCache();

        fakeAsync((async) {
          videoEventService.subscribeToVideoFeed(
            subscriptionType: SubscriptionType.profile,
            authors: ['a' * 64],
          );
          async.flushMicrotasks();

          async.elapse(const Duration(seconds: 31));
          async.flushMicrotasks();

          _expectSingleCompletion(
            performanceMonitor,
            traceName: 'feed_load_profile',
            completion: 'timeout',
            eventCount: 0,
          );
        });
      });

      test(
        'idempotent: first relay event wins, later EOSE does not re-complete',
        () async {
          withEmptyCache();

          await videoEventService
              .subscribeToVideoFeed(
                subscriptionType: SubscriptionType.profile,
                authors: ['a' * 64],
              )
              .timeout(const Duration(milliseconds: 100));

          relayController.add(_relayVideoEvent());
          await pumpEventQueue();

          // eventCount is now 1, so this drives the 'eose' branch — which must
          // be blocked by the first-wins guard rather than re-completing.
          relayEose!();
          await pumpEventQueue();

          _expectSingleCompletion(
            performanceMonitor,
            traceName: 'feed_load_profile',
            completion: 'first_relay_event',
            eventCount: 1,
          );
        },
      );

      test(
        'idempotent: first relay event wins, later done does not re-complete',
        () async {
          withEmptyCache();

          await videoEventService
              .subscribeToVideoFeed(subscriptionType: SubscriptionType.search)
              .timeout(const Duration(milliseconds: 100));

          relayController.add(_relayVideoEvent());
          await pumpEventQueue();

          await relayController.close();

          _expectSingleCompletion(
            performanceMonitor,
            traceName: 'feed_load_search',
            completion: 'first_relay_event',
            eventCount: 1,
          );
        },
      );
    });
  });
}

Event _cachedVideoEvent() {
  final event = Event(
    'a' * 64,
    34236,
    const [
      ['url', 'https://example.com/cached-video.mp4'],
      ['m', 'video/mp4'],
      ['thumb', 'https://example.com/cached-thumb.jpg'],
      ['title', 'Cached video'],
    ],
    'cached content',
    createdAt: 1_700_000_000,
  );
  event.id = 'b' * 64;
  return event;
}

Event _relayVideoEvent() {
  final event = Event(
    'a' * 64,
    34236,
    const [
      ['url', 'https://example.com/relay-video.mp4'],
      ['m', 'video/mp4'],
      ['thumb', 'https://example.com/relay-thumb.jpg'],
      ['title', 'Relay video'],
    ],
    'relay content',
    createdAt: 1_700_000_001,
  );
  event.id = 'c' * 64;
  return event;
}
