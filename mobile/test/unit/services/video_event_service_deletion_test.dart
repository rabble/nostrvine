// ABOUTME: Unit tests for VideoEventService.removeVideoCompletely() method
// ABOUTME: Tests comprehensive video removal from all data structures (issue #270)

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/repositories/video_repository.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/services/video_event_service.dart';

// Mock classes
class MockNostrService extends Mock implements NostrClient {}

class TestSubscriptionManager extends Mock implements SubscriptionManager {
  TestSubscriptionManager(this.eventStreamController);
  final StreamController<Event> eventStreamController;

  @override
  Future<String> createSubscription({
    required String name,
    required List<Filter> filters,
    required Function(Event) onEvent,
    Function(dynamic)? onError,
    VoidCallback? onComplete,
    Duration? timeout,
    int priority = 5,
  }) async {
    return 'mock_sub_$name';
  }

  @override
  Future<void> cancelSubscription(String subscriptionId) async {}
}

class FakeFilter extends Fake implements Filter {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeFilter());
    registerFallbackValue(<Filter>[]);
  });

  group('VideoEventService.removeVideoCompletely()', () {
    late VideoEventService videoEventService;
    late MockNostrService mockNostrService;
    late VideoRepository videoRepository;
    late StreamController<Event> eventStreamController;

    setUp(() {
      mockNostrService = MockNostrService();
      videoRepository = VideoRepository();
      eventStreamController = StreamController<Event>.broadcast();

      when(() => mockNostrService.isInitialized).thenReturn(true);
      when(() => mockNostrService.connectedRelayCount).thenReturn(1);
      when(
        () => mockNostrService.subscribe(any()),
      ).thenAnswer((_) => eventStreamController.stream);

      final testSubscriptionManager = TestSubscriptionManager(
        eventStreamController,
      );

      videoEventService = VideoEventService(
        mockNostrService,
        subscriptionManager: testSubscriptionManager,
        videoRepository: videoRepository,
      );
    });

    tearDown(() async {
      await eventStreamController.close();
      reset(mockNostrService);
    });

    test('marks video as locally deleted in VideoEventService', () {
      const videoId = 'test-video-id-local-delete';

      // Remove a video
      videoEventService.removeVideoCompletely(videoId);

      // Verify video is marked as locally deleted
      expect(videoEventService.isVideoLocallyDeleted(videoId), isTrue);
    });

    test('marks video as locally deleted in VideoRepository', () {
      const videoId = 'test-video-id-repo-delegate';

      videoEventService.removeVideoCompletely(videoId);

      // Verify VideoRepository has the video marked as deleted
      expect(videoRepository.isVideoLocallyDeleted(videoId), isTrue);
    });

    test('handles non-existent video gracefully without throwing', () {
      const videoId = 'non-existent-video-id';

      // Should not throw
      expect(
        () => videoEventService.removeVideoCompletely(videoId),
        returnsNormally,
      );

      // Video should still be marked as locally deleted
      expect(videoEventService.isVideoLocallyDeleted(videoId), isTrue);
      expect(videoRepository.isVideoLocallyDeleted(videoId), isTrue);
    });

    test(
      'deprecated removeVideoFromAuthorList delegates to removeVideoCompletely',
      () {
        const videoId = 'test-video-deprecated';
        const pubkey =
            'c3dd74d68e414f0305db9f7dc96ec32e616502e6ccf5bbf5739de19a96b67f3e';

        // Call deprecated method
        // ignore: deprecated_member_use_from_same_package
        videoEventService.removeVideoFromAuthorList(pubkey, videoId);

        // Verify video is marked as deleted (proves delegation happened)
        expect(videoEventService.isVideoLocallyDeleted(videoId), isTrue);
        expect(videoRepository.isVideoLocallyDeleted(videoId), isTrue);
      },
    );

    test(
      'prevents resurrection of deleted videos via isVideoLocallyDeleted',
      () {
        const videoId = 'test-video-resurrection';

        // Initially not deleted
        expect(videoEventService.isVideoLocallyDeleted(videoId), isFalse);

        // Delete the video
        videoEventService.removeVideoCompletely(videoId);

        // Now marked as deleted
        expect(videoEventService.isVideoLocallyDeleted(videoId), isTrue);

        // This check is used during pagination to filter out deleted videos
        // ensuring they don't "resurrect" when new data loads
      },
    );

    test('works with both service and repository deletion tracking', () {
      const videoId = 'test-video-dual-tracking';

      videoEventService.removeVideoCompletely(videoId);

      // Both services should track deletion
      expect(videoEventService.isVideoLocallyDeleted(videoId), isTrue);
      expect(videoRepository.isVideoLocallyDeleted(videoId), isTrue);

      // The isVideoLocallyDeleted method checks both sources
      // This ensures comprehensive deletion tracking
    });
  });
}
