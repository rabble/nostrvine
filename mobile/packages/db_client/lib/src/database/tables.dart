// ABOUTME: Drift table definitions for OpenVine's shared Nostr database.
// ABOUTME: Defines tables for events, profiles, metrics, stats,
// ABOUTME: notifications, and uploads.

import 'package:drift/drift.dart';

/// Nostr events table storing all cached events from relays.
///
/// Contains all Nostr events including video events (kind 34236), profiles
/// (kind 0), reactions (kind 7), etc.
@DataClassName('NostrEventRow')
class NostrEvents extends Table {
  @override
  String get tableName => 'event';

  TextColumn get id => text()();
  TextColumn get pubkey => text()();
  IntColumn get createdAt => integer().named('created_at')();
  IntColumn get kind => integer()();
  TextColumn get tags => text()(); // JSON-encoded array
  TextColumn get content => text()();
  TextColumn get sig => text()();
  TextColumn get sources => text().nullable()(); // JSON-encoded array

  /// Unix timestamp when this cached event should be considered expired.
  /// Null means the event never expires. Used for cache eviction.
  IntColumn get expireAt => integer().nullable().named('expire_at')();

  @override
  Set<Column> get primaryKey => {id};

  List<Index> get indexes => [
    // Index on kind for filtering video events (kind IN (34236, 6))
    Index(
      'idx_event_kind',
      'CREATE INDEX IF NOT EXISTS idx_event_kind ON event (kind)',
    ),

    // Index on created_at for sorting by timestamp (ORDER BY created_at DESC)
    Index(
      'idx_event_created_at',
      'CREATE INDEX IF NOT EXISTS idx_event_created_at '
          'ON event (created_at)',
    ),

    // Composite index for optimal video queries
    // (WHERE kind = ? ORDER BY created_at DESC)
    Index(
      'idx_event_kind_created_at',
      'CREATE INDEX IF NOT EXISTS idx_event_kind_created_at '
          'ON event (kind, created_at)',
    ),

    // Index on pubkey for author queries (WHERE pubkey = ?)
    Index(
      'idx_event_pubkey',
      'CREATE INDEX IF NOT EXISTS idx_event_pubkey ON event (pubkey)',
    ),

    // Composite index for profile page video queries
    // (WHERE kind = ? AND pubkey = ?)
    Index(
      'idx_event_kind_pubkey',
      'CREATE INDEX IF NOT EXISTS idx_event_kind_pubkey '
          'ON event (kind, pubkey)',
    ),

    // Composite index for author video timeline
    // (WHERE pubkey = ? ORDER BY created_at DESC)
    Index(
      'idx_event_pubkey_created_at',
      'CREATE INDEX IF NOT EXISTS idx_event_pubkey_created_at '
          'ON event (pubkey, created_at)',
    ),

    // Index on expire_at for cache eviction queries
    // (WHERE expire_at IS NOT NULL AND expire_at < ?)
    Index(
      'idx_event_expire_at',
      'CREATE INDEX IF NOT EXISTS idx_event_expire_at ON event (expire_at)',
    ),
  ];
}

/// Denormalized cache of user profiles extracted from kind 0 events
///
/// Profiles are parsed from kind 0 events and stored here for fast reactive
/// queries.
/// This avoids having to parse JSON for every profile display.
@DataClassName('UserProfileRow')
class UserProfiles extends Table {
  @override
  String get tableName => 'user_profiles';

  TextColumn get pubkey => text()();
  TextColumn get displayName => text().nullable().named('display_name')();
  TextColumn get name => text().nullable()();
  TextColumn get about => text().nullable()();
  TextColumn get picture => text().nullable()();
  TextColumn get banner => text().nullable()();
  TextColumn get website => text().nullable()();
  TextColumn get nip05 => text().nullable()();
  TextColumn get lud16 => text().nullable()();
  TextColumn get lud06 => text().nullable()();
  TextColumn get rawData =>
      text().nullable().named('raw_data')(); // JSON-encoded map
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  TextColumn get eventId => text().named('event_id')();
  DateTimeColumn get lastFetched => dateTime().named('last_fetched')();

