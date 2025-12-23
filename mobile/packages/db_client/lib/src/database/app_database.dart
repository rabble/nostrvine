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
    // Delete expired events - safe since DAO checks hasExpireAtColumn
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
