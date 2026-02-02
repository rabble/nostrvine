// ABOUTME: Main Drift database for OpenVine's shared Nostr database.
// ABOUTME: Provides reactive queries for events, profiles, metrics,
// ABOUTME: and uploads.

import 'package:db_client/db_client.dart';
import 'package:drift/drift.dart';

part 'app_database.g.dart';

/// Default retention period for notifications (7 days)
const _notificationRetentionDays = 7;

/// Main application database using Drift
///
/// This database uses SQLite (divine_db.db) to store all Nostr events,
/// user profiles, video metrics, and other app data.
@DriftDatabase(
  tables: [
    // TODO(any): investigate to possibly remove this table if not needed
    NostrEvents,
    UserProfiles,
    VideoMetrics,
    ProfileStats,
    HashtagStats,
    Notifications,
    PendingUploads,
    PersonalReactions,
    PersonalReposts,
    PendingActions,
    Nip05Verifications,
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
    PersonalRepostsDao,
    PendingActionsDao,
    Nip05VerificationsDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Default constructor - uses platform-appropriate connection
  AppDatabase([QueryExecutor? e]) : super(e ?? openConnection());

  /// Constructor that accepts a custom QueryExecutor (for testing)
  AppDatabase.test(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    beforeOpen: (details) async {
      // Create any missing tables that should have been part of v1
      await _createMissingTables();

      // Run cleanup of expired data on every app startup
      await runStartupCleanup();
    },
  );

  /// Creates tables that were added to the schema but missing from some
  /// installs.
  ///
  /// This handles cases where tables were added to the Drift schema but
  /// existing databases don't have them yet. Rather than incrementing the
  /// schema version, we check and create missing tables on startup.
  Future<void> _createMissingTables() async {
    // Check if personal_reposts table exists, create if missing
    final repostsResult = await customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' "
      "AND name='personal_reposts'",
    ).get();

    if (repostsResult.isEmpty) {
      await customStatement('''
        CREATE TABLE personal_reposts (
          addressable_id TEXT NOT NULL,
          repost_event_id TEXT NOT NULL,
          original_author_pubkey TEXT NOT NULL,
          user_pubkey TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          PRIMARY KEY (addressable_id, user_pubkey)
        )
      ''');
    }

    // Check if nip05_verifications table exists, create if missing
    final nip05Result = await customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' "
      "AND name='nip05_verifications'",
    ).get();

    if (nip05Result.isEmpty) {
      await customStatement('''
        CREATE TABLE nip05_verifications (
          pubkey TEXT NOT NULL PRIMARY KEY,
          nip05 TEXT NOT NULL,
          status TEXT NOT NULL,
          verified_at INTEGER NOT NULL,
          expires_at INTEGER NOT NULL
        )
      ''');
      await customStatement('''
        CREATE INDEX IF NOT EXISTS idx_nip05_expires_at
        ON nip05_verifications (expires_at)
      ''');
    }
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
  Future<CleanupResult> runStartupCleanup() async {
    // Delete expired events (also deletes events with NULL expire_at)
    final expiredEventsDeleted = await nostrEventsDao.deleteExpiredEvents(null);

    // Delete expired profile stats (5 minute expiry)
    final expiredProfileStatsDeleted = await profileStatsDao.deleteExpired();

    // Delete expired hashtag stats (1 hour expiry)
    final expiredHashtagStatsDeleted = await hashtagStatsDao.deleteExpired();

    // Delete old notifications (7 day retention)
    final notificationCutoff =
        DateTime.now()
            .subtract(const Duration(days: _notificationRetentionDays))
            .millisecondsSinceEpoch ~/
        1000;
    final oldNotificationsDeleted = await notificationsDao.deleteOlderThan(
      notificationCutoff,
    );

    return CleanupResult(
      expiredEventsDeleted: expiredEventsDeleted,
      expiredProfileStatsDeleted: expiredProfileStatsDeleted,
      expiredHashtagStatsDeleted: expiredHashtagStatsDeleted,
      oldNotificationsDeleted: oldNotificationsDeleted,
    );
  }
}
