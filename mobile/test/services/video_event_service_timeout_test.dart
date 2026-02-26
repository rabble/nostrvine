import 'dart:async';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/services/video_event_service.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockSubscriptionManager extends Mock implements SubscriptionManager {}

void main() {
  setUpAll(() {
    registerFallbackValue(<Filter>[]);
  });

  group('VideoEventService Timeout Cleanup', () {
    late VideoEventService videoEventService;
    late _MockNostrClient mockNostrService;
    late _MockSubscriptionManager mockSubscriptionManager;

    setUp(() {
      mockNostrService = _MockNostrClient();
      mockSubscriptionManager = _MockSubscriptionManager();

      // Setup mock NostrService
      when(() => mockNostrService.isInitialized).thenReturn(true);
      when(() => mockNostrService.connectedRelayCount).thenReturn(1);
      // Ensure we return a stream that hangs (never emits) to simulate
      // timeout conditions. Stream.empty() closes immediately, triggering
      // onDone - we want it to HANG.
      when(
        () => mockNostrService.subscribe(any(), onEose: any(named: 'onEose')),
      ).thenAnswer((_) {
        final controller = StreamController<Event>();
        addTearDown(controller.close);
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
        addTearDown(controller.close);

        // Override mock to use our tracked controller
        when(
          () => mockNostrService.subscribe(any(), onEose: any(named: 'onEose')),
        ).thenAnswer((_) => controller.stream);

        fakeAsync((async) {
          // 1. Initial subscription
          videoEventService.subscribeToVideoFeed(
            subscriptionType: SubscriptionType.discovery,
          );

          async.flushMicrotasks();

          // Verify subscription started
          verify(
            () =>
                mockNostrService.subscribe(any(), onEose: any(named: 'onEose')),
          ).called(1);

          reset(mockNostrService);
          when(() => mockNostrService.isInitialized).thenReturn(true);
          when(() => mockNostrService.connectedRelayCount).thenReturn(1);
          when(
            () =>
                mockNostrService.subscribe(any(), onEose: any(named: 'onEose')),
          ).thenAnswer((_) {
            final c = StreamController<Event>();
            addTearDown(c.close);
            return c.stream;
          });

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
          videoEventService.subscribeToVideoFeed(
            subscriptionType: SubscriptionType.discovery,
          );

          async.flushMicrotasks();

          // 4. Verify that subscribe was called A SECOND TIME
          verify(
            () =>
                mockNostrService.subscribe(any(), onEose: any(named: 'onEose')),
          ).called(1);
        });
      },
    );
  });
}
