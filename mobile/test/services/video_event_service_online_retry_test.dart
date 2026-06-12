// ABOUTME: Tests for the online-retry cycle after subscription errors
// ABOUTME: Retries must re-establish the FAILED feed, not hardcode discovery

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/services/performance_monitoring_service.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/services/video_event_service.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockSubscriptionManager extends Mock implements SubscriptionManager {}

class _MockPerformanceTraceMonitor extends Mock
    implements PerformanceTraceMonitor {}

class _FakeFilter extends Fake implements Filter {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeFilter());
    registerFallbackValue(<Filter>[]);
  });

  group('online retry after subscription error', () {
    const followedAuthor =
        '385c3a6ec0b9d57a4330dbd6284989be5bd00e41c535f9ca39b6ae7c521b81cd';

    late _MockNostrClient mockNostrService;
    late _MockSubscriptionManager mockSubscriptionManager;
    late _MockPerformanceTraceMonitor mockPerformanceMonitor;
    late VideoEventService service;
    late List<List<Filter>> subscribeCalls;
    late List<StreamController<Event>> streamControllers;

    setUp(() {
      mockNostrService = _MockNostrClient();
      mockSubscriptionManager = _MockSubscriptionManager();
      mockPerformanceMonitor = _MockPerformanceTraceMonitor();
      subscribeCalls = [];
      streamControllers = [];

      when(() => mockNostrService.isInitialized).thenReturn(true);
      when(() => mockNostrService.publicKey).thenReturn('');
      when(() => mockNostrService.connectedRelayCount).thenReturn(1);
      when(
        () => mockNostrService.subscribe(any(), onEose: any(named: 'onEose')),
      ).thenAnswer((invocation) {
        subscribeCalls.add(
          (invocation.positionalArguments.first as List<Filter>).toList(),
        );
        // Single-subscription controller with an async onCancel: broadcast
        // subscriptions' cancel() futures cannot be driven by fakeAsync
        // (the service awaits cancel() when force-replacing), so the test
        // would hang at that await with a broadcast controller.
        final controller = StreamController<Event>(onCancel: () async {});
        streamControllers.add(controller);
        return controller.stream;
      });
      when(() => mockNostrService.unsubscribe(any())).thenAnswer((_) async {});

      when(
        () => mockPerformanceMonitor.startTrace(any()),
      ).thenAnswer((_) async {});
      when(
        () => mockPerformanceMonitor.stopTrace(any()),
      ).thenAnswer((_) async {});
      when(
        () => mockPerformanceMonitor.setMetric(any(), any(), any()),
      ).thenReturn(null);
      when(
        () => mockPerformanceMonitor.putAttribute(any(), any(), any()),
      ).thenReturn(null);

      service = VideoEventService(
        mockNostrService,
        subscriptionManager: mockSubscriptionManager,
        performanceMonitor: mockPerformanceMonitor,
      );
    });

    tearDown(() {
      service.dispose();
    });

    test('connection error on home feed retries the home feed with its '
        'original authors', () {
      fakeAsync((fake) {
        unawaited(
          service.subscribeToVideoFeed(
            subscriptionType: SubscriptionType.homeFeed,
            authors: [followedAuthor],
          ),
        );
        fake.flushMicrotasks();
        expect(subscribeCalls, hasLength(1));

        // Relay connection drops — the subscription stream errors out.
        streamControllers.first.addError(
          Exception('websocket connection failed'),
        );
        fake.flushMicrotasks();

        // First retry tick.
        fake
          ..elapse(const Duration(seconds: 10))
          ..flushMicrotasks();

        expect(
          subscribeCalls,
          hasLength(2),
          reason: 'the retry cycle must re-issue a relay subscription',
        );
        final retryFilters = subscribeCalls[1];
        expect(
          retryFilters.any(
            (filter) => filter.authors?.contains(followedAuthor) ?? false,
          ),
          isTrue,
          reason:
              'the retry must re-establish the FAILED home feed with its '
              'original authors, not a parameterless discovery feed',
        );

        // The successful retry ends the cycle — no further re-subscribes.
        fake
          ..elapse(const Duration(seconds: 30))
          ..flushMicrotasks();
        expect(subscribeCalls, hasLength(2));
      });
    });
  });
}
