// dart format width=80
import 'package:db_client/src/database/app_database.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated/schema.dart';
import 'generated/schema_v2.dart' as v2;
import 'generated/schema_v3.dart' as v3;
import 'generated/schema_v4.dart' as v4;
import 'generated/schema_v5.dart' as v5;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  group('schema validation', () {
    test('current schema version is 4', () {
      expect(AppDatabase(NativeDatabase.memory()).schemaVersion, 4);
    });

    test('v4 schema is valid and up to date', () async {
      final schema = await verifier.schemaAt(4);
      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 4);
      await db.close();
    });

    test('v3 schema migrates to v4', () async {
      final schema = await verifier.schemaAt(3);
      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 4);
      await db.close();
    });

    test('v2 schema migrates to v4', () async {
      final schema = await verifier.schemaAt(2);
      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 4);
      await db.close();
    });

    test('legacy v1 schema migrates to v4', () async {
      final schema = await verifier.schemaAt(1);
      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 4);
      await db.close();
    });

    test('migrates v2 profile statistic follower timestamps', () async {
      final schema = await verifier.schemaAt(2);
      final cachedAt =
          DateTime.now()
              .subtract(const Duration(hours: 10))
              .millisecondsSinceEpoch ~/
          1000;

      schema.rawDatabase.execute(
        'INSERT INTO profile_statistics '
        '(pubkey, video_count, follower_count, following_count, total_views, '
        'total_likes, cached_at) '
        'VALUES (?, NULL, ?, ?, NULL, NULL, ?)',
        ['withcounts', 12, 7, cachedAt],
      );
      schema.rawDatabase.execute(
        'INSERT INTO profile_statistics '
        '(pubkey, video_count, follower_count, following_count, total_views, '
        'total_likes, cached_at) '
        'VALUES (?, NULL, NULL, NULL, NULL, NULL, ?)',
        ['withoutcounts', cachedAt],
      );

      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 4);

      final rows = await db
          .customSelect(
            'SELECT pubkey, follower_counts_updated_at '
            'FROM profile_statistics ORDER BY pubkey',
          )
          .get();
      final byPubkey = {
        for (final row in rows) row.read<String>('pubkey'): row,
      };

      expect(
        byPubkey['withcounts']!.read<int?>('follower_counts_updated_at'),
        cachedAt,
      );
      expect(byPubkey.containsKey('withoutcounts'), isFalse);
      await db.close();
    });

    test('v2 identity_events rows survive the upgrade unstamped', () async {
      await verifier.testWithDataIntegrity(
        oldVersion: 2,
        newVersion: 4,
        createOld: v2.DatabaseAtV2.new,
        createNew: v4.DatabaseAtV4.new,
        openTestedDatabase: AppDatabase.new,
        createItems: (batch, oldDb) => batch.insert(
          oldDb.identityEvents,
          v2.IdentityEventsData(
            pubkey: 'a' * 64,
            tagsJson: '[["i","github:alice","proof-a"]]',
            sourceKind: 10011,
          ),
        ),
        validateItems: (newDb) async {
          final row = await newDb.select(newDb.identityEvents).getSingle();
          expect(row.tagsJson, '[["i","github:alice","proof-a"]]');
          expect(row.sourceKind, 10011);
          // Nothing knows which event a pre-upgrade row came from, so it
          // stays out of the staleness comparison until the next read
          // stamps it.
          expect(row.sourceCreatedAt, null);
          expect(row.sourceEventId, null);
        },
      );
    });

    test(
      'v2 clips survive the v4 migration uncategorized and unarchived',
      () async {
        final schema = await verifier.schemaAt(2);
        schema.rawDatabase.execute(
          'INSERT INTO clips (id, duration_ms, recorded_at, data) '
          'VALUES (?, ?, ?, ?)',
          ['clip-1', 3000, 1700000000, '{}'],
        );

        final db = AppDatabase(schema.newConnection());
        await verifier.migrateAndValidate(db, 4);

        final migrated = await db.clipsDao.getClipById('clip-1');
        expect(migrated?.id, 'clip-1');
        expect(migrated?.categoryId, null);
        expect(migrated?.archivedAt, null);
        await db.close();
      },
    );

    test(
      'v3 clips survive the v4 migration uncategorized and unarchived',
      () async {
        final schema = await verifier.schemaAt(3);
        schema.rawDatabase.execute(
          'INSERT INTO clips (id, duration_ms, recorded_at, data) '
          'VALUES (?, ?, ?, ?)',
          ['clip-1', 3000, 1700000000, '{}'],
        );

        final db = AppDatabase(schema.newConnection());
        await verifier.migrateAndValidate(db, 4);

        final migrated = await db.clipsDao.getClipById('clip-1');
        expect(migrated?.id, 'clip-1');
        expect(migrated?.categoryId, null);
        expect(migrated?.archivedAt, null);
        await db.close();
      },
    );
    test('v3 pending_view_events rows survive the v5 upgrade '
        'without a d tag', () async {
      await verifier.testWithDataIntegrity(
        oldVersion: 3,
        newVersion: 5,
        createOld: v3.DatabaseAtV3.new,
        createNew: v5.DatabaseAtV5.new,
        openTestedDatabase: AppDatabase.new,
        createItems: (batch, oldDb) => batch.insert(
          oldDb.pendingViewEvents,
          v3.PendingViewEventsCompanion.insert(
            id: 'queued-before-v5',
            videoId: 'b' * 64,
            videoPubkey: 'c' * 64,
            userPubkey: 'd' * 64,
            watchDurationMs: 4200,
            trafficSource: 'feed',
            status: 'pending',
            createdAt: DateTime.utc(2026, 8, 12).millisecondsSinceEpoch ~/ 1000,
          ),
        ),
        validateItems: (newDb) async {
          final row = await newDb.select(newDb.pendingViewEvents).getSingle();
          expect(row.watchDurationMs, 4200);
          // There is nothing to backfill the tag from, so the row keeps a
          // null one. The sweep discards those instead of retrying a publish
          // that can never address its subject.
          expect(row.videoAddressableDTag, null);
        },
      );
    });
  });
}
