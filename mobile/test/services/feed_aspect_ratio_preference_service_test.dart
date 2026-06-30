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

    VideoEvent video({required String dimensions}) {
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

    VideoEvent videoWithoutDimensions({required String id}) {
      return VideoEvent(
        id: id,
        pubkey: 'pubkey',
        createdAt: 1,
        content: '',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
        videoUrl: 'https://example.com/$id.mp4',
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

      expect(service.shouldHideVideo(video(dimensions: '')), isFalse);
    });

    test('square-only hides a video learned non-square from rendered '
        'dimensions', () async {
      final service = FeedAspectRatioPreferenceService(prefs);
      await service.setPreference(FeedAspectRatioPreference.squareOnly);
      final target = videoWithoutDimensions(id: 'v1');

      expect(service.shouldHideVideo(target), isFalse);

      service.recordRenderedDimensions('v1', 720, 1280);

      expect(service.shouldHideVideo(target), isTrue);
    });

    test('square-only keeps a video learned square from rendered '
        'dimensions', () async {
      final service = FeedAspectRatioPreferenceService(prefs);
      await service.setPreference(FeedAspectRatioPreference.squareOnly);
      final target = videoWithoutDimensions(id: 'v1');

      service.recordRenderedDimensions('v1', 640, 640);

      expect(service.shouldHideVideo(target), isFalse);
    });

    test(
      'metadata dimensions take precedence over rendered dimensions',
      () async {
        final service = FeedAspectRatioPreferenceService(prefs);
        await service.setPreference(FeedAspectRatioPreference.squareOnly);

        // Rendered says portrait, but the event metadata says square.
        service.recordRenderedDimensions('event-id', 720, 1280);

        expect(service.shouldHideVideo(video(dimensions: '640x640')), isFalse);
      },
    );

    test('rendered dimensions are ignored under square-and-portrait', () {
      final service = FeedAspectRatioPreferenceService(prefs);
      final target = videoWithoutDimensions(id: 'v1');

      service.recordRenderedDimensions('v1', 720, 1280);

      expect(service.shouldHideVideo(target), isFalse);
    });

    test('revision bumps only when a new non-square video is learned '
        'under square-only', () async {
      final service = FeedAspectRatioPreferenceService(prefs);
      await service.setPreference(FeedAspectRatioPreference.squareOnly);

      expect(service.renderedDimensionsRevision.value, 0);

      service.recordRenderedDimensions('square', 640, 640);
      expect(service.renderedDimensionsRevision.value, 0);

      service.recordRenderedDimensions('portrait', 720, 1280);
      expect(service.renderedDimensionsRevision.value, 1);

      // Re-recording the same result does not bump again.
      service.recordRenderedDimensions('portrait', 720, 1280);
      expect(service.renderedDimensionsRevision.value, 1);
    });

    test('revision does not bump under square-and-portrait', () {
      final service = FeedAspectRatioPreferenceService(prefs);

      service.recordRenderedDimensions('portrait', 720, 1280);

      expect(service.renderedDimensionsRevision.value, 0);
    });
  });
}
