// dart format width=80
// ignore_for_file: unused_local_variable, unused_import
import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:db_client/src/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'generated/schema.dart';

import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v2.dart' as v2;

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

  // The following template shows how to write tests ensuring your migrations
  // preserve existing data.
  // Testing this can be useful for migrations that change existing columns
  // (e.g. by alterating their type or constraints). Migrations that only add
  // tables or columns typically don't need these advanced tests. For more
  // information, see https://drift.simonbinder.eu/migrations/tests/#verifying-data-integrity
  // TODO: This generated template shows how these tests could be written. Adopt
  // it to your own needs when testing migrations with data integrity.
  test('migration from v1 to v2 does not corrupt data', () async {
    // Add data to insert into the old database, and the expected rows after the
    // migration.
    // TODO: Fill these lists
    final oldEventData = <v1.EventData>[];
    final expectedNewEventData = <v2.EventData>[];

    final oldUserProfilesData = <v1.UserProfilesData>[];
    final expectedNewUserProfilesData = <v2.UserProfilesData>[];

    final oldVideoMetricsData = <v1.VideoMetricsData>[];
    final expectedNewVideoMetricsData = <v2.VideoMetricsData>[];

    final oldProfileStatsData = <v1.ProfileStatsData>[];
    final expectedNewProfileStatsData = <v2.ProfileStatsData>[];

    final oldHashtagStatsData = <v1.HashtagStatsData>[];
    final expectedNewHashtagStatsData = <v2.HashtagStatsData>[];

    final oldNotificationsData = <v1.NotificationsData>[];
    final expectedNewNotificationsData = <v2.NotificationsData>[];

    final oldPendingUploadsData = <v1.PendingUploadsData>[];
    final expectedNewPendingUploadsData = <v2.PendingUploadsData>[];

    final oldPersonalReactionsData = <v1.PersonalReactionsData>[];
    final expectedNewPersonalReactionsData = <v2.PersonalReactionsData>[];

    await verifier.testWithDataIntegrity(
      oldVersion: 1,
      newVersion: 2,
      createOld: v1.DatabaseAtV1.new,
      createNew: v2.DatabaseAtV2.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, oldDb) {
        batch.insertAll(oldDb.event, oldEventData);
        batch.insertAll(oldDb.userProfiles, oldUserProfilesData);
        batch.insertAll(oldDb.videoMetrics, oldVideoMetricsData);
        batch.insertAll(oldDb.profileStats, oldProfileStatsData);
        batch.insertAll(oldDb.hashtagStats, oldHashtagStatsData);
        batch.insertAll(oldDb.notifications, oldNotificationsData);
        batch.insertAll(oldDb.pendingUploads, oldPendingUploadsData);
        batch.insertAll(oldDb.personalReactions, oldPersonalReactionsData);
      },
      validateItems: (newDb) async {
        expect(expectedNewEventData, await newDb.select(newDb.event).get());
        expect(
          expectedNewUserProfilesData,
          await newDb.select(newDb.userProfiles).get(),
        );
        expect(
          expectedNewVideoMetricsData,
          await newDb.select(newDb.videoMetrics).get(),
        );
        expect(
          expectedNewProfileStatsData,
          await newDb.select(newDb.profileStats).get(),
        );
        expect(
          expectedNewHashtagStatsData,
          await newDb.select(newDb.hashtagStats).get(),
        );
        expect(
          expectedNewNotificationsData,
          await newDb.select(newDb.notifications).get(),
        );
        expect(
          expectedNewPendingUploadsData,
          await newDb.select(newDb.pendingUploads).get(),
        );
        expect(
          expectedNewPersonalReactionsData,
          await newDb.select(newDb.personalReactions).get(),
        );
      },
    );
  });
}
