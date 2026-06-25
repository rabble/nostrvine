// ABOUTME: Data Access Object for conversation metadata persistence.
// ABOUTME: Provides CRUD, reactive watch streams, and unread counts
// ABOUTME: for the messages tab conversation list.
// ABOUTME: All queries are scoped by ownerPubkey for multi-account isolation.

import 'package:db_client/db_client.dart';
import 'package:drift/drift.dart';

part 'conversations_dao.g.dart';

@DriftAccessor(tables: [Conversations])
class ConversationsDao extends DatabaseAccessor<AppDatabase>
    with _$ConversationsDaoMixin {
  ConversationsDao(super.attachedDatabase);

  static const String _latestMessagePreviewCase = '''
CASE
  WHEN dm.message_kind = 15 THEN
    CASE
      WHEN dm.file_type IS NULL THEN 'Sent a file'
      WHEN dm.file_type LIKE 'image/%' THEN 'Sent a photo'
      WHEN dm.file_type LIKE 'video/%' THEN 'Sent a video'
      WHEN dm.file_type LIKE 'audio/%' THEN 'Sent an audio message'
      ELSE 'Sent a file'
    END
  ELSE dm.content
END
''';

  /// Build a filter expression that returns rows owned by [ownerPubkey]
  /// **or** legacy rows with no owner (NULL).
  Expression<bool> _ownedOrLegacy(
    GeneratedColumn<String> column,
    String? ownerPubkey,
  ) {
    if (ownerPubkey == null) return const Constant(true);
    return column.equals(ownerPubkey) | column.isNull();
  }

  /// Upsert a conversation (create or update last-message metadata).
  ///
  /// On conflict the following update semantics apply in **both** branches:
  ///
  /// * `participantPubkeys`, `isGroup` — always overwritten.
  /// * `isRead` — updated only when the incoming event becomes the stored
  ///   latest message (strictly newer [lastMessageTimestamp]); otherwise
  ///   preserved. Notably NOT written under [forceUpdateLastMessage]: a
  ///   deletion preview refresh must not change read state. Flip read
  ///   state explicitly via [markAsRead] / [markMultipleAsRead].
  /// * `subject`, `ownerPubkey`, `dmProtocol` — updated only when the
  ///   incoming value is non-null; existing non-null value is preserved.
  /// * `currentUserHasSent` — one-way ratchet: once `true` it is never
  ///   cleared back to `false` by an incoming `false`.
  /// * `lastMessageContent`, `lastMessageTimestamp`,
  ///   `lastMessageSenderPubkey` — conditionally updated:
  ///   - When [forceUpdateLastMessage] is `false` (default), these are only
  ///     written if the incoming [lastMessageTimestamp] is strictly newer
  ///     than the stored one. This prevents out-of-order gift-wrap arrivals
  ///     during backfill from overwriting a fresher denormalized preview.
  ///   - When [forceUpdateLastMessage] is `true`, these are always written.
  ///     Use this only when the caller has already established that the
  ///     incoming values are the correct current preview — e.g. after a
  ///     deletion when the replacement message may be older than the one
  ///     that was removed.
  ///
  /// Throws [InvalidDataException] if a column constraint is violated.
  Future<void> upsertConversation({
    required String id,
    required String participantPubkeys,
    required bool isGroup,
    required int createdAt,
    String? lastMessageContent,
    int? lastMessageTimestamp,
    String? lastMessageSenderPubkey,
    String? subject,
    bool isRead = true,
    bool currentUserHasSent = false,
    String? ownerPubkey,
    String? dmProtocol,
    bool forceUpdateLastMessage = false,
  }) {
    final row = ConversationsCompanion.insert(
      id: id,
      participantPubkeys: participantPubkeys,
      isGroup: Value(isGroup),
      createdAt: createdAt,
      lastMessageContent: Value(lastMessageContent),
      lastMessageTimestamp: Value(lastMessageTimestamp),
      lastMessageSenderPubkey: Value(lastMessageSenderPubkey),
      subject: Value(subject),
      isRead: Value(isRead),
      currentUserHasSent: Value(currentUserHasSent),
      ownerPubkey: Value(ownerPubkey),
      dmProtocol: Value(dmProtocol),
    );

    return into(conversations).insert(
      row,
      onConflict: DoUpdate.withExcluded((old, excl) {
        // Determine whether the incoming preview columns should win.
        // When forced, always take the incoming values. Otherwise only
        // update when the incoming timestamp is strictly newer than the
        // stored one (NULL stored timestamp counts as 0 via COALESCE).
        final incomingIsNewer = excl.lastMessageTimestamp.isBiggerThan(
          coalesce([old.lastMessageTimestamp, const Constant(0)]),
        );
        final previewCondition = forceUpdateLastMessage
            ? const Constant<bool>(true)
            : incomingIsNewer;

        return ConversationsCompanion.custom(
          // Always updated.
          participantPubkeys: excl.participantPubkeys,
          isGroup: excl.isGroup,
          // Read state only follows the latest message: gated on
          // incomingIsNewer (not previewCondition) so a deletion
          // force-refresh updates the preview without marking read.
          isRead: excl.isRead.iif(incomingIsNewer, old.isRead),
          // Preserve existing non-null value; only update when incoming
          // value is non-null.
          subject: coalesce([excl.subject, old.subject]),
          ownerPubkey: coalesce([excl.ownerPubkey, old.ownerPubkey]),
          dmProtocol: coalesce([excl.dmProtocol, old.dmProtocol]),
          // One-way ratchet: never clear true back to false.
          currentUserHasSent: old.currentUserHasSent | excl.currentUserHasSent,
          // Preview columns: conditional on timestamp guard.
          // iif(condition, ifFalse) is called on the ifTrue expression.
          lastMessageTimestamp: excl.lastMessageTimestamp.iif(
            previewCondition,
            old.lastMessageTimestamp,
          ),
          lastMessageContent: excl.lastMessageContent.iif(
            previewCondition,
            old.lastMessageContent,
          ),
          lastMessageSenderPubkey: excl.lastMessageSenderPubkey.iif(
            previewCondition,
            old.lastMessageSenderPubkey,
          ),
        );
      }),
    );
  }

  /// Get all conversations sorted by last message (newest first).
  Future<List<ConversationRow>> getAllConversations({
    int? limit,
    int? offset,
    String? ownerPubkey,
  }) {
    final query = select(conversations)
      ..where((t) => _ownedOrLegacy(t.ownerPubkey, ownerPubkey))
      ..orderBy([
        (t) => OrderingTerm(
          expression: t.lastMessageTimestamp,
          mode: OrderingMode.desc,
        ),
      ]);
    if (limit != null) query.limit(limit, offset: offset);
    return query.get();
  }

  /// Watch all conversations (reactive stream), newest first.
  Stream<List<ConversationRow>> watchAllConversations({
    int? limit,
    int? offset,
    String? ownerPubkey,
  }) {
    final query = select(conversations)
      ..where((t) => _ownedOrLegacy(t.ownerPubkey, ownerPubkey))
      ..orderBy([
        (t) => OrderingTerm(
          expression: t.lastMessageTimestamp,
          mode: OrderingMode.desc,
        ),
      ]);
    if (limit != null) query.limit(limit, offset: offset);
    return query.watch();
  }

  /// Watch conversations where the user has sent at least one message.
  ///
  /// These are "accepted" conversations that are never message requests.
  /// Supports pagination via [limit] and [offset].
  Stream<List<ConversationRow>> watchAcceptedConversations({
    int? limit,
    int? offset,
    String? ownerPubkey,
  }) {
    final query = select(conversations)
      ..where(
        (t) =>
            t.currentUserHasSent.equals(true) &
            _ownedOrLegacy(t.ownerPubkey, ownerPubkey),
      )
      ..orderBy([
        (t) => OrderingTerm(
          expression: t.lastMessageTimestamp,
          mode: OrderingMode.desc,
        ),
      ]);
    if (limit != null) query.limit(limit, offset: offset);
    return query.watch();
  }

  /// Watch conversations where the user has never sent a message.
  ///
  /// These are potential message requests (final classification depends
  /// on follow state, which is applied in the BLoC layer). Returned
  /// without pagination since the count is typically small and needed
  /// in full for accurate badge counts.
  Stream<List<ConversationRow>> watchPotentialRequestConversations({
    String? ownerPubkey,
  }) {
    final query = select(conversations)
      ..where(
        (t) =>
            t.currentUserHasSent.equals(false) &
            _ownedOrLegacy(t.ownerPubkey, ownerPubkey),
      )
      ..orderBy([
        (t) => OrderingTerm(
          expression: t.lastMessageTimestamp,
          mode: OrderingMode.desc,
        ),
      ]);
    return query.watch();
  }

  /// Watch count of potential request conversations.
  Stream<int> watchPotentialRequestCount({String? ownerPubkey}) {
    final query = selectOnly(conversations)
      ..where(
        conversations.currentUserHasSent.equals(false) &
            _ownedOrLegacy(conversations.ownerPubkey, ownerPubkey),
      )
      ..addColumns([conversations.id.count()]);
    return query.watchSingle().map(
      (row) => row.read(conversations.id.count()) ?? 0,
    );
  }

  /// Get a single conversation by ID.
  Future<ConversationRow?> getConversation(String id, {String? ownerPubkey}) {
    return (select(conversations)..where(
          (t) => t.id.equals(id) & _ownedOrLegacy(t.ownerPubkey, ownerPubkey),
        ))
        .getSingleOrNull();
  }

  /// Watch a single conversation by ID.
  Stream<ConversationRow?> watchConversation(String id, {String? ownerPubkey}) {
    return (select(conversations)..where(
          (t) => t.id.equals(id) & _ownedOrLegacy(t.ownerPubkey, ownerPubkey),
        ))
        .watchSingleOrNull();
  }

  /// Mark a conversation as read.
  ///
  /// Sets `isRead = true` and advances the read cursor
  /// [Conversations.lastReadTimestamp] forward to the conversation's latest
  /// message timestamp (monotonic: `max(existing, lastMessageTimestamp)`,
  /// never lowered). The cursor is the cross-device / reinstall-restorable
  /// read pointer (#4977).
  ///
  /// Returns `true` if the row was updated, `false` if [id] was not found.
  Future<bool> markAsRead(String id, {String? ownerPubkey}) async {
    final rows = await customUpdate(
      'UPDATE conversations SET is_read = 1, '
      'last_read_timestamp = MAX( '
      'COALESCE(last_read_timestamp, 0), '
      'COALESCE(last_message_timestamp, 0)) '
      'WHERE id = ?${_ownerSqlClause(ownerPubkey)}',
      variables: [Variable(id), ..._ownerSqlVariables(ownerPubkey)],
      updates: {attachedDatabase.conversations},
      updateKind: UpdateKind.update,
    );
    return rows > 0;
  }

  /// Advances the read cursor for [id] to `max(existing, timestamp)` and, when
  /// the cursor then covers the latest message, marks the conversation read.
  ///
  /// Used by cross-device reconcile (a restored remote read-marker) and the
  /// reinstall last-sent floor. Monotonic — never lowers the cursor, never
  /// flips a genuinely-unread conversation read (only marks read when the
  /// cursor reaches the latest message). Returns `true` if a row matched.
  Future<bool> applyReadCursor(
    String id,
    int timestamp, {
    String? ownerPubkey,
  }) async {
    final rows = await customUpdate(
      'UPDATE conversations SET '
      'last_read_timestamp = MAX(COALESCE(last_read_timestamp, 0), ?), '
      'is_read = CASE WHEN COALESCE(last_message_timestamp, 0) <= '
      'MAX(COALESCE(last_read_timestamp, 0), ?) THEN 1 ELSE is_read END '
      'WHERE id = ?${_ownerSqlClause(ownerPubkey)}',
      variables: [
        Variable(timestamp),
        Variable(timestamp),
        Variable(id),
        ..._ownerSqlVariables(ownerPubkey),
      ],
      updates: {attachedDatabase.conversations},
      updateKind: UpdateKind.update,
    );
    return rows > 0;
  }

  /// Owner filter as a raw-SQL fragment matching [_ownedOrLegacy]: empty when
  /// [ownerPubkey] is null (all rows), else owner-or-legacy-NULL.
  String _ownerSqlClause(String? ownerPubkey) => ownerPubkey == null
      ? ''
      : ' AND (owner_pubkey = ? OR owner_pubkey IS NULL)';

  List<Variable<Object>> _ownerSqlVariables(String? ownerPubkey) =>
      ownerPubkey == null ? const [] : [Variable(ownerPubkey)];

  /// Returns the timestamp of [userPubkey]'s own most-recent (non-deleted)
  /// sent message per conversation, keyed by conversation id.
  ///
  /// The source for the reinstall "last-sent floor" (#4977): a conversation
  /// the user last replied in can have its read cursor restored from the
  /// self-1059 wraps the history drain recovered, without any read-marker.
  Future<Map<String, int>> lastSentTimestampsByConversation(
    String userPubkey, {
    String? ownerPubkey,
  }) async {
    final rows = await customSelect(
      'SELECT conversation_id AS cid, MAX(created_at) AS ts '
      'FROM direct_messages '
      'WHERE sender_pubkey = ? AND is_deleted = 0'
      '${_ownerSqlClause(ownerPubkey)} '
      'GROUP BY conversation_id',
      variables: [Variable(userPubkey), ..._ownerSqlVariables(ownerPubkey)],
    ).get();
    return {
      for (final row in rows) row.read<String>('cid'): row.read<int>('ts'),
    };
  }

  /// Get unread conversation count.
  Future<int> getUnreadCount({String? ownerPubkey}) async {
    final query = selectOnly(conversations)
      ..where(
        conversations.isRead.equals(false) &
            _ownedOrLegacy(conversations.ownerPubkey, ownerPubkey),
      )
      ..addColumns([conversations.id.count()]);
    final result = await query.getSingle();
    return result.read(conversations.id.count()) ?? 0;
  }

  /// Watch unread conversation count (all conversations).
  Stream<int> watchUnreadCount({String? ownerPubkey}) {
    final query = selectOnly(conversations)
      ..where(
        conversations.isRead.equals(false) &
            _ownedOrLegacy(conversations.ownerPubkey, ownerPubkey),
      )
      ..addColumns([conversations.id.count()]);
    return query.watchSingle().map(
      (row) => row.read(conversations.id.count()) ?? 0,
    );
  }

  /// Watch unread count for accepted conversations only.
  ///
  /// Excludes conversations where the user has never sent a message
  /// (potential requests), so the badge on the nav bar reflects only
  /// the "Messages" tab unreads.
  Stream<int> watchUnreadAcceptedCount({String? ownerPubkey}) {
    final query = selectOnly(conversations)
      ..where(
        conversations.isRead.equals(false) &
            conversations.currentUserHasSent.equals(true) &
            _ownedOrLegacy(conversations.ownerPubkey, ownerPubkey),
      )
      ..addColumns([conversations.id.count()]);
    return query.watchSingle().map(
      (row) => row.read(conversations.id.count()) ?? 0,
    );
  }

  /// Mark multiple conversations as read in a single batch.
  ///
  /// Advances each conversation's read cursor
  /// [Conversations.lastReadTimestamp] to its latest message timestamp, with
  /// the same monotonic semantics as [markAsRead].
  Future<void> markMultipleAsRead(
    List<String> ids, {
    String? ownerPubkey,
  }) async {
    if (ids.isEmpty) return;
    final placeholders = List.filled(ids.length, '?').join(', ');
    await customUpdate(
      'UPDATE conversations SET is_read = 1, '
      'last_read_timestamp = MAX( '
      'COALESCE(last_read_timestamp, 0), '
      'COALESCE(last_message_timestamp, 0)) '
      'WHERE id IN ($placeholders)${_ownerSqlClause(ownerPubkey)}',
      variables: [
        ...ids.map(Variable.new),
        ..._ownerSqlVariables(ownerPubkey),
      ],
      updates: {attachedDatabase.conversations},
      updateKind: UpdateKind.update,
    );
  }

  /// Delete a conversation by ID.
  Future<int> deleteConversation(String id, {String? ownerPubkey}) {
    return (delete(conversations)..where(
          (t) => t.id.equals(id) & _ownedOrLegacy(t.ownerPubkey, ownerPubkey),
        ))
        .go();
  }

  /// Delete multiple conversations in a single batch.
  Future<int> deleteMultiple(List<String> ids, {String? ownerPubkey}) {
    if (ids.isEmpty) return Future.value(0);
    return (delete(conversations)..where(
          (t) => t.id.isIn(ids) & _ownedOrLegacy(t.ownerPubkey, ownerPubkey),
        ))
        .go();
  }

  /// Run a callback inside a database transaction.
  Future<T> runInTransaction<T>(Future<T> Function() action) {
    return attachedDatabase.transaction(action);
  }

  /// Delete all conversations for a specific user.
  Future<int> clearAllForUser(String ownerPubkey) {
    return (delete(
      conversations,
    )..where((t) => t.ownerPubkey.equals(ownerPubkey))).go();
  }

  /// Delete all conversations.
  Future<int> clearAll() {
    return delete(conversations).go();
  }

  /// Backfill `current_user_has_sent` for conversations where the user
  /// has sent messages but the flag is still `false`.
  ///
  /// Fixes a migration gap where the column was added with DEFAULT 0
  /// without retroactively checking existing messages. Idempotent: only
  /// flips `false` to `true`, never `true` to `false`.
  ///
  /// Returns the number of conversations updated.
  Future<int> backfillCurrentUserHasSent(String userPubkey) {
    return customUpdate(
      'UPDATE conversations SET current_user_has_sent = 1 '
      'WHERE current_user_has_sent = 0 '
      'AND (owner_pubkey = ? OR owner_pubkey IS NULL) '
      'AND id IN (SELECT DISTINCT conversation_id '
      'FROM direct_messages WHERE sender_pubkey = ? '
      'AND (owner_pubkey = ? OR owner_pubkey IS NULL))',
      variables: [
        Variable(userPubkey),
        Variable(userPubkey),
        Variable(userPubkey),
      ],
      updates: {attachedDatabase.conversations},
      updateKind: UpdateKind.update,
    );
  }

  /// Backfills denormalized latest-message preview columns from
  /// `direct_messages`.
  ///
  /// Fixes stale conversation previews written by app versions prior to the
  /// write-path timestamp guard in [upsertConversation]. Idempotent: once a
  /// conversation row matches the newest non-deleted message (or correctly has
  /// no preview because no messages remain), subsequent runs are no-ops.
  ///
  /// Returns the number of conversations updated.
  Future<int> backfillLatestMessagePreviews({String? ownerPubkey}) {
    final scopedConversationFilter = ownerPubkey == null
        ? '1 = 1'
        : '(c.owner_pubkey = ? OR c.owner_pubkey IS NULL)';
    // Legacy conversation rows may still be ownerless, but scoped reads expose
    // them to the current user alongside that user's messages.
    final latestMessageOwnerFilter = ownerPubkey == null
        ? '1 = 1'
        : '(dm.owner_pubkey = ? OR dm.owner_pubkey IS NULL)';
    final latestPreviewContentSubquery =
        '''
SELECT $_latestMessagePreviewCase
FROM direct_messages dm
WHERE dm.conversation_id = c.id
  AND dm.is_deleted = 0
  AND $latestMessageOwnerFilter
ORDER BY dm.created_at DESC, dm.id DESC
LIMIT 1
''';
    final latestTimestampSubquery =
        '''
SELECT dm.created_at
FROM direct_messages dm
WHERE dm.conversation_id = c.id
  AND dm.is_deleted = 0
  AND $latestMessageOwnerFilter
ORDER BY dm.created_at DESC, dm.id DESC
LIMIT 1
''';
    final latestSenderSubquery =
        '''
SELECT dm.sender_pubkey
FROM direct_messages dm
WHERE dm.conversation_id = c.id
  AND dm.is_deleted = 0
  AND $latestMessageOwnerFilter
ORDER BY dm.created_at DESC, dm.id DESC
LIMIT 1
''';

    return customUpdate(
      '''
      UPDATE conversations AS c
      SET last_message_content = ($latestPreviewContentSubquery),
          last_message_timestamp = ($latestTimestampSubquery),
          last_message_sender_pubkey = ($latestSenderSubquery)
      WHERE $scopedConversationFilter
        AND (
          COALESCE(c.last_message_content, '') !=
              COALESCE(($latestPreviewContentSubquery), '') OR
          COALESCE(c.last_message_timestamp, -1) !=
              COALESCE(($latestTimestampSubquery), -1) OR
          COALESCE(c.last_message_sender_pubkey, '') !=
              COALESCE(($latestSenderSubquery), '')
        )
      ''',
      variables: [
        if (ownerPubkey != null) ...[
          Variable(ownerPubkey),
          Variable(ownerPubkey),
          Variable(ownerPubkey),
          Variable(ownerPubkey),
          Variable(ownerPubkey),
          Variable(ownerPubkey),
          Variable(ownerPubkey),
        ],
      ],
      updates: {attachedDatabase.conversations},
      updateKind: UpdateKind.update,
    );
  }

  /// Returns the newest `last_message_timestamp` across all conversations
  /// for the given owner, or `null` if no conversations exist.
  Future<int?> getNewestMessageTimestamp({String? ownerPubkey}) async {
    final maxCol = conversations.lastMessageTimestamp.max();
    final query = selectOnly(conversations)
      ..where(_ownedOrLegacy(conversations.ownerPubkey, ownerPubkey))
      ..addColumns([maxCol]);
    final result = await query.getSingleOrNull();
    return result?.read(maxCol);
  }
}
