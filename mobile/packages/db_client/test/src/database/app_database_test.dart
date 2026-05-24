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

        await dao.upsertEvent(expiredEvent, expireAt: pastExpiry);
        await dao.upsertEvent(validEvent, expireAt: futureExpiry);

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

      test('upgrade path — recreates outgoing_dms when missing', () async {
        // Simulate an existing install that pre-dates the
        // outgoing_dms table (added for #3909 / #3911 without a
        // schema-version bump): drop the table from a fresh database,
        // close, then reopen and assert the runtime
        // CREATE-IF-NOT-EXISTS path in `_createMissingTables`
        // recreated the table, indexes, and that the DAO works.
        await database.customStatement('DROP TABLE outgoing_dms');

        // Confirm the precondition — table really is gone before reopen.
        final droppedCheck = await database
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type='table' "
              "AND name='outgoing_dms'",
            )
            .get();
        expect(
          droppedCheck,
          isEmpty,
          reason: 'precondition: outgoing_dms must be missing before reopen',
        );

        await database.close();

        // Reopen the same on-disk file. `beforeOpen` runs
        // `_createMissingTables`, which should detect the missing
        // outgoing_dms table and recreate it without bumping
        // schemaVersion.
        database = AppDatabase.test(NativeDatabase(File(tempDbPath)));

        // Trigger `beforeOpen` by issuing a query (Drift opens the
        // database lazily on first use).
        final tableCheck = await database
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type='table' "
              "AND name='outgoing_dms'",
            )
            .get();
        expect(
          tableCheck,
          hasLength(1),
          reason: 'outgoing_dms must be re-created on reopen',
        );

        // Assert the indexes are in place too — the runtime path also
        // owns those, and a missing index would silently degrade
        // retry-sweep performance without failing the table check.
        final indexCheck = await database
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type='index' "
              "AND tbl_name='outgoing_dms'",
            )
            .get();
        final indexNames = indexCheck
            .map((row) => row.read<String>('name'))
            .toSet();
        expect(
          indexNames,
          containsAll(<String>[
            'idx_outgoing_dms_owner_conversation',
            'idx_outgoing_dms_owner_recipient_status',
            'idx_outgoing_dms_owner_self_status',
            'idx_outgoing_dms_queued_at',
          ]),
        );

        // Finally, prove the DAO actually works against the upgraded
        // schema — a re-created table with mismatched columns or a
        // botched insert path would break this round-trip.
        final dao = database.outgoingDmsDao;
        final dm = OutgoingDm(
          id: 'upgrade-test-id',
          conversationId: 'conv-1',
          recipientPubkey: testPubkey,
          content: 'hello after upgrade',
          createdAt: 1700000000,
          rumorEventJson:
              '{"id":"upgrade-test-id","kind":14,"content":"hello"}',
          recipientWrapStatus: OutgoingWrapStatus.pending,
          selfWrapStatus: OutgoingWrapStatus.pending,
          queuedAt: DateTime.utc(2026, 5),
          ownerPubkey: testPubkey,
        );
        await dao.enqueue(dm);

        final fetched = await dao.getById('upgrade-test-id');
        expect(fetched, isNotNull);
        expect(fetched!.content, equals('hello after upgrade'));
        expect(fetched.recipientWrapStatus, OutgoingWrapStatus.pending);
        expect(fetched.selfWrapStatus, OutgoingWrapStatus.pending);
      });

      test(
        'schema parity — fresh-install matches runtime CREATE-IF-NOT-EXISTS '
        'path column-for-column and index-for-index',
        () async {
          // The `outgoing_dms` table is defined in two places:
          //   1. Drift `OutgoingDms` table in `tables.dart`, applied by
          //      `m.createAll()` on first open of a brand-new database.
          //   2. Handwritten SQL in `_createMissingTables`, applied to
          //      existing installs that pre-date the table.
          // Both paths must agree exactly. This test inspects the same
          // database from both code paths and diffs the resulting
          // `outgoing_dms` shape — a future Drift edit that misses the
          // runtime SQL (or vice-versa) fails this test loudly.

          // Path 1: capture the fresh-install shape from the database
          // already opened by the outer `setUp` (Drift's `m.createAll()`
          // path). This represents a brand-new install.
          final freshColumns = await _collectTableInfo(
            database,
            'outgoing_dms',
          );
          final freshIndexes = await _collectIndexNames(
            database,
            'outgoing_dms',
          );

          expect(
            freshColumns,
            isNotEmpty,
            reason: 'precondition: fresh install should have outgoing_dms',
          );

          // Path 2: drop the table and reopen the same on-disk file so
          // `_createMissingTables` recreates it via the runtime SQL path.
          await database.customStatement('DROP TABLE outgoing_dms');
          // Drop the indexes too so `_createMissingTables` is responsible
          // for recreating them — otherwise stale indexes could mask a
          // missing CREATE INDEX statement.
          for (final indexName in freshIndexes) {
            await database.customStatement('DROP INDEX IF EXISTS $indexName');
          }
          await database.close();

          database = AppDatabase.test(NativeDatabase(File(tempDbPath)));
          // Trigger `beforeOpen` lazily.
          await database
              .customSelect(
                "SELECT name FROM sqlite_master WHERE type='table' "
                "AND name='outgoing_dms'",
              )
              .get();

          final recreatedColumns = await _collectTableInfo(
            database,
            'outgoing_dms',
          );
          final recreatedIndexes = await _collectIndexNames(
            database,
            'outgoing_dms',
          );

          // Column-by-column equality: `pragma table_info` returns
          // (name, type, notnull, dflt_value, pk) tuples. List equality
          // also catches column ordering drift, which sqlite preserves
          // across `CREATE TABLE` statements and would surface a
          // mis-ordered hand-written runtime SQL.
          expect(
            recreatedColumns,
            equals(freshColumns),
            reason:
                'runtime CREATE-IF-NOT-EXISTS path must produce the same '
                'columns as Drift `m.createAll()` — drift between the two '
                'is exactly the bug Liz flagged',
          );

          // Index name set equality. Drift and the runtime SQL may emit
          // CREATE INDEX statements in different orders, so set
          // semantics is the right comparison here.
          expect(
            recreatedIndexes,
            equals(freshIndexes),
            reason:
                'runtime CREATE-IF-NOT-EXISTS path must declare the same '
                'index set as Drift fresh-install',
          );
        },
      );

      test('upgrade path recreates pending_view_events when missing', () async {
        await database.customStatement('DROP TABLE pending_view_events');

        final droppedCheck = await database
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type='table' "
              "AND name='pending_view_events'",
            )
            .get();
        expect(
          droppedCheck,
          isEmpty,
          reason: 'precondition: pending_view_events must be missing',
        );

        await database.close();
        database = AppDatabase.test(NativeDatabase(File(tempDbPath)));

        final tableCheck = await database
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type='table' "
              "AND name='pending_view_events'",
            )
            .get();
        expect(
          tableCheck,
          hasLength(1),
          reason: 'pending_view_events must be re-created on reopen',
        );

        final indexNames = await _collectIndexNames(
          database,
          'pending_view_events',
        );
        expect(
          indexNames,
          containsAll(<String>{
            'idx_pending_view_events_user_status',
            'idx_pending_view_events_created_at',
          }),
        );

        final dao = database.pendingViewEventsDao;
        await dao.enqueue(
          PendingViewEvent(
            id: 'upgrade-view-id',
            videoId: testPubkey,
            videoPubkey: testPubkey,
            userPubkey: testPubkey,
            watchDurationMs: 2500,
            trafficSource: 'home',
            status: PendingViewEventStatus.pending,
            createdAt: DateTime.utc(2026, 5),
          ),
        );

        final fetched = await dao.getById('upgrade-view-id');
        expect(fetched, isNotNull);
        expect(fetched!.status, PendingViewEventStatus.pending);
        expect(fetched.watchDurationMs, 2500);
      });

      test(
        'schema parity — pending_view_events fresh-install matches runtime '
        'CREATE-IF-NOT-EXISTS path',
        () async {
          final freshColumns = await _collectTableInfo(
            database,
            'pending_view_events',
          );
          final freshIndexes = await _collectIndexNames(
            database,
            'pending_view_events',
          );

          expect(
            freshColumns,
            isNotEmpty,
            reason:
                'precondition: fresh install should have pending_view_events',
          );

          await database.customStatement('DROP TABLE pending_view_events');
          for (final indexName in freshIndexes) {
            await database.customStatement('DROP INDEX IF EXISTS $indexName');
          }
          await database.close();

          database = AppDatabase.test(NativeDatabase(File(tempDbPath)));
          await database
              .customSelect(
                "SELECT name FROM sqlite_master WHERE type='table' "
                "AND name='pending_view_events'",
              )
              .get();

          final recreatedColumns = await _collectTableInfo(
            database,
            'pending_view_events',
          );
          final recreatedIndexes = await _collectIndexNames(
            database,
            'pending_view_events',
          );

          expect(recreatedColumns, equals(freshColumns));
          expect(recreatedIndexes, equals(freshIndexes));
        },
      );

      test('does not delete non-expired data', () async {
        final eventsDao = database.nostrEventsDao;
        final profileStatsDao = database.profileStatsDao;
        final hashtagStatsDao = database.hashtagStatsDao;
        final notificationsDao = database.notificationsDao;

        // Insert valid (non-expired) data
        final validEvent = createEvent(content: 'valid');
        await eventsDao.upsertEvent(
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

/// Captures `pragma table_info(<table>)` as a list of comparable tuples.
///
/// Each entry is `(name, type, notnull, dflt_value)` — the four fields
/// that define the column shape. `cid` is intentionally dropped because
/// it is just the column ordinal and is already encoded by the list
/// position, and `pk` is included because the primary-key flag is part
/// of the shape contract. `dflt_value` is a string sqlite-renders for
/// defaults (e.g. `'0'`, `'14'`) so the same Dart-level default lands
/// at the same string from both the Drift and the runtime SQL paths.
Future<List<List<Object?>>> _collectTableInfo(
  AppDatabase db,
  String table,
) async {
  final rows = await db.customSelect('PRAGMA table_info($table)').get();
  return rows
      .map(
        (row) => <Object?>[
          row.read<String>('name'),
          row.read<String>('type'),
          row.read<int>('notnull'),
          row.readNullable<String>('dflt_value'),
          row.read<int>('pk'),
        ],
      )
      .toList();
}

/// Captures the set of index names attached to [table], excluding the
/// auto-generated `sqlite_autoindex_*` entries that sqlite adds for
/// primary keys. Returns a [Set] because Drift and the runtime SQL may
/// declare indexes in different orders.
Future<Set<String>> _collectIndexNames(
  AppDatabase db,
  String table,
) async {
  final rows = await db
      .customSelect(
        "SELECT name FROM sqlite_master WHERE type='index' "
        "AND tbl_name='$table' AND name NOT LIKE 'sqlite_autoindex_%'",
      )
      .get();
  return rows.map((row) => row.read<String>('name')).toSet();
}
