// ABOUTME: Data Access Object for conversation metadata persistence.
// ABOUTME: Provides CRUD, reactive watch streams, and unread counts
// ABOUTME: for the messages tab conversation list.

import 'package:db_client/db_client.dart';
import 'package:drift/drift.dart';

part 'conversations_dao.g.dart';

@DriftAccessor(tables: [Conversations])
class ConversationsDao extends DatabaseAccessor<AppDatabase>
    with _$ConversationsDaoMixin {
  ConversationsDao(super.attachedDatabase);

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
      ),
    );
  }

  /// Get all conversations sorted by last message (newest first).
  Future<List<ConversationRow>> getAllConversations({int? limit}) {
    final query = select(conversations)
      ..orderBy([
        (t) => OrderingTerm(
          expression: t.lastMessageTimestamp,
          mode: OrderingMode.desc,
        ),
      ]);
    if (limit != null) query.limit(limit);
    return query.get();
  }

  /// Watch all conversations (reactive stream), newest first.
  Stream<List<ConversationRow>> watchAllConversations({int? limit}) {
    final query = select(conversations)
      ..orderBy([
        (t) => OrderingTerm(
          expression: t.lastMessageTimestamp,
          mode: OrderingMode.desc,
        ),
      ]);
    if (limit != null) query.limit(limit);
    return query.watch();
  }

  /// Get a single conversation by ID.
  Future<ConversationRow?> getConversation(String id) {
    return (select(
      conversations,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Watch a single conversation by ID.
  Stream<ConversationRow?> watchConversation(String id) {
    return (select(
      conversations,
    )..where((t) => t.id.equals(id))).watchSingleOrNull();
  }

  /// Mark a conversation as read.
  ///
  /// Returns `true` if the row was updated, `false` if [id] was not found.
  ///
  /// Throws:
  ///
  /// * [InvalidDataException] if a column constraint is violated.
  Future<bool> markAsRead(String id) async {
    final rows = await (update(conversations)..where((t) => t.id.equals(id)))
        .write(const ConversationsCompanion(isRead: Value(true)));
    return rows > 0;
  }

  /// Get unread conversation count.
  Future<int> getUnreadCount() async {
    final query = selectOnly(conversations)
      ..where(conversations.isRead.equals(false))
      ..addColumns([conversations.id.count()]);
    final result = await query.getSingle();
    return result.read(conversations.id.count()) ?? 0;
  }

  /// Watch unread conversation count.
  Stream<int> watchUnreadCount() {
    final query = selectOnly(conversations)
      ..where(conversations.isRead.equals(false))
      ..addColumns([conversations.id.count()]);
    return query.watchSingle().map(
      (row) => row.read(conversations.id.count()) ?? 0,
    );
  }

  /// Delete a conversation by ID.
  Future<int> deleteConversation(String id) {
    return (delete(conversations)..where((t) => t.id.equals(id))).go();
  }

  /// Delete all conversations.
  Future<int> clearAll() {
    return delete(conversations).go();
  }
}