  @override
  Set<Column> get primaryKey => {pubkey};
}

/// Denormalized cache of video engagement metrics extracted from video
/// event tags.
///
/// Metrics are parsed from video events (kind 34236, etc.) and stored here
/// for fast sorted queries. This avoids having to parse JSON tags for every
/// sort/filter operation.
@DataClassName('VideoMetricRow')
class VideoMetrics extends Table {
  @override
  String get tableName => 'video_metrics';

  TextColumn get eventId => text().named('event_id')();
  IntColumn get loopCount => integer().nullable().named('loop_count')();
  IntColumn get likes => integer().nullable()();
  IntColumn get views => integer().nullable()();
  IntColumn get comments => integer().nullable()();
  RealColumn get avgCompletion => real().nullable().named('avg_completion')();
  IntColumn get hasProofmode => integer().nullable().named('has_proofmode')();
  IntColumn get hasDeviceAttestation =>
      integer().nullable().named('has_device_attestation')();
  IntColumn get hasPgpSignature =>
      integer().nullable().named('has_pgp_signature')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  @override
  Set<Column> get primaryKey => {eventId};

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (event_id) REFERENCES event(id) ON DELETE CASCADE',
  ];

  List<Index> get indexes => [
    // Index on loop_count for trending/popular queries
    // (ORDER BY loop_count DESC)
    Index(
      'idx_metrics_loop_count',
      'CREATE INDEX IF NOT EXISTS idx_metrics_loop_count '
          'ON video_metrics (loop_count)',
    ),

    // Index on likes for sorting by popularity (ORDER BY likes DESC)
    Index(
      'idx_metrics_likes',
      'CREATE INDEX IF NOT EXISTS idx_metrics_likes ON video_metrics (likes)',
    ),

    // Index on views for sorting by view count (ORDER BY views DESC)
    Index(
      'idx_metrics_views',
      'CREATE INDEX IF NOT EXISTS idx_metrics_views ON video_metrics (views)',
    ),
  ];
}

/// Cache of profile statistics (followers, following, video counts, etc.)
///
/// Stores aggregated stats for user profiles with a 5-minute expiry.
@DataClassName('ProfileStatRow')
class ProfileStats extends Table {
  @override
  String get tableName => 'profile_statistics';

  TextColumn get pubkey => text()();
  IntColumn get videoCount => integer().nullable().named('video_count')();
  IntColumn get followerCount => integer().nullable().named('follower_count')();
  IntColumn get followingCount =>
      integer().nullable().named('following_count')();
  IntColumn get totalViews => integer().nullable().named('total_views')();
  IntColumn get totalLikes => integer().nullable().named('total_likes')();
  DateTimeColumn get cachedAt => dateTime().named('cached_at')();

  @override
  Set<Column> get primaryKey => {pubkey};
}

/// Cache of trending/popular hashtags
///
/// Stores hashtag statistics with a 1-hour expiry.
@DataClassName('HashtagStatRow')
class HashtagStats extends Table {
  @override
  String get tableName => 'hashtag_stats';

  TextColumn get hashtag => text()();
  IntColumn get videoCount => integer().nullable().named('video_count')();
  IntColumn get totalViews => integer().nullable().named('total_views')();
  IntColumn get totalLikes => integer().nullable().named('total_likes')();
  DateTimeColumn get cachedAt => dateTime().named('cached_at')();

  @override
  Set<Column> get primaryKey => {hashtag};

  List<Index> get indexes => [
    Index(
      'idx_hashtag_video_count',
      'CREATE INDEX IF NOT EXISTS idx_hashtag_video_count '
          'ON hashtag_stats (video_count DESC)',
    ),
  ];
}

/// Persistent storage for notifications
///
/// Stores notification metadata for offline access.
@DataClassName('NotificationRow')
class Notifications extends Table {
  @override
  String get tableName => 'notifications';

