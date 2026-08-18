// dart format width=80
import 'package:db_client/src/database/app_database.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated/schema.dart';
import 'generated/schema_v2.dart' as v2;
import 'generated/schema_v3.dart' as v3;
import 'generated/schema_v8.dart' as v8;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  group('schema validation', () {
    test('current schema version is 9', () {
      expect(AppDatabase(NativeDatabase.memory()).schemaVersion, 9);
    });

    test('v9 schema is valid and up to date', () async {
      final schema = await verifier.schemaAt(9);
      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 9);
      await db.close();
    });

    test('v8 schema migrates to v9', () async {
      final schema = await verifier.schemaAt(8);
      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 9);
      const conversationId =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      const ownerPubkey =
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
      await db.removedConversationsDao.record(
        conversationId: conversationId,
        ownerPubkey: ownerPubkey,
        removedAt: 1700000000,
      );
      expect(
        await db.removedConversationsDao.removedAtFor(
          conversationId: conversationId,
          ownerPubkey: ownerPubkey,
        ),
        1700000000,
      );
      await db.close();
    });

    test('v7 schema migrates to v9', () async {
      final schema = await verifier.schemaAt(7);
      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 9);
      await db.close();
    });

    test('v6 schema migrates to v9', () async {
      final schema = await verifier.schemaAt(6);
      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 9);
      await db.close();
    });

    test('v5 schema migrates to v9', () async {
      final schema = await verifier.schemaAt(5);
      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 9);
      await db.close();
    });

    test('v3 schema migrates to v9', () async {
      final schema = await verifier.schemaAt(3);
      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 9);
      await db.close();
    });

    test('v2 schema migrates to v9', () async {
      final schema = await verifier.schemaAt(2);
      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 9);
      await db.close();
    });

    test('legacy v1 schema migrates to v9', () async {
      final schema = await verifier.schemaAt(1);
      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 9);
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
      await verifier.migrateAndValidate(db, 9);

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
        newVersion: 8,
        createOld: v2.DatabaseAtV2.new,
        createNew: v8.DatabaseAtV8.new,
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
      'v2 clips survive the migration uncategorized and unarchived',
      () async {
        final schema = await verifier.schemaAt(2);
        schema.rawDatabase.execute(
          'INSERT INTO clips (id, duration_ms, recorded_at, data) '
          'VALUES (?, ?, ?, ?)',
          ['clip-1', 3000, 1700000000, '{}'],
        );

        final db = AppDatabase(schema.newConnection());
        await verifier.migrateAndValidate(db, 9);

        final migrated = await db.clipsDao.getClipById('clip-1');
        expect(migrated?.id, 'clip-1');
        expect(migrated?.categoryId, null);
        expect(migrated?.archivedAt, null);
        await db.close();
      },
    );

    test(
      'v3 clips survive the migration uncategorized and unarchived',
      () async {
        final schema = await verifier.schemaAt(3);
        schema.rawDatabase.execute(
          'INSERT INTO clips (id, duration_ms, recorded_at, data) '
          'VALUES (?, ?, ?, ?)',
          ['clip-1', 3000, 1700000000, '{}'],
        );

        final db = AppDatabase(schema.newConnection());
        await verifier.migrateAndValidate(db, 9);

        final migrated = await db.clipsDao.getClipById('clip-1');
        expect(migrated?.id, 'clip-1');
        expect(migrated?.categoryId, null);
        expect(migrated?.archivedAt, null);
        await db.close();
      },
    );

    test('v6 copies a distinct pre-v5 vine id into the d-tag column', () async {
      await verifier.testWithDataIntegrity(
        oldVersion: 3,
        newVersion: 8,
        createOld: v3.DatabaseAtV3.new,
        createNew: v8.DatabaseAtV8.new,
        openTestedDatabase: AppDatabase.new,
        createItems: (batch, oldDb) {
          batch
            ..insert(
              oldDb.pendingViewEvents,
              v3.PendingViewEventsCompanion.insert(
                id: 'queued-with-d-tag',
                videoId: 'b' * 64,
                videoPubkey: 'c' * 64,
                videoVineId: const Value('the-d-tag'),
                userPubkey: 'd' * 64,
                watchDurationMs: 4200,
                trafficSource: 'feed',
                status: 'pending',
                createdAt:
                    DateTime.utc(2026, 8, 12).millisecondsSinceEpoch ~/ 1000,
              ),
            )
            ..insert(
              oldDb.pendingViewEvents,
              v3.PendingViewEventsCompanion.insert(
                id: 'queued-event-id-fallback',
                videoId: 'e' * 64,
                videoPubkey: 'c' * 64,
                videoVineId: Value('e' * 64),
                userPubkey: 'd' * 64,
                watchDurationMs: 2500,
                trafficSource: 'feed',
                status: 'pending',
                createdAt:
                    DateTime.utc(2026, 8, 12).millisecondsSinceEpoch ~/ 1000,
              ),
            );
        },
        validateItems: (newDb) async {
          final rows = await newDb.select(newDb.pendingViewEvents).get();
          expect(rows, hasLength(2));
          final byId = {for (final row in rows) row.id: row};
          expect(byId['queued-with-d-tag']!.videoAddressableDTag, 'the-d-tag');
          expect(byId['queued-event-id-fallback']!.videoAddressableDTag, null);
        },
      );
    });

    test('v7 queued view rows gain a NULL phase at v8', () async {
      final schema = await verifier.schemaAt(7);
      schema.rawDatabase.execute(
        'INSERT INTO pending_view_events '
        '(id, video_id, video_pubkey, user_pubkey, watch_duration_ms, '
        'traffic_source, status, created_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        [
          'legacy-row',
          'b' * 64,
          'c' * 64,
          'd' * 64,
          4200,
          'feed',
          'pending',
          1786483200,
        ],
      );

      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 9);

      final row = await db
          .customSelect(
            'SELECT phase FROM pending_view_events WHERE id = ?',
            variables: [Variable.withString('legacy-row')],
          )
          .getSingle();
      // Pre-phase rows must stay NULL: the replay path publishes them without
      // a phase tag so the relay still counts their view.
      expect(row.read<String?>('phase'), isNull);

      // And post-upgrade rows can carry the two-phase marker.
      await db.customStatement(
        'INSERT INTO pending_view_events '
        '(id, video_id, video_pubkey, user_pubkey, watch_duration_ms, '
        'traffic_source, status, created_at, phase) '
        "VALUES ('start-row', '${'b' * 64}', '${'c' * 64}', '${'d' * 64}', "
        "0, 'feed', 'pending', 1786483201, 'start')",
      );
      final phased = await db
          .customSelect(
            'SELECT phase FROM pending_view_events WHERE id = ?',
            variables: [Variable.withString('start-row')],
          )
          .getSingle();
      expect(phased.read<String?>('phase'), 'start');
      await db.close();
    });

    test(
      'v5 restores the follower column on an original-v3 database',
      () async {
        final schema = await verifier.schemaAt(3);
        // #6911 redefined v3 in place, so a database cut at the original v3
        // reports user_version 3 without the follower column — and hadUpgrade
        // suppresses the beforeOpen repair during the 3 -> 4 open.
        schema.rawDatabase.execute(
          'ALTER TABLE profile_statistics '
          'DROP COLUMN follower_counts_updated_at',
        );
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
          ['healme', 12, 7, cachedAt],
        );

        final db = AppDatabase(schema.newConnection());
        await verifier.migrateAndValidate(db, 9);

        final row = await db
            .customSelect(
              'SELECT follower_counts_updated_at FROM profile_statistics '
              'WHERE pubkey = ?',
              variables: [Variable.withString('healme')],
            )
            .getSingle();
        expect(row.read<int?>('follower_counts_updated_at'), cachedAt);
        await db.close();
      },
    );

    test('v7 backfills the consolidated indexes onto a v6 database', () async {
      // The `List<Index>` getters these replace were never read by Drift, so
      // a v6 database has none of them. Folding the backfill into an earlier
      // `from <` block would silently skip every database already at v6.
      const consolidated = <String>[
        'idx_metrics_loop_count',
        'idx_metrics_likes',
        'idx_metrics_views',
        'idx_hashtag_video_count',
        'idx_notification_timestamp',
        'idx_notification_is_read',
        'idx_notification_owner_timestamp',
        'idx_pending_upload_status',
        'idx_pending_upload_created',
        'idx_personal_reactions_user',
        'idx_personal_reactions_reaction_id',
        'idx_personal_reactions_addressable_id',
        'idx_personal_reposts_user',
        'idx_personal_reposts_repost_id',
        'idx_personal_reposts_user_created',
      ];

      final schema = await verifier.schemaAt(6);
      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 9);

      final rows = await db
          .customSelect("SELECT name FROM sqlite_master WHERE type = 'index'")
          .get();
      final present = rows.map((row) => row.read<String>('name')).toSet();
      expect(present, containsAll(consolidated));
      await db.close();
    });
  });
}
