// ABOUTME: Data Access Object for the durable failed-decrypt gift-wrap queue.
// ABOUTME: Persists raw kind-1059 wraps that failed decryption, for retry.

import 'package:db_client/db_client.dart';
import 'package:drift/drift.dart';
import 'package:meta/meta.dart';

part 'pending_gift_wraps_dao.g.dart';

/// A gift wrap that failed decryption and is queued for a later retry.
@immutable
class PendingGiftWrap {
  const PendingGiftWrap({
    required this.giftWrapId,
    required this.ownerPubkey,
    required this.rawJson,
    required this.createdAt,
    this.attempts = 0,
    this.lastAttemptAt,
  });

  final String giftWrapId;
  final String ownerPubkey;
  final String rawJson;
  final int createdAt;
  final int attempts;
  final int? lastAttemptAt;
}

@DriftAccessor(tables: [PendingGiftWraps])
class PendingGiftWrapsDao extends DatabaseAccessor<AppDatabase>
    with _$PendingGiftWrapsDaoMixin {
  PendingGiftWrapsDao(super.attachedDatabase);

  /// Records a failed decryption for [giftWrapId]. Inserts a new row
  /// (attempts = 1) or increments the attempt count of an existing one.
  /// The raw event is stored only on first insert.
  Future<void> recordFailedDecrypt({
    required String giftWrapId,
    required String ownerPubkey,
    required String rawJson,
    required int createdAt,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await transaction(() async {
      final existing =
          await (select(pendingGiftWraps)..where(
                (t) =>
                    t.giftWrapId.equals(giftWrapId) &
                    t.ownerPubkey.equals(ownerPubkey),
              ))
              .getSingleOrNull();
      if (existing == null) {
        await into(pendingGiftWraps).insert(
          PendingGiftWrapsCompanion.insert(
            giftWrapId: giftWrapId,
            ownerPubkey: ownerPubkey,
            rawJson: rawJson,
            createdAt: createdAt,
            attempts: const Value(1),
            lastAttemptAt: Value(now),
          ),
        );
      } else {
        await (update(pendingGiftWraps)..where(
              (t) =>
                  t.giftWrapId.equals(giftWrapId) &
                  t.ownerPubkey.equals(ownerPubkey),
            ))
            .write(
              PendingGiftWrapsCompanion(
                attempts: Value(existing.attempts + 1),
                lastAttemptAt: Value(now),
              ),
            );
      }
    });
  }

  /// Removes the pending row for [giftWrapId] (no-op if absent). Called when
  /// a wrap finally decrypts or is otherwise resolved.
  Future<void> deletePending({
    required String giftWrapId,
    required String ownerPubkey,
  }) async {
    await (delete(pendingGiftWraps)..where(
          (t) =>
              t.giftWrapId.equals(giftWrapId) &
              t.ownerPubkey.equals(ownerPubkey),
        ))
        .go();
  }

  /// Deletes rows for [ownerPubkey] that have reached [maxAttempts] — wraps
  /// declared permanently undecryptable. Bounds queue growth so a
  /// never-decryptable or spammed gift wrap cannot accumulate forever.
  Future<int> deleteExhausted({
    required String ownerPubkey,
    required int maxAttempts,
  }) {
    return (delete(pendingGiftWraps)..where(
          (t) =>
              t.ownerPubkey.equals(ownerPubkey) &
              t.attempts.isBiggerOrEqualValue(maxAttempts),
        ))
        .go();
  }

  /// Removes every pending row. Called during account cleanup (switch /
  /// destructive sign-out) alongside the other DM-table wipes so an account's
  /// raw (still-encrypted) gift wraps never outlive its decrypted DM data.
  Future<int> clearAll() => delete(pendingGiftWraps).go();

  /// Returns rows for [ownerPubkey] still below [maxAttempts], newest first
  /// (so recent conversations are recovered before older ones).
  Future<List<PendingGiftWrap>> getRetryable({
    required String ownerPubkey,
    required int maxAttempts,
  }) async {
    final rows =
        await (select(pendingGiftWraps)
              ..where(
                (t) =>
                    t.ownerPubkey.equals(ownerPubkey) &
                    t.attempts.isSmallerThanValue(maxAttempts),
              )
              ..orderBy([
                (t) => OrderingTerm(
                  expression: t.createdAt,
                  mode: OrderingMode.desc,
                ),
              ]))
            .get();
    return rows.map(_rowToModel).toList();
  }

  /// Total pending rows for [ownerPubkey] (diagnostics / tests).
  Future<int> countForOwner(String ownerPubkey) async {
    final rows = await (select(
      pendingGiftWraps,
    )..where((t) => t.ownerPubkey.equals(ownerPubkey))).get();
    return rows.length;
  }

  PendingGiftWrap _rowToModel(PendingGiftWrapRow row) => PendingGiftWrap(
    giftWrapId: row.giftWrapId,
    ownerPubkey: row.ownerPubkey,
    rawJson: row.rawJson,
    createdAt: row.createdAt,
    attempts: row.attempts,
    lastAttemptAt: row.lastAttemptAt,
  );
}
