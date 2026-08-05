// ABOUTME: Tests VideoEventService filtering for the feed video-shape preference.
// ABOUTME: Verifies square-only filtering at the shared list-surface chokepoint.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/services/feed_aspect_ratio_preference_service.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockSubscriptionManager extends Mock implements SubscriptionManager {}

VideoEvent _video({required String id, String? dimensions}) {
  return VideoEvent(
    id: id,
    pubkey: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    createdAt: 1704067200,
    content: '',
    timestamp: DateTime.fromMillisecondsSinceEpoch(1704067200 * 1000),
    title: 'Test Video',
    videoUrl: 'https://example.com/$id.mp4',
    dimensions: dimensions,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoEventService aspect-ratio filtering', () {
    late VideoEventService service;
    late FeedAspectRatioPreferenceService aspectRatioPreference;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      aspectRatioPreference = FeedAspectRatioPreferenceService(prefs);
      service = VideoEventService(
        _MockNostrClient(),
        subscriptionManager: _MockSubscriptionManager(),
      );
      service.setFeedAspectRatioPreferenceService(aspectRatioPreference);
    });

    tearDown(() {
      service.dispose();
    });

    test(
      'filterVideoList hides portrait videos when square-only is enabled',
      () async {
        await aspectRatioPreference.setPreference(
          FeedAspectRatioPreference.squareOnly,
        );

        final filtered = service.filterVideoList([
          _video(id: 'square', dimensions: '640x640'),
          _video(id: 'portrait', dimensions: '720x1280'),
        ]);

        expect(filtered.map((video) => video.id), equals(['square']));
      },
    );

    test(
      'filterVideoList keeps square and portrait videos when preference is off',
      () {
        final filtered = service.filterVideoList([
          _video(id: 'square', dimensions: '640x640'),
          _video(id: 'portrait', dimensions: '720x1280'),
        ]);

        expect(
          filtered.map((video) => video.id),
          equals(['square', 'portrait']),
        );
      },
    );

    test(
      'filterVideoList keeps videos with unknown or malformed dimensions',
      () async {
        await aspectRatioPreference.setPreference(
          FeedAspectRatioPreference.squareOnly,
        );

        final filtered = service.filterVideoList([
          _video(id: 'missing'),
          _video(id: 'empty', dimensions: ''),
          _video(id: 'malformed', dimensions: '480000'),
          _video(id: 'partial', dimensions: '480x'),
        ]);

        expect(
          filtered.map((video) => video.id),
          equals(['missing', 'empty', 'malformed', 'partial']),
        );
      },
    );
  });
}
