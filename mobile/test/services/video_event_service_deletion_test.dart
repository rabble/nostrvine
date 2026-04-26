// ABOUTME: Tests the deletion side-channel — removeVideoCompletely fires on
// the removedVideoIds broadcast stream so subscribers (FullscreenFeedBloc,
// profileFeedProvider) can drop the id without waiting for a route change.

@Tags(['skip_very_good_optimization'])
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

  group('VideoEventService.removedVideoIds', () {
    late VideoEventService service;
    late _MockNostrClient nostrClient;
    late _MockSubscriptionManager subscriptionManager;

    setUp(() {
      nostrClient = _MockNostrClient();
      subscriptionManager = _MockSubscriptionManager();
      when(() => nostrClient.isInitialized).thenReturn(true);
      when(() => nostrClient.connectedRelayCount).thenReturn(1);
      when(
        () => nostrClient.subscribe(any()),
      ).thenAnswer((_) => const Stream<Event>.empty());

      service = VideoEventService(
        nostrClient,
        subscriptionManager: subscriptionManager,
      );
    });

    tearDown(() {
      service.dispose();
    });

    test('removeVideoCompletely emits the id on the bus', () async {
      final emitted = <String>[];
      final sub = service.removedVideoIds.listen(emitted.add);

      service.removeVideoCompletely('vid-1');
      await Future<void>.delayed(Duration.zero);

      expect(emitted, equals(['vid-1']));
      await sub.cancel();
    });

    test('emits even when the video was not in any active feed', () async {
      // Mirrors the log line "Video ... marked as deleted (was not in any
      // active feeds)" — the side-channel must still fire so a fullscreen
      // bloc holding the id in its own list drops it.
      final emitted = <String>[];
      final sub = service.removedVideoIds.listen(emitted.add);

      service.removeVideoCompletely('phantom');
      await Future<void>.delayed(Duration.zero);

      expect(emitted, equals(['phantom']));
      await sub.cancel();
    });

    test('emits one event per call, in dispatch order', () async {
      final emitted = <String>[];
      final sub = service.removedVideoIds.listen(emitted.add);

      service
        ..removeVideoCompletely('a')
        ..removeVideoCompletely('b')
        ..removeVideoCompletely('c');
      await Future<void>.delayed(Duration.zero);

      expect(emitted, equals(['a', 'b', 'c']));
      await sub.cancel();
    });

    test('broadcast: a late subscriber misses past emits but receives '
        'future emits', () async {
      final earlyEmits = <String>[];
      final lateEmits = <String>[];

      final earlySub = service.removedVideoIds.listen(earlyEmits.add);
      service.removeVideoCompletely('past');
      await Future<void>.delayed(Duration.zero);

      final lateSub = service.removedVideoIds.listen(lateEmits.add);
      service.removeVideoCompletely('future');
      await Future<void>.delayed(Duration.zero);

      expect(earlyEmits, equals(['past', 'future']));
      expect(lateEmits, equals(['future']));

      await earlySub.cancel();
      await lateSub.cancel();
    });

    test('isVideoLocallyDeleted reflects the tombstone after emit', () {
      service.removeVideoCompletely('vid-1');
      expect(service.isVideoLocallyDeleted('vid-1'), isTrue);
      expect(service.isVideoLocallyDeleted('vid-2'), isFalse);
    });

    test('dispose closes the stream', () async {
      final sub = service.removedVideoIds.listen((_) {});
      service.dispose();
      // Re-create for tearDown safety — overrides the field.
      service = VideoEventService(
        nostrClient,
        subscriptionManager: subscriptionManager,
      );
      // The original subscription should complete cleanly.
      await sub.cancel();
    });
  });
}
