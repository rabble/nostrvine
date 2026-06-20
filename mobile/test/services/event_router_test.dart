// ABOUTME: Tests EventRouter batch caching + transaction-wrapped kind routing
// ABOUTME: Verifies events are stored and kind 0 profiles extracted in one batch

import 'dart:async';
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
      router = EventRouter(db);
    });

    tearDown(() async {
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

    /// Drives [events] through [handleEvent] so the whole list is flushed in a
    /// single batch. The queue processes immediately once it reaches 50, so the
    /// list is padded with filler video events and the final `handleEvent` is
    /// awaited — no reliance on the 50ms batch timer.
    Future<void> flush(List<Event> events) async {
      // Only the final handleEvent is awaited, and it's the one that trips the
      // immediate flush. That holds only because the input is padded up to the
      // production threshold; with that many or more input events, the trip
      // would fire inside an unawaited call and the batch would not be awaited.
      assert(
        events.length < eventRouterBatchFlushThreshold,
        'flush() awaits only the padded final event; pass fewer than '
        '$eventRouterBatchFlushThreshold events.',
      );
      final padded = [...events];
      var filler = 1 << 20;
      while (padded.length < eventRouterBatchFlushThreshold) {
        padded.add(videoEvent(filler++));
      }
      for (var i = 0; i < padded.length - 1; i++) {
        unawaited(router.handleEvent(padded[i]));
      }
      await router.handleEvent(padded.last);
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
  });
}