  TextColumn get id => text()();
  TextColumn get type => text()(); // like, repost, follow, comment, mention
  TextColumn get fromPubkey => text().named('from_pubkey')();
  TextColumn get targetEventId => text().nullable().named('target_event_id')();
  TextColumn get targetPubkey => text().nullable().named('target_pubkey')();
  TextColumn get content => text().nullable()();
  IntColumn get timestamp => integer()(); // Unix timestamp
  BoolColumn get isRead => boolean().withDefault(const Constant(false))();
  DateTimeColumn get cachedAt => dateTime().named('cached_at')();

  @override
  Set<Column> get primaryKey => {id};

  List<Index> get indexes => [
    Index(
      'idx_notification_timestamp',
      'CREATE INDEX IF NOT EXISTS idx_notification_timestamp '
          'ON notifications (timestamp DESC)',
    ),
    Index(
      'idx_notification_is_read',
      'CREATE INDEX IF NOT EXISTS idx_notification_is_read '
          'ON notifications (is_read)',
    ),
  ];
}

/// Tracks video uploads in progress
///
/// Stores pending upload state for resumption after app restart.
@DataClassName('PendingUploadRow')
class PendingUploads extends Table {
  @override
  String get tableName => 'pending_uploads';

  TextColumn get id => text()();
  TextColumn get localVideoPath => text().named('local_video_path')();
  TextColumn get nostrPubkey => text().named('nostr_pubkey')();
  TextColumn get status => text()(); // pending, uploading, processing, etc.
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  TextColumn get cloudinaryPublicId =>
      text().nullable().named('cloudinary_public_id')();
  TextColumn get videoId => text().nullable().named('video_id')();
  TextColumn get cdnUrl => text().nullable().named('cdn_url')();
  TextColumn get errorMessage => text().nullable().named('error_message')();
  RealColumn get uploadProgress =>
      real().nullable().named('upload_progress')(); // 0.0 to 1.0
  TextColumn get thumbnailPath => text().nullable().named('thumbnail_path')();
  TextColumn get title => text().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get hashtags =>
      text().nullable()(); // JSON-encoded array of strings
  TextColumn get nostrEventId => text().nullable().named('nostr_event_id')();
  DateTimeColumn get completedAt =>
      dateTime().nullable().named('completed_at')();
  IntColumn get retryCount =>
      integer().withDefault(const Constant(0)).named('retry_count')();
  IntColumn get videoWidth => integer().nullable().named('video_width')();
  IntColumn get videoHeight => integer().nullable().named('video_height')();
  IntColumn get videoDurationMillis =>
      integer().nullable().named('video_duration_millis')();
  TextColumn get proofManifestJson =>
      text().nullable().named('proof_manifest_json')();
  TextColumn get streamingMp4Url =>
      text().nullable().named('streaming_mp4_url')();
  TextColumn get streamingHlsUrl =>
      text().nullable().named('streaming_hls_url')();
  TextColumn get fallbackUrl => text().nullable().named('fallback_url')();

  @override
  Set<Column> get primaryKey => {id};

  List<Index> get indexes => [
    Index(
      'idx_pending_upload_status',
      'CREATE INDEX IF NOT EXISTS idx_pending_upload_status '
          'ON pending_uploads (status)',
    ),
    Index(
      'idx_pending_upload_created',
      'CREATE INDEX IF NOT EXISTS idx_pending_upload_created '
          'ON pending_uploads (created_at DESC)',
    ),
  ];
}

/// Stores the current user's own reaction events (Kind 7 likes).
///
/// This table tracks the mapping between target events (videos) and the
/// user's reaction event IDs. This mapping is essential for unlikes, which
/// require the reaction event ID to create a Kind 5 deletion event.
///
/// Only stores reactions created by the current user, not reactions from
/// others.
@DataClassName('PersonalReactionRow')
class PersonalReactions extends Table {
  @override
  String get tableName => 'personal_reactions';

  /// The event ID that was liked (e.g., video event ID)
  TextColumn get targetEventId => text().named('target_event_id')();

  /// The Kind 7 reaction event ID created by the user
  TextColumn get reactionEventId => text().named('reaction_event_id')();

  /// The pubkey of the user who created this reaction
  TextColumn get userPubkey => text().named('user_pubkey')();

