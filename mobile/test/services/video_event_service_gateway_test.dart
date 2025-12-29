// ABOUTME: Tests for gateway query integration in VideoEventService
// ABOUTME: Verifies that public feeds use the REST gateway for faster loading

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/services/video_event_service.dart';

// Import mocks from pagination test to avoid regenerating them
import 'video_event_service_pagination_test.mocks.dart';

void main() {
  group('VideoEventService Gateway Integration', () {
    late VideoEventService videoEventService;
    late MockNostrClient mockNostrService;
    late MockSubscriptionManager mockSubscriptionManager;

    setUp(() {
      mockNostrService = MockNostrClient();
      mockSubscriptionManager = MockSubscriptionManager();

      // Setup basic mock responses
      when(mockNostrService.isInitialized).thenReturn(true);
      when(mockNostrService.connectedRelayCount).thenReturn(1);

      // Stub subscribe to return a stream (needed because subscribeToVideoFeed calls it too)
      when(
        mockNostrService.subscribe(any, onEose: anyNamed('onEose')),
      ).thenAnswer((_) => Stream<Event>.empty());

      // Stub queryEvents (the gateway call)
      when(
        mockNostrService.queryEvents(
          any,
          useGateway: anyNamed('useGateway'),
          useCache: anyNamed('useCache'),
        ),
      ).thenAnswer((_) async => <Event>[]);

      videoEventService = VideoEventService(
        mockNostrService,
        subscriptionManager: mockSubscriptionManager,
      );
    });

    test('should query gateway for PopularNow feed', () async {
      // Act
      await videoEventService.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.popularNow,
      );

      // Assert
      // Verify queryEvents was called with useGateway: true
      verify(
        mockNostrService.queryEvents(any, useGateway: true, useCache: false),
      ).called(1);
    });

    test('should NOT query gateway for HomeFeed', () async {
      // Act
      await videoEventService.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.homeFeed,
      );

      // Assert
      // Verify queryEvents was NOT called
      verifyNever(
        mockNostrService.queryEvents(any, useGateway: true, useCache: false),
      );
    });

    test('should handle gateway events by adding them to the feed', () async {
      // Arrange
      final testEvent = Event(
        '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
        34236,
        [
          ['d', 'video_event123'],
          [
            'url',
            'https://example.com/video.mp4',
          ], // Required for hasVideo=true
        ], // tags
        'content', // content
        createdAt: 1000,
      );
      // NOTE: Event constructor calculates ID automatically based on fields

      when(
        mockNostrService.queryEvents(any, useGateway: true, useCache: false),
      ).thenAnswer((_) async => [testEvent]);

      // Act
      await videoEventService.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
      );

      // Wait for async unawaited gateway call to complete
      await Future.delayed(const Duration(milliseconds: 50));

      // Assert
      verify(
        mockNostrService.queryEvents(any, useGateway: true, useCache: false),
      ).called(1);

      // Check if event was added to the list
      expect(
        videoEventService.getVideos(SubscriptionType.discovery).isNotEmpty,
        true,
      );
      final video = videoEventService
          .getVideos(SubscriptionType.discovery)
          .first;
      // We check content/pubkey or calculated ID.
      expect(video.pubkey, testEvent.pubkey);
    });

    test('should query gateway in parallel (non-blocking)', () async {
      // Arrange
      final gatewayCompleter = Completer<List<Event>>();
      final testEvent = Event(
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        34236,
        [
          ['d', 'video_event_blocking'],
          ['url', 'https://example.com/video.mp4'],
        ],
        'content',
        createdAt: 2000,
      );

      when(
        mockNostrService.queryEvents(any, useGateway: true, useCache: false),
      ).thenAnswer((_) => gatewayCompleter.future);

      // Act
      final future = videoEventService.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.trending,
      );

      // Assert: The subscription function should complete immediately
      // WITHOUT waiting for the gateway response.
      await expectLater(future, completes);

      // Verify the gateway call was started but we can't verify result yet
      verify(
        mockNostrService.queryEvents(any, useGateway: true, useCache: false),
      ).called(1);

      // At this point, the list should arguably be empty or contain cache/subscription items
      // assuming no other sources provided items yet.
      expect(videoEventService.getVideos(SubscriptionType.trending), isEmpty);

      // Now complete the gateway call
      gatewayCompleter.complete([testEvent]);

      // Allow async gap for the .then() callback on the future to execute
      await Future.microtask(() {});

      // Verify results are now populated
      expect(
        videoEventService.getVideos(SubscriptionType.trending),
        isNotEmpty,
      );
      expect(
        videoEventService.getVideos(SubscriptionType.trending).first.pubkey,
        testEvent.pubkey,
      );
    });
  });
}
