// ABOUTME: Tests the durable seen-video membership and recency store.
// ABOUTME: Covers single and batch writes, recency, pruning, and deletion.

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(SeenVideosDao, () {
    late AppDatabase database;
    late SeenVideosDao dao;

    setUp(() {
      database = AppDatabase.test(NativeDatabase.memory());
      dao = database.seenVideosDao;
    });

    tearDown(() async {
      await database.close();
    });

    test('markSeen stores and replaces timestamps for one video', () async {
      await dao.markSeen('video-a', firstSeenAt: 100, lastSeenAt: 200);
      await dao.markSeen('video-a', firstSeenAt: 100, lastSeenAt: 300);

      final row = await dao.getAll().then((rows) => rows.single);
      expect(row.videoId, 'video-a');
      expect(row.firstSeenAt, 100);
      expect(row.lastSeenAt, 300);
      expect(await dao.count(), 1);
    });

    test('markSeenBatch stores every supplied row', () async {
      await dao.markSeenBatch(const [
        SeenVideoRow(videoId: 'video-a', firstSeenAt: 100, lastSeenAt: 200),
        SeenVideoRow(videoId: 'video-b', firstSeenAt: 300, lastSeenAt: 400),
      ]);

      expect(await dao.getAllSeenIds(), {'video-a', 'video-b'});
      expect(await dao.count(), 2);
    });

    test(
      'upsertBatch refreshes lastSeenAt without losing firstSeenAt',
      () async {
        await dao.markSeen('video-a', firstSeenAt: 100, lastSeenAt: 200);

        await dao.upsertBatch(['video-a', 'video-b'], nowMs: 500);

        final rows = {for (final row in await dao.getAll()) row.videoId: row};
        expect(rows['video-a']!.firstSeenAt, 100);
        expect(rows['video-a']!.lastSeenAt, 500);
        expect(rows['video-b']!.firstSeenAt, 500);
        expect(rows['video-b']!.lastSeenAt, 500);
      },
    );

    test('hasSeen and wasSeenRecently reflect stored recency', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await dao.markSeen(
        'recent',
        firstSeenAt: now,
        lastSeenAt: now,
      );
      await dao.markSeen(
        'old',
        firstSeenAt: now - const Duration(days: 3).inMilliseconds,
        lastSeenAt: now - const Duration(days: 2).inMilliseconds,
      );

      expect(await dao.hasSeen('recent'), isTrue);
      expect(await dao.hasSeen('missing'), isFalse);
      expect(await dao.wasSeenRecently('recent'), isTrue);
      expect(await dao.wasSeenRecently('old'), isFalse);
      expect(
        await dao.wasSeenRecently('old', within: const Duration(days: 3)),
        isTrue,
      );
    });

    test('pruneExpired removes only rows outside the TTL', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await dao.markSeenBatch([
        SeenVideoRow(
          videoId: 'expired',
          firstSeenAt: now - const Duration(days: 3).inMilliseconds,
          lastSeenAt: now - const Duration(days: 2).inMilliseconds,
        ),
        SeenVideoRow(videoId: 'fresh', firstSeenAt: now, lastSeenAt: now),
      ]);

      expect(await dao.pruneExpired(ttl: const Duration(days: 1)), 1);
      expect(await dao.getAllSeenIds(), {'fresh'});
    });

    test('remove and clearAll delete the requested rows', () async {
      await dao.upsertBatch(['video-a', 'video-b'], nowMs: 500);

      expect(await dao.remove('video-a'), 1);
      expect(await dao.getAllSeenIds(), {'video-b'});
      expect(await dao.clearAll(), 1);
      expect(await dao.getAllSeenIds(), isEmpty);
    });
  });
}