  /// Unix timestamp when the reaction was created
  IntColumn get createdAt => integer().named('created_at')();

  @override
  Set<Column> get primaryKey => {targetEventId, userPubkey};

  List<Index> get indexes => [
    // Index on user_pubkey for fetching all user's reactions
    Index(
      'idx_personal_reactions_user',
      'CREATE INDEX IF NOT EXISTS idx_personal_reactions_user '
          'ON personal_reactions (user_pubkey)',
    ),
    // Index on reaction_event_id for lookups when processing deletions
    Index(
      'idx_personal_reactions_reaction_id',
      'CREATE INDEX IF NOT EXISTS idx_personal_reactions_reaction_id '
          'ON personal_reactions (reaction_event_id)',
    ),
  ];
}

/// Stores pending offline actions (likes, reposts, follows) for sync on
/// reconnect.
///
/// When the user performs a social action while offline, it's queued here
/// and synced when connectivity is restored.
@DataClassName('PendingActionRow')
class PendingActions extends Table {
  @override
  String get tableName => 'pending_actions';

  /// Unique identifier for this action
  TextColumn get id => text()();

  /// Type of action: like, unlike, repost, unrepost, follow, unfollow
  TextColumn get type => text()();

  /// Target event ID (for likes/reposts) or pubkey (for follows)
  TextColumn get targetId => text().named('target_id')();

  /// Pubkey of the original event author (for likes/reposts)
  TextColumn get authorPubkey => text().nullable().named('author_pubkey')();

  /// Addressable ID for reposts (format: "kind:pubkey:d-tag")
  TextColumn get addressableId => text().nullable().named('addressable_id')();

  /// Kind of the target event (e.g., 34236 for videos)
  IntColumn get targetKind => integer().nullable().named('target_kind')();

  /// Current sync status: pending, syncing, completed, failed
  TextColumn get status => text()();

  /// The pubkey of the user who queued this action
  TextColumn get userPubkey => text().named('user_pubkey')();

  /// When the action was queued
  DateTimeColumn get createdAt => dateTime().named('created_at')();

  /// Number of sync attempts
  IntColumn get retryCount =>
      integer().withDefault(const Constant(0)).named('retry_count')();

  /// Last error message if sync failed
  TextColumn get lastError => text().nullable().named('last_error')();

  /// Timestamp of last sync attempt
  DateTimeColumn get lastAttemptAt =>
      dateTime().nullable().named('last_attempt_at')();

  @override
  Set<Column> get primaryKey => {id};

  List<Index> get indexes => [
    // Index on status for fetching pending actions
    Index(
      'idx_pending_action_status',
      'CREATE INDEX IF NOT EXISTS idx_pending_action_status '
          'ON pending_actions (status)',
    ),
    // Index on user_pubkey for user-specific queries
    Index(
      'idx_pending_action_user',
      'CREATE INDEX IF NOT EXISTS idx_pending_action_user '
          'ON pending_actions (user_pubkey)',
    ),
    // Composite index for user + status
    Index(
      'idx_pending_action_user_status',
      'CREATE INDEX IF NOT EXISTS idx_pending_action_user_status '
          'ON pending_actions (user_pubkey, status)',
    ),
    // Index on created_at for ordering
    Index(
      'idx_pending_action_created',
      'CREATE INDEX IF NOT EXISTS idx_pending_action_created '
          'ON pending_actions (created_at)',
    ),
  ];
}

/// Cache of NIP-05 verification results.
///
/// Stores the verification status of NIP-05 addresses for user profiles.
/// Uses TTL-based expiration:
/// - verified: 24 hours (stable, rarely changes)
/// - failed: 1 hour (allow retry for transient issues)
/// - error: 5 minutes (network issues, retry soon)
@DataClassName('Nip05VerificationRow')
class Nip05Verifications extends Table {
  @override
  String get tableName => 'nip05_verifications';

  /// The pubkey of the user whose NIP-05 is being verified
  TextColumn get pubkey => text()();

  /// The claimed NIP-05 address (e.g., "alice@example.com")
  TextColumn get nip05 => text()();

  /// Verification status: 'verified', 'failed', 'error', 'pending'
  TextColumn get status => text()();

