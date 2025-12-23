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
      await m.createAll();
    },
    beforeOpen: (details) async {
      // Run cleanup of expired data on every app startup
      await runStartupCleanup();
    },
    onUpgrade: _schemaUpgrade,
  );

  /// Runs cleanup of expired data from all tables.
  ///
  /// This method should be called during app startup to remove:
  /// - Expired Nostr events (based on expire_at timestamp)
  /// - Expired profile stats (older than 5 minutes)
  /// - Expired hashtag stats (older than 1 hour)
  /// - Old notifications (older than 7 days)
  ///
  /// Returns a [CleanupResult] with counts of deleted records.
  ///
  /// Note: This method handles cases where tables may not exist during
  /// migrations from older schema versions.
  Future<CleanupResult> runStartupCleanup() async {
    // Delete expired Nostr events
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
    },
  );
}
