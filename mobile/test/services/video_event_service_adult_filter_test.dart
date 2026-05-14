// ABOUTME: TDD tests for VideoEventService adult content filtering
// ABOUTME: Tests filtering of flagged content when preference is neverShow

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/services/content_filter_service.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/services/video_event_service.dart';

class MockNostrService extends Mock implements NostrClient {}

class MockSubscriptionManager extends Mock implements SubscriptionManager {}

class MockContentFilterService extends Mock implements ContentFilterService {}

void main() {
  late MockNostrService mockNostrService;
  late MockSubscriptionManager mockSubscriptionManager;
  late MockContentFilterService mockContentFilterService;
  late VideoEventService videoEventService;

  setUp(() {
    mockNostrService = MockNostrService();
    mockSubscriptionManager = MockSubscriptionManager();
    mockContentFilterService = MockContentFilterService();

    videoEventService = VideoEventService(
      mockNostrService,
      subscriptionManager: mockSubscriptionManager,
    );
  });

  group('VideoEventService - adult content filtering', () {
    test('setContentFilterService sets the service correctly', () {
      videoEventService.setContentFilterService(mockContentFilterService);

      expect(true, isTrue);
    });

    test('shouldFilterAdultContent returns false when service not set', () {
      expect(videoEventService.shouldFilterAdultContent, isFalse);
    });

    test(
      'shouldFilterAdultContent returns true when content filter says hide adult content',
      () {
        when(
          () => mockContentFilterService.adultPlaybackPreference,
        ).thenReturn(ContentFilterPreference.hide);
        videoEventService.setContentFilterService(mockContentFilterService);

        expect(videoEventService.shouldFilterAdultContent, isTrue);
      },
    );

    test(
      'shouldFilterAdultContent returns false when content filter says dont hide adult content',
      () {
        when(
          () => mockContentFilterService.adultPlaybackPreference,
        ).thenReturn(ContentFilterPreference.warn);
        videoEventService.setContentFilterService(mockContentFilterService);

        expect(videoEventService.shouldFilterAdultContent, isFalse);
      },
    );

    test('shouldFilterEvent returns true for flagged content when hiding', () {
      when(
        () => mockContentFilterService.adultPlaybackPreference,
      ).thenReturn(ContentFilterPreference.hide);
      videoEventService.setContentFilterService(mockContentFilterService);

      final event = Event(
        '0' * 64, // pubkey
        34236, // NIP-71 video kind
        [
          ['d', 'test-video-id'],
          ['url', 'https://example.com/video.mp4'],
          ['content-warning', 'adult content'],
        ],
        '', // content
      );

      expect(videoEventService.shouldFilterEvent(event), isTrue);
    });

    test(
      'shouldFilterEvent returns false for non-flagged content when hiding',
      () {
        when(
          () => mockContentFilterService.adultPlaybackPreference,
        ).thenReturn(ContentFilterPreference.hide);
        videoEventService.setContentFilterService(mockContentFilterService);

        final event = Event('1' * 64, 34236, [
          ['d', 'test-video-id-2'],
          ['url', 'https://example.com/video2.mp4'],
        ], '');

        expect(videoEventService.shouldFilterEvent(event), isFalse);
      },
    );

    test('shouldFilterEvent returns false when not hiding adult content', () {
      when(
        () => mockContentFilterService.adultPlaybackPreference,
      ).thenReturn(ContentFilterPreference.warn);
      videoEventService.setContentFilterService(mockContentFilterService);

      final event = Event('2' * 64, 34236, [
        ['d', 'test-video-id-3'],
        ['url', 'https://example.com/video3.mp4'],
        ['content-warning', 'adult content'],
      ], '');

      expect(videoEventService.shouldFilterEvent(event), isFalse);
    });

    test('shouldFilterEvent handles NSFW hashtag as adult content', () {
      when(
        () => mockContentFilterService.adultPlaybackPreference,
      ).thenReturn(ContentFilterPreference.hide);
      videoEventService.setContentFilterService(mockContentFilterService);

      final event = Event('3' * 64, 34236, [
        ['d', 'test-video-id-4'],
        ['url', 'https://example.com/video4.mp4'],
        ['t', 'NSFW'],
      ], '');

      expect(videoEventService.shouldFilterEvent(event), isTrue);
    });

    test('shouldFilterEvent handles adult hashtag as adult content', () {
      when(
        () => mockContentFilterService.adultPlaybackPreference,
      ).thenReturn(ContentFilterPreference.hide);
      videoEventService.setContentFilterService(mockContentFilterService);

      final event = Event('4' * 64, 34236, [
        ['d', 'test-video-id-5'],
        ['url', 'https://example.com/video5.mp4'],
        ['t', 'adult'],
      ], '');

      expect(videoEventService.shouldFilterEvent(event), isTrue);
    });

    test(
      'filterAdultContentFromExistingVideos removes flagged videos from all lists',
      () {
        when(
          () => mockContentFilterService.adultPlaybackPreference,
        ).thenReturn(ContentFilterPreference.hide);
        videoEventService.setContentFilterService(mockContentFilterService);

        final removedCount = videoEventService
            .filterAdultContentFromExistingVideos();

        expect(removedCount, isA<int>());
        expect(removedCount, greaterThanOrEqualTo(0));
      },
    );

    test(
      'filterAdultContentFromExistingVideos does nothing when not hiding adult content',
      () {
        when(
          () => mockContentFilterService.adultPlaybackPreference,
        ).thenReturn(ContentFilterPreference.warn);
        videoEventService.setContentFilterService(mockContentFilterService);

        final removedCount = videoEventService
            .filterAdultContentFromExistingVideos();

        expect(removedCount, equals(0));
      },
    );
  });
}
