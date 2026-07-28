// ABOUTME: Data Access Object for pubkeys with a NIP-62 request to vanish.
// ABOUTME: Durable so a deleted account stays evicted across app restarts.

import 'package:db_client/db_client.dart';
import 'package:drift/drift.dart';

part 'vanished_profiles_dao.g.dart';

@DriftAccessor(tables: [VanishedProfiles])
class VanishedProfilesDao extends DatabaseAccessor<AppDatabase>
    with _$VanishedProfilesDaoMixin {
  VanishedProfilesDao(super.attachedDatabase);

  /// Records that [pubkey] has requested deletion.
  ///
  /// Idempotent: re-marking an already-vanished pubkey refreshes
  /// `detected_at` rather than failing.
  Future<void> markVanished(String pubkey, {DateTime? detectedAt}) {
    return into(vanishedProfiles).insertOnConflictUpdate(
      VanishedProfilesCompanion.insert(
        pubkey: pubkey,
        detectedAt: detectedAt ?? DateTime.now(),
      ),
    );
  }

  /// Forgets that [pubkey] ever vanished.
  ///
  /// Called when the server reports the account as live again, so a wrong
  /// `deleted: true` is recoverable instead of erasing the user from this
  /// device permanently.
  Future<int> clearVanished(String pubkey) {
    return (delete(
      vanishedProfiles,
    )..where((t) => t.pubkey.equals(pubkey))).go();
  }

  /// Whether [pubkey] is known to have requested deletion.
  Future<bool> isVanished(String pubkey) async {
    final query = select(vanishedProfiles)
      ..where((t) => t.pubkey.equals(pubkey))
      ..limit(1);
    return await query.getSingleOrNull() != null;
  }

  /// Emits whether [pubkey] is vanished, and again whenever that changes.
  Stream<bool> watchIsVanished(String pubkey) {
    final query = select(vanishedProfiles)
      ..where((t) => t.pubkey.equals(pubkey))
      ..limit(1);
    return query.watchSingleOrNull().map((row) => row != null).distinct();
  }

  /// Every vanished pubkey, for warming an in-memory set at startup.
  Future<List<String>> getAllPubkeys() async {
    final rows = await select(vanishedProfiles).get();
    return rows.map((row) => row.pubkey).toList();
  }

  /// Clears every vanished-profile row.
  ///
  /// Test and maintenance affordance only. Production must not call this on
  /// logout or account switch — see [VanishedProfiles].
  Future<int> clearAll() {
    return delete(vanishedProfiles).go();
  }
}
