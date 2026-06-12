// ABOUTME: Regression test for the subscribeToVideoFeed check-then-act race
// ABOUTME: Concurrent identical subscribes must produce exactly one relay REQ

import 'dart:async';

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

  group('subscribeToVideoFeed concurrency', () {
    late _MockNostrClient mockNostrService;
    late _MockSubscriptionManager mockSubscriptionManager;
    late _MockPerformanceTraceMonitor mockPerformanceMonitor;
    late VideoEventService service;

    setUp(() {
      mockNostrService = _MockNostrClient();
      mockSubscriptionManager = _MockSubscriptionManager();
      mockPerformanceMonitor = _MockPerformanceTraceMonitor();

      when(() => mockNostrService.isInitialized).thenReturn(true);
      when(() => mockNostrService.publicKey).thenReturn('');
      when(() => mockNostrService.connectedRelayCount).thenReturn(1);
      when(
        () => mockNostrService.subscribe(any(), onEose: any(named: 'onEose')),
      ).thenAnswer((_) => StreamController<Event>.broadcast().stream);

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

    test(
      'concurrent identical subscribes create exactly one relay subscription',
      () async {
        // Hold the FIRST subscribe call inside its async gap (between the
        // duplicate-id check and subscription registration) by blocking its
        // performance-trace await; later calls proceed immediately.
        final firstTraceGate = Completer<void>();
        var startTraceCalls = 0;
        when(() => mockPerformanceMonitor.startTrace(any())).thenAnswer((_) {
          startTraceCalls++;
          if (startTraceCalls == 1) return firstTraceGate.future;
          return Future<void>.value();
        });

        // First call enters the async gap and parks on the trace gate.
        final first = service.subscribeToVideoFeed(
          subscriptionType: SubscriptionType.discovery,
          limit: 10,
        );

        // Second identical call races through while the first is parked.
        final second = service.subscribeToVideoFeed(
          subscriptionType: SubscriptionType.discovery,
          limit: 10,
        );
        await second;

        // Release the first call and let it finish.
        firstTraceGate.complete();
        await first;

        verify(
          () => mockNostrService.subscribe(any(), onEose: any(named: 'onEose')),
        ).called(1);
      },
    );

    test(
      'pending reuse does not block retry if first setup fails',
      () async {
        final firstTraceGate = Completer<void>();
        var startTraceCalls = 0;
        when(() => mockPerformanceMonitor.startTrace(any())).thenAnswer((_) {
          startTraceCalls++;
          if (startTraceCalls == 1) return firstTraceGate.future;
          return Future<void>.value();
        });

        final first = service.subscribeToVideoFeed(
          subscriptionType: SubscriptionType.discovery,
          limit: 10,
        );

        await service.subscribeToVideoFeed(
          subscriptionType: SubscriptionType.discovery,
          limit: 10,
        );

        firstTraceGate.completeError(
          StateError('trace failed'),
          StackTrace.current,
        );
        await first;

        await service.subscribeToVideoFeed(
          subscriptionType: SubscriptionType.discovery,
          limit: 10,
        );

        verify(
          () => mockNostrService.subscribe(any(), onEose: any(named: 'onEose')),
        ).called(1);
      },
    );
  });
}
