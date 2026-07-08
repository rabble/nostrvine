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
    DmMessageReactions,
    Conversations,
    OutgoingDms,
    PendingViewEvents,
    PendingProductEvents,
    PendingGiftWraps,
    ProcessedGiftWraps,
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
    DmReactionsDao,
    ConversationsDao,
    OutgoingDmsDao,
    PendingViewEventsDao,
    PendingProductEventsDao,
    PendingGiftWrapsDao,
    ProcessedGiftWrapsDao,
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

    // Add indexed draft-owned file reference columns (if missing)
    await _addColumnIfMissing('drafts', 'rendered_file_path', 'TEXT');
    await _addColumnIfMissing('drafts', 'rendered_thumbnail_path', 'TEXT');
    await _addColumnIfMissing('drafts', 'custom_thumbnail_path', 'TEXT');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_draft_rendered_file_path
      ON drafts (rendered_file_path)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_draft_rendered_thumbnail_path
      ON drafts (rendered_thumbnail_path)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_draft_custom_thumbnail_path
      ON drafts (custom_thumbnail_path)
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

    // Soft-delete marker for clip trash bin. NULL = active; non-NULL =
    // trashed at that timestamp. Purged after the retention window.
    await _addColumnIfMissing('clips', 'deleted_at', 'INTEGER');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_clip_deleted_at
      ON clips (deleted_at)
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

    // Add last_read_timestamp read cursor for cross-device read-state sync
    // (#4977). Backfill already-read rows once so the upgrade doesn't surface
    // a one-time unread bump. The WHERE clause makes it self-idempotent: once
    // a row has a non-null cursor (set here or by markAsRead) it is skipped on
    // subsequent launches.
    await _addColumnIfMissing(
      'conversations',
      'last_read_timestamp',
      'INTEGER',
    );
    await customStatement(
      'UPDATE conversations SET last_read_timestamp = last_message_timestamp '
      'WHERE last_read_timestamp IS NULL AND is_read = 1 '
      'AND last_message_timestamp IS NOT NULL',
    );

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

    // Check if outgoing_dms table exists, create if missing.
    // Added for #3909 (durable outgoing-DM queue + self-wrap retry).
    // Schema version stays at 1 — same runtime CREATE-IF-NOT-EXISTS
    // pattern as personal_reposts and nip05_verifications above.
    final outgoingDmsResult = await customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' "
      "AND name='outgoing_dms'",
    ).get();

    if (outgoingDmsResult.isEmpty) {
      await customStatement('''
        CREATE TABLE outgoing_dms (
          id TEXT NOT NULL PRIMARY KEY,
          conversation_id TEXT NOT NULL,
          recipient_pubkey TEXT NOT NULL,
          content TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          rumor_event_json TEXT NOT NULL,
          message_kind INTEGER NOT NULL DEFAULT 14,
          reply_to_id TEXT,
          recipient_wrap_status TEXT NOT NULL,
          self_wrap_status TEXT NOT NULL,
          recipient_wrap_event_id TEXT,
          self_wrap_event_id TEXT,
          retry_count INTEGER NOT NULL DEFAULT 0,
          recipient_wrap_last_error TEXT,
          self_wrap_last_error TEXT,
          last_attempt_at INTEGER,
          queued_at INTEGER NOT NULL,
          owner_pubkey TEXT NOT NULL
        )
      ''');
    }
    // Create indexes unconditionally (for new and existing databases).
    // Drift's `m.createAll()` doesn't register the `List<Index> get
    // indexes` getter on `OutgoingDms` (the project doesn't wire them
    // through `@DriftDatabase(indexes: ...)`), so a Drift-created fresh
    // install would otherwise have the table but none of its indexes,
    // and `getRetryableForOwner` / `getStillPendingForOwner` would fall
    // back to a full table scan. Hoisting the CREATE INDEX statements
    // outside the "if table missing" block makes the runtime path the
    // single source of truth for the index set on both new and existing
    // databases — and makes the fresh-install vs runtime-create paths
    // emit identical schemas, which the schema-parity test in
    // `app_database_test.dart` pins.
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_outgoing_dms_owner_conversation
      ON outgoing_dms (owner_pubkey, conversation_id, created_at DESC)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_outgoing_dms_owner_recipient_status
      ON outgoing_dms (owner_pubkey, recipient_wrap_status)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_outgoing_dms_owner_self_status
      ON outgoing_dms (owner_pubkey, self_wrap_status)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_outgoing_dms_queued_at
      ON outgoing_dms (queued_at)
    ''');

    // Check if dm_message_reactions table exists, create if missing.
    // Added for #4633 (DM emoji reactions). Schema version stays at 1 —
    // same runtime CREATE-IF-NOT-EXISTS pattern as outgoing_dms above.
    final dmReactionsResult = await customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' "
      "AND name='dm_message_reactions'",
    ).get();

    if (dmReactionsResult.isEmpty) {
      await customStatement('''
        CREATE TABLE dm_message_reactions (
          id TEXT NOT NULL,
          conversation_id TEXT NOT NULL,
          target_message_id TEXT NOT NULL,
          target_message_author TEXT NOT NULL,
          reactor_pubkey TEXT NOT NULL,
          emoji TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          gift_wrap_id TEXT,
          owner_pubkey TEXT NOT NULL,
          is_deleted INTEGER NOT NULL DEFAULT 0,
          rumor_event_json TEXT,
          publish_status TEXT,
          PRIMARY KEY (id, owner_pubkey)
        )
      ''');
    }
    // Create indexes unconditionally so the runtime path matches Drift's
    // m.createAll() output (the dm_message_reactions schema-parity test in
    // app_database_test.dart pins this).
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_dm_reactions_target_live
      ON dm_message_reactions (conversation_id, target_message_id)
      WHERE is_deleted = 0
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_dm_reactions_reactor
      ON dm_message_reactions (target_message_id, reactor_pubkey)
      WHERE is_deleted = 0
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_dm_reactions_owner_created
      ON dm_message_reactions (owner_pubkey, created_at)
    ''');

    // Cap-at-one storage invariant (#5419): at most one LIVE reaction per
    // (target_message_id, reactor_pubkey, owner_pubkey). The dedup UPDATE
    // MUST run before CREATE UNIQUE INDEX — SQLite refuses to build a unique
    // index over rows that already violate it. It soft-deletes every live row
    // that has a strictly-newer live sibling in its tuple, keeping the single
    // MAX(created_at, id) row. The created_at half matches the read-side
    // DmReactionsRepository._collapsePerReactor keep-rule; the id tie-break is
    // an extra deterministic guard the read side lacks, and only diverges on
    // equal-created_at distinct ids — impossible once the unique index caps
    // each tuple to one live row. The statement is idempotent: once converged
    // (and once the unique index self-enforces) no row has a newer sibling, so
    // subsequent startups match nothing.
    await customStatement('''
      UPDATE dm_message_reactions
      SET is_deleted = 1
      WHERE is_deleted = 0
        AND EXISTS (
          SELECT 1 FROM dm_message_reactions AS newer
          WHERE newer.target_message_id = dm_message_reactions.target_message_id
            AND newer.reactor_pubkey = dm_message_reactions.reactor_pubkey
            AND newer.owner_pubkey = dm_message_reactions.owner_pubkey
            AND newer.is_deleted = 0
            AND (newer.created_at > dm_message_reactions.created_at
              OR (newer.created_at = dm_message_reactions.created_at
                  AND newer.id > dm_message_reactions.id))
        )
    ''');
    await customStatement('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_dm_reactions_unique_live
      ON dm_message_reactions (target_message_id, reactor_pubkey, owner_pubkey)
      WHERE is_deleted = 0
    ''');

    final pendingViewEventsResult = await customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' "
      "AND name='pending_view_events'",
    ).get();

    if (pendingViewEventsResult.isEmpty) {
      await customStatement('''
        CREATE TABLE pending_view_events (
          id TEXT NOT NULL PRIMARY KEY,
          video_id TEXT NOT NULL,
          video_pubkey TEXT NOT NULL,
          video_vine_id TEXT,
          user_pubkey TEXT NOT NULL,
          watch_duration_ms INTEGER NOT NULL,
          total_duration_ms INTEGER,
          loop_count INTEGER,
          traffic_source TEXT NOT NULL,
          source_detail TEXT,
          status TEXT NOT NULL,
          retry_count INTEGER NOT NULL DEFAULT 0,
          last_error TEXT,
          last_attempt_at INTEGER,
          created_at INTEGER NOT NULL
        )
      ''');
    }
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_pending_view_events_user_status
      ON pending_view_events (user_pubkey, status)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_pending_view_events_created_at
      ON pending_view_events (created_at)
    ''');

    final pendingProductEventsResult = await customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' "
      "AND name='pending_product_events'",
    ).get();

    if (pendingProductEventsResult.isEmpty) {
      await customStatement('''
        CREATE TABLE pending_product_events (
          id TEXT NOT NULL PRIMARY KEY,
          event_name TEXT NOT NULL,
          payload_json TEXT NOT NULL,
          status TEXT NOT NULL,
          attempt_count INTEGER NOT NULL DEFAULT 0,
          next_attempt_at INTEGER,
          last_error TEXT,
          created_at INTEGER NOT NULL
        )
      ''');
    }
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_pending_product_events_status_next_attempt
      ON pending_product_events (status, next_attempt_at)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_pending_product_events_created_at
      ON pending_product_events (created_at)
    ''');

    // Check if pending_gift_wraps table exists, create if missing.
    // Added for #5202 (durable failed-decrypt gift-wrap retry queue).
    // Schema version stays at 1 — same runtime CREATE-IF-NOT-EXISTS pattern
    // as outgoing_dms / pending_view_events above.
    final pendingGiftWrapsResult = await customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' "
      "AND name='pending_gift_wraps'",
    ).get();

    if (pendingGiftWrapsResult.isEmpty) {
      await customStatement('''
        CREATE TABLE pending_gift_wraps (
          gift_wrap_id TEXT NOT NULL,
          owner_pubkey TEXT NOT NULL,
          raw_json TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          attempts INTEGER NOT NULL DEFAULT 0,
          last_attempt_at INTEGER,
          PRIMARY KEY (gift_wrap_id, owner_pubkey)
        )
      ''');
    }
    // Create the index unconditionally so the runtime path matches Drift's
    // m.createAll() output (the schema-parity test pins this).
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_pending_gift_wraps_owner_attempts
      ON pending_gift_wraps (owner_pubkey, attempts)
    ''');

    // Check if processed_gift_wraps table exists, create if missing.
    // Added for #5452 (dedup ledger so DM reaction/deletion gift wraps are not
    // re-decrypted on every launch). Schema version stays at 1 — same runtime
    // CREATE-IF-NOT-EXISTS pattern as pending_gift_wraps above. No index: the
    // only access is a primary-key lookup on gift_wrap_id.
    final processedGiftWrapsResult = await customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' "
      "AND name='processed_gift_wraps'",
    ).get();

    if (processedGiftWrapsResult.isEmpty) {
      await customStatement('''
        CREATE TABLE processed_gift_wraps (
          gift_wrap_id TEXT NOT NULL,
          processed_at INTEGER NOT NULL,
          owner_pubkey TEXT,
          PRIMARY KEY (gift_wrap_id)
        )
      ''');
    }

    // Denormalized NIP-33 d-tag column so replaceable-event upserts can use
    // an indexed lookup instead of decoding the tags JSON of every
    // (pubkey, kind) row (on-device profiling: ~23% of main-isolate CPU).
    await _addColumnIfMissing('event', 'd_tag', 'TEXT');

    // Create the event indexes unconditionally. The `List<Index> get
    // indexes` getter on NostrEvents is not wired through
    // `@DriftDatabase(...)`, so Drift's m.createAll() never creates them —
    // this runtime path is the source of truth for the index set (same
    // pattern as outgoing_dms above; keep in sync with tables.dart).
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_event_kind_created_at
      ON event (kind, created_at)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_event_pubkey_created_at
      ON event (pubkey, created_at)
    ''');
    // The trailing created_at makes the replaceable-upsert MAX(created_at)
    // lookup a covering-index seek; without it SQLite's min/max
    // optimization picks idx_event_kind_created_at and reverse-scans the
    // kind partition (PR #5957 review). The DROP cleans up the narrower
    // predecessor index from pre-release builds of this change.
    await customStatement('DROP INDEX IF EXISTS idx_event_pubkey_kind_d_tag');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_event_pubkey_kind_d_tag_created_at
      ON event (pubkey, kind, d_tag, created_at)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_event_created_at
      ON event (created_at)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_event_expire_at
      ON event (expire_at)
    ''');

    // Populate new columns from existing JSON data blobs
    await _backfillFilePathColumns();
    await _backfillEventDTagColumn();
  }

  /// Adds a column to a table if it does not already exist.
  Future<void> _addColumnIfMissing(
    String table,
    String column,
    String type,
  ) async {
    final columns = await customSelect('PRAGMA table_info($table)').get();
    final exists = columns.any((row) => row.read<String>('name') == column);
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

    // Drafts: backfill custom_thumbnail_path where missing
    await customStatement(r'''
      UPDATE drafts
      SET custom_thumbnail_path = json_extract(data, '$.customThumbnailPath')
      WHERE custom_thumbnail_path IS NULL
    ''');
  }

  /// Populates the denormalized d_tag column for parameterized replaceable
  /// events (kind 30000-39999) that were written before the column existed.
  ///
  /// Matches NostrEventsDao's d-tag semantics: the value of the first 'd'
  /// tag, '' when the tag has no value or the event has no d-tag (NIP-01).
  /// Idempotent — once a row has a non-NULL d_tag it is skipped.
  Future<void> _backfillEventDTagColumn() async {
    await customStatement(r'''
      UPDATE event
      SET d_tag = COALESCE(
        (
          SELECT COALESCE(json_extract(tag.value, '$[1]'), '')
          FROM json_each(event.tags) AS tag
          WHERE json_extract(tag.value, '$[0]') = 'd'
          ORDER BY tag.key
          LIMIT 1
        ),
        ''
      )
      WHERE d_tag IS NULL AND kind >= 30000 AND kind < 40000
    ''');
  }

  /// Runs cleanup of expired data from all tables.
  ///
  /// This method should be called during app startup to remove:
  /// - Expired Nostr events (based on expire_at timestamp, including NULL)
  /// - Expired profile stats (older than 5 minutes)
  /// - Expired hashtag stats (older than 1 hour)
  /// - Notification cache rows written more than 7 days ago
  ///
  /// Returns a [CleanupResult] with counts of deleted records.
  Future<CleanupResult> runStartupCleanup() async {
    // Delete expired events (also deletes events with NULL expire_at)
    final expiredEventsDeleted = await nostrEventsDao.deleteExpiredEvents(null);

    // Delete expired profile stats (5 minute expiry)
    final expiredProfileStatsDeleted = await profileStatsDao.deleteExpired();

    // Delete expired hashtag stats (1 hour expiry)
    final expiredHashtagStatsDeleted = await hashtagStatsDao.deleteExpired();

    // Delete notification cache rows written more than 7 days ago. Retention
    // is keyed on when the row was cached, not the notification's own age, so
    // still-current notifications about older events survive to hydrate the
    // next cold start.
    final notificationCutoff = DateTime.now().subtract(
      const Duration(days: _notificationRetentionDays),
    );
    final oldNotificationsDeleted = await notificationsDao.deleteCachedBefore(
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
