// ABOUTME: Tests that VideoEventService filters videos confirmed unavailable
// ABOUTME: via the attached BrokenVideoTracker across list surfaces.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/services/broken_video_tracker.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockSubscriptionManager extends Mock implements SubscriptionManager {}

VideoEvent _videoEvent({required String id}) {
  final event =
      Event(
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          34236,
          [
            ['d', 'd-$id'],
            ['url', 'https://example.com/$id.mp4'],
          ],
          'test video',
          createdAt: 1000,
        )
        ..id = id
        ..sig = 'sig-$id';
  return VideoEvent.fromNostrEvent(event);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(<Filter>[]);
  });

  group('VideoEventService broken-video filtering', () {
    late VideoEventService service;
    late _MockNostrClient nostrClient;
    late _MockSubscriptionManager subscriptionManager;
    late BrokenVideoTracker tracker;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      nostrClient = _MockNostrClient();
      subscriptionManager = _MockSubscriptionManager();
      when(() => nostrClient.isInitialized).thenReturn(true);
      when(() => nostrClient.connectedRelayCount).thenReturn(1);
      when(() => nostrClient.publicKey).thenReturn(
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      );
      when(
        () => nostrClient.subscribe(any()),
      ).thenAnswer((_) => const Stream<Event>.empty());

      service = VideoEventService(
        nostrClient,
        subscriptionManager: subscriptionManager,
      );

      tracker = BrokenVideoTracker();
      await tracker.initialize();
    });

    tearDown(() {
      service.dispose();
    });

    test('filterVideoList drops videos marked broken by the tracker', () async {
      await tracker.markVideoBroken('broken1', 'Confirmed unavailable');
      service.setBrokenVideoTracker(tracker);

      final videos = [
        _videoEvent(id: 'good1'),
        _videoEvent(id: 'broken1'),
        _videoEvent(id: 'good2'),
      ];

      final filtered = service.filterVideoList(videos);

      expect(filtered.map((v) => v.id), equals(['good1', 'good2']));
    });

    test('filterVideoList keeps all videos when no tracker attached', () {
      final videos = [_videoEvent(id: 'a'), _videoEvent(id: 'b')];

      final filtered = service.filterVideoList(videos);

      expect(filtered.map((v) => v.id), equals(['a', 'b']));
    });

    test(
      'filterVideoList keeps videos that become broken only after attach',
      () async {
        service.setBrokenVideoTracker(tracker);

        final videos = [_videoEvent(id: 'x'), _videoEvent(id: 'y')];
        expect(service.filterVideoList(videos).map((v) => v.id), ['x', 'y']);

        // Tracker reads live state, so a later mark is reflected immediately.
        await tracker.markVideoBroken('x', 'Confirmed unavailable');
        expect(service.filterVideoList(videos).map((v) => v.id), ['y']);
      },
    );

    test(
      'tracker persistence is scoped between anonymous and signed-in users',
      () async {
        final anonymousTracker = BrokenVideoTracker();
        await anonymousTracker.initialize();
        await anonymousTracker.markVideoBroken('signed-in-can-watch', '404');

        final signedInTracker = BrokenVideoTracker(ownerPubkey: 'a' * 64);
        await signedInTracker.initialize();

        expect(signedInTracker.isVideoBroken('signed-in-can-watch'), isFalse);

        await signedInTracker.markVideoBroken('blocked-for-user', '404');

        final reloadedSignedInTracker = BrokenVideoTracker(
          ownerPubkey: 'a' * 64,
        );
        await reloadedSignedInTracker.initialize();
        final reloadedAnonymousTracker = BrokenVideoTracker();
        await reloadedAnonymousTracker.initialize();

        expect(
          reloadedSignedInTracker.isVideoBroken('blocked-for-user'),
          isTrue,
        );
        expect(
          reloadedAnonymousTracker.isVideoBroken('blocked-for-user'),
          isFalse,
        );
        expect(
          reloadedAnonymousTracker.isVideoBroken('signed-in-can-watch'),
          isTrue,
        );
      },
    );
  });
}