  /// When the verification was performed
  DateTimeColumn get verifiedAt => dateTime().named('verified_at')();

  /// When this cache entry expires (TTL-based)
  DateTimeColumn get expiresAt => dateTime().named('expires_at')();

  @override
  Set<Column> get primaryKey => {pubkey};

  List<Index> get indexes => [
    // Index on expires_at for cache eviction queries
    Index(
      'idx_nip05_expires_at',
      'CREATE INDEX IF NOT EXISTS idx_nip05_expires_at '
          'ON nip05_verifications (expires_at)',
    ),
  ];
}

/// Persistent storage for video drafts
///
/// Stores draft metadata and full serialized JSON for offline access.
/// Key fields are indexed columns for efficient queries; the full draft
/// payload (clips, editor state, etc.) lives in the [data] JSON blob.
@DataClassName('DraftRow')
class Drafts extends Table {
  @override
  String get tableName => 'drafts';

  /// Unique draft identifier (e.g. "draft_1700000000000")
  TextColumn get id => text()();

  /// User-provided title (may be empty)
  TextColumn get title => text().withDefault(const Constant(''))();

  /// User-provided description (may be empty)
  TextColumn get description => text().withDefault(const Constant(''))();

  /// Current publish status: draft, publishing, failed, published
  TextColumn get publishStatus =>
      text().withDefault(const Constant('draft')).named('publish_status')();

  /// Number of publish attempts
  IntColumn get publishAttempts =>
      integer().withDefault(const Constant(0)).named('publish_attempts')();

  /// Last publish error message
  TextColumn get publishError => text().nullable().named('publish_error')();

  /// When the draft was originally created
  DateTimeColumn get createdAt => dateTime().named('created_at')();

  /// When the draft was last modified
  DateTimeColumn get lastModified => dateTime().named('last_modified')();

  /// Full JSON-serialized draft payload (clips, hashtags, editor state, etc.)
  TextColumn get data => text()();

  /// Basename of the final rendered video file (for indexed lookups)
  TextColumn get renderedFilePath =>
      text().nullable().named('rendered_file_path')();

  /// Basename of the final rendered thumbnail (for indexed lookups)
  TextColumn get renderedThumbnailPath =>
      text().nullable().named('rendered_thumbnail_path')();

  /// Hex public key of the account that owns this draft.
  /// NULL for legacy drafts created before multi-account support.
  TextColumn get ownerPubkey => text().nullable().named('owner_pubkey')();

  @override
  Set<Column> get primaryKey => {id};

  List<Index> get indexes => [
    Index(
      'idx_draft_owner_pubkey',
      'CREATE INDEX IF NOT EXISTS idx_draft_owner_pubkey '
          'ON drafts (owner_pubkey)',
    ),
    Index(
      'idx_draft_publish_status',
      'CREATE INDEX IF NOT EXISTS idx_draft_publish_status '
          'ON drafts (publish_status)',
    ),
    Index(
      'idx_draft_last_modified',
      'CREATE INDEX IF NOT EXISTS idx_draft_last_modified '
          'ON drafts (last_modified DESC)',
    ),
    Index(
      'idx_draft_created_at',
      'CREATE INDEX IF NOT EXISTS idx_draft_created_at '
          'ON drafts (created_at DESC)',
    ),
    Index(
      'idx_draft_rendered_file_path',
      'CREATE INDEX IF NOT EXISTS idx_draft_rendered_file_path '
          'ON drafts (rendered_file_path)',
    ),
    Index(
      'idx_draft_rendered_thumbnail_path',
      'CREATE INDEX IF NOT EXISTS idx_draft_rendered_thumbnail_path '
          'ON drafts (rendered_thumbnail_path)',
    ),
  ];
}

/// Persistent storage for video clips belonging to drafts
///
/// Each clip is a recorded video segment that belongs to a single draft.
/// Key fields are indexed columns for efficient queries; the full clip
/// payload (lens metadata, thumbnail info, etc.) lives in the [data]
/// JSON blob.
@DataClassName('ClipRow')
class Clips extends Table {
  @override
  String get tableName => 'clips';

