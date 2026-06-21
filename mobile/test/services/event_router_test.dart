// ABOUTME: Tests EventRouter batch caching + transaction-wrapped kind routing
// ABOUTME: Verifies events are stored and kind 0 profiles extracted in one batch

import 'dart:convert';

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/services/event_router.dart';

void main() {
  group(EventRouter, () {
    late AppDatabase db;
    late EventRouter router;

    setUp(() {
      db = AppDatabase.test(NativeDatabase.memory());
      router = EventRouter(
        db,
        config: const EventRouterConfig(autoStart: false),
      );
    });

    tearDown(() async {
      router.dispose();
      await db.close();
    });

    /// Returns a 64-hex pubkey derived from [seed] (valid per `keyIsValid`).
    String pubkeyFor(int seed) => seed.toRadixString(16).padLeft(64, '0');

    Event videoEvent(int seed) =>
        Event(pubkeyFor(seed), NIP71VideoKinds.addressableShortVideo, const [
          ['url', 'https://example.com/video.mp4'],
        ], 'video $seed');

    Event profileEvent(int seed, {required String content}) =>
        Event(pubkeyFor(seed), 0, const [], content);

    /// Drives [events] through the deterministic test drain.
    Future<void> flush(List<Event> events) async {
      for (final event in events) {
        router.handleEvent(event);
      }
      await router.drainForTesting();
    }

    test('stores every event in the batch in the nostr_events table', () async {
      final video = videoEvent(1);
      final profile = profileEvent(2, content: jsonEncode({'name': 'alice'}));

      await flush([video, profile]);

      expect(await db.nostrEventsDao.getEventById(video.id), isNotNull);
      expect(await db.nostrEventsDao.getEventById(profile.id), isNotNull);
    });

    test('extracts multiple kind 0 profiles from a single batch', () async {
      final alice = profileEvent(2, content: jsonEncode({'name': 'alice'}));
      final bob = profileEvent(3, content: jsonEncode({'name': 'bob'}));

      await flush([alice, bob]);

      final aliceProfile = await db.userProfilesDao.getProfile(alice.pubkey);
      final bobProfile = await db.userProfilesDao.getProfile(bob.pubkey);
      expect(aliceProfile?.name, equals('alice'));
      expect(bobProfile?.name, equals('bob'));
    });

    test('a malformed profile does not abort routing for the rest of the '
        'batch', () async {
      final broken = profileEvent(2, content: 'not-json-{');
      final valid = profileEvent(3, content: jsonEncode({'name': 'carol'}));
      final video = videoEvent(4);

      await flush([broken, valid, video]);

      // The valid profile and the raw events are still persisted.
      expect(
        (await db.userProfilesDao.getProfile(valid.pubkey))?.name,
        equals('carol'),
      );
      expect(await db.nostrEventsDao.getEventById(video.id), isNotNull);
      expect(await db.nostrEventsDao.getEventById(broken.id), isNotNull);
    });

    test('drains visible events before background events', () async {
      final background = profileEvent(
        10,
        content: jsonEncode({'name': 'background'}),
      );
      final visible = profileEvent(
        11,
        content: jsonEncode({'name': 'visible'}),
      );

      router.dispose();
      router = EventRouter(
        db,
        config: const EventRouterConfig(
          autoStart: false,
          maxBatchSize: 1,
        ),
      );

      router.handleEvent(
        background,
        priority: EventIngestionPriority.background,
      );
      router.handleEvent(visible, priority: EventIngestionPriority.visible);

      await router.drainOneBatchForTesting();

      expect(await db.nostrEventsDao.getEventById(visible.id), isNotNull);
      expect(await db.nostrEventsDao.getEventById(background.id), isNull);
    });

    test(
      'yields between bounded batches so large drains are cooperative',
      () async {
        var yieldCount = 0;
        router.dispose();
        router = EventRouter(
          db,
          config: const EventRouterConfig(
            autoStart: false,
            maxBatchSize: 10,
          ),
          yieldToEventLoop: () async {
            yieldCount++;
            await Future<void>.delayed(Duration.zero);
          },
        );

        final events = List.generate(25, (i) => videoEvent(2000 + i));
        for (final event in events) {
          router.handleEvent(event);
        }

        await router.drainForTesting();

        expect(yieldCount, greaterThanOrEqualTo(2));
        for (final event in events) {
          expect(
            await db.nostrEventsDao.getEventById(event.id),
            isNotNull,
          );
        }
      },
    );

    test('stores all raw profile events but routes only the latest profile per '
        'pubkey', () async {
      final pubkey = pubkeyFor(44);
      final older = Event(
        pubkey,
        0,
        const [],
        jsonEncode({'name': 'old'}),
        createdAt: 100,
      );
      final latest = Event(
        pubkey,
        0,
        const [],
        jsonEncode({'name': 'new'}),
        createdAt: 200,
      );

      router.handleEvent(older);
      router.handleEvent(latest);

      await router.drainForTesting();

      expect(await db.nostrEventsDao.getEventById(older.id), isNotNull);
      expect(await db.nostrEventsDao.getEventById(latest.id), isNotNull);
      expect(
        (await db.userProfilesDao.getProfile(pubkey))?.name,
        equals('new'),
      );
    });

    test('replaces superseded addressable video rows for the same '
        'coordinate', () async {
      final pubkey = pubkeyFor(55);
      final older = Event(
        pubkey,
        NIP71VideoKinds.addressableShortVideo,
        const [
          ['d', 'clip-1'],
          ['url', 'https://example.com/old.mp4'],
        ],
        'old',
        createdAt: 100,
      );
      final latest = Event(
        pubkey,
        NIP71VideoKinds.addressableShortVideo,
        const [
          ['d', 'clip-1'],
          ['url', 'https://example.com/new.mp4'],
        ],
        'new',
        createdAt: 200,
      );

      router.handleEvent(older);
      router.handleEvent(latest);

      await router.drainForTesting();

      // Same pubkey+kind+d-tag: the older raw row is deleted so cache-first
      // LIMIT queries don't return a stale duplicate of the edited video.
      expect(await db.nostrEventsDao.getEventById(older.id), isNull);
      expect(await db.nostrEventsDao.getEventById(latest.id), isNotNull);
    });

    test('ignores events enqueued after dispose', () async {
      final event = videoEvent(77);

      router.dispose();
      router.handleEvent(event);

      // A late relay callback after dispose must not re-arm a drain that
      // would run SQLite against a closing/closed database.
      await router.drainForTesting();

      expect(await db.nostrEventsDao.getEventById(event.id), isNull);
    });

    test(
      'handleEvent enqueues without synchronously persisting the event',
      () async {
        final event = videoEvent(99);

        router.handleEvent(
          event,
          priority: EventIngestionPriority.background,
        );

        // Enqueue is intentionally fire-and-forget. Persistence happens when the
        // cooperative router drain runs, so the relay callback can keep updating
        // in-memory UI state.
        expect(await db.nostrEventsDao.getEventById(event.id), isNull);

        await router.drainForTesting();

        expect(await db.nostrEventsDao.getEventById(event.id), isNotNull);
      },
    );
  });
}
