// dart format width=80
// ignore_for_file: unused_local_variable, unused_import
import 'dart:io';

import 'package:db_client/src/database/app_database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
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

  group('profile_stats old schema migration', () {
    late String tempDbPath;
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('profile_stats_migration_');
      tempDbPath = '${tempDir.path}/test.db';
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    /// Creates all v1 schema tables in the database.
    Future<void> createV1Schema(NativeDatabase db) async {
      // Create event table (v1 schema without expire_at)
      await db.runCustom('''
        CREATE TABLE IF NOT EXISTS event (
          id TEXT NOT NULL PRIMARY KEY,
          pubkey TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          kind INTEGER NOT NULL,
          tags TEXT NOT NULL,
          content TEXT NOT NULL,
          sig TEXT NOT NULL,
          sources TEXT
        )
      ''');

      // Create other required tables with v1 schema
      await db.runCustom('''
        CREATE TABLE IF NOT EXISTS user_profiles (
          pubkey TEXT NOT NULL PRIMARY KEY,
          display_name TEXT,
          name TEXT,
          about TEXT,
          picture TEXT,
          banner TEXT,
          website TEXT,
          nip05 TEXT,
          lud16 TEXT,
          lud06 TEXT,
          raw_data TEXT,
          created_at INTEGER NOT NULL,
          event_id TEXT NOT NULL,
          last_fetched INTEGER NOT NULL
        )
      ''');

      await db.runCustom('''
        CREATE TABLE IF NOT EXISTS video_metrics (
          event_id TEXT NOT NULL PRIMARY KEY,
          loop_count INTEGER,
          like_count INTEGER,
          repost_count INTEGER,
          comment_count INTEGER,
          last_played_position INTEGER,
          has_user_liked INTEGER DEFAULT 0 NOT NULL,
          has_user_reposted INTEGER DEFAULT 0 NOT NULL,
          user_comment_count INTEGER DEFAULT 0 NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');

      await db.runCustom('''
        CREATE TABLE IF NOT EXISTS hashtag_stats (
          hashtag TEXT NOT NULL PRIMARY KEY,
          video_count INTEGER,
          total_views INTEGER,
          total_likes INTEGER,
          cached_at INTEGER NOT NULL
        )
      ''');

      await db.runCustom('''
        CREATE TABLE IF NOT EXISTS notifications (
          id TEXT NOT NULL PRIMARY KEY,
          type TEXT NOT NULL,
          from_pubkey TEXT NOT NULL,
          target_event_id TEXT,
          target_pubkey TEXT,
          content TEXT,
          timestamp INTEGER NOT NULL,
          is_read INTEGER DEFAULT 0 NOT NULL,
          cached_at INTEGER NOT NULL
        )
      ''');

      await db.runCustom('''
        CREATE TABLE IF NOT EXISTS pending_uploads (
          id TEXT NOT NULL PRIMARY KEY,
          local_video_path TEXT NOT NULL,
          nostr_pubkey TEXT NOT NULL,
          status TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          cloudinary_public_id TEXT,
          video_id TEXT,
          cdn_url TEXT,
          error_message TEXT,
          upload_progress REAL,
          thumbnail_path TEXT,
          title TEXT,
          description TEXT,
          hashtags TEXT,
          nostr_event_id TEXT,
          completed_at INTEGER,
          retry_count INTEGER DEFAULT 0 NOT NULL,
          video_width INTEGER,
          video_height INTEGER,
          video_duration_millis INTEGER,
          proof_manifest_json TEXT,
          streaming_mp4_url TEXT,
          streaming_hls_url TEXT,
          fallback_url TEXT
        )
      ''');

      await db.runCustom('''
        CREATE TABLE IF NOT EXISTS personal_reactions (
          target_event_id TEXT NOT NULL,
          user_pubkey TEXT NOT NULL,
          reaction_event_id TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          PRIMARY KEY (target_event_id, user_pubkey)
        )
      ''');
    }

    test('migrates profile_stats with old schema (updated_at instead of '
        'cached_at)', () async {
      // Create a database with old profile_stats schema using raw sqlite3
      final rawDb = NativeDatabase(File(tempDbPath));
      await rawDb.ensureOpen(
        _StubUser(schemaVersion: 0, onCreate: (_) async {}),
      );

      // Create v1 schema tables
      await createV1Schema(rawDb);

      // Create the old profile_stats schema (with updated_at instead of
      // cached_at)
      await rawDb.runCustom('''
        CREATE TABLE IF NOT EXISTS profile_stats (
          pubkey TEXT NOT NULL PRIMARY KEY,
          video_count INTEGER,
          follower_count INTEGER,
          following_count INTEGER,
          updated_at INTEGER NOT NULL
        )
      ''');

      // Set schema version to 1 so migration runs
      await rawDb.runCustom('PRAGMA user_version = 1');

      // Insert some test data
      await rawDb.runCustom('''
        INSERT INTO profile_stats (pubkey, video_count, follower_count,
          following_count, updated_at)
        VALUES ('test_pubkey_abc123', 10, 100, 50, 1234567890)
      ''');

      await rawDb.close();

      // Now open with AppDatabase which should run migration
      final db = AppDatabase.test(NativeDatabase(File(tempDbPath)));

      // Query to verify the new schema has correct columns
      final columns = await db
          .customSelect(
            'PRAGMA table_info(profile_stats)',
          )
          .get();

      final columnNames = columns
          .map((row) => row.data['name'] as String)
          .toSet();

      // New schema should have cached_at, total_views, total_likes
      expect(columnNames, contains('cached_at'));
      expect(columnNames, contains('total_views'));
      expect(columnNames, contains('total_likes'));

      // Old data should be cleared (table was recreated)
      final stats = await db.select(db.profileStats).get();
      expect(stats, isEmpty);

      await db.close();
    });

    test(
      'migrates profile_stats missing total_views and total_likes columns',
      () async {
        // Create a database with partially old schema (has cached_at but missing
        // total_views/total_likes)
        final rawDb = NativeDatabase(File(tempDbPath));
        await rawDb.ensureOpen(
          _StubUser(schemaVersion: 0, onCreate: (_) async {}),
        );

        // Create v1 schema tables
        await createV1Schema(rawDb);

        await rawDb.runCustom('''
        CREATE TABLE IF NOT EXISTS profile_stats (
          pubkey TEXT NOT NULL PRIMARY KEY,
          video_count INTEGER,
          follower_count INTEGER,
          following_count INTEGER,
          cached_at INTEGER NOT NULL
        )
      ''');

        // Set schema version to 1 so migration runs
        await rawDb.runCustom('PRAGMA user_version = 1');

        await rawDb.close();

        // Open with AppDatabase which should run migration
        final db = AppDatabase.test(NativeDatabase(File(tempDbPath)));

        // Query to verify the new schema has all columns
        final columns = await db
            .customSelect(
              'PRAGMA table_info(profile_stats)',
            )
            .get();

        final columnNames = columns
            .map((row) => row.data['name'] as String)
            .toSet();

        expect(columnNames, contains('cached_at'));
        expect(columnNames, contains('total_views'));
        expect(columnNames, contains('total_likes'));

        await db.close();
      },
    );

    test('does not modify profile_stats with correct schema', () async {
      // Create a database with correct schema
      final rawDb = NativeDatabase(File(tempDbPath));
      await rawDb.ensureOpen(
        _StubUser(schemaVersion: 0, onCreate: (_) async {}),
      );

      // Create v1 schema tables
      await createV1Schema(rawDb);

      await rawDb.runCustom('''
        CREATE TABLE IF NOT EXISTS profile_stats (
          pubkey TEXT NOT NULL PRIMARY KEY,
          video_count INTEGER,
          follower_count INTEGER,
          following_count INTEGER,
          total_views INTEGER,
          total_likes INTEGER,
          cached_at INTEGER NOT NULL
        )
      ''');

      // Set schema version to 1 so migration runs
      await rawDb.runCustom('PRAGMA user_version = 1');

      // Insert test data
      final now = DateTime.now().millisecondsSinceEpoch;
      await rawDb.runCustom('''
        INSERT INTO profile_stats (pubkey, video_count, follower_count,
          following_count, total_views, total_likes, cached_at)
        VALUES ('test_pubkey_abc123', 10, 100, 50, 500, 200, $now)
      ''');

      await rawDb.close();

      // Open with AppDatabase
      final db = AppDatabase.test(NativeDatabase(File(tempDbPath)));

      // Data should be preserved since schema was already correct
      final stats = await db.select(db.profileStats).get();
      expect(stats.length, equals(1));
      expect(stats.first.pubkey, equals('test_pubkey_abc123'));
      expect(stats.first.videoCount, equals(10));
      expect(stats.first.totalViews, equals(500));
      expect(stats.first.totalLikes, equals(200));

      await db.close();
    });
  });
}

/// Stub QueryExecutorUser for initializing raw NativeDatabase connections.
class _StubUser extends QueryExecutorUser {
  _StubUser({required this.schemaVersion, required this.onCreate});

  @override
  final int schemaVersion;

  final Future<void> Function(QueryExecutor) onCreate;

  @override
  Future<void> beforeOpen(
    QueryExecutor executor,
    OpeningDetails details,
  ) async {
    if (details.wasCreated) {
      await onCreate(executor);
    }
  }
}
