// ABOUTME: Data Access Object for the durable outgoing-DM queue.
// ABOUTME: Tracks per-wrap publish status (recipient + self gift wrap)
// ABOUTME: so partial deliveries can be retried without double-delivering.

import 'package:db_client/db_client.dart';
import 'package:drift/drift.dart';
import 'package:meta/meta.dart';

part 'outgoing_dms_dao.g.dart';

/// Status of one of the two NIP-17 gift-wrap publishes for an outgoing DM.
///
/// Each row in `outgoing_dms` carries two of these — one for the
/// recipient gift wrap and one for the self-addressed gift wrap. They
/// transition independently so a partial delivery (recipient sent, self
/// failed) can be retried without re-publishing to the recipient.
enum OutgoingWrapStatus {
  /// Not yet attempted, or attempted and waiting for a relay reply.
  pending,

  /// Published and accepted by at least one relay.
  sent,

  /// Last attempt failed. `last_error` carries the reason; the retry
  /// service will replay this wrap (only) until `retry_count` reaches
  /// the policy cap.
  failed,
}

/// Domain model for one queued outgoing DM.
///
/// Independent of [OutgoingDmRow] (the Drift-generated row) so callers
/// at the repository / service / bloc layers don't import Drift types.
@immutable
class OutgoingDm {
  const OutgoingDm({
    required this.id,
    required this.conversationId,
    required this.recipientPubkey,
    required this.content,
    required this.createdAt,
    required this.rumorEventJson,
    required this.recipientWrapStatus,
    required this.selfWrapStatus,
    required this.queuedAt,
    required this.ownerPubkey,
    this.messageKind = 14,
    this.replyToId,
    this.recipientWrapEventId,
    this.selfWrapEventId,
    this.retryCount = 0,
    this.lastError,
    this.lastAttemptAt,
  });

  /// Rumor event id (kind 14/15). Stable across retries.
  final String id;
  final String conversationId;
  final String recipientPubkey;
  final String content;
  final int createdAt;
  final String rumorEventJson;
  final int messageKind;
  final String? replyToId;
  final OutgoingWrapStatus recipientWrapStatus;
  final OutgoingWrapStatus selfWrapStatus;
  final String? recipientWrapEventId;
  final String? selfWrapEventId;
  final int retryCount;
  final String? lastError;
  final DateTime? lastAttemptAt;
  final DateTime queuedAt;
  final String ownerPubkey;

  /// Whether **both** wraps have landed. The repository deletes the
  /// queue row only when this is true (in the same transaction that
  /// inserts the corresponding `direct_messages` row).
  bool get isFullyDelivered =>
      recipientWrapStatus == OutgoingWrapStatus.sent &&
      selfWrapStatus == OutgoingWrapStatus.sent;

  /// Whether either wrap is still in a retryable failed state. The
  /// retry service uses this filter to enumerate work.
  bool get hasRetryableFailure =>
      recipientWrapStatus == OutgoingWrapStatus.failed ||
      selfWrapStatus == OutgoingWrapStatus.failed;

