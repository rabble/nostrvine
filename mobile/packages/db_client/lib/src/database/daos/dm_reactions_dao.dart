// ABOUTME: DAO for NIP-25 emoji reactions on NIP-17 direct messages.
// ABOUTME: Handles optimistic insert + placeholder swap, soft-delete on
// ABOUTME: supersede or NIP-09, and reactive watch for chip rendering.

import 'package:db_client/db_client.dart';
import 'package:drift/drift.dart';

part 'dm_reactions_dao.g.dart';

/// DAO for the `dm_message_reactions` table.
///
/// Two write paths, both enforcing the cap-at-one storage invariant (#5419):
/// at most one live reaction per `(target_message_id, reactor_pubkey,
/// owner_pubkey)`, backed by the partial unique index
/// `idx_dm_reactions_unique_live`.
/// - **Outgoing**: [insertOwnReactionSuperseding] soft-deletes any prior live
///   reaction by this reactor on the target, then writes a row with a
///   placeholder id plus `publishStatus = 'pending'` and the serialized rumor
///   JSON — all in one transaction. Once the publish lands, [swapPlaceholderId]
///   marks the row `'sent'` and clears the JSON.
/// - **Incoming**: [upsertIncoming] de-dups on `(id, owner_pubkey)` (the rumor
///   id is stable across the recipient and self gift-wraps) and collapses a
///   new-id same-tuple reaction to the most recent, soft-deleting the loser so
///   the live set stays capped at one.
@DriftAccessor(tables: [DmMessageReactions])
class DmReactionsDao extends DatabaseAccessor<AppDatabase>
    with _$DmReactionsDaoMixin {
  DmReactionsDao(super.attachedDatabase);

  /// `publish_status` value for a soft-deleted own reaction whose NIP-09
  /// kind-5 deletion still needs durable (re)delivery. The row is
  /// `is_deleted = 1` (hidden from the chip) but keeps its stored deletion
  /// rumor in `rumor_event_json` so the retry sweep can re-drive it.
  static const String _deletionPendingStatus = 'deletion_pending';

  /// Terminal `publish_status` for a deletion whose kind-5 reached a relay.
  static const String _deletionSentStatus = 'deletion_sent';

  /// Terminal `publish_status` for an outgoing reaction the send policy (#176
  /// protected-minor DM restriction) refused. Not retryable — excluded from
  /// [getRetryableOwnReactions] — since retrying only re-hits the same policy.
  static const String _blockedStatus = 'blocked';

  /// Insert an optimistic outgoing row before the publish attempt, atomically
  /// superseding any prior LIVE reactions by this reactor on this target.
  ///
  /// [placeholderId] is the rumor id used while the publish is in flight; once
  /// it lands, call [swapPlaceholderId] to mark the row `sent`.
  ///
  /// Enforces the cap-at-one storage invariant (#5419) at the write boundary:
  /// in one transaction it soft-deletes every prior live row for
  /// `(targetMessageId, reactorPubkey, ownerPubkey)` and then inserts the new
  /// pending row. The partial unique index `idx_dm_reactions_unique_live` is
  /// the backstop. The final insert uses [InsertMode.insertOrIgnore] so a
  /// concurrent second cubit's racing insert is a silent no-op (cap holds, no
  /// crash) instead of a UNIQUE-constraint throw — the dual-cubit race the
  /// issue targets.
  ///
  /// One narrow path bypasses that ignore: re-reacting the same emoji within
  /// one wall-clock second of removing it rebuilds a byte-identical rumor id,
  /// which collides with the row just soft-deleted by `removeOwn`. That row is
  /// resurrected (flipped live, `publishStatus = 'pending'`) rather than
  /// dropped, so the re-reaction is not silently lost.
  ///
  /// Returns the ids of the superseded prior live rows so the caller can emit
  /// NIP-09 kind-5 deletions on the wire (outside this transaction).
  Future<List<String>> insertOwnReactionSuperseding({
    required String placeholderId,
    required String conversationId,
    required String targetMessageId,
    required String targetMessageAuthor,
    required String reactorPubkey,
    required String emoji,
    required int createdAt,
    required String ownerPubkey,
    required String rumorEventJson,
  }) {
    return transaction(() async {
      final priors =
          await (select(dmMessageReactions)..where(
                (t) =>
                    t.targetMessageId.equals(targetMessageId) &
                    t.reactorPubkey.equals(reactorPubkey) &
                    t.ownerPubkey.equals(ownerPubkey) &
                    t.isDeleted.equals(false),
              ))
              .get();
      final superseded = <String>[];
      for (final prior in priors) {
        if (prior.id == placeholderId) continue;
        await (update(dmMessageReactions)..where(
              (t) => t.id.equals(prior.id) & t.ownerPubkey.equals(ownerPubkey),
            ))
            .write(const DmMessageReactionsCompanion(isDeleted: Value(true)));
        superseded.add(prior.id);
      }

      // A react → remove → re-react with the SAME emoji inside one wall-clock
      // second rebuilds an identical rumor id, so [placeholderId] collides
      // with the row just soft-deleted by `removeOwn`. That row is excluded
      // from `priors` (live-only), so the [InsertMode.insertOrIgnore] below
      // would discard this *wanted* re-reaction against the primary key.
      // Resurrect it instead. Scoped to `is_deleted = 1` so a still-live
      // same-id row (idempotent double-tap) keeps its publish status and is
      // left to the no-op insert.
      final resurrected =
          await (update(dmMessageReactions)..where(
                (t) =>
                    t.id.equals(placeholderId) &
                    t.ownerPubkey.equals(ownerPubkey) &
                    t.isDeleted.equals(true),
              ))
              .write(
                DmMessageReactionsCompanion(
                  isDeleted: const Value(false),
                  publishStatus: const Value('pending'),
                  rumorEventJson: Value(rumorEventJson),
                  giftWrapId: const Value(null),
                ),
              );
      if (resurrected > 0) {
        return superseded;
      }

      await into(dmMessageReactions).insert(
        DmMessageReactionsCompanion.insert(
          id: placeholderId,
          conversationId: conversationId,
          targetMessageId: targetMessageId,
          targetMessageAuthor: targetMessageAuthor,
          reactorPubkey: reactorPubkey,
          emoji: emoji,
          createdAt: createdAt,
          ownerPubkey: ownerPubkey,
          giftWrapId: const Value(null),
          rumorEventJson: Value(rumorEventJson),
          publishStatus: const Value('pending'),
        ),
        mode: InsertMode.insertOrIgnore,
      );
      return superseded;
    });
  }

  /// Swap the placeholder id for the real rumor event id once publish
  /// landed. Clears `rumorEventJson` (no longer needed for retry) and
  /// marks `publishStatus = 'sent'`.
  Future<void> swapPlaceholderId({
    required String placeholderId,
    required String realRumorId,
    required String ownerPubkey,
    String? giftWrapId,
  }) async {
    await (update(dmMessageReactions)..where(
          (t) => t.id.equals(placeholderId) & t.ownerPubkey.equals(ownerPubkey),
        ))
        .write(
          DmMessageReactionsCompanion(
            id: Value(realRumorId),
            giftWrapId: Value(giftWrapId),
            rumorEventJson: const Value(null),
            publishStatus: const Value('sent'),
          ),
        );
  }

  /// Mark an outgoing row as `'failed'` after a publish attempt threw.
  /// Keeps the `rumorEventJson` for retry.
  Future<void> markFailed({
    required String placeholderId,
    required String ownerPubkey,
  }) async {
    await (update(dmMessageReactions)..where(
          (t) => t.id.equals(placeholderId) & t.ownerPubkey.equals(ownerPubkey),
        ))
        .write(
          const DmMessageReactionsCompanion(publishStatus: Value('failed')),
        );
  }

  /// Mark an outgoing row as `'pending'` — used by retry to surface
  /// in-flight state in the persistent layer so a cubit rebuild
  /// (auth flip, hot-restart, navigation) recovers the correct UI.
  Future<void> markPending({
    required String id,
    required String ownerPubkey,
  }) async {
    await (update(
      dmMessageReactions,
    )..where((t) => t.id.equals(id) & t.ownerPubkey.equals(ownerPubkey))).write(
      const DmMessageReactionsCompanion(publishStatus: Value('pending')),
    );
  }

  /// Mark an outgoing row terminally `'blocked'` — the send policy refused the
  /// recipient (#176). Clears `rumorEventJson` so the row can never be selected
  /// by [getRetryableOwnReactions] (which requires a stored rumor), making the
  /// block terminal on both the status and the rumor-presence predicate.
  Future<void> markBlocked({
    required String id,
    required String ownerPubkey,
  }) async {
    await (update(dmMessageReactions)..where(
          (t) => t.id.equals(id) & t.ownerPubkey.equals(ownerPubkey),
        ))
        .write(
          const DmMessageReactionsCompanion(
            publishStatus: Value(_blockedStatus),
            rumorEventJson: Value(null),
          ),
        );
  }

  /// Soft-delete a row (NIP-09 kind 5 deletion received, or own-reaction
  /// supersede when toggling a different emoji).
  Future<int> softDelete({
    required String id,
    required String ownerPubkey,
  }) async {
    return (update(dmMessageReactions)
          ..where((t) => t.id.equals(id) & t.ownerPubkey.equals(ownerPubkey)))
        .write(const DmMessageReactionsCompanion(isDeleted: Value(true)));
  }

  /// Hard-delete a failed-and-discarded pending row (long-press dismiss).
  Future<int> deleteById({
    required String id,
    required String ownerPubkey,
  }) async {
    return (delete(
      dmMessageReactions,
    )..where((t) => t.id.equals(id) & t.ownerPubkey.equals(ownerPubkey))).go();
  }

  /// Upsert an incoming reaction, enforcing the cap-at-one storage invariant
  /// (#5419) at the write boundary.
  ///
  /// - **Same rumor id** (recipient + self gift-wrap, or relay replay):
  ///   resolves on the primary key `(id, owner_pubkey)` and updates the stable
  ///   fields in place. `is_deleted` is deliberately left untouched so a prior
  ///   kind-5 removal is not resurrected by a replayed wrap.
  /// - **New rumor id, same `(target, reactor, owner)` tuple**: keeps the most
  ///   recent by `(created_at, id)`. If the incoming is newest it supersedes
  ///   (soft-deletes) the prior live rows and lands live; if an existing live
  ///   row is newer (out-of-order / replayed delivery) the incoming is recorded
  ///   as already-deleted so gift-wrap dedup and history are preserved without
  ///   violating the partial unique index `idx_dm_reactions_unique_live`.
  ///
  /// The final insert uses [InsertMode.insertOrIgnore] as a race backstop so a
  /// concurrent writer can never turn this into a UNIQUE-constraint throw.
  Future<void> upsertIncoming({
    required String id,
    required String conversationId,
    required String targetMessageId,
    required String targetMessageAuthor,
    required String reactorPubkey,
    required String emoji,
    required int createdAt,
    required String giftWrapId,
    required String ownerPubkey,
  }) {
    return transaction(() async {
      final existing =
          await (select(dmMessageReactions)
                ..where(
                  (t) => t.id.equals(id) & t.ownerPubkey.equals(ownerPubkey),
                )
                ..limit(1))
              .getSingleOrNull();
      if (existing != null) {
        // Same rumor id: update stable fields in place, never `is_deleted`.
        await into(dmMessageReactions).insertOnConflictUpdate(
          DmMessageReactionsCompanion.insert(
            id: id,
            conversationId: conversationId,
            targetMessageId: targetMessageId,
            targetMessageAuthor: targetMessageAuthor,
            reactorPubkey: reactorPubkey,
            emoji: emoji,
            createdAt: createdAt,
            ownerPubkey: ownerPubkey,
            giftWrapId: Value(giftWrapId),
          ),
        );
        return;
      }

      final liveForTuple =
          await (select(dmMessageReactions)..where(
                (t) =>
                    t.targetMessageId.equals(targetMessageId) &
                    t.reactorPubkey.equals(reactorPubkey) &
                    t.ownerPubkey.equals(ownerPubkey) &
                    t.isDeleted.equals(false),
              ))
              .get();
      final hasNewerLive = liveForTuple.any(
        (r) =>
            r.createdAt > createdAt ||
            (r.createdAt == createdAt && r.id.compareTo(id) > 0),
      );
      if (!hasNewerLive) {
        // Incoming is the newest: supersede every prior live row for the tuple.
        for (final r in liveForTuple) {
          await (update(dmMessageReactions)..where(
                (t) => t.id.equals(r.id) & t.ownerPubkey.equals(ownerPubkey),
              ))
              .write(
                const DmMessageReactionsCompanion(isDeleted: Value(true)),
              );
        }
      }
      await into(dmMessageReactions).insert(
        DmMessageReactionsCompanion.insert(
          id: id,
          conversationId: conversationId,
          targetMessageId: targetMessageId,
          targetMessageAuthor: targetMessageAuthor,
          reactorPubkey: reactorPubkey,
          emoji: emoji,
          createdAt: createdAt,
          ownerPubkey: ownerPubkey,
          giftWrapId: Value(giftWrapId),
          isDeleted: Value(hasNewerLive),
        ),
        mode: InsertMode.insertOrIgnore,
      );
    });
  }

  /// Reactive stream of every live reaction in [conversationId] for the
  /// account [ownerPubkey].
  Stream<List<DmReactionRow>> watchForConversation({
    required String conversationId,
    required String ownerPubkey,
  }) {
    final query = select(dmMessageReactions)
      ..where(
        (t) =>
            t.conversationId.equals(conversationId) &
            t.ownerPubkey.equals(ownerPubkey) &
            t.isDeleted.equals(false),
      )
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]);
    return query.watch();
  }

  /// Fetch this user's own outgoing reactions that a retry sweep should
  /// re-drive: live rows authored by [ownerPubkey] whose publish is
  /// `'failed'` or still `'pending'`, that still carry the rumor JSON needed
  /// to replay the gift wrap.
  ///
  /// Soft-deleted rows (superseded / removed) and already-`'sent'` rows (whose
  /// JSON is cleared on [swapPlaceholderId]) are excluded, so a re-driven
  /// reaction is always a genuinely undelivered one. Ordered oldest-first so
  /// retries drain in send order.
  Future<List<DmReactionRow>> getRetryableOwnReactions({
    required String ownerPubkey,
  }) {
    return (select(dmMessageReactions)
          ..where(
            (t) =>
                t.ownerPubkey.equals(ownerPubkey) &
                t.reactorPubkey.equals(ownerPubkey) &
                t.isDeleted.equals(false) &
                t.rumorEventJson.isNotNull() &
                t.publishStatus.isIn(const ['failed', 'pending']),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  /// Soft-delete an own reaction AND record its NIP-09 kind-5 deletion rumor
  /// for durable (re)delivery.
  ///
  /// The row leaves the live set immediately (`is_deleted = 1`, so the chip
  /// hides on the same frame as the tap) but keeps [deletionRumorJson] and
  /// `publish_status = 'deletion_pending'` so the retry sweep can re-drive the
  /// kind-5 until a relay confirms it — closing the gap where a removal made
  /// offline (or on a flaky relay) was silently dropped. Overloads the
  /// existing `rumor_event_json` column with the deletion rumor: the prior
  /// add-reaction rumor is no longer needed once the reaction is removed.
  Future<void> markOwnDeletionPending({
    required String id,
    required String ownerPubkey,
    required String deletionRumorJson,
  }) async {
    await (update(dmMessageReactions)..where(
          (t) => t.id.equals(id) & t.ownerPubkey.equals(ownerPubkey),
        ))
        .write(
          DmMessageReactionsCompanion(
            isDeleted: const Value(true),
            publishStatus: const Value(_deletionPendingStatus),
            rumorEventJson: Value(deletionRumorJson),
          ),
        );
  }

  /// Mark a pending own-reaction deletion as delivered: clears the stored
  /// deletion rumor and moves the row to the terminal `'deletion_sent'` status
  /// so the sweep stops re-driving it. The row stays `is_deleted = 1`.
  Future<void> markDeletionSent({
    required String id,
    required String ownerPubkey,
  }) async {
    await (update(dmMessageReactions)..where(
          (t) => t.id.equals(id) & t.ownerPubkey.equals(ownerPubkey),
        ))
        .write(
          const DmMessageReactionsCompanion(
            publishStatus: Value(_deletionSentStatus),
            rumorEventJson: Value(null),
          ),
        );
  }

  /// Fetch this user's own soft-deleted reactions whose kind-5 deletion still
  /// needs durable delivery (`publish_status = 'deletion_pending'` with a
  /// stored deletion rumor). Ordered oldest-first so removals drain in order.
  Future<List<DmReactionRow>> getRetryableOwnDeletions({
    required String ownerPubkey,
  }) {
    return (select(dmMessageReactions)
          ..where(
            (t) =>
                t.ownerPubkey.equals(ownerPubkey) &
                t.reactorPubkey.equals(ownerPubkey) &
                t.isDeleted.equals(true) &
                t.rumorEventJson.isNotNull() &
                t.publishStatus.equals(_deletionPendingStatus),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  /// Return the stored rumor JSON for a pending/failed outgoing row, or
  /// `null` if no row matches or the row has no stored rumor.
  Future<String?> getRumorJson({
    required String id,
    required String ownerPubkey,
  }) async {
    final query = select(dmMessageReactions)
      ..where((t) => t.id.equals(id) & t.ownerPubkey.equals(ownerPubkey))
      ..limit(1);
    final row = await query.getSingleOrNull();
    return row?.rumorEventJson;
  }

  /// Return a single reaction row by stable reaction rumor id, or `null`
  /// when no row matches in this account's view.
  Future<DmReactionRow?> getById({
    required String id,
    required String ownerPubkey,
  }) {
    final query = select(dmMessageReactions)
      ..where((t) => t.id.equals(id) & t.ownerPubkey.equals(ownerPubkey))
      ..limit(1);
    return query.getSingleOrNull();
  }

  /// Has the gift wrap with id `giftWrapId` already produced a row? Used by the
  /// receive pipeline to short-circuit before decryption work. Returns
  /// `true` only when a non-null match exists in this account's view.
  Future<bool> hasGiftWrap({
    required String giftWrapId,
    required String ownerPubkey,
  }) async {
    final query = selectOnly(dmMessageReactions)
      ..addColumns([dmMessageReactions.id])
      ..where(
        dmMessageReactions.giftWrapId.equals(giftWrapId) &
            dmMessageReactions.ownerPubkey.equals(ownerPubkey),
      )
      ..limit(1);
    return (await query.get()).isNotEmpty;
  }

  /// Delete everything owned by [ownerPubkey]. Sign-out cleanup.
  Future<int> deleteAllForOwner(String ownerPubkey) async {
    return (delete(
      dmMessageReactions,
    )..where((t) => t.ownerPubkey.equals(ownerPubkey))).go();
  }
}
