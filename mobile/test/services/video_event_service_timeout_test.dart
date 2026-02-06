import 'dart:async';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/services/video_event_service.dart';

import 'video_event_service_deduplication_test.mocks.dart';

void main() {
  group('VideoEventService Timeout Cleanup', () {
    late VideoEventService videoEventService;
    late MockNostrClient mockNostrService;
    late MockSubscriptionManager mockSubscriptionManager;

    setUp(() {
      mockNostrService = MockNostrClient();
      mockSubscriptionManager = MockSubscriptionManager();

      // Setup mock NostrService
      when(mockNostrService.isInitialized).thenReturn(true);
      when(mockNostrService.connectedRelayCount).thenReturn(1);
      // Ensure we return a stream that hangs (never emits) to simulate timeout conditions
      // Stream.empty() closes immediately, triggering onDone - we want it to HANG
      when(
        mockNostrService.subscribe(
          argThat(anything),
          onEose: anyNamed('onEose'),
        ),
      ).thenAnswer((_) {
        final controller = StreamController<Event>();
        addTearDown(() => controller.close());
        return controller.stream;
      });

      videoEventService = VideoEventService(
        mockNostrService,
        subscriptionManager: mockSubscriptionManager,
      );
    });

    test(
      'should clean up active subscription on timeout so retry is possible',
      () {
        bool wasCancelled = false;
        final controller = StreamController<Event>(
          onCancel: () {
            wasCancelled = true;
          },
        );
        addTearDown(() => controller.close());

        // Override mock to use our tracked controller
        when(
          mockNostrService.subscribe(
            argThat(anything),
            onEose: anyNamed('onEose'),
          ),
        ).thenAnswer((_) => controller.stream);

        fakeAsync((async) {
          // 1. Initial subscription
          videoEventService.subscribeToVideoFeed(
            subscriptionType: SubscriptionType.discovery,
          );

          async.flushMicrotasks();

          // Verify subscription started
          verify(
            mockNostrService.subscribe(
              argThat(anything),
              onEose: anyNamed('onEose'),
            ),
          ).called(1);

          clearInteractions(mockNostrService);

          expect(
            videoEventService.isSubscribed(SubscriptionType.discovery),
            isTrue,
            reason: 'Should be subscribed initially',
          );

          expect(
            videoEventService.isLoadingForSubscription(
              SubscriptionType.discovery,
            ),
            isTrue,
            reason: 'Should be loading initially',
          );

          // 2. Fast forward 30 seconds to trigger timeout
          async.elapse(const Duration(seconds: 31));

          // Verify that cleanup happened
          expect(
            videoEventService.isSubscribed(SubscriptionType.discovery),
            isFalse,
            reason: 'Should be unsubscribed after timeout cleanup',
          );

          // Verify loading state is reset
          expect(
            videoEventService.isLoadingForSubscription(
              SubscriptionType.discovery,
            ),
            isFalse,
            reason: 'Loading state should be reset after timeout',
          );

          // Verify subscription was cancelled (Fix #1 verification)
          expect(
            wasCancelled,
            isTrue,
            reason: 'StreamSubscription should be cancelled on timeout',
          );

          // 3. Try to subscribe again (simulate user coming back)
          // If cleanup failed, this will skip re-subscription because it thinks it's a duplicate
          videoEventService.subscribeToVideoFeed(
            subscriptionType: SubscriptionType.discovery,
            force: false, // Default behavior relies on deduplication
          );

          async.flushMicrotasks();

          // 4. Verify that subscribe was called A SECOND TIME
          // If the bug exists, the total count will be 1 (second call skipped)
          // If fixed, the total count will be 2

          // Simplified verification to avoid argument matching issues
          verify(
            mockNostrService.subscribe(any, onEose: anyNamed('onEose')),
          ).called(1);
        });
      },
    );
  });
}