  /// Unique clip identifier
  TextColumn get id => text()();

  /// Foreign key to the parent draft (null for library clips)
  TextColumn get draftId => text().nullable().named('draft_id')();

  /// Position of this clip within the draft (0-based)
  IntColumn get orderIndex =>
      integer().withDefault(const Constant(0)).named('order_index')();

  /// Duration in milliseconds
  IntColumn get durationMs => integer().named('duration_ms')();

  /// When the clip was recorded
  DateTimeColumn get recordedAt => dateTime().named('recorded_at')();

  /// Full JSON-serialized clip payload (file path, thumbnail, lens metadata,
  /// aspect ratio, etc.)
  TextColumn get data => text()();

  /// Basename of the video file (for indexed lookups)
  TextColumn get filePath => text().nullable().named('file_path')();

  /// Basename of the thumbnail file (for indexed lookups)
  TextColumn get thumbnailPath => text().nullable().named('thumbnail_path')();

  /// Hex public key of the account that owns this clip.
  /// NULL for legacy clips created before multi-account support.
  TextColumn get ownerPubkey => text().nullable().named('owner_pubkey')();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (draft_id) REFERENCES drafts(id) ON DELETE CASCADE',
  ];

  List<Index> get indexes => [
    Index(
      'idx_clip_owner_pubkey',
      'CREATE INDEX IF NOT EXISTS idx_clip_owner_pubkey '
          'ON clips (owner_pubkey)',
    ),
    // Partial index for library clips (clips without a draft)
    Index(
      'idx_clip_library',
      'CREATE INDEX IF NOT EXISTS idx_clip_library '
          'ON clips (draft_id) WHERE draft_id IS NULL',
    ),
    Index(
      'idx_clip_draft_id',
      'CREATE INDEX IF NOT EXISTS idx_clip_draft_id '
          'ON clips (draft_id)',
    ),
    Index(
      'idx_clip_draft_order',
      'CREATE INDEX IF NOT EXISTS idx_clip_draft_order '
          'ON clips (draft_id, order_index)',
    ),
    Index(
      'idx_clip_recorded_at',
      'CREATE INDEX IF NOT EXISTS idx_clip_recorded_at '
          'ON clips (recorded_at DESC)',
    ),
    Index(
      'idx_clip_file_path',
      'CREATE INDEX IF NOT EXISTS idx_clip_file_path '
          'ON clips (file_path)',
    ),
    Index(
      'idx_clip_thumbnail_path',
      'CREATE INDEX IF NOT EXISTS idx_clip_thumbnail_path '
          'ON clips (thumbnail_path)',
    ),
  ];
}

/// Stores decrypted NIP-17 direct messages (kind 14 rumor content).
///
/// After a gift-wrapped event (kind 1059) is received and decrypted through
/// the seal (kind 13) to the rumor (kind 14), the plaintext message is
/// persisted here for offline access and reactive UI queries.
@DataClassName('DirectMessageRow')
class DirectMessages extends Table {
  @override
  String get tableName => 'direct_messages';

  /// The rumor event ID (kind 14/15 id field).
  TextColumn get id => text()();

  /// Deterministic conversation identifier (SHA-256 of sorted participant
  /// pubkeys). Shared by all messages in the same chat room.
  TextColumn get conversationId => text().named('conversation_id')();

  /// Public key of the message sender.
  TextColumn get senderPubkey => text().named('sender_pubkey')();

  /// For kind 14: decrypted plaintext content.
  /// For kind 15: the encrypted file URL.
  TextColumn get content => text()();

  /// Unix timestamp from the rumor event's created_at.
  IntColumn get createdAt => integer().named('created_at')();

  /// Optional parent message ID (from `e` tag) for threaded replies.
  TextColumn get replyToId => text().nullable().named('reply_to_id')();

  /// The gift-wrap event ID (kind 1059) used for deduplication.
  TextColumn get giftWrapId => text().named('gift_wrap_id')();

  /// Optional conversation subject/title (from `subject` tag).
  TextColumn get subject => text().nullable()();

