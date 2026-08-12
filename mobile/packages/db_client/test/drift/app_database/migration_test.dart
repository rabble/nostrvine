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

    test('migrates v2 profile statistic follower timestamps to v3', () async {
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
      await verifier.migrateAndValidate(db, 3);

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
      expect(
        byPubkey.containsKey('withoutcounts'),
        isFalse,
      );
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

    test('v4 copies a distinct pre-v4 vine id into the d-tag column', () async {
      await verifier.testWithDataIntegrity(
        oldVersion: 3,
        newVersion: 4,
        createOld: v3.DatabaseAtV3.new,
        createNew: v4.DatabaseAtV4.new,
        openTestedDatabase: AppDatabase.new,
        createItems: (batch, oldDb) {
          batch.insert(
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
          );
          batch.insert(
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
  });
}
