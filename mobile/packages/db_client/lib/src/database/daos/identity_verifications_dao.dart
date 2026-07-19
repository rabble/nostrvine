// ABOUTME: Data Access Object for the NIP-39 verification verdict cache.
// ABOUTME: One verified-claims snapshot row per profile; verified-only.

import 'package:db_client/db_client.dart';
import 'package:drift/drift.dart';

part 'identity_verifications_dao.g.dart';

@DriftAccessor(tables: [IdentityVerifications])
class IdentityVerificationsDao extends DatabaseAccessor<AppDatabase>
    with _$IdentityVerificationsDaoMixin {
  IdentityVerificationsDao(super.attachedDatabase);

  /// Upserts the verified-claims snapshot for [pubkey].
  ///
  /// [verifiedClaimsJson] is the JSON-encoded list of verified
  /// `{platform, identity, proof}` tuples; [checkedAtFloor] is the minimum
  /// verifier `checked_at` (unix seconds) across the batch.
  Future<void> upsertVerification({
    required String pubkey,
    required String verifiedClaimsJson,
    required int checkedAtFloor,
  }) {
    return into(identityVerifications).insertOnConflictUpdate(
      IdentityVerificationsCompanion.insert(
        pubkey: pubkey,
        verifiedClaimsJson: verifiedClaimsJson,
        checkedAtFloor: checkedAtFloor,
      ),
    );
  }

  /// Returns the verified-claims snapshot for [pubkey], or null.
  Future<IdentityVerificationRow?> getVerification(String pubkey) {
    final query = select(identityVerifications)
      ..where((t) => t.pubkey.equals(pubkey));
    return query.getSingleOrNull();
  }

  /// Deletes the snapshot for [pubkey]. Returns the number of rows deleted.
  Future<int> deleteVerification(String pubkey) {
    return (delete(
      identityVerifications,
    )..where((t) => t.pubkey.equals(pubkey))).go();
  }
}
