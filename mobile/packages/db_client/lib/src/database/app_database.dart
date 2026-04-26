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
    Drafts,
    Clips,
    DirectMessages,
    Conversations,
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
    DraftsDao,
    ClipsDao,
    DirectMessagesDao,
    ConversationsDao,
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

    // Check if pending_actions table exists, create if missing
    final pendingActionsResult = await customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' "
      "AND name='pending_actions'",
    ).get();

    if (pendingActionsResult.isEmpty) {
      await customStatement('''
        CREATE TABLE pending_actions (
          id TEXT NOT NULL PRIMARY KEY,
          type TEXT NOT NULL,
          target_id TEXT NOT NULL,
          author_pubkey TEXT,
          addressable_id TEXT,
          target_kind INTEGER,
          status TEXT NOT NULL,
          user_pubkey TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          retry_count INTEGER NOT NULL DEFAULT 0,
          last_error TEXT,
          last_attempt_at INTEGER
        )
      ''');
      await customStatement('''
        CREATE INDEX IF NOT EXISTS idx_pending_action_status
        ON pending_actions (status)
      ''');
      await customStatement('''
        CREATE INDEX IF NOT EXISTS idx_pending_action_user
        ON pending_actions (user_pubkey)
      ''');
      await customStatement('''
        CREATE INDEX IF NOT EXISTS idx_pending_action_user_status
        ON pending_actions (user_pubkey, status)
      ''');
      await customStatement('''
        CREATE INDEX IF NOT EXISTS idx_pending_action_created
        ON pending_actions (created_at)
      ''');
    }

    // Check if drafts table exists, create if missing
    final draftsResult = await customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' "
      "AND name='drafts'",
    ).get();

    if (draftsResult.isEmpty) {
      await customStatement('''
        CREATE TABLE drafts (
          id TEXT NOT NULL PRIMARY KEY,
          title TEXT NOT NULL DEFAULT '',
          description TEXT NOT NULL DEFAULT '',
          publish_status TEXT NOT NULL DEFAULT 'draft',
          publish_attempts INTEGER NOT NULL DEFAULT 0,
          publish_error TEXT,
          created_at INTEGER NOT NULL,
          last_modified INTEGER NOT NULL,
          data TEXT NOT NULL
        )
      ''');
      await customStatement('''
        CREATE INDEX IF NOT EXISTS idx_draft_publish_status
        ON drafts (publish_status)
      ''');
      await customStatement('''
        CREATE INDEX IF NOT EXISTS idx_draft_last_modified
        ON drafts (last_modified DESC)
      ''');
      await customStatement('''
        CREATE INDEX IF NOT EXISTS idx_draft_created_at
        ON drafts (created_at DESC)
      ''');
    }

    // Check if clips table exists, create if missing
    final clipsResult = await customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' "
      "AND name='clips'",
    ).get();

    if (clipsResult.isEmpty) {
      await customStatement('''
        CREATE TABLE clips (
          id TEXT NOT NULL PRIMARY KEY,
          draft_id TEXT,
          order_index INTEGER NOT NULL DEFAULT 0,
          duration_ms INTEGER NOT NULL,
          recorded_at INTEGER NOT NULL,
          data TEXT NOT NULL,
          FOREIGN KEY (draft_id) REFERENCES drafts(id) ON DELETE CASCADE
        )
      ''');
      await customStatement('''
        CREATE INDEX IF NOT EXISTS idx_clip_draft_id
        ON clips (draft_id)
      ''');
      await customStatement('''
        CREATE INDEX IF NOT EXISTS idx_clip_draft_order
        ON clips (draft_id, order_index)
      ''');
      await customStatement('''
        CREATE INDEX IF NOT EXISTS idx_clip_recorded_at
        ON clips (recorded_at DESC)
      ''');
    }

    // Create partial index unconditionally (for new and existing databases)
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_clip_library
      ON clips (draft_id) WHERE draft_id IS NULL
    ''');

    // Add file_path / thumbnail_path columns to clips (if missing)
    await _addColumnIfMissing('clips', 'file_path', 'TEXT');
    await _addColumnIfMissing('clips', 'thumbnail_path', 'TEXT');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_clip_file_path
      ON clips (file_path)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_clip_thumbnail_path
      ON clips (thumbnail_path)
    ''');

    // Add rendered_file_path / rendered_thumbnail_path to drafts (if missing)
    await _addColumnIfMissing('drafts', 'rendered_file_path', 'TEXT');
    await _addColumnIfMissing('drafts', 'rendered_thumbnail_path', 'TEXT');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_draft_rendered_file_path
      ON drafts (rendered_file_path)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_draft_rendered_thumbnail_path
      ON drafts (rendered_thumbnail_path)
    ''');

    // Add owner_pubkey columns for multi-account isolation
    await _addColumnIfMissing('drafts', 'owner_pubkey', 'TEXT');
    await _addColumnIfMissing('clips', 'owner_pubkey', 'TEXT');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_draft_owner_pubkey
      ON drafts (owner_pubkey)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_clip_owner_pubkey
      ON clips (owner_pubkey)
    ''');

    // Check if direct_messages table exists, create if missing
    final dmResult = await customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' "
      "AND name='direct_messages'",
    ).get();

    if (dmResult.isEmpty) {
      await customStatement('''
        CREATE TABLE direct_messages (
          id TEXT NOT NULL PRIMARY KEY,
          conversation_id TEXT NOT NULL,
          sender_pubkey TEXT NOT NULL,
          content TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          reply_to_id TEXT,
          gift_wrap_id TEXT NOT NULL,
          subject TEXT,
          tags_json TEXT,
          message_kind INTEGER NOT NULL DEFAULT 14,
          file_type TEXT,
          encryption_algorithm TEXT,
          decryption_key TEXT,
          decryption_nonce TEXT,
          file_hash TEXT,
          original_file_hash TEXT,
          file_size INTEGER,
          dimensions TEXT,
          blurhash TEXT,
          thumbnail_url TEXT
        )
      ''');
      await customStatement('''
        CREATE INDEX IF NOT EXISTS idx_dm_conversation_id
        ON direct_messages (conversation_id)
      ''');
      await customStatement('''
        CREATE INDEX IF NOT EXISTS idx_dm_conversation_created
        ON direct_messages (conversation_id, created_at DESC)
      ''');
      await customStatement('''
        CREATE UNIQUE INDEX IF NOT EXISTS idx_dm_gift_wrap_id
        ON direct_messages (gift_wrap_id)
      ''');
      await customStatement('''
        CREATE INDEX IF NOT EXISTS idx_dm_sender
        ON direct_messages (sender_pubkey)
      ''');
    }

    // Add Kind 15 file metadata columns to direct_messages (if missing)
    await _addColumnIfMissing(
      'direct_messages',
      'message_kind',
      'INTEGER NOT NULL DEFAULT 14',
    );
    await _addColumnIfMissing('direct_messages', 'file_type', 'TEXT');
    await _addColumnIfMissing(
      'direct_messages',
      'encryption_algorithm',
      'TEXT',
    );
    await _addColumnIfMissing('direct_messages', 'decryption_key', 'TEXT');
    await _addColumnIfMissing('direct_messages', 'decryption_nonce', 'TEXT');
    await _addColumnIfMissing('direct_messages', 'file_hash', 'TEXT');
    await _addColumnIfMissing('direct_messages', 'original_file_hash', 'TEXT');
    await _addColumnIfMissing('direct_messages', 'file_size', 'INTEGER');
    await _addColumnIfMissing('direct_messages', 'dimensions', 'TEXT');
    await _addColumnIfMissing('direct_messages', 'blurhash', 'TEXT');
    await _addColumnIfMissing('direct_messages', 'thumbnail_url', 'TEXT');
    await _addColumnIfMissing('direct_messages', 'tags_json', 'TEXT');

    // Check if conversations table exists, create if missing
    final convResult = await customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' "
      "AND name='conversations'",
    ).get();

    if (convResult.isEmpty) {
      await customStatement('''
        CREATE TABLE conversations (
          id TEXT NOT NULL PRIMARY KEY,
          participant_pubkeys TEXT NOT NULL,
          is_group INTEGER NOT NULL DEFAULT 0,
          last_message_content TEXT,
          last_message_timestamp INTEGER,
          last_message_sender_pubkey TEXT,
          subject TEXT,
          is_read INTEGER NOT NULL DEFAULT 1,
          current_user_has_sent INTEGER NOT NULL DEFAULT 0,
          created_at INTEGER NOT NULL
        )
      ''');
      await customStatement('''
        CREATE INDEX IF NOT EXISTS idx_conversation_last_message
        ON conversations (last_message_timestamp DESC)
      ''');
      await customStatement('''
        CREATE INDEX IF NOT EXISTS idx_conversation_is_read
        ON conversations (is_read)
      ''');
    }

    // Add current_user_has_sent column to existing conversations tables.
    await _addColumnIfMissing(
      'conversations',
      'current_user_has_sent',
      'INTEGER NOT NULL DEFAULT 0',
    );

    // Add owner_pubkey columns for multi-account DM isolation
    await _addColumnIfMissing('direct_messages', 'owner_pubkey', 'TEXT');
    await _addColumnIfMissing('conversations', 'owner_pubkey', 'TEXT');

    // Add dm_protocol column for NIP-04/NIP-17 protocol tracking
    await _addColumnIfMissing('conversations', 'dm_protocol', 'TEXT');

    // Add is_deleted column for NIP-09 kind 5 soft-delete support
    await _addColumnIfMissing(
      'direct_messages',
      'is_deleted',
      'INTEGER NOT NULL DEFAULT 0',
    );
    // Ensure the UNIQUE index on gift_wrap_id exists unconditionally.
    // It was originally inside the "if table missing" block, so databases
    // created by Drift's m.createAll() were missing it.
    await customStatement('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_dm_gift_wrap_id
      ON direct_messages (gift_wrap_id)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_dm_owner_pubkey
      ON direct_messages (owner_pubkey)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_dm_owner_conversation
      ON direct_messages (owner_pubkey, conversation_id, created_at DESC)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_conversation_owner_pubkey
      ON conversations (owner_pubkey)
    ''');

    // Populate new columns from existing JSON data blobs
    await _backfillFilePathColumns();
  }

  /// Adds a column to a table if it does not already exist.
  Future<void> _addColumnIfMissing(
    String table,
    String column,
    String type,
  ) async {
    final columns = await customSelect(
      'PRAGMA table_info($table)',
    ).get();
    final exists = columns.any(
      (row) => row.read<String>('name') == column,
    );
    if (!exists) {
      await customStatement('ALTER TABLE $table ADD COLUMN $column $type');
    }
  }

  /// Populates file_path / thumbnail_path columns from JSON data blobs
  /// for rows where they are still NULL.
  Future<void> _backfillFilePathColumns() async {
    // Clips: backfill file_path where missing
    await customStatement(r'''
      UPDATE clips
      SET file_path = json_extract(data, '$.filePath')
      WHERE file_path IS NULL
    ''');

    // Clips: backfill thumbnail_path where missing
    await customStatement(r'''
      UPDATE clips
      SET thumbnail_path = json_extract(data, '$.thumbnailPath')
      WHERE thumbnail_path IS NULL
    ''');

    // Drafts: backfill rendered_file_path where missing
    await customStatement(r'''
      UPDATE drafts
      SET rendered_file_path = json_extract(
            data, '$.finalRenderedClip.filePath'
          )
      WHERE rendered_file_path IS NULL
    ''');

    // Drafts: backfill rendered_thumbnail_path where missing
    await customStatement(r'''
      UPDATE drafts
      SET rendered_thumbnail_path = json_extract(
            data, '$.finalRenderedClip.thumbnailPath'
          )
      WHERE rendered_thumbnail_path IS NULL
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
