// ABOUTME: Main Drift database for OpenVine's shared Nostr database.
// ABOUTME: Provides reactive queries for events, profiles, metrics,
// ABOUTME: and uploads.

import 'package:db_client/db_client.dart';
import 'package:db_client/src/database/app_database.steps.dart';
import 'package:drift/drift.dart';

part 'app_database.g.dart';

/// Default retention period for notifications (7 days)
const _notificationRetentionDays = 7;

/// Main application database using Drift
///
/// This database shares the same SQLite file as nostr_sdk's embedded relay
/// (local_relay.db) to provide a single source of truth for all Nostr events.
@DriftDatabase(
  tables: [
    NostrEvents,
    UserProfiles,
    VideoMetrics,
    ProfileStats,
    HashtagStats,
    Notifications,
    PendingUploads,
    PersonalReactions,
  ],
  daos: [
    UserProfilesDao,
    NostrEventsDao,
    VideoMetricsDao,
    ProfileStatsDao,
    HashtagStatsDao,
    NotificationsDao,
    PendingUploadsDao,
    PersonalReactionsDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Default constructor - uses platform-appropriate connection
  AppDatabase([QueryExecutor? e]) : super(e ?? openConnection());

  /// Constructor that accepts a custom QueryExecutor (for testing)
  AppDatabase.test(super.e);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      // Use createAll for standard Drift table creation
      await m.createAll();

      // IMPORTANT: The database file may have been created by nostr_sdk's
      // embedded relay before our schema ran. In that case, some tables
      // exist (event) but ours don't. Explicitly ensure our tables exist.
      // This handles the case where user_version=0 but db file exists.
      await _ensureAllTablesExist();
    },
    onUpgrade: _schemaUpgrade,
    beforeOpen: (details) async {
      // Ensure the event table has the expire_at column.
      // The event table is managed by nostr_sdk's embedded relay, so we need
      // to add this column ourselves if it doesn't exist.
      await _ensureExpireAtColumn();

      // Run cleanup of expired data on every app startup
      await runStartupCleanup();
    },
  );

  /// Whether the expire_at column exists in the event table.
  /// Set during startup and used to conditionally skip expire_at operations.
  bool _hasExpireAtColumn = false;

  /// Check if expire_at column is available for queries.
  bool get hasExpireAtColumn => _hasExpireAtColumn;

  /// Ensures the expire_at column exists in the event table.
  ///
  /// The event table is created by nostr_sdk's embedded relay, which doesn't
  /// include this column. We add it here for cache eviction functionality.
  ///
  /// Returns true if the column exists (or was successfully added).
  Future<bool> _ensureExpireAtColumn() async {
    try {
      // Check if the event table exists first
      final tableCheck = await customSelect(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='event'",
        variables: [],
        readsFrom: {},
      ).get();

      if (tableCheck.isEmpty) {
        // Table doesn't exist yet - nostr_sdk hasn't created it.
        // This is fine, we'll try again when events start coming in.
        _hasExpireAtColumn = false;
        return false;
      }

      // Check if column exists by querying table schema
      final result = await customSelect(
        "PRAGMA table_info('event')",
        variables: [],
        readsFrom: {},
      ).get();

      final hasExpireAt = result.any(
        (row) => row.read<String>('name') == 'expire_at',
      );

      if (hasExpireAt) {
        _hasExpireAtColumn = true;
        return true;
      }

      // Add the column - this is safe because it's nullable
      await customStatement(
        'ALTER TABLE event ADD COLUMN expire_at INTEGER',
      );
      _hasExpireAtColumn = true;
      return true;
    } on Exception {
      // This can happen if the table is locked or in use
      _hasExpireAtColumn = false;
      return false;
    }
  }

  /// Ensures all application tables exist in the database.
  ///
  /// This handles the case where the database file was created by nostr_sdk's
  /// embedded relay (with user_version=0) before our Drift schema ran.
  /// In that case, Drift's onCreate runs but createAll() may not create
  /// all tables because the database already has some tables from nostr_sdk.
  ///
  /// Uses CREATE TABLE IF NOT EXISTS to safely create missing tables.
  Future<void> _ensureAllTablesExist() async {
    // user_profiles - stores cached Nostr kind 0 profile metadata
    await customStatement('''
      CREATE TABLE IF NOT EXISTS "user_profiles" (
        "pubkey" TEXT NOT NULL PRIMARY KEY,
        "display_name" TEXT NULL,
        "name" TEXT NULL,
        "about" TEXT NULL,
        "picture" TEXT NULL,
        "banner" TEXT NULL,
        "website" TEXT NULL,
        "nip05" TEXT NULL,
        "lud16" TEXT NULL,
        "lud06" TEXT NULL,
        "raw_data" TEXT NULL,
        "created_at" INTEGER NOT NULL,
        "event_id" TEXT NOT NULL,
        "last_fetched" INTEGER NOT NULL
      )
    ''');

    // video_metrics - stores video engagement metrics
    await customStatement('''
      CREATE TABLE IF NOT EXISTS "video_metrics" (
        "event_id" TEXT NOT NULL PRIMARY KEY,
        "loop_count" INTEGER NULL,
        "likes" INTEGER NULL,
        "views" INTEGER NULL,
        "comments" INTEGER NULL,
        "avg_completion" REAL NULL,
        "has_proofmode" INTEGER NULL,
        "has_device_attestation" INTEGER NULL,
        "has_pgp_signature" INTEGER NULL,
        "updated_at" INTEGER NOT NULL,
        FOREIGN KEY("event_id") REFERENCES "event"("id") ON DELETE CASCADE
      )
    ''');

    // profile_statistics - cached profile stats
    // (renamed from profile_stats in v3)
    await customStatement('''
      CREATE TABLE IF NOT EXISTS "profile_statistics" (
        "pubkey" TEXT NOT NULL PRIMARY KEY,
        "video_count" INTEGER NULL,
        "follower_count" INTEGER NULL,
        "following_count" INTEGER NULL,
        "total_views" INTEGER NULL,
        "total_likes" INTEGER NULL,
        "cached_at" INTEGER NOT NULL
      )
    ''');

    // hashtag_stats - cached hashtag statistics
    await customStatement('''
      CREATE TABLE IF NOT EXISTS "hashtag_stats" (
        "hashtag" TEXT NOT NULL PRIMARY KEY,
        "video_count" INTEGER NULL,
        "total_views" INTEGER NULL,
        "total_likes" INTEGER NULL,
        "cached_at" INTEGER NOT NULL
      )
    ''');

    // notifications - user notifications
    await customStatement('''
      CREATE TABLE IF NOT EXISTS "notifications" (
        "id" TEXT NOT NULL PRIMARY KEY,
        "type" TEXT NOT NULL,
        "from_pubkey" TEXT NOT NULL,
        "target_event_id" TEXT NULL,
        "target_pubkey" TEXT NULL,
        "content" TEXT NULL,
        "timestamp" INTEGER NOT NULL,
        "is_read" INTEGER NOT NULL DEFAULT 0 CHECK (is_read IN (0, 1)),
        "cached_at" INTEGER NOT NULL
      )
    ''');

    // pending_uploads - tracks upload queue state
    await customStatement('''
      CREATE TABLE IF NOT EXISTS "pending_uploads" (
        "id" TEXT NOT NULL PRIMARY KEY,
        "local_video_path" TEXT NOT NULL,
        "nostr_pubkey" TEXT NOT NULL,
        "status" TEXT NOT NULL,
        "created_at" INTEGER NOT NULL,
        "cloudinary_public_id" TEXT NULL,
        "video_id" TEXT NULL,
        "cdn_url" TEXT NULL,
        "error_message" TEXT NULL,
        "upload_progress" REAL NULL,
        "thumbnail_path" TEXT NULL,
        "title" TEXT NULL,
        "description" TEXT NULL,
        "hashtags" TEXT NULL,
        "nostr_event_id" TEXT NULL,
        "completed_at" INTEGER NULL,
        "retry_count" INTEGER NOT NULL DEFAULT 0,
        "video_width" INTEGER NULL,
        "video_height" INTEGER NULL,
        "video_duration_millis" INTEGER NULL,
        "proof_manifest_json" TEXT NULL,
        "streaming_mp4_url" TEXT NULL,
        "streaming_hls_url" TEXT NULL,
        "fallback_url" TEXT NULL
      )
    ''');

    // personal_reactions - tracks user's likes/reactions
    await customStatement('''
      CREATE TABLE IF NOT EXISTS "personal_reactions" (
        "target_event_id" TEXT NOT NULL,
        "reaction_event_id" TEXT NOT NULL,
        "user_pubkey" TEXT NOT NULL,
        "created_at" INTEGER NOT NULL,
        PRIMARY KEY("target_event_id", "user_pubkey")
      )
    ''');
  }

  /// Runs cleanup of expired data from all tables.
  ///
  /// This method should be called during app startup to remove:
  /// - Expired Nostr events (based on expire_at timestamp, including NULL)
  /// - Expired profile stats (older than 5 minutes)
  /// - Expired hashtag stats (older than 1 hour)
  /// - Old notifications (older than 7 days)
  ///
  /// Returns a [CleanupResult] with counts of deleted records.
  ///
  /// Note: This method handles cases where tables may not exist during
  /// migrations from older schema versions.
  Future<CleanupResult> runStartupCleanup() async {
    // Delete expired events (also deletes events with NULL expire_at)
    final expiredEventsDeleted = await nostrEventsDao.deleteExpiredEvents(null);

    // Delete expired profile stats (5 minute expiry)
    // Note: Table may not exist during migrations from older versions
    var expiredProfileStatsDeleted = 0;
    try {
      expiredProfileStatsDeleted = await profileStatsDao.deleteExpired();
    } on Exception {
      // Table doesn't exist yet (migrating from older schema)
    }

    // Delete expired hashtag stats (1 hour expiry)
    // Note: Table may not exist during migrations from older versions
    var expiredHashtagStatsDeleted = 0;
    try {
      expiredHashtagStatsDeleted = await hashtagStatsDao.deleteExpired();
    } on Exception {
      // Table doesn't exist yet (migrating from older schema)
    }

    // Delete old notifications (7 day retention)
    // Note: Table may not exist during migrations from older versions
    var oldNotificationsDeleted = 0;
    try {
      final notificationCutoff =
          DateTime.now()
              .subtract(const Duration(days: _notificationRetentionDays))
              .millisecondsSinceEpoch ~/
          1000;
      oldNotificationsDeleted = await notificationsDao.deleteOlderThan(
        notificationCutoff,
      );
    } on Exception {
      // Table doesn't exist yet (migrating from older schema)
    }

    return CleanupResult(
      expiredEventsDeleted: expiredEventsDeleted,
      expiredProfileStatsDeleted: expiredProfileStatsDeleted,
      expiredHashtagStatsDeleted: expiredHashtagStatsDeleted,
      oldNotificationsDeleted: oldNotificationsDeleted,
    );
  }
}

extension Migrations on GeneratedDatabase {
  OnUpgrade get _schemaUpgrade => stepByStep(
    from1To2: (m, schema) async {
      // Add expire_at column to event table
      await m.alterTable(
        TableMigration(
          schema.event,
          newColumns: [schema.event.expireAt],
        ),
      );
    },
    from2To3: (m, schema) async {
      // Drop old profile_stats table (renamed to profile_statistics).
      // This handles any schema mismatches from older versions.
      // Data loss is acceptable since this is a cache with 5-minute expiry.
      await customStatement('DROP TABLE IF EXISTS profile_stats');

      // Create new profile_statistics table with correct schema
      await m.createTable(schema.profileStatistics);

      // Ensure hashtag_stats table exists.
      // Some users may be missing this table due to database being created
      // by nostr_sdk's embedded relay before our schema ran onCreate.
      await customStatement('''
        CREATE TABLE IF NOT EXISTS "hashtag_stats" (
          "hashtag" TEXT NOT NULL PRIMARY KEY,
          "video_count" INTEGER NULL,
          "total_views" INTEGER NULL,
          "total_likes" INTEGER NULL,
          "cached_at" INTEGER NOT NULL
        )
      ''');
    },
  );
}
