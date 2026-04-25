// ABOUTME: Tests that EOSE with zero events properly clears per-subscription
// ABOUTME: loading state, fixing the infinite spinner bug (#1906, #2115).

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

  group('VideoEventService EOSE with empty results', () {
    late VideoEventService videoEventService;
    late _MockNostrClient mockNostrService;
    late _MockSubscriptionManager mockSubscriptionManager;

    setUp(() {
      mockNostrService = _MockNostrClient();
      mockSubscriptionManager = _MockSubscriptionManager();

      when(() => mockNostrService.isInitialized).thenReturn(true);
      when(() => mockNostrService.connectedRelayCount).thenReturn(1);

      videoEventService = VideoEventService(
        mockNostrService,
        subscriptionManager: mockSubscriptionManager,
      );
    });

    test('should clear per-subscription loading state when EOSE arrives '
        'with zero events for hashtag subscription', () {
      void Function()? capturedOnEose;
      final controller = StreamController<Event>();
      addTearDown(controller.close);

      when(
        () => mockNostrService.subscribe(any(), onEose: any(named: 'onEose')),
      ).thenAnswer((invocation) {
        capturedOnEose = invocation.namedArguments[#onEose] as void Function()?;
        return controller.stream;
      });

      fakeAsync((async) {
        videoEventService.subscribeToVideoFeed(
          subscriptionType: SubscriptionType.hashtag,
          hashtags: ['comedyvine'],
        );

        async.flushMicrotasks();

        // Verify loading state is true after subscription starts
        expect(
          videoEventService.isLoadingForSubscription(SubscriptionType.hashtag),
          isTrue,
          reason: 'Should be loading after subscription starts',
        );

        // Simulate relay sending EOSE with zero events
        expect(capturedOnEose, isNotNull, reason: 'onEose should be set');
        capturedOnEose!();

        async.flushMicrotasks();

        // Verify loading state is cleared after EOSE
        expect(
          videoEventService.isLoadingForSubscription(SubscriptionType.hashtag),
          isFalse,
          reason: 'Loading state should be false after EOSE with zero events',
        );

        // Verify hasMore is false (no content available)
        final paginationStates = videoEventService
            .getPaginationStatesForTesting();
        final hashtagState = paginationStates[SubscriptionType.hashtag]!;
        expect(
          hashtagState.hasMore,
          isFalse,
          reason: 'hasMore should be false when no events were received',
        );
      });
    });

    test('should clear per-subscription loading state when EOSE arrives '
        'with zero events for search subscription', () {
      void Function()? capturedOnEose;
      final controller = StreamController<Event>();
      addTearDown(controller.close);

      when(
        () => mockNostrService.subscribe(any(), onEose: any(named: 'onEose')),
      ).thenAnswer((invocation) {
        capturedOnEose = invocation.namedArguments[#onEose] as void Function()?;
        return controller.stream;
      });

      fakeAsync((async) {
        videoEventService.subscribeToVideoFeed(
          subscriptionType: SubscriptionType.search,
        );

        async.flushMicrotasks();

        expect(
          videoEventService.isLoadingForSubscription(SubscriptionType.search),
          isTrue,
          reason: 'Should be loading after subscription starts',
        );

        capturedOnEose!();
        async.flushMicrotasks();

        expect(
          videoEventService.isLoadingForSubscription(SubscriptionType.search),
          isFalse,
          reason: 'Loading state should be false after EOSE with zero events',
        );
      });
    });

    test('should notify listeners when EOSE arrives with zero events', () {
      void Function()? capturedOnEose;
      final controller = StreamController<Event>();
      addTearDown(controller.close);

      when(
        () => mockNostrService.subscribe(any(), onEose: any(named: 'onEose')),
      ).thenAnswer((invocation) {
        capturedOnEose = invocation.namedArguments[#onEose] as void Function()?;
        return controller.stream;
      });

      fakeAsync((async) {
        videoEventService.subscribeToVideoFeed(
          subscriptionType: SubscriptionType.hashtag,
          hashtags: ['empty'],
        );

        async.flushMicrotasks();

        var notified = false;
        videoEventService.addListener(() => notified = true);

        // Fire EOSE with zero events
        capturedOnEose!();
        async.flushMicrotasks();

        expect(
          notified,
          isTrue,
          reason:
              'Listeners should be notified so UI transitions from '
              'spinner to empty state',
        );
      });
    });
  });
}
