// dart format width=80
// ignore_for_file: unused_local_variable
import 'package:db_client/src/database/app_database.dart';
import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated/schema.dart';
import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v2.dart' as v2;
import 'generated/schema_v3.dart' as v3;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  group('simple database migrations', () {
    // These simple tests verify all possible schema updates with a simple (no
    // data) migration. This is a quick way to ensure that written database
    // migrations properly alter the schema.
    const versions = GeneratedHelper.versions;
    for (final (i, fromVersion) in versions.indexed) {
      group('from $fromVersion', () {
        for (final toVersion in versions.skip(i + 1)) {
          test('to $toVersion', () async {
            final schema = await verifier.schemaAt(fromVersion);
            final db = AppDatabase(schema.newConnection());
            await verifier.migrateAndValidate(db, toVersion);
            await db.close();
          });
        }
      });
    }
  });

  group('data integrity tests', () {
    test('migration from v1 to v2 preserves event data', () async {
      final oldEventData = <v1.EventData>[];
      final expectedNewEventData = <v2.EventData>[];

      await verifier.testWithDataIntegrity(
        oldVersion: 1,
        newVersion: 2,
        createOld: v1.DatabaseAtV1.new,
        createNew: v2.DatabaseAtV2.new,
        openTestedDatabase: AppDatabase.new,
        createItems: (batch, oldDb) {
          batch.insertAll(oldDb.event, oldEventData);
        },
        validateItems: (newDb) async {
          expect(
            expectedNewEventData,
            await newDb.select(newDb.event).get(),
          );
        },
      );
    });

    test('migration from v2 to v3 drops profile_stats and creates '
        'profile_statistics', () async {
      // v2 has profile_stats, v3 has profile_statistics
      // The migration drops profile_stats and creates profile_statistics
      await verifier.testWithDataIntegrity(
        oldVersion: 2,
        newVersion: 3,
        createOld: v2.DatabaseAtV2.new,
        createNew: v3.DatabaseAtV3.new,
        openTestedDatabase: AppDatabase.new,
        createItems: (batch, oldDb) {
          // Insert data into profile_stats (old table name)
          batch.insertAll(oldDb.profileStats, [
            v2.ProfileStatsData(
              pubkey: 'test_pubkey_abc123',
              videoCount: 10,
              followerCount: 100,
              followingCount: 50,
              totalViews: 500,
              totalLikes: 200,
              cachedAt: DateTime.now().millisecondsSinceEpoch,
            ),
          ]);
        },
        validateItems: (newDb) async {
          // After migration, profile_statistics should exist but be empty
          // (old profile_stats data is dropped during rename)
          final stats = await newDb.select(newDb.profileStatistics).get();
          expect(stats, isEmpty);
        },
      );
    });
  });
}
