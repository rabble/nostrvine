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
  /// kind the tags came from (10011 or 0).
  Future<void> upsertEvent({
    required String pubkey,
    required String tagsJson,
    required int sourceKind,
  }) {
    return into(identityEvents).insertOnConflictUpdate(
      IdentityEventsCompanion.insert(
        pubkey: pubkey,
        tagsJson: tagsJson,
        sourceKind: sourceKind,
      ),
    );
  }

  /// Returns the cached identity-claims source for [pubkey], or null.
  Future<IdentityEventRow?> getEvent(String pubkey) {
    final query = select(identityEvents)..where((t) => t.pubkey.equals(pubkey));
    return query.getSingleOrNull();
  }

  /// Clears every cached identity-claims source row.
  Future<int> clearAll() {
    return delete(identityEvents).go();
  }
}
