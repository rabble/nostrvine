// ABOUTME: Data Access Object for NIP-17 direct message persistence.
// ABOUTME: Provides CRUD operations for decrypted DM storage and
// ABOUTME: conversation-scoped queries with reactive streams.
// ABOUTME: All queries are scoped by ownerPubkey for multi-account isolation.

import 'package:db_client/db_client.dart';
import 'package:drift/drift.dart';

part 'direct_messages_dao.g.dart';

/// Which arrival protocol a stored `direct_messages` row must have for
/// [DirectMessagesDao.hasMatchingMessage] to treat it as a duplicate.
///
/// This is not `Conversations.dmProtocol`, which classifies a whole
/// *conversation* for send routing. This names one stored *row*, and it is
/// derived rather than stored: the NIP-04 receive path writes the wire event
/// id into both `id` and `gift_wrap_id`, while every NIP-17 path writes a
/// rumor id distinct from its gift-wrap id.
enum DmDedupCounterpart {
  /// Only a row that arrived over NIP-04 counts. Asked by the NIP-17 receive
  /// path: a near-identical row from its *own* protocol is a genuine earlier
  /// message, not this one.
  nip04Copy,

  /// Only a row that arrived over NIP-17 counts. Mirror of [nip04Copy], asked
  /// by the NIP-04 receive path.
  nip17Copy,

  /// No arrival constraint. For the self-send paths that match the user's own
  /// persisted message rather than a cross-protocol twin.
  unconstrained,
}

