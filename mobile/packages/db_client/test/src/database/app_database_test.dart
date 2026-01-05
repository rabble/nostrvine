// ABOUTME: Unit tests for AppDatabase startup cleanup functionality.
// ABOUTME: Tests automatic cleanup of expired data on database initialization.

import 'dart:io';

import 'package:db_client/db_client.dart' hide Filter;
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

void main() {
  late AppDatabase database;
  late String tempDbPath;

  /// Valid 64-char hex pubkey for testing
  const testPubkey =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

  /// Helper to create a valid Nostr Event for testing.
  Event createEvent({
    String pubkey = testPubkey,
    int kind = 1,
    List<List<String>>? tags,
    String content = 'test content',
    int? createdAt,
  }) {
    final event = Event(
      pubkey,
      kind,
      tags ?? [],
      content,
      createdAt: createdAt,
    )..sig = 'testsig$testPubkey';
    return event;
  }

  /// Helper to get current Unix timestamp
  int nowUnix() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

  setUp(() async {
    final tempDir = Directory.systemTemp.createTempSync('app_db_test_');
    tempDbPath = '${tempDir.path}/test.db';

    database = AppDatabase.test(NativeDatabase(File(tempDbPath)));
  });

  tearDown(() async {
    await database.close();
    final file = File(tempDbPath);
    if (file.existsSync()) {
      file.deleteSync();
    }
    final dir = Directory(tempDbPath).parent;
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  });

  group('AppDatabase', () {
    group('runStartupCleanup', () {
      test('deletes expired nostr events', () async {
        final dao = database.nostrEventsDao;

        // Insert expired and valid events
        final expiredEvent = createEvent(content: 'expired', createdAt: 1000);
        final validEvent = createEvent(content: 'valid', createdAt: 2000);

        final pastExpiry = nowUnix() - 100;
        final futureExpiry = nowUnix() + 3600;

        await dao.upsertEventWithExpiry(expiredEvent, expireAt: pastExpiry);
        await dao.upsertEventWithExpiry(validEvent, expireAt: futureExpiry);

        // Run cleanup
        final result = await database.runStartupCleanup();

        // Expired event should be deleted
        final expiredResult = await dao.getEventById(expiredEvent.id);
        expect(expiredResult, isNull);

        // Valid event should remain
        final validResult = await dao.getEventById(validEvent.id);
        expect(validResult, isNotNull);

        // Result should indicate what was cleaned
        expect(result.expiredEventsDeleted, equals(1));
      });

      test('deletes expired profile stats', () async {
        // Insert stats with old cachedAt using proper Drift insert
        final oldTime = DateTime.now().subtract(const Duration(minutes: 10));
        await database
            .into(database.profileStats)
            .insert(
              ProfileStatsCompanion.insert(
                pubkey: testPubkey,
                videoCount: const Value(10),
                followerCount: const Value(100),
                cachedAt: oldTime,
              ),
            );

        // Run cleanup (default expiry is 5 minutes, entry is 10 minutes old)
        final result = await database.runStartupCleanup();

        // Expired stats should be deleted
        final stats = await database.profileStatsDao.getStats(testPubkey);
        expect(stats, isNull);

        expect(result.expiredProfileStatsDeleted, equals(1));
      });

      test('deletes expired hashtag stats', () async {
        // Insert stats with old cachedAt using proper Drift insert
        final oldTime = DateTime.now().subtract(const Duration(hours: 2));
        await database
            .into(database.hashtagStats)
            .insert(
              HashtagStatsCompanion.insert(
                hashtag: 'flutter',
                videoCount: const Value(50),
                cachedAt: oldTime,
              ),
            );

        // Run cleanup (default expiry is 1 hour, entry is 2 hours old)
        final result = await database.runStartupCleanup();

        // Expired stats should be deleted
        final isFresh = await database.hashtagStatsDao.isCacheFresh();
        expect(isFresh, isFalse);

        expect(result.expiredHashtagStatsDeleted, equals(1));
      });

      test('deletes old notifications', () async {
        final dao = database.notificationsDao;

        // Insert notification from 8 days ago (older than 7 day retention)
        final oldTimestamp = nowUnix() - (8 * 24 * 60 * 60);
        await dao.upsertNotification(
          id: 'old_notification',
          type: 'like',
          fromPubkey: testPubkey,
          timestamp: oldTimestamp,
        );

        // Insert recent notification
        await dao.upsertNotification(
          id: 'recent_notification',
          type: 'like',
          fromPubkey: testPubkey,
          timestamp: nowUnix(),
        );

        // Run cleanup
        final result = await database.runStartupCleanup();

        // Old notification should be deleted
        final notifications = await dao.getAllNotifications();
        expect(notifications.length, equals(1));
        expect(notifications.first.id, equals('recent_notification'));

        expect(result.oldNotificationsDeleted, equals(1));
      });

      test('returns cleanup result with all counts', () async {
        // Run cleanup on empty database
        final result = await database.runStartupCleanup();

        expect(result.expiredEventsDeleted, equals(0));
        expect(result.expiredProfileStatsDeleted, equals(0));
        expect(result.expiredHashtagStatsDeleted, equals(0));
        expect(result.oldNotificationsDeleted, equals(0));
      });

      test('handles cleanup when database is empty', () async {
        // Should not throw on empty database
        final result = await database.runStartupCleanup();

        expect(result.expiredEventsDeleted, equals(0));
        expect(result.expiredProfileStatsDeleted, equals(0));
        expect(result.expiredHashtagStatsDeleted, equals(0));
        expect(result.oldNotificationsDeleted, equals(0));
      });

      test('does not delete non-expired data', () async {
        final eventsDao = database.nostrEventsDao;
        final profileStatsDao = database.profileStatsDao;
        final hashtagStatsDao = database.hashtagStatsDao;
        final notificationsDao = database.notificationsDao;

        // Insert valid (non-expired) data
        final validEvent = createEvent(content: 'valid');
        await eventsDao.upsertEventWithExpiry(
          validEvent,
          expireAt: nowUnix() + 3600,
        );

        await profileStatsDao.upsertStats(
          pubkey: testPubkey,
          videoCount: 10,
        );

        await hashtagStatsDao.upsertHashtag(
          hashtag: 'dart',
          videoCount: 20,
        );

        await notificationsDao.upsertNotification(
          id: 'recent',
          type: 'follow',
          fromPubkey: testPubkey,
          timestamp: nowUnix(),
        );

        // Run cleanup
        await database.runStartupCleanup();

        // All data should remain
        final event = await eventsDao.getEventById(validEvent.id);
        expect(event, isNotNull);

        final stats = await profileStatsDao.getStats(testPubkey);
        expect(stats, isNotNull);

        final hashtagFresh = await hashtagStatsDao.isCacheFresh();
        expect(hashtagFresh, isTrue);

        final notifications = await notificationsDao.getAllNotifications();
        expect(notifications.length, equals(1));
      });
    });
  });
}
