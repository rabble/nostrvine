// ABOUTME: Tests for VideoEventResolver - layered video event resolution.
// ABOUTME: Covers in-memory, personal cache, relay fetch, and own-content bypass.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/services/personal_event_cache_service.dart';
import 'package:openvine/services/video_event_resolver.dart';
import 'package:openvine/services/video_event_service.dart';

class _MockVideoEventService extends Mock implements VideoEventService {}

class _MockPersonalEventCacheService extends Mock
    implements PersonalEventCacheService {}

class _FakeVideoEvent extends Fake implements VideoEvent {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeVideoEvent());
  });

  group('VideoEventResolver', () {
    const ownerPubkey = 'owner-pubkey';
    const otherPubkey = 'other-pubkey';
    const eventId = 'video-event-id-1';

    late _MockVideoEventService videoService;
    late _MockPersonalEventCacheService cache;
    late StreamController<Event> relayController;
    String? viewerPubkey;

    VideoEventResolver build({
      Stream<Event> Function(List<Filter>)? subscribe,
    }) {
      return VideoEventResolver(
        videoEventService: videoService,
        personalEventCache: cache,
        subscribe: subscribe ?? (_) => relayController.stream,
        viewerPubkeyHex: () => viewerPubkey,
      );
    }

    setUp(() {
      videoService = _MockVideoEventService();
      cache = _MockPersonalEventCacheService();
      relayController = StreamController<Event>.broadcast();
      viewerPubkey = null;

      // Default stubs: nothing found, nothing hidden.
      when(() => videoService.getVideoEventById(any())).thenReturn(null);
      when(() => videoService.shouldHideVideo(any())).thenReturn(false);
      when(() => cache.getEventById(any())).thenReturn(null);
    });

    tearDown(() async {
      await relayController.close();
    });

    test('returns in-memory hit without touching cache or relay', () async {
      final video = _videoEvent(id: eventId, pubkey: otherPubkey);
      when(() => videoService.getVideoEventById(eventId)).thenReturn(video);

      final resolver = build(subscribe: (_) => const Stream.empty());
      final result = await resolver.resolveById(eventId);

      expect(result, same(video));
      verifyNever(() => cache.getEventById(any()));
    });

    test('returns personal cache hit when in-memory misses', () async {
      final event = _kind34236Event(id: eventId, pubkey: otherPubkey);
      when(() => cache.getEventById(eventId)).thenReturn(event);

      final resolver = build(subscribe: (_) => const Stream.empty());
      final result = await resolver.resolveById(eventId);

      expect(result, isNotNull);
      expect(result!.id, eventId);
      expect(result.pubkey, otherPubkey);
    });

    test('fetches from relay when nothing cached', () async {
      final event = _kind34236Event(id: eventId, pubkey: otherPubkey);
      final resolver = build();

      final future = resolver.resolveById(eventId);
      relayController.add(event);

      final result = await future;
      expect(result, isNotNull);
      expect(result!.id, eventId);
    });

    test('returns null when relay closes without an event', () async {
      final resolver = build();
      final future = resolver.resolveById(eventId);
      await relayController.close();

      expect(await future, isNull);
    });

    test('returns null on relay timeout', () async {
      final resolver = build();
      final result = await resolver.resolveById(
        eventId,
        timeout: const Duration(milliseconds: 50),
      );
      expect(result, isNull);
    });

    test(
      'owner bypass returns video even when shouldHideVideo is true',
      () async {
        final video = _videoEvent(id: eventId, pubkey: ownerPubkey);
        when(() => videoService.getVideoEventById(eventId)).thenReturn(video);
        when(() => videoService.shouldHideVideo(video)).thenReturn(true);
        viewerPubkey = ownerPubkey;

        final resolver = build(subscribe: (_) => const Stream.empty());
        final result = await resolver.resolveById(
          eventId,
          allowOwnContentBypass: true,
        );

        expect(result, same(video));
      },
    );

    test('without bypass, hidden video resolves to null', () async {
      final video = _videoEvent(id: eventId, pubkey: ownerPubkey);
      when(() => videoService.getVideoEventById(eventId)).thenReturn(video);
      when(() => videoService.shouldHideVideo(video)).thenReturn(true);
      viewerPubkey = ownerPubkey;

      final resolver = build(subscribe: (_) => const Stream.empty());
      final result = await resolver.resolveById(eventId);

      expect(result, isNull);
    });

    test('bypass does not apply when viewer is not the author', () async {
      final video = _videoEvent(id: eventId, pubkey: ownerPubkey);
      when(() => videoService.getVideoEventById(eventId)).thenReturn(video);
      when(() => videoService.shouldHideVideo(video)).thenReturn(true);
      viewerPubkey = otherPubkey;

      final resolver = build(subscribe: (_) => const Stream.empty());
      final result = await resolver.resolveById(
        eventId,
        allowOwnContentBypass: true,
      );

      expect(result, isNull);
    });

    test('returns null for empty id', () async {
      final resolver = build(subscribe: (_) => const Stream.empty());
      expect(await resolver.resolveById(''), isNull);
      verifyNever(() => videoService.getVideoEventById(any()));
    });
  });
}

VideoEvent _videoEvent({required String id, required String pubkey}) {
  return VideoEvent(
    id: id,
    pubkey: pubkey,
    createdAt: 1700000000,
    content: 'content',
    timestamp: DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000),
    videoUrl: 'https://example.com/video.mp4',
  );
}

Event _kind34236Event({required String id, required String pubkey}) {
  return Event.fromJson({
    'id': id,
    'pubkey': pubkey,
    'created_at': 1700000000,
    'kind': 34236,
    'tags': [
      ['d', 'd-tag-$id'],
      ['url', 'https://example.com/video.mp4'],
    ],
    'content': 'content',
    'sig': 'signature',
  });
}
