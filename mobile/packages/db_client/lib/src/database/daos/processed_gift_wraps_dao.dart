// ABOUTME: Data Access Object for the processed-gift-wrap dedup ledger.
// ABOUTME: Records terminally-processed kind-1059 wrap ids so they never
// ABOUTME: re-decrypt on a later launch. See #5452.

import 'package:db_client/db_client.dart';
import 'package:drift/drift.dart';

part 'processed_gift_wraps_dao.g.dart';

@DriftAccessor(tables: [ProcessedGiftWraps])
class ProcessedGiftWrapsDao extends DatabaseAccessor<AppDatabase>
    with _$ProcessedGiftWrapsDaoMixin {
  ProcessedGiftWrapsDao(super.attachedDatabase);

  /// Has the gift wrap [giftWrapId] already been terminally processed?
  ///
  /// Global (NOT owner-scoped): gift-wrap event ids are globally unique, so a
  /// wrap processed under any local account dedups for all of them — matching
  /// [DirectMessagesDao.hasGiftWrap].
  Future<bool> hasGiftWrap(String giftWrapId) async {
    final query = selectOnly(processedGiftWraps)
      ..addColumns([processedGiftWraps.giftWrapId])
      ..where(processedGiftWraps.giftWrapId.equals(giftWrapId))
      ..limit(1);
    return (await query.get()).isNotEmpty;
  }

  /// Records [giftWrapId] as terminally processed (idempotent — a re-delivered
  /// wrap or a concurrent writer never throws). [ownerPubkey] is informational
  /// only — not part of the dedup key, and not used to scope deletes (cleanup
  /// is global via [clearAll]).
  Future<void> record({
    required String giftWrapId,
    String? ownerPubkey,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await into(processedGiftWraps).insert(
      ProcessedGiftWrapsCompanion.insert(
        giftWrapId: giftWrapId,
        processedAt: now,
        ownerPubkey: Value(ownerPubkey),
      ),
      mode: InsertMode.insertOrIgnore,
    );
  }

  /// Removes every processed-wrap row. Called during account cleanup (switch /
  /// destructive sign-out) alongside the other DM-table wipes so a stale ledger
  /// can never suppress re-population of an account's reactions/deletions.
  Future<int> clearAll() => delete(processedGiftWraps).go();

  /// Total processed-wrap rows (diagnostics / tests).
  Future<int> count() async {
    final rows = await select(processedGiftWraps).get();
    return rows.length;
  }
}
