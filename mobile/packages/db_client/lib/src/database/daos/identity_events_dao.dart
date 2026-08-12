// ABOUTME: Data Access Object for the NIP-39 identity-claims source cache.
// ABOUTME: One row per profile mirroring the latest kind 10011/0 i tags.

import 'package:db_client/db_client.dart';
import 'package:drift/drift.dart';

part 'identity_events_dao.g.dart';

@DriftAccessor(tables: [IdentityEvents])
class IdentityEventsDao extends DatabaseAccessor<AppDatabase>
    with _$IdentityEventsDaoMixin {
  IdentityEventsDao(super.attachedDatabase);

  /// Upserts the identity-claims source for [pubkey].
  ///
  /// [tagsJson] is the JSON-encoded `i` tag list and [sourceKind] the event
  /// kind the tags came from (10011 or 0). [sourceCreatedAt] and
  /// [sourceEventId] identify the kind-10011 event the tags came from and are
  /// always written, including as null, so the coordinates can never describe
  /// a set of tags they did not come with.
  ///
  /// Callers decide whether a write is allowed at all: this row is a mirror of
  /// a replaceable event, so it must not be moved backwards by a relay read
  /// that is behind (#7081).
  Future<void> upsertEvent({
    required String pubkey,
    required String tagsJson,
    required int sourceKind,
    int? sourceCreatedAt,
    String? sourceEventId,
  }) {
    return into(identityEvents).insertOnConflictUpdate(
      IdentityEventsCompanion.insert(
        pubkey: pubkey,
        tagsJson: tagsJson,
        sourceKind: sourceKind,
        sourceCreatedAt: Value(sourceCreatedAt),
        sourceEventId: Value(sourceEventId),
      ),
    );
  }

  /// Returns the cached identity-claims source for [pubkey], or null.
  Future<IdentityEventRow?> getEvent(String pubkey) {
    final query = select(identityEvents)..where((t) => t.pubkey.equals(pubkey));
    return query.getSingleOrNull();
  }

  /// Deletes the cached identity-claims source for [pubkey].
  ///
  /// Used when evicting an account that requested deletion, so its claims do
  /// not outlive the profile row they belong to.
  Future<int> deleteEvent(String pubkey) {
    return (delete(identityEvents)..where((t) => t.pubkey.equals(pubkey))).go();
  }

  /// Clears every cached identity-claims source row.
  Future<int> clearAll() {
    return delete(identityEvents).go();
  }
}
