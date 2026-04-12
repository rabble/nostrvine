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
  /// Throws:
  ///
  /// * [InvalidDataException] if a column constraint is violated.
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
  }) {
    return into(conversations).insertOnConflictUpdate(
      ConversationsCompanion.insert(
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
      ),
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
  Future<ConversationRow?> getConversation(
    String id, {
    String? ownerPubkey,
  }) {
    return (select(conversations)..where(
          (t) => t.id.equals(id) & _ownedOrLegacy(t.ownerPubkey, ownerPubkey),
        ))
        .getSingleOrNull();
  }

  /// Watch a single conversation by ID.
  Stream<ConversationRow?> watchConversation(
    String id, {
    String? ownerPubkey,
  }) {
    return (select(conversations)..where(
          (t) => t.id.equals(id) & _ownedOrLegacy(t.ownerPubkey, ownerPubkey),
        ))
        .watchSingleOrNull();
  }

  /// Mark a conversation as read.
  ///
  /// Returns `true` if the row was updated, `false` if [id] was not found.
  ///
  /// Throws:
  ///
  /// * [InvalidDataException] if a column constraint is violated.
  Future<bool> markAsRead(
    String id, {
    String? ownerPubkey,
  }) async {
    final rows =
        await (update(conversations)..where(
              (t) =>
                  t.id.equals(id) & _ownedOrLegacy(t.ownerPubkey, ownerPubkey),
            ))
            .write(const ConversationsCompanion(isRead: Value(true)));
    return rows > 0;
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
  Future<void> markMultipleAsRead(
    List<String> ids, {
    String? ownerPubkey,
  }) async {
    if (ids.isEmpty) return;
    await (update(conversations)..where(
          (t) => t.id.isIn(ids) & _ownedOrLegacy(t.ownerPubkey, ownerPubkey),
        ))
        .write(const ConversationsCompanion(isRead: Value(true)));
  }

  /// Delete a conversation by ID.
  Future<int> deleteConversation(
    String id, {
    String? ownerPubkey,
  }) {
    return (delete(conversations)..where(
          (t) => t.id.equals(id) & _ownedOrLegacy(t.ownerPubkey, ownerPubkey),
        ))
        .go();
  }

  /// Delete multiple conversations in a single batch.
  Future<int> deleteMultiple(
    List<String> ids, {
    String? ownerPubkey,
  }) {
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