@DriftAccessor(tables: [DirectMessages])
class DirectMessagesDao extends DatabaseAccessor<AppDatabase>
    with _$DirectMessagesDaoMixin {
  DirectMessagesDao(super.attachedDatabase);

  /// Soft-deleted locally; the kind-5 wrap still needs a confirmed delivery.
  static const String _deletionPending = 'deletion_pending';

  /// A relay confirmed the wrap. Terminal.
  static const String _deletionSent = 'deletion_sent';

  /// Send policy refused every recipient. Terminal, but NOT delivered.
  static const String _deletionBlocked = 'deletion_blocked';

  /// Build a filter expression that returns rows owned by [ownerPubkey]
  /// **or** legacy rows with no owner (NULL).
  Expression<bool> _ownedOrLegacy(
    GeneratedColumn<String> column,
    String? ownerPubkey,
  ) {
    if (ownerPubkey == null) return const Constant(true);
    return column.equals(ownerPubkey) | column.isNull();
  }

  /// Insert a decrypted DM, returning whether a row was actually written.
  ///
  /// Uses `INSERT OR IGNORE` so that violations on either the primary key
  /// (`id`) **or** the UNIQUE index on `gift_wrap_id` are handled gracefully
  /// without throwing. A `false` return means a local uniqueness constraint
  /// skipped the row, and callers must avoid advancing receive-side state that
  /// depends on a newly persisted message.
  ///
  /// NIP-17 rumor events are immutable — the same rumor ID always carries
  /// the same content. The current message uniqueness constraints are global,
  /// so callers still need owner-scoped checks where account isolation matters.
  ///
  /// For kind 14 (text), only [content] is used.
  /// For kind 15 (file), [content] holds the file URL and file metadata
  /// fields are populated from the event tags.
  Future<bool> insertMessage({
    required String id,
    required String conversationId,
    required String senderPubkey,
    required String content,
    required int createdAt,
    required String giftWrapId,
    int messageKind = 14,
    String? replyToId,
    String? subject,
    String? tagsJson,
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
    String? sendBatchId,
  }) async {
    final inserted = await into(directMessages).insertReturningOrNull(
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
        tagsJson: Value(tagsJson),
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
        sendBatchId: Value(sendBatchId),
      ),
      mode: InsertMode.insertOrIgnore,
    );
    return inserted != null;
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
        (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
        // `id` is the rumor event hash: this secondary sort is a stable but
        // arbitrary tie-break for messages sharing a `createdAt` second. Keep
        // it `id DESC` to match ConversationsDao.backfillLatestMessagePreviews
        // so the inbox preview agrees with the open conversation's newest row.
        (t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc),
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
        (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
        // `id` is the rumor event hash: this secondary sort is a stable but
        // arbitrary tie-break for messages sharing a `createdAt` second. Keep
        // it `id DESC` to match ConversationsDao.backfillLatestMessagePreviews
        // so the inbox preview agrees with the open conversation's newest row.
        (t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc),
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
  Future<bool> markMessageDeleted(String rumorId, {String? ownerPubkey}) async {
    final rows =
        await (update(directMessages)..where(
              (t) =>
                  t.id.equals(rumorId) &
                  _ownedOrLegacy(t.ownerPubkey, ownerPubkey),
            ))
            .write(const DirectMessagesCompanion(isDeleted: Value(true)));
    return rows > 0;
  }

  /// Soft-delete [rumorId] and durably record the kind-5 rumor that still
  /// has to reach the recipient.
  ///
  /// One write, so a crash between hiding the bubble and storing the rumor
  /// cannot lose the retraction. The row leaves the live set immediately
  /// (`watchMessagesForConversation` excludes `is_deleted`), while
  /// `deletion_publish_status = 'deletion_pending'` keeps it visible to the
  /// retry sweep until a relay confirms the wrap. Mirrors
  /// `DmReactionsDao.markOwnDeletionPending`.
  ///
  /// Returns `true` if the row was updated, `false` if [rumorId] was not
  /// found.
  Future<bool> markMessageDeletionPending(
    String rumorId, {
    required String deletionRumorJson,
    String? ownerPubkey,
  }) async {
    final rows =
        await (update(directMessages)..where(
              (t) =>
                  t.id.equals(rumorId) &
                  _ownedOrLegacy(t.ownerPubkey, ownerPubkey),
            ))
            .write(
              DirectMessagesCompanion(
                isDeleted: const Value(true),
                deletionRumorJson: Value(deletionRumorJson),
                deletionPublishStatus: const Value(_deletionPending),
              ),
            );
    return rows > 0;
  }

  /// A relay confirmed the deletion wrap: drop the stored rumor and move the
  /// row to the terminal `'deletion_sent'` status so the sweep stops.
  Future<bool> markMessageDeletionSent(String rumorId, {String? ownerPubkey}) =>
      _settleMessageDeletion(
        rumorId,
        status: _deletionSent,
        // Delivered, so there is nothing left to replay.
        retainRumor: false,
        ownerPubkey: ownerPubkey,
      );

  /// Send policy blocked every failed recipient: stop re-driving a send that
  /// will always be refused, but record it as `'deletion_blocked'` rather than
  /// `'deletion_sent'`. Other recipients may already have succeeded.
  ///
  /// The reaction path collapses these two, reasoning that a blocked peer
  /// never received the reaction either so the removal is moot. That does not
  /// transfer to a message, which may well have been delivered before the
  /// block took effect — calling it sent would misreport a message the peer
  /// still holds.
  ///
  /// The rumor is **kept**. A block is the one terminal state that can lift
  /// while the build is running — the minor restriction reads live remote
  /// state, and a server-side signer refusal clears on re-authorization. (The
  /// retired-moderation-account case cannot: that list is a compile-time
  /// `const`, so lifting it needs a new build.)
  ///
  /// The stored rumor is also the idempotency token, not merely a payload. A
  /// replay of the stored JSON carries a byte-identical rumor id that the
  /// recipient dedups; a rebuilt one carries a fresh id, and so lands as a
  /// second, distinct retraction. Dropping it therefore leaves the row
  /// unrepairable rather than merely un-retried — including in the mixed case
  /// where some recipients already received the retraction (#8226).
  ///
  /// Retention is inert for the sweep: [getRetryableOwnMessageDeletions]
  /// additionally requires `deletion_pending`, so a blocked row stays off the
  /// worklist whether or not the rumor is present.
  Future<bool> markMessageDeletionBlocked(
    String rumorId, {
    String? ownerPubkey,
  }) => _settleMessageDeletion(
    rumorId,
    status: _deletionBlocked,
    retainRumor: true,
    ownerPubkey: ownerPubkey,
  );

  /// Move a deletion row to a terminal [status].
  ///
  /// [retainRumor] is required rather than defaulted: whether the payload
  /// survives is the whole difference between the two terminal states, so a
  /// future third caller has to decide it deliberately.
  Future<bool> _settleMessageDeletion(
    String rumorId, {
    required String status,
    required bool retainRumor,
    String? ownerPubkey,
  }) async {
    final rows =
        await (update(directMessages)..where(
              (t) =>
                  t.id.equals(rumorId) &
                  _ownedOrLegacy(t.ownerPubkey, ownerPubkey),
            ))
            .write(
              DirectMessagesCompanion(
                deletionRumorJson: retainRumor
                    ? const Value.absent()
                    : const Value(null),
                deletionPublishStatus: Value(status),
              ),
            );
    return rows > 0;
  }

  /// Own deletions still awaiting confirmed delivery, oldest first — the
  /// retry sweep's worklist.
  ///
  /// Scoped to rows this account authored *and* soft-deleted, so a peer's
  /// deletion applied locally is never re-published from this device.
  Future<List<DirectMessageRow>> getRetryableOwnMessageDeletions({
    required String ownerPubkey,
  }) {
    return (select(directMessages)
          ..where(
            (t) =>
                _ownedOrLegacy(t.ownerPubkey, ownerPubkey) &
                t.senderPubkey.equals(ownerPubkey) &
                t.isDeleted.equals(true) &
                t.deletionRumorJson.isNotNull() &
                t.deletionPublishStatus.equals(_deletionPending),
          )
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
        .get();
  }

  /// Look up a message by rumor event ID.
  ///
  /// Used to validate sender pubkey before applying a kind 5 deletion.
  Future<DirectMessageRow?> getMessageById(String id, {String? ownerPubkey}) {
    return (select(directMessages)..where(
          (t) => t.id.equals(id) & _ownedOrLegacy(t.ownerPubkey, ownerPubkey),
        ))
        .getSingleOrNull();
  }

  /// Check if a gift wrap event has already been processed (dedup).
  ///
  /// Intentionally NOT scoped by `ownerPubkey`: gift-wrap event IDs are
  /// globally unique per the Nostr protocol, so cross-account dedup
  /// prevents re-processing the same relay event for multiple local accounts.
  Future<bool> hasGiftWrap(String giftWrapId) async {
    final query = selectOnly(directMessages)
      ..where(directMessages.giftWrapId.equals(giftWrapId))
      ..addColumns([directMessages.id]);
    final result = await query.getSingleOrNull();
    return result != null;
  }

  /// Which of [giftWrapIds] already have a persisted message row. Batched
  /// counterpart to [hasGiftWrap]: one `IN` query instead of N single-id
  /// lookups, used by the history-drain dedup probe to avoid a per-wrap DB
  /// round trip. Like [hasGiftWrap], it is NOT scoped by `ownerPubkey`
  /// (gift-wrap IDs are globally unique). Returns an empty set for an empty
  /// input.
  Future<Set<String>> giftWrapIdsPresent(Set<String> giftWrapIds) async {
    if (giftWrapIds.isEmpty) return const <String>{};
    final query = selectOnly(directMessages)
      ..addColumns([directMessages.giftWrapId])
      ..where(directMessages.giftWrapId.isIn(giftWrapIds));
    final rows = await query.get();
    final present = <String>{};
    for (final row in rows) {
      final id = row.read(directMessages.giftWrapId);
      if (id != null) present.add(id);
    }
    return present;
  }

  /// Restricts a dedup match to rows that arrived over [counterpart]'s
  /// protocol, read off the two id columns.
  ///
  /// The NIP-04 receive path stores the wire event id in BOTH `id` and
  /// `gift_wrap_id`; every NIP-17 path stores a rumor id distinct from its
  /// gift-wrap id. Both columns are `NOT NULL`, so `id = gift_wrap_id` is a
  /// plain two-valued predicate and its negation is exact.
  Expression<bool> _arrivedOverCounterpart(DmDedupCounterpart counterpart) {
    final arrivedOverNip04 = directMessages.id.equalsExp(
      directMessages.giftWrapId,
    );
    return switch (counterpart) {
      DmDedupCounterpart.nip04Copy => arrivedOverNip04,
      DmDedupCounterpart.nip17Copy => arrivedOverNip04.not(),
      DmDedupCounterpart.unconstrained => const Constant(true),
    };
  }

  /// Whether a message with the same sender and content is already stored in
  /// [conversationId] within ±[windowSeconds] **and** arrived over the
  /// protocol named by [counterpart].
  ///
  /// This is cross-protocol dedup. A dual-send puts one message on the wire
  /// twice — a NIP-17 rumor and a NIP-04 event with unrelated ids — so
  /// [hasGiftWrap] cannot collapse them and only `(sender, content, ~time)`
  /// can.
  ///
  /// [counterpart] is what stops that heuristic eating real messages. A
  /// NIP-17 rumor is a duplicate only of a stored NIP-04 copy, and a NIP-04
  /// event only of a stored NIP-17 copy; a genuine second send of the same
  /// text seconds later is same-protocol, so it no longer matches and is kept
  /// (#7324). Same-protocol replays need no help here — the primary key on
  /// `id` and the UNIQUE index on `gift_wrap_id` already make [insertMessage]
  /// a no-op for them.
  ///
  /// Two self-authored cases need [DmDedupCounterpart.unconstrained], because
  /// both match the user's OWN persisted send rather than a cross-protocol
  /// twin. A group send's siblings carry distinct rumor ids, so the primary
  /// key does not collapse their self-wrap echoes — prefer
  /// [hasMessageWithSendBatchId] there when the batch token is available,
  /// since it matches exactly instead of heuristically. And the user's own
  /// replayed NIP-04 fallback may match a send written before #2654, which
  /// stored the gift-wrap id in both columns and so reads as NIP-04 (#8211).
  Future<bool> hasMatchingMessage({
    required String conversationId,
    required String senderPubkey,
    required String content,
    required int createdAt,
    required DmDedupCounterpart counterpart,
    int windowSeconds = 5,
    String? ownerPubkey,
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
            ) &
            _arrivedOverCounterpart(counterpart) &
            _ownedOrLegacy(directMessages.ownerPubkey, ownerPubkey),
      )
      ..addColumns([directMessages.id])
      ..limit(1);
    final result = await query.getSingleOrNull();
    return result != null;
  }

  /// Whether a message tagged with group-send [batchId] is already persisted
  /// for [ownerPubkey]. The collision-proof replacement for
  /// [hasMatchingMessage] on the group-send / recovery dedup path: a group
  /// send persists ONE local message for the whole fan-out, stamped with the
  /// batch's durable id (`DirectMessages.sendBatchId`). Recovery of a later
  /// sibling — or the happy-path persist racing a concurrent recovery — asks
  /// this to avoid inserting a second copy.
  ///
  /// Scoped by strict `owner_pubkey` equality (not `_ownedOrLegacy`): generated
  /// send ids are only stamped on the owner's sends, including self-wrap echoes
  /// received on another device, so the NULL-owner legacy branch would only
  /// widen the match with nothing to gain.
  Future<bool> hasMessageWithSendBatchId({
    required String batchId,
    required String ownerPubkey,
  }) async {
    final query = selectOnly(directMessages)
      ..where(
        directMessages.sendBatchId.equals(batchId) &
            directMessages.ownerPubkey.equals(ownerPubkey),
      )
      ..addColumns([directMessages.id])
      ..limit(1);
    final result = await query.getSingleOrNull();
    return result != null;
  }

  /// Delete all messages in a conversation.
  ///
  /// Returns the number of deleted rows.
  Future<int> deleteConversationMessages(
    String conversationId, {
    String? ownerPubkey,
  }) {
    return (delete(directMessages)..where(
          (t) =>
              t.conversationId.equals(conversationId) &
              _ownedOrLegacy(t.ownerPubkey, ownerPubkey),
        ))
        .go();
  }

  /// Delete a single message by ID.
  Future<int> deleteMessage(String id, {String? ownerPubkey}) {
    return (delete(directMessages)..where(
          (t) => t.id.equals(id) & _ownedOrLegacy(t.ownerPubkey, ownerPubkey),
        ))
        .go();
  }

  /// Delete messages for multiple conversations in a single batch.
  Future<int> deleteMultipleConversationMessages(
    List<String> conversationIds, {
    String? ownerPubkey,
  }) {
    if (conversationIds.isEmpty) return Future.value(0);
    return (delete(directMessages)..where(
          (t) =>
              t.conversationId.isIn(conversationIds) &
              _ownedOrLegacy(t.ownerPubkey, ownerPubkey),
        ))
        .go();
  }

  /// Move all messages from one conversation to another.
  ///
  /// Used when merging duplicate conversations into a canonical one.
  Future<int> reassignConversation({
    required String fromConversationId,
    required String toConversationId,
    String? ownerPubkey,
  }) {
    return (update(directMessages)..where(
          (t) =>
              t.conversationId.equals(fromConversationId) &
              _ownedOrLegacy(t.ownerPubkey, ownerPubkey),
        ))
        .write(
          DirectMessagesCompanion(conversationId: Value(toConversationId)),
        );
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

  /// Run a callback inside a database transaction.
  Future<T> runInTransaction<T>(Future<T> Function() action) {
    return attachedDatabase.transaction(action);
  }

  /// Deletes DMs for the departing account plus unattributed legacy rows.
  ///
  /// Ambiguous rows must never cross an account boundary and become visible to
  /// the incoming account. Rows owned by every other known account survive.
  Future<int> clearForAccountSwitch(String ownerPubkey) {
    return (delete(directMessages)..where(
          (t) =>
              t.ownerPubkey.equals(ownerPubkey) |
              t.ownerPubkey.isNull() |
              t.ownerPubkey.equals(''),
        ))
        .go();
  }

  /// Deletes only unattributed legacy rows when the departing account is
  /// unknown, preserving every row with a valid owner.
  Future<int> clearUnowned() {
    return (delete(
      directMessages,
    )..where((t) => t.ownerPubkey.isNull() | t.ownerPubkey.equals(''))).go();
  }
}
