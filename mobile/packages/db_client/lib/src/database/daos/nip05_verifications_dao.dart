// ABOUTME: Data Access Object for NIP-05 verification cache operations.
// ABOUTME: Provides upsert with TTL-based expiry checking.

import 'package:db_client/db_client.dart';
import 'package:drift/drift.dart';

part 'nip05_verifications_dao.g.dart';

/// TTL durations for different verification statuses
class Nip05CacheTtl {
  /// Verified status is stable, cache for 24 hours
  static const verified = Duration(hours: 24);

  /// Failed verification, allow retry after 1 hour
  static const failed = Duration(hours: 1);

  /// Network error, retry soon (5 minutes)
  static const error = Duration(minutes: 5);

  /// Pending status, short timeout (30 seconds)
  static const pending = Duration(seconds: 30);
}

@DriftAccessor(tables: [Nip05Verifications])
class Nip05VerificationsDao extends DatabaseAccessor<AppDatabase>
    with _$Nip05VerificationsDaoMixin {
  Nip05VerificationsDao(super.attachedDatabase);

  /// Upsert a verification result with appropriate TTL
  Future<void> upsertVerification({
    required String pubkey,
    required String nip05,
    required String status,
  }) {
    final now = DateTime.now();
    final ttl = _getTtlForStatus(status);
    final expiresAt = now.add(ttl);

    return into(nip05Verifications).insertOnConflictUpdate(
      Nip05VerificationsCompanion.insert(
        pubkey: pubkey,
        nip05: nip05,
        status: status,
        verifiedAt: now,
        expiresAt: expiresAt,
      ),
    );
  }

  /// Get verification for a pubkey (returns null if not found)
  Future<Nip05VerificationRow?> getVerification(String pubkey) async {
    final query = select(nip05Verifications)
      ..where((t) => t.pubkey.equals(pubkey));
    return query.getSingleOrNull();
  }

  /// Get valid (non-expired) verification for a pubkey
  /// Returns null if not found or expired
  Future<Nip05VerificationRow?> getValidVerification(String pubkey) async {
    final result = await getVerification(pubkey);

    if (result == null) return null;

    // Check if expired
    if (result.expiresAt.isBefore(DateTime.now())) {
      // Expired - delete and return null
      await deleteVerification(pubkey);
      return null;
    }

    return result;
  }

  /// Get multiple verifications by pubkeys (for batch queries)
  Future<List<Nip05VerificationRow>> getVerifications(
    List<String> pubkeys,
  ) async {
    if (pubkeys.isEmpty) return [];

    final query = select(nip05Verifications)
      ..where((t) => t.pubkey.isIn(pubkeys));
    return query.get();
  }

  /// Get valid verifications for multiple pubkeys (filters expired)
  Future<List<Nip05VerificationRow>> getValidVerifications(
    List<String> pubkeys,
  ) async {
    if (pubkeys.isEmpty) return [];

    final now = DateTime.now();
    final query = select(nip05Verifications)
      ..where(
        (t) => t.pubkey.isIn(pubkeys) & t.expiresAt.isBiggerThanValue(now),
      );
    return query.get();
  }

  /// Delete verification for a pubkey
  Future<int> deleteVerification(String pubkey) {
    return (delete(
      nip05Verifications,
    )..where((t) => t.pubkey.equals(pubkey))).go();
  }

  /// Delete all expired verifications
  Future<int> deleteExpired() {
    final now = DateTime.now();
    return (delete(
      nip05Verifications,
    )..where((t) => t.expiresAt.isSmallerThanValue(now))).go();
  }

  /// Clear all verifications
  Future<int> clearAll() {
    return delete(nip05Verifications).go();
  }

  /// Watch verification status for a pubkey
  Stream<Nip05VerificationRow?> watchVerification(String pubkey) {
    final query = select(nip05Verifications)
      ..where((t) => t.pubkey.equals(pubkey));
    return query.watchSingleOrNull();
  }

  /// Get the appropriate TTL for a status
  Duration _getTtlForStatus(String status) {
    switch (status) {
      case 'verified':
        return Nip05CacheTtl.verified;
      case 'failed':
        return Nip05CacheTtl.failed;
      case 'error':
        return Nip05CacheTtl.error;
      case 'pending':
        return Nip05CacheTtl.pending;
      default:
        return Nip05CacheTtl.error;
    }
  }
}
