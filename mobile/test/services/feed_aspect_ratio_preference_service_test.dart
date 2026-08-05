// ABOUTME: Tests for the feed aspect-ratio viewing preference.
// ABOUTME: Verifies persistence and square-only video filtering behavior.

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/services/feed_aspect_ratio_preference_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('FeedAspectRatioPreferenceService', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    VideoEvent video({String? dimensions}) {
      return VideoEvent(
        id: 'event-id',
        pubkey: 'pubkey',
        createdAt: 1,
        content: '',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
        videoUrl: 'https://example.com/video.mp4',
        dimensions: dimensions,
      );
    }

    test('defaults to showing square and portrait videos', () {
      final service = FeedAspectRatioPreferenceService(prefs);

      expect(service.preference, FeedAspectRatioPreference.squareAndPortrait);
      expect(service.shouldHideVideo(video(dimensions: '640x640')), isFalse);
      expect(service.shouldHideVideo(video(dimensions: '720x1280')), isFalse);
    });

    test('persists square-only preference', () async {
      final service = FeedAspectRatioPreferenceService(prefs);

      await service.setPreference(FeedAspectRatioPreference.squareOnly);

      final reloaded = FeedAspectRatioPreferenceService(prefs);
      expect(reloaded.preference, FeedAspectRatioPreference.squareOnly);
    });

    test('square-only hides non-square videos with known dimensions', () async {
      final service = FeedAspectRatioPreferenceService(prefs);
      await service.setPreference(FeedAspectRatioPreference.squareOnly);

      expect(service.shouldHideVideo(video(dimensions: '640x640')), isFalse);
      expect(service.shouldHideVideo(video(dimensions: '720x1280')), isTrue);
      expect(service.shouldHideVideo(video(dimensions: '1280x720')), isTrue);
    });

    test('square-only keeps videos without dimensions', () async {
      final service = FeedAspectRatioPreferenceService(prefs);
      await service.setPreference(FeedAspectRatioPreference.squareOnly);

      expect(service.shouldHideVideo(video()), isFalse);
      expect(service.shouldHideVideo(video(dimensions: '')), isFalse);
    });

    test('square-only keeps videos with malformed dimensions', () async {
      final service = FeedAspectRatioPreferenceService(prefs);
      await service.setPreference(FeedAspectRatioPreference.squareOnly);

      // A bare integer is what a NIP-94 `size` (bytes) tag looks like if it
      // ever reaches `dimensions`; `480x` is a truncated `dim`. Neither
      // yields a height, and the filter must fail open rather than hide.
      expect(service.shouldHideVideo(video(dimensions: '480000')), isFalse);
      expect(service.shouldHideVideo(video(dimensions: '480x')), isFalse);
    });
  });
}
