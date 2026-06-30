// ABOUTME: Tests that VideoEventService.filterVideoList drops non-square videos
// ABOUTME: when the "square only" feed aspect-ratio preference is attached.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/services/feed_aspect_ratio_preference_service.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockSubscriptionManager extends Mock implements SubscriptionManager {}

VideoEvent _videoEvent({required String id, String? dimensions}) {
  final event =
      Event(
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          34236,
          [
            ['d', 'd-$id'],
            ['url', 'https://example.com/$id.mp4'],
            if (dimensions != null) ['dim', dimensions],
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

  group('VideoEventService aspect-ratio filtering', () {
    late VideoEventService service;
    late _MockNostrClient nostrClient;
    late _MockSubscriptionManager subscriptionManager;
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
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
    });

    tearDown(() {
      service.dispose();
    });

    test(
      'filterVideoList drops non-square videos when square-only is attached',
      () async {
        final preference = FeedAspectRatioPreferenceService(prefs);
        await preference.setPreference(FeedAspectRatioPreference.squareOnly);
        service.setFeedAspectRatioPreference(preference);

        final videos = [
          _videoEvent(id: 'square', dimensions: '640x640'),
          _videoEvent(id: 'portrait', dimensions: '720x1280'),
          _videoEvent(id: 'landscape', dimensions: '1280x720'),
        ];

        final filtered = service.filterVideoList(videos);

        expect(filtered.map((v) => v.id), equals(['square']));
      },
    );

    test(
      'filterVideoList keeps dimensionless videos even when square-only',
      () async {
        final preference = FeedAspectRatioPreferenceService(prefs);
        await preference.setPreference(FeedAspectRatioPreference.squareOnly);
        service.setFeedAspectRatioPreference(preference);

        final videos = [
          _videoEvent(id: 'square', dimensions: '640x640'),
          _videoEvent(id: 'unknown'),
        ];

        final filtered = service.filterVideoList(videos);

        expect(filtered.map((v) => v.id), equals(['square', 'unknown']));
      },
    );

    test(
      'filterVideoList keeps all videos when no preference is attached',
      () {
        final videos = [
          _videoEvent(id: 'square', dimensions: '640x640'),
          _videoEvent(id: 'portrait', dimensions: '720x1280'),
        ];

        final filtered = service.filterVideoList(videos);

        expect(filtered.map((v) => v.id), equals(['square', 'portrait']));
      },
    );

    test(
      'filterVideoList keeps all videos under square-and-portrait preference',
      () async {
        final preference = FeedAspectRatioPreferenceService(prefs);
        await preference.setPreference(
          FeedAspectRatioPreference.squareAndPortrait,
        );
        service.setFeedAspectRatioPreference(preference);

        final videos = [
          _videoEvent(id: 'square', dimensions: '640x640'),
          _videoEvent(id: 'portrait', dimensions: '720x1280'),
        ];

        final filtered = service.filterVideoList(videos);

        expect(filtered.map((v) => v.id), equals(['square', 'portrait']));
      },
    );

    test(
      'filterVideoList reflects a live preference change after attach',
      () async {
        final preference = FeedAspectRatioPreferenceService(prefs);
        service.setFeedAspectRatioPreference(preference);

        final videos = [
          _videoEvent(id: 'square', dimensions: '640x640'),
          _videoEvent(id: 'portrait', dimensions: '720x1280'),
        ];
        expect(
          service.filterVideoList(videos).map((v) => v.id),
          equals(['square', 'portrait']),
        );

        await preference.setPreference(FeedAspectRatioPreference.squareOnly);
        expect(
          service.filterVideoList(videos).map((v) => v.id),
          equals(['square']),
        );
      },
    );
  });
}