  /// The inner event kind: 14 (text) or 15 (file). Defaults to 14.
  IntColumn get messageKind =>
      integer().withDefault(const Constant(14)).named('message_kind')();

  // ---- Kind 15 file metadata (null for kind 14) ----

  /// MIME type of the file before encryption (e.g. `image/jpeg`).
  TextColumn get fileType => text().nullable().named('file_type')();

  /// Encryption algorithm (e.g. `aes-gcm`).
  TextColumn get encryptionAlgorithm =>
      text().nullable().named('encryption_algorithm')();

  /// Hex-encoded AES key for file decryption.
  TextColumn get decryptionKey => text().nullable().named('decryption_key')();

  /// Hex-encoded nonce/IV for file decryption.
  TextColumn get decryptionNonce =>
      text().nullable().named('decryption_nonce')();

  /// SHA-256 hex hash of the encrypted file.
  TextColumn get fileHash => text().nullable().named('file_hash')();

  /// SHA-256 hex hash of the original file before encryption.
  TextColumn get originalFileHash =>
      text().nullable().named('original_file_hash')();

  /// Size of the encrypted file in bytes.
  IntColumn get fileSize => integer().nullable().named('file_size')();

  /// Dimensions in `<width>x<height>` format.
  TextColumn get dimensions => text().nullable()();

  /// BlurHash string for image preview.
  TextColumn get blurhash => text().nullable()();

  /// URL of an encrypted thumbnail (same key/nonce).
  TextColumn get thumbnailUrl => text().nullable().named('thumbnail_url')();

  /// Whether this message has been soft-deleted via a NIP-09 kind 5 event.
  ///
  /// Soft-deleting (rather than hard-deleting) preserves the `giftWrapId` so
  /// the dedup check (`hasGiftWrap`) continues to reject the relay
  /// re-delivering the gift-wrapped event on the next poll cycle.
  BoolColumn get isDeleted =>
      boolean().withDefault(const Constant(false)).named('is_deleted')();

  /// Hex public key of the account that received/sent this message.
  /// NULL for legacy messages created before multi-account support.
  TextColumn get ownerPubkey => text().nullable().named('owner_pubkey')();

  @override
  Set<Column> get primaryKey => {id};

  List<Index> get indexes => [
    Index(
      'idx_dm_conversation_id',
      'CREATE INDEX IF NOT EXISTS idx_dm_conversation_id '
          'ON direct_messages (conversation_id)',
    ),
    Index(
      'idx_dm_conversation_created',
      'CREATE INDEX IF NOT EXISTS idx_dm_conversation_created '
          'ON direct_messages (conversation_id, created_at DESC)',
    ),
    Index(
      'idx_dm_gift_wrap_id',
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_dm_gift_wrap_id '
          'ON direct_messages (gift_wrap_id)',
    ),
    Index(
      'idx_dm_sender',
      'CREATE INDEX IF NOT EXISTS idx_dm_sender '
          'ON direct_messages (sender_pubkey)',
    ),
    Index(
      'idx_dm_owner_pubkey',
      'CREATE INDEX IF NOT EXISTS idx_dm_owner_pubkey '
          'ON direct_messages (owner_pubkey)',
    ),
    Index(
      'idx_dm_owner_conversation',
      'CREATE INDEX IF NOT EXISTS idx_dm_owner_conversation '
          'ON direct_messages (owner_pubkey, conversation_id, created_at DESC)',
    ),
  ];
}

/// Denormalized conversation metadata for fast list queries.
///
/// Each row represents a unique chat room defined by the set of participant
/// pubkeys. Updated whenever a new message arrives in the conversation.
@DataClassName('ConversationRow')
class Conversations extends Table {
  @override
  String get tableName => 'conversations';

  /// Deterministic conversation identifier (SHA-256 of sorted participant
  /// pubkeys).
  TextColumn get id => text()();

  /// JSON-encoded list of participant pubkeys (sorted).
  TextColumn get participantPubkeys => text().named('participant_pubkeys')();

  /// Whether this is a group conversation (more than 2 participants).
  BoolColumn get isGroup =>
      boolean().withDefault(const Constant(false)).named('is_group')();