  OutgoingDm copyWith({
    String? id,
    String? conversationId,
    String? recipientPubkey,
    String? content,
    int? createdAt,
    String? rumorEventJson,
    int? messageKind,
    String? replyToId,
    OutgoingWrapStatus? recipientWrapStatus,
    OutgoingWrapStatus? selfWrapStatus,
    String? recipientWrapEventId,
    String? selfWrapEventId,
    int? retryCount,
    String? lastError,
    DateTime? lastAttemptAt,
    DateTime? queuedAt,
    String? ownerPubkey,
  }) => OutgoingDm(
    id: id ?? this.id,
    conversationId: conversationId ?? this.conversationId,
    recipientPubkey: recipientPubkey ?? this.recipientPubkey,
    content: content ?? this.content,
    createdAt: createdAt ?? this.createdAt,
    rumorEventJson: rumorEventJson ?? this.rumorEventJson,
    messageKind: messageKind ?? this.messageKind,
    replyToId: replyToId ?? this.replyToId,
    recipientWrapStatus: recipientWrapStatus ?? this.recipientWrapStatus,
    selfWrapStatus: selfWrapStatus ?? this.selfWrapStatus,
    recipientWrapEventId: recipientWrapEventId ?? this.recipientWrapEventId,
    selfWrapEventId: selfWrapEventId ?? this.selfWrapEventId,
    retryCount: retryCount ?? this.retryCount,
    lastError: lastError ?? this.lastError,
    lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
    queuedAt: queuedAt ?? this.queuedAt,
    ownerPubkey: ownerPubkey ?? this.ownerPubkey,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OutgoingDm && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'OutgoingDm{id: $id, conversation: $conversationId, '
      'recipient: $recipientWrapStatus, self: $selfWrapStatus, '
      'retry: $retryCount}';
}

@DriftAccessor(tables: [OutgoingDms])
class OutgoingDmsDao extends DatabaseAccessor<AppDatabase>
    with _$OutgoingDmsDaoMixin {
  OutgoingDmsDao(super.attachedDatabase);

  // ---------------------------------------------------------------------
  // Mapping
  // ---------------------------------------------------------------------

  OutgoingDmsCompanion _modelToCompanion(OutgoingDm dm) {
    return OutgoingDmsCompanion.insert(
      id: dm.id,
      conversationId: dm.conversationId,
      recipientPubkey: dm.recipientPubkey,
      content: dm.content,
      createdAt: dm.createdAt,
      rumorEventJson: dm.rumorEventJson,
      messageKind: Value(dm.messageKind),
      replyToId: Value(dm.replyToId),
      recipientWrapStatus: dm.recipientWrapStatus.name,
      selfWrapStatus: dm.selfWrapStatus.name,
      recipientWrapEventId: Value(dm.recipientWrapEventId),
      selfWrapEventId: Value(dm.selfWrapEventId),
      retryCount: Value(dm.retryCount),
      lastError: Value(dm.lastError),
      lastAttemptAt: Value(dm.lastAttemptAt),
      queuedAt: dm.queuedAt,
      ownerPubkey: dm.ownerPubkey,
    );
  }

  OutgoingDm _rowToModel(OutgoingDmRow row) {
    return OutgoingDm(
      id: row.id,
      conversationId: row.conversationId,
      recipientPubkey: row.recipientPubkey,
      content: row.content,
      createdAt: row.createdAt,
      rumorEventJson: row.rumorEventJson,
      messageKind: row.messageKind,
      replyToId: row.replyToId,
      recipientWrapStatus: _parseStatus(row.recipientWrapStatus),
      selfWrapStatus: _parseStatus(row.selfWrapStatus),
      recipientWrapEventId: row.recipientWrapEventId,
      selfWrapEventId: row.selfWrapEventId,
      retryCount: row.retryCount,
      lastError: row.lastError,
      lastAttemptAt: row.lastAttemptAt,
      queuedAt: row.queuedAt,
      ownerPubkey: row.ownerPubkey,
    );
  }

  OutgoingWrapStatus _parseStatus(String raw) =>
      OutgoingWrapStatus.values.firstWhere(
        (e) => e.name == raw,
        orElse: () => OutgoingWrapStatus.pending,
      );

  // ---------------------------------------------------------------------
  // Writes
  // ---------------------------------------------------------------------

  /// Enqueue a new outgoing DM with both wraps in [OutgoingWrapStatus.pending].
  ///
  /// Uses `INSERT OR REPLACE` semantics via `insertOnConflictUpdate` so that
  /// a retry which re-enqueues the same rumor id is a safe no-op (the row
  /// already exists, and the PRIMARY KEY clash is resolved by replacing the
  /// row with the same id — which is the same logical row).
  Future<void> enqueue(OutgoingDm dm) {
    return into(outgoingDms).insertOnConflictUpdate(_modelToCompanion(dm));
  }

  /// Update the recipient gift-wrap status for [id]. Pass [eventId] when
  /// transitioning to [OutgoingWrapStatus.sent] so the published id is
  /// recorded for downstream debugging.
  Future<bool> markRecipientWrapStatus({
    required String id,
    required OutgoingWrapStatus status,
    String? eventId,
    String? lastError,
  }) async {
    final rows = await (update(outgoingDms)..where((t) => t.id.equals(id)))
        .write(
          OutgoingDmsCompanion(
            recipientWrapStatus: Value(status.name),
            recipientWrapEventId: eventId != null
                ? Value(eventId)
                : const Value.absent(),
            lastError: lastError != null
                ? Value(lastError)
                : const Value.absent(),
            lastAttemptAt: Value(DateTime.now()),
          ),
        );
    return rows > 0;
  }

  /// Update the self-addressed gift-wrap status for [id].
  Future<bool> markSelfWrapStatus({
    required String id,
    required OutgoingWrapStatus status,
    String? eventId,
    String? lastError,
  }) async {
    final rows = await (update(outgoingDms)..where((t) => t.id.equals(id)))
        .write(
          OutgoingDmsCompanion(
            selfWrapStatus: Value(status.name),
            selfWrapEventId: eventId != null
                ? Value(eventId)
                : const Value.absent(),
            lastError: lastError != null
                ? Value(lastError)
                : const Value.absent(),
            lastAttemptAt: Value(DateTime.now()),
          ),
        );
    return rows > 0;
  }

  /// Increment the retry count for [id]. The retry service calls this
  /// after scheduling a replay regardless of the eventual outcome —
  /// backoff caps growth at the policy max.
  Future<bool> incrementRetry(String id) async {
    final rows = await customUpdate(
      'UPDATE outgoing_dms SET retry_count = retry_count + 1, '
      'last_attempt_at = ? WHERE id = ?',
      variables: [
        Variable<int>(DateTime.now().millisecondsSinceEpoch),
        Variable<String>(id),
      ],
      updates: {outgoingDms},
    );
    return rows > 0;
  }

  /// Delete the row for [id]. Called by the repository in the same
  /// transaction that promotes the message to `direct_messages` once
  /// both wraps are sent (atomicity prevents a watcher window where the
  /// message is in neither table) — and called directly by the user's
  /// "Cancel send" action while the message is still pending or failed.
  Future<int> deleteById(String id) {
    return (delete(outgoingDms)..where((t) => t.id.equals(id))).go();
  }

  // ---------------------------------------------------------------------
  // Reads
  // ---------------------------------------------------------------------

  /// Fetch the queue row for [id], or `null` if not enqueued.
  Future<OutgoingDm?> getById(String id) async {
    final query = select(outgoingDms)..where((t) => t.id.equals(id));
    final row = await query.getSingleOrNull();
    return row == null ? null : _rowToModel(row);
  }

  /// Watch every row in [conversationId] for the given account, newest
  /// first. Empty stream if no enqueued sends.
  ///
  /// The conversation BLoC merges this with `watchMessagesForConversation`
  /// to render a unified timeline including pending / failed bubbles.
  Stream<List<OutgoingDm>> watchForConversation({
    required String conversationId,
    required String ownerPubkey,
  }) {
    final query = select(outgoingDms)
      ..where(
        (t) =>
            t.conversationId.equals(conversationId) &
            t.ownerPubkey.equals(ownerPubkey),
      )
      ..orderBy([
        (t) => OrderingTerm(
          expression: t.createdAt,
          mode: OrderingMode.desc,
        ),
      ]);
    return query.watch().map((rows) => rows.map(_rowToModel).toList());
  }

  /// Watch every row for the given account, oldest first.
  ///
  /// Used by the retry service / a future "X messages failed" badge in
  /// the inbox app bar.
  Stream<List<OutgoingDm>> watchAllForOwner(String ownerPubkey) {
    final query = select(outgoingDms)
      ..where((t) => t.ownerPubkey.equals(ownerPubkey))
      ..orderBy([(t) => OrderingTerm(expression: t.queuedAt)]);
    return query.watch().map((rows) => rows.map(_rowToModel).toList());
  }

  /// Fetch all rows for [ownerPubkey] where at least one wrap is still
  /// in [OutgoingWrapStatus.failed]. Excludes rows that have exhausted
  /// the retry budget (caller decides what to do with those, typically
  /// surface a manual retry affordance).
  Future<List<OutgoingDm>> getRetryableForOwner({
    required String ownerPubkey,
    required int maxRetries,
  }) async {
    final query = select(outgoingDms)
      ..where(
        (t) =>
            t.ownerPubkey.equals(ownerPubkey) &
            t.retryCount.isSmallerThanValue(maxRetries) &
            (t.recipientWrapStatus.equals(OutgoingWrapStatus.failed.name) |
                t.selfWrapStatus.equals(OutgoingWrapStatus.failed.name)),
      )
      ..orderBy([(t) => OrderingTerm(expression: t.queuedAt)]);
    final rows = await query.get();
    return rows.map(_rowToModel).toList();
  }

  /// Fetch all rows for [ownerPubkey] still in
  /// [OutgoingWrapStatus.pending] for either wrap. Used to recover
  /// in-flight sends after an app kill that interrupted the publish
  /// before the row could be marked sent or failed.
  Future<List<OutgoingDm>> getStillPendingForOwner(String ownerPubkey) async {
    final query = select(outgoingDms)
      ..where(
        (t) =>
            t.ownerPubkey.equals(ownerPubkey) &
            (t.recipientWrapStatus.equals(OutgoingWrapStatus.pending.name) |
                t.selfWrapStatus.equals(OutgoingWrapStatus.pending.name)),
      )
      ..orderBy([(t) => OrderingTerm(expression: t.queuedAt)]);
    final rows = await query.get();
    return rows.map(_rowToModel).toList();
  }
}
