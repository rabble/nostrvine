// ABOUTME: Tests for PersonalEventCacheService initialization race handling.
// ABOUTME: Ensures signed user events are not dropped while Hive boxes open.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/services/personal_event_cache_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory testDir;
  late PersonalEventCacheService service;

  final userPubkey = List.filled(64, 'a').join();
  final otherPubkey = List.filled(64, 'b').join();

  String hexId(int index) => index.toRadixString(16).padLeft(64, '0');

  Event createEvent({
    required String pubkey,
    required String id,
    String content = 'A plant video',
  }) {
    final event = Event(
      pubkey,
      32222,
      const [
        ['d', 'test-video-id'],
        ['title', 'Plants'],
      ],
      content,
      createdAt: 1700000000,
    );
    event.id = id;
    event.sig = id.padRight(128, '0').substring(0, 128);
    return event;
  }

  setUp(() async {
    // Defend against Hive state leaked by an earlier file in the shared
    // very_good --optimization isolate: this service suite and the sibling
    // provider suite both open boxes under the same fixed names, so force a
    // clean Hive registry before init (#5738).
    try {
      await Hive.close();
    } on PathNotFoundException catch (_) {}
    testDir = await Directory.systemTemp.createTemp(
      'personal_event_cache_service_test_',
    );
    Hive.init(testDir.path);
    service = PersonalEventCacheService();
  });

  tearDown(() async {
    service.dispose();
    // Drain the fire-and-forget box close (dispose -> unawaited _closeBox)
    // before Hive.close() so the two don't race and leak box state into the
    // next file in the shared VGV isolate (#5738).
    await pumpEventQueue();
    try {
      await Hive.close();
    } on PathNotFoundException catch (_) {
      // Hive may already have removed its lock file during async shutdown.
    }
    try {
      await testDir.delete(recursive: true);
    } on PathNotFoundException catch (_) {
      // Lock file may already be gone after Hive.close().
    }
  });

  group('PersonalEventCacheService initialization', () {
    test('caches user events queued while initialize is in flight', () async {
      final event = createEvent(pubkey: userPubkey, id: hexId(1));

      final initialize = service.initialize(userPubkey);
      service.cacheUserEvent(event);

      await initialize;

      expect(service.isInitialized, isTrue);
      expect(service.hasEvent(event.id), isTrue);
      expect(service.getEventById(event.id)?.id, event.id);
      expect(
        service
            .getEventsByKind(event.kind)
            .map((cachedEvent) => cachedEvent.id),
        contains(event.id),
      );
    });

    test('drops queued events for a different user after initialize', () async {
      final otherUserEvent = createEvent(pubkey: otherPubkey, id: hexId(2));

      final initialize = service.initialize(userPubkey);
      service.cacheUserEvent(otherUserEvent);

      await initialize;

      expect(service.hasEvent(otherUserEvent.id), isFalse);
      expect(service.getEventById(otherUserEvent.id), isNull);
    });

    test(
      'filters queued events by pubkey when no user was known at queue time',
      () async {
        // No initialize() has run yet, so _currentUserPubkey is null and the
        // queue-time pubkey filter cannot apply. The filter must instead kick in
        // when the queue is flushed after initialization resolves the pubkey.
        final ownEvent = createEvent(pubkey: userPubkey, id: hexId(3));
        final foreignEvent = createEvent(pubkey: otherPubkey, id: hexId(4));

        service.cacheUserEvent(ownEvent);
        service.cacheUserEvent(foreignEvent);

        await service.initialize(userPubkey);

        expect(service.hasEvent(ownEvent.id), isTrue);
        expect(service.hasEvent(foreignEvent.id), isFalse);
      },
    );

    test(
      'keeps only the latest queued write for a repeated event id',
      () async {
        final stale = createEvent(
          pubkey: userPubkey,
          id: hexId(5),
          content: 'stale content',
        );
        final fresh = createEvent(
          pubkey: userPubkey,
          id: hexId(5),
          content: 'fresh content',
        );

        service.cacheUserEvent(stale);
        service.cacheUserEvent(fresh);

        await service.initialize(userPubkey);

        expect(service.getEventById(hexId(5))?.content, 'fresh content');
      },
    );

    test('drops the oldest queued event past the pending-write cap', () async {
      const pendingWriteCap = 100;
      // Queue one more than the cap before initialization completes; the
      // first-queued (oldest) event must be evicted to honor the bound.
      for (var i = 0; i <= pendingWriteCap; i++) {
        service.cacheUserEvent(createEvent(pubkey: userPubkey, id: hexId(i)));
      }

      await service.initialize(userPubkey);

      expect(service.hasEvent(hexId(0)), isFalse);
      expect(service.hasEvent(hexId(1)), isTrue);
      expect(service.hasEvent(hexId(pendingWriteCap)), isTrue);
      expect(service.getEventsByKind(32222), hasLength(pendingWriteCap));
    });

    test(
      'dispose prevents in-flight initialize from resurrecting cache',
      () async {
        final event = createEvent(pubkey: userPubkey, id: hexId(101));

        final initialize = service.initialize(userPubkey);
        service.cacheUserEvent(event);
        service.dispose();

        await initialize;

        expect(service.isInitialized, isFalse);
        expect(service.hasEvent(event.id), isFalse);
        expect(service.getEventById(event.id), isNull);
      },
    );

    test('reads only return events for the current initialized user', () async {
      final userEvent = createEvent(pubkey: userPubkey, id: hexId(201));
      final otherUserEvent = createEvent(pubkey: otherPubkey, id: hexId(202));

      await service.initialize(userPubkey);
      service.cacheUserEvent(userEvent);
      await pumpEventQueue();

      await service.initialize(otherPubkey);
      service.cacheUserEvent(otherUserEvent);
      await pumpEventQueue();

      expect(service.hasEvent(userEvent.id), isFalse);
      expect(service.getEventById(userEvent.id), isNull);
      expect(service.hasEvent(otherUserEvent.id), isTrue);
      expect(service.getEventById(otherUserEvent.id)?.id, otherUserEvent.id);
      expect(
        service.getEventsByKind(32222).map((event) => event.id),
        containsAll(<String>[otherUserEvent.id]),
      );
      expect(
        service.getEventsByKind(32222).map((event) => event.id),
        isNot(contains(userEvent.id)),
      );
    });

    test(
      'resetCurrentUser makes cached events unreadable until reauth',
      () async {
        final event = createEvent(pubkey: userPubkey, id: hexId(203));

        await service.initialize(userPubkey);
        service.cacheUserEvent(event);
        await pumpEventQueue();
        expect(service.hasEvent(event.id), isTrue);

        service.resetCurrentUser();

        expect(service.isInitialized, isFalse);
        expect(service.hasEvent(event.id), isFalse);
        expect(service.getEventById(event.id), isNull);

        await service.initialize(userPubkey);

        expect(service.hasEvent(event.id), isTrue);
      },
    );
  });
}