  /// Preview text of the last message.
  TextColumn get lastMessageContent =>
      text().nullable().named('last_message_content')();

  /// Unix timestamp of the last message.
  IntColumn get lastMessageTimestamp =>
      integer().nullable().named('last_message_timestamp')();

  /// Pubkey of the last message sender.
  TextColumn get lastMessageSenderPubkey =>
      text().nullable().named('last_message_sender_pubkey')();

  /// Optional conversation title (from `subject` tag).
  TextColumn get subject => text().nullable()();

  /// Whether the conversation has unread messages.
  BoolColumn get isRead =>
      boolean().withDefault(const Constant(true)).named('is_read')();

  /// Whether the current user has sent a message in this conversation.
  BoolColumn get currentUserHasSent => boolean()
      .withDefault(const Constant(false))
      .named('current_user_has_sent')();

  /// Unix timestamp when the conversation was first created.
  IntColumn get createdAt => integer().named('created_at')();

  /// Hex public key of the account that owns this conversation view.
  /// NULL for legacy conversations created before multi-account support.
  TextColumn get ownerPubkey => text().nullable().named('owner_pubkey')();

  /// The DM protocol used for this conversation: 'nip04' or 'nip17'.
  /// NULL when the protocol is unknown (e.g. conversation created before
  /// protocol tracking was added).
  TextColumn get dmProtocol => text().nullable().named('dm_protocol')();

  @override
  Set<Column> get primaryKey => {id};

  List<Index> get indexes => [
    Index(
      'idx_conversation_last_message',
      'CREATE INDEX IF NOT EXISTS idx_conversation_last_message '
          'ON conversations (last_message_timestamp DESC)',
    ),
    Index(
      'idx_conversation_is_read',
      'CREATE INDEX IF NOT EXISTS idx_conversation_is_read '
          'ON conversations (is_read)',
    ),
    Index(
      'idx_conversation_owner_pubkey',
      'CREATE INDEX IF NOT EXISTS idx_conversation_owner_pubkey '
          'ON conversations (owner_pubkey)',
    ),
  ];
}

/// Stores the current user's own repost events (Kind 16 generic reposts).
///
/// This table tracks the mapping between addressable video IDs and the
/// user's repost event IDs. This mapping is essential for unreposts, which
/// require the repost event ID to create a Kind 5 deletion event.
///
/// Only stores reposts created by the current user, not reposts from others.
@DataClassName('PersonalRepostRow')
class PersonalReposts extends Table {
  @override
  String get tableName => 'personal_reposts';

  /// The addressable ID of the video that was reposted.
  /// Format: `34236:<author_pubkey>:<d-tag>`
  TextColumn get addressableId => text().named('addressable_id')();

  /// The Kind 16 repost event ID created by the user
  TextColumn get repostEventId => text().named('repost_event_id')();

  /// The pubkey of the original video author
  TextColumn get originalAuthorPubkey =>
      text().named('original_author_pubkey')();

  /// The pubkey of the user who created this repost
  TextColumn get userPubkey => text().named('user_pubkey')();

  /// Unix timestamp when the repost was created
  IntColumn get createdAt => integer().named('created_at')();

  @override
  Set<Column> get primaryKey => {addressableId, userPubkey};

  List<Index> get indexes => [
    // Index on user_pubkey for fetching all user's reposts
    Index(
      'idx_personal_reposts_user',
      'CREATE INDEX IF NOT EXISTS idx_personal_reposts_user '
          'ON personal_reposts (user_pubkey)',
    ),
    // Index on repost_event_id for lookups when processing deletions
    Index(
      'idx_personal_reposts_repost_id',
      'CREATE INDEX IF NOT EXISTS idx_personal_reposts_repost_id '
          'ON personal_reposts (repost_event_id)',
    ),
    // Composite index for user + created_at for ordered queries
    Index(
      'idx_personal_reposts_user_created',
      'CREATE INDEX IF NOT EXISTS idx_personal_reposts_user_created '
          'ON personal_reposts (user_pubkey, created_at DESC)',
    ),
  ];
}
