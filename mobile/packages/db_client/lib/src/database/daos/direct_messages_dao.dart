// ABOUTME: Data Access Object for NIP-17 direct message persistence.
// ABOUTME: Provides CRUD operations for decrypted DM storage and
// ABOUTME: conversation-scoped queries with reactive streams.
// ABOUTME: All queries are scoped by ownerPubkey for multi-account isolation.

import 'package:db_client/db_client.dart';
import 'package:drift/drift.dart';

part 'direct_messages_dao.g.dart';

@DriftAccessor(tables: [DirectMessages])
class DirectMessagesDao extends DatabaseAccessor<AppDatabase>
    with _$DirectMessagesDaoMixin {
  DirectMessagesDao(super.attachedDatabase);

  /// Build a filter expression that returns rows owned by [ownerPubkey]
  /// **or** legacy rows with no owner (NULL).
  Expression<bool> _ownedOrLegacy(
    GeneratedColumn<String> column,
    String? ownerPubkey,
  ) {
    if (ownerPubkey == null) return const Constant(true);
    return column.equals(ownerPubkey) | column.isNull();
  }

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
    String? ownerPubkey,
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
        ownerPubkey: Value(ownerPubkey),
      ),
    );
  }

  /// Get messages for a conversation, newest first.
  ///
  /// Excludes soft-deleted messages (NIP-09 kind 5).
  Future<List<DirectMessageRow>> getMessagesForConversation(
    String conversationId, {
    int? limit,
    int? offset,
    String? ownerPubkey,
  }) {
    final query = select(directMessages)
      ..where(
        (t) =>
            t.conversationId.equals(conversationId) &
            t.isDeleted.equals(false) &
            _ownedOrLegacy(t.ownerPubkey, ownerPubkey),
      )
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
  ///
  /// Excludes soft-deleted messages (NIP-09 kind 5).
  Stream<List<DirectMessageRow>> watchMessagesForConversation(
    String conversationId, {
    int? limit,
    String? ownerPubkey,
  }) {
    final query = select(directMessages)
      ..where(
        (t) =>
            t.conversationId.equals(conversationId) &
            t.isDeleted.equals(false) &
            _ownedOrLegacy(t.ownerPubkey, ownerPubkey),
      )
      ..orderBy([
        (t) => OrderingTerm(
          expression: t.createdAt,
          mode: OrderingMode.desc,
        ),
      ]);
    if (limit != null) query.limit(limit);
    return query.watch();
  }

  /// Soft-delete a message by rumor event ID (NIP-09 kind 5).
  ///
  /// Sets `is_deleted = true` instead of removing the row so the
  /// `gift_wrap_id` remains for deduplication.
  ///
  /// Returns `true` if the row was updated, `false` if [rumorId] was not
  /// found.
  Future<bool> markMessageDeleted(String rumorId) async {
    final rows =
        await (update(directMessages)..where((t) => t.id.equals(rumorId)))
            .write(const DirectMessagesCompanion(isDeleted: Value(true)));
    return rows > 0;
  }

  /// Look up a message by rumor event ID.
  ///
  /// Used to validate sender pubkey before applying a kind 5 deletion.
  Future<DirectMessageRow?> getMessageById(String id) {
    return (select(
      directMessages,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Check if a gift wrap event has already been processed (dedup).
  Future<bool> hasGiftWrap(String giftWrapId) async {
    final query = selectOnly(directMessages)
      ..where(directMessages.giftWrapId.equals(giftWrapId))
      ..addColumns([directMessages.id]);
    final result = await query.getSingleOrNull();
    return result != null;
  }

  /// Check if a message with the same sender and content already exists in a
  /// conversation within a ±5 second window. Used for cross-protocol dedup
  /// when both a NIP-17 and NIP-04 copy of the same message arrive.
  ///
  /// The time window prevents false positives when a user genuinely sends
  /// the same text twice (e.g. "ok") while still catching dual-send
  /// duplicates where timestamps differ by at most a few seconds.
  Future<bool> hasMatchingMessage({
    required String conversationId,
    required String senderPubkey,
    required String content,
    required int createdAt,
    int windowSeconds = 5,
  }) async {
    final query = selectOnly(directMessages)
      ..where(
        directMessages.conversationId.equals(conversationId) &
            directMessages.senderPubkey.equals(senderPubkey) &
            directMessages.content.equals(content) &
            directMessages.createdAt.isBiggerOrEqualValue(
              createdAt - windowSeconds,
            ) &
            directMessages.createdAt.isSmallerOrEqualValue(
              createdAt + windowSeconds,
            ),
      )
      ..addColumns([directMessages.id])
      ..limit(1);
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

  /// Delete messages for multiple conversations in a single batch.
  Future<int> deleteMultipleConversationMessages(
    List<String> conversationIds,
  ) {
    if (conversationIds.isEmpty) return Future.value(0);
    return (delete(
      directMessages,
    )..where((t) => t.conversationId.isIn(conversationIds))).go();
  }

  /// Count messages in a conversation.
  Future<int> countMessages(
    String conversationId, {
    String? ownerPubkey,
  }) async {
    final query = selectOnly(directMessages)
      ..where(
        directMessages.conversationId.equals(conversationId) &
            _ownedOrLegacy(directMessages.ownerPubkey, ownerPubkey),
      )
      ..addColumns([directMessages.id.count()]);
    final result = await query.getSingle();
    return result.read(directMessages.id.count()) ?? 0;
  }

  /// Delete all DMs for a specific user.
  Future<int> clearAllForUser(String ownerPubkey) {
    return (delete(
      directMessages,
    )..where((t) => t.ownerPubkey.equals(ownerPubkey))).go();
  }

  /// Delete all DMs.
  Future<int> clearAll() {
    return delete(directMessages).go();
  }
}
