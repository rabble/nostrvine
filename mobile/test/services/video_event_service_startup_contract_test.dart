import 'dart:async';

import 'package:db_client/db_client.dart' hide Filter;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/services/event_router.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:profile_repository/profile_repository.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockSubscriptionManager extends Mock implements SubscriptionManager {}

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockAppDatabase extends Mock implements AppDatabase {}

class _MockNostrEventsDao extends Mock implements NostrEventsDao {}

class _FakeFilter extends Fake implements Filter {}

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

    setUp(() {
      mockNostrService = _MockNostrClient();
      mockSubscriptionManager = _MockSubscriptionManager();
      mockProfileRepository = _MockProfileRepository();
      mockDatabase = _MockAppDatabase();
      mockNostrEventsDao = _MockNostrEventsDao();
      relayController = StreamController<Event>.broadcast();
      batchFetchCompleter = Completer<Map<String, UserProfile>>();

      when(() => mockNostrService.isInitialized).thenReturn(true);
      when(() => mockNostrService.connectedRelayCount).thenReturn(1);
      when(
        () => mockNostrService.subscribe(any(), onEose: any(named: 'onEose')),
      ).thenAnswer((_) => relayController.stream);

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
