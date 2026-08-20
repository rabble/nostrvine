// ABOUTME: Regression tests for case-insensitive hashtag filtering in VideoEventService
// ABOUTME: Pins realtime/pagination parity so load-more stops dropping capitalised hashtags
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/constants/nip71_migration.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/services/video_event_service.dart';

class _MinimalNostrClient implements NostrClient {
  @override
  bool get isInitialized => true;

  @override
  bool get isDisposed => false;

  @override
  List<String> get connectedRelays => ['wss://localhost:8080'];

  @override
  int get connectedRelayCount => 1;

  @override
  int get configuredRelayCount => 1;

  @override
  List<String> get configuredRelays => ['wss://localhost:8080'];

  @override
  String get publicKey => '';

  @override
  bool get hasKeys => false;

  @override
  Future<void> dispose() async {}

  @override
  Future<void> initialize({List<String>? customRelays}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Event _videoEvent({required String id, required String hashtag}) {
  final event = Event(
    'a' * 64,
    NIP71VideoKinds.addressableShortVideo,
    [
      ['d', 'vine_$id'],
      ['url', 'https://media.divine.video/$id.mp4'],
      ['m', 'video/mp4'],
      ['t', hashtag],
    ],
    '',
    createdAt: 1787236269,
  );
  event.id = id;
  return event;
}

void main() {
  group(VideoEventService, () {
    late _MinimalNostrClient nostrClient;
    late SubscriptionManager subscriptionManager;
    late VideoEventService service;

    setUp(() {
      nostrClient = _MinimalNostrClient();
      subscriptionManager = SubscriptionManager(nostrClient);
      service = VideoEventService(
        nostrClient,
        subscriptionManager: subscriptionManager,
      );
    });

    tearDown(() async {
      service.dispose();
      await subscriptionManager.dispose();
    });

    group('hashtag filter casing', () {
      // `subscribeToVideoFeed` lowercases the tag for the relay REQ (NIP-24)
      // but stores the caller's original casing in `_activeHashtagFilters`, so
      // every event the relay returns carries the lowercase form. A
      // case-sensitive compare on the pagination path therefore rejected 100%
      // of them whenever the hashtag had any uppercase character.
      test(
        'pagination keeps a lowercase-tagged video under a capitalised filter',
        () {
          service.setActiveHashtagFilterForTesting(
            SubscriptionType.hashtag,
            ['DivineUniversity'],
          );

          service.handleHistoricalEventForTesting(
            _videoEvent(id: 'b' * 64, hashtag: 'divineuniversity'),
            SubscriptionType.hashtag,
          );

          expect(service.getVideos(SubscriptionType.hashtag), hasLength(1));
        },
      );

      test('realtime and pagination agree for the same event and filter', () {
        service.setActiveHashtagFilterForTesting(
          SubscriptionType.hashtag,
          ['DivineUniversity'],
        );

        service.handleEventForTesting(
          _videoEvent(id: 'c' * 64, hashtag: 'divineuniversity'),
          SubscriptionType.hashtag,
        );
        service.handleHistoricalEventForTesting(
          _videoEvent(id: 'd' * 64, hashtag: 'divineuniversity'),
          SubscriptionType.hashtag,
        );

        expect(service.getVideos(SubscriptionType.hashtag), hasLength(2));
      });

      test('a genuinely unrelated hashtag is still rejected on both paths', () {
        service.setActiveHashtagFilterForTesting(
          SubscriptionType.hashtag,
          ['DivineUniversity'],
        );

        service.handleEventForTesting(
          _videoEvent(id: 'e' * 64, hashtag: 'cats'),
          SubscriptionType.hashtag,
        );
        service.handleHistoricalEventForTesting(
          _videoEvent(id: 'f' * 64, hashtag: 'cats'),
          SubscriptionType.hashtag,
        );

        expect(service.getVideos(SubscriptionType.hashtag), isEmpty);
      });
    });
  });
}
