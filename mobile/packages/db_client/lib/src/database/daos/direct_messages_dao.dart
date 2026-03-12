// ABOUTME: Data Access Object for NIP-17 direct message persistence.
// ABOUTME: Provides CRUD operations for decrypted DM storage and
// ABOUTME: conversation-scoped queries with reactive streams.

import 'package:db_client/db_client.dart';
import 'package:drift/drift.dart';

part 'direct_messages_dao.g.dart';

@DriftAccessor(tables: [DirectMessages])
class DirectMessagesDao extends DatabaseAccessor<AppDatabase>
    with _$DirectMessagesDaoMixin {
  DirectMessagesDao(super.attachedDatabase);

  /// Insert a decrypted DM, ignoring duplicates by gift_wrap_id.
  ///
  /// For kind 14 (text), only [content] is used.
  /// For kind 15 (file), [content] holds the file URL and file metadata
  /// fields are populated from the event tags.
  ///
  /// Throws:
  ///
  /// * [InvalidDataException] if a column constraint is violated.
  Future<void> insertMessage({
    required String id,
    required String conversationId,
    required String senderPubkey,
    required String content,
    required int createdAt,
    required String giftWrapId,
    int messageKind = 14,
    String? replyToId,
    String? subject,
    String? fileType,
    String? encryptionAlgorithm,
    String? decryptionKey,
    String? decryptionNonce,
    String? fileHash,
    String? originalFileHash,
    int? fileSize,
    String? dimensions,
    String? blurhash,
    String? thumbnailUrl,
  }) {
    return into(directMessages).insertOnConflictUpdate(
      DirectMessagesCompanion.insert(
        id: id,
        conversationId: conversationId,
        senderPubkey: senderPubkey,
        content: content,
        createdAt: createdAt,
        giftWrapId: giftWrapId,
        messageKind: Value(messageKind),
        replyToId: Value(replyToId),
        subject: Value(subject),
        fileType: Value(fileType),
        encryptionAlgorithm: Value(encryptionAlgorithm),
        decryptionKey: Value(decryptionKey),
        decryptionNonce: Value(decryptionNonce),
        fileHash: Value(fileHash),
        originalFileHash: Value(originalFileHash),
        fileSize: Value(fileSize),
        dimensions: Value(dimensions),
        blurhash: Value(blurhash),
        thumbnailUrl: Value(thumbnailUrl),
      ),
    );
  }

  /// Get messages for a conversation, newest first.
  Future<List<DirectMessageRow>> getMessagesForConversation(
    String conversationId, {
    int? limit,
    int? offset,
  }) {
    final query = select(directMessages)
      ..where((t) => t.conversationId.equals(conversationId))
      ..orderBy([
        (t) => OrderingTerm(
          expression: t.createdAt,
          mode: OrderingMode.desc,
        ),
      ]);
    if (limit != null) query.limit(limit, offset: offset);
    return query.get();
  }

  /// Watch messages for a conversation (reactive stream), newest first.
  Stream<List<DirectMessageRow>> watchMessagesForConversation(
    String conversationId, {
    int? limit,
  }) {
    final query = select(directMessages)
      ..where((t) => t.conversationId.equals(conversationId))
      ..orderBy([
        (t) => OrderingTerm(
          expression: t.createdAt,
          mode: OrderingMode.desc,
        ),
      ]);
    if (limit != null) query.limit(limit);
    return query.watch();
  }

  /// Check if a gift wrap event has already been processed (dedup).
  Future<bool> hasGiftWrap(String giftWrapId) async {
    final query = selectOnly(directMessages)
      ..where(directMessages.giftWrapId.equals(giftWrapId))
      ..addColumns([directMessages.id]);
    final result = await query.getSingleOrNull();
    return result != null;
  }

  /// Delete all messages in a conversation.
  ///
  /// Returns the number of deleted rows.
  Future<int> deleteConversationMessages(String conversationId) {
    return (delete(
      directMessages,
    )..where((t) => t.conversationId.equals(conversationId))).go();
  }

  /// Delete a single message by ID.
  Future<int> deleteMessage(String id) {
    return (delete(directMessages)..where((t) => t.id.equals(id))).go();
  }

  /// Count messages in a conversation.
  Future<int> countMessages(String conversationId) async {
    final query = selectOnly(directMessages)
      ..where(directMessages.conversationId.equals(conversationId))
      ..addColumns([directMessages.id.count()]);
    final result = await query.getSingle();
    return result.read(directMessages.id.count()) ?? 0;
  }

  /// Delete all DMs.
  Future<int> clearAll() {
    return delete(directMessages).go();
  }
}
