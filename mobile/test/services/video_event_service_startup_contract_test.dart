import 'dart:async';

import 'package:db_client/db_client.dart' hide Filter;
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
      await relayController.close();
    });

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

    test(
      'stops profile feed trace when cached events populate the feed',
      () async {
        await videoEventService
            .subscribeToVideoFeed(
              subscriptionType: SubscriptionType.profile,
              authors: ['a' * 64],
            )
            .timeout(const Duration(milliseconds: 100));

        expect(performanceMonitor.startedTraces, contains('feed_load_profile'));
        expect(performanceMonitor.stoppedTraces, contains('feed_load_profile'));
        expect(
          performanceMonitor.metrics['feed_load_profile']?['event_count'],
          1,
        );
        expect(
          performanceMonitor.attributes['feed_load_profile']?['completion'],
          'cache',
        );
      },
    );

    test('stops profile feed trace when relay completes empty', () async {
      when(
        () => mockNostrEventsDao.getEventsByFilter(
          any(),
          sortBy: any(named: 'sortBy'),
        ),
      ).thenAnswer((_) async => const <Event>[]);

      await videoEventService
          .subscribeToVideoFeed(
            subscriptionType: SubscriptionType.profile,
            authors: ['a' * 64],
          )
          .timeout(const Duration(milliseconds: 100));

      relayEose!();

      expect(performanceMonitor.startedTraces, contains('feed_load_profile'));
      expect(performanceMonitor.stoppedTraces, contains('feed_load_profile'));
      expect(
        performanceMonitor.metrics['feed_load_profile']?['event_count'],
        0,
      );
      expect(
        performanceMonitor.attributes['feed_load_profile']?['completion'],
        'eose_empty',
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
