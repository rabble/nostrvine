// ABOUTME: Pins that an initial subscription's pre-EOSE events count toward
// ABOUTME: pagination, so a full first page does not report the feed exhausted.

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

const _author =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

Event _videoEvent(int index) {
  final event = Event(
    _author,
    34236,
    [
      ['url', 'https://media.example.com/$index.mp4'],
      ['m', 'video/mp4'],
    ],
    'video $index',
    createdAt: 1700000000 - index,
  );
  event.id = index.toRadixString(16).padLeft(64, '0');
  event.sig = 'f' * 128;
  event.sources.add('wss://relay.example.com');
  return event;
}

void main() {
  setUpAll(() {
    registerFallbackValue(<Filter>[]);
  });

  group('VideoEventService initial-page pagination', () {
    late VideoEventService videoEventService;
    late _MockNostrClient mockNostrService;
    late _MockSubscriptionManager mockSubscriptionManager;

    setUp(() {
      mockNostrService = _MockNostrClient();
      mockSubscriptionManager = _MockSubscriptionManager();

      when(() => mockNostrService.isInitialized).thenReturn(true);
      when(() => mockNostrService.publicKey).thenReturn('');
      when(() => mockNostrService.connectedRelayCount).thenReturn(1);
      when(
        () => mockNostrService.configuredRelays,
      ).thenReturn(['wss://relay.example.com']);
      when(
        () => mockNostrService.connectedRelays,
      ).thenReturn(['wss://relay.example.com']);
      when(
        () => mockNostrService.queryEvents(any()),
      ).thenAnswer((_) async => <Event>[]);
      when(mockNostrService.getRelayStats).thenAnswer((_) async => null);

      videoEventService = VideoEventService(
        mockNostrService,
        subscriptionManager: mockSubscriptionManager,
      );
    });

    tearDown(() {
      videoEventService.dispose();
    });

    test('keeps hasMore when a full first page arrives before EOSE', () {
      // The initial subscription delivers stored events through the real-time
      // handler, so the `isHistorical` counter — which only the load-more path
      // drives — stays at zero. Before the fix, completeQuery read that zero
      // and set hasMore=false however many events had actually landed.
      const limit = 5;
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
          subscriptionType: SubscriptionType.profile,
          authors: [_author],
          limit: limit,
        );
        async.flushMicrotasks();

        for (var i = 0; i < limit; i++) {
          controller.add(_videoEvent(i));
        }
        async.flushMicrotasks();

        expect(capturedOnEose, isNotNull, reason: 'onEose should be set');
        capturedOnEose!();
        async.flushMicrotasks();

        final state = videoEventService
            .getPaginationStatesForTesting()[SubscriptionType.profile]!;

        expect(
          state.eventsReceivedInCurrentQuery,
          greaterThanOrEqualTo(limit),
          reason:
              'the tally must reflect the events that actually arrived before '
              'EOSE, not the load-more-only isHistorical count',
        );
        expect(
          state.hasMore,
          isTrue,
          reason:
              'a first page that filled the requested limit cannot prove the '
              'feed is exhausted',
        );
      });
    });
  });
}
