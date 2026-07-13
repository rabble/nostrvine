// ABOUTME: Data Access Object for the durable single-row-per-user
// ABOUTME: pending profile/username save slot (#3161). Holds a kind-0
// ABOUTME: save whose relay publish is not yet confirmed, for background
// ABOUTME: re-drive on connectivity/foreground.

import 'package:db_client/db_client.dart';
import 'package:drift/drift.dart';
import 'package:meta/meta.dart';

part 'pending_profile_saves_dao.g.dart';

/// Lifecycle status of a queued profile save.
enum PendingProfileSaveStatus {
  /// Queued, waiting for the retry service to attempt the publish.
  pending,

  /// A publish attempt is currently in flight.
  syncing,

  /// The publish has failed past the retry policy cap. The UI surfaces a
  /// manual retry affordance; the row is kept so the user can re-drive it.
  failed,
}

/// Thrown when [PendingProfileSavesDao] reads a row whose persisted status
/// string does not match any known [PendingProfileSaveStatus].
///
/// Signals database corruption or a downgrade from a future schema. The DAO
/// refuses to coerce the unknown value back to
/// [PendingProfileSaveStatus.pending] — that would silently re-activate a row
/// a newer client already moved to a terminal state.
class UnknownPendingProfileSaveStatusException implements Exception {
  const UnknownPendingProfileSaveStatusException(this.rawValue);

  /// The raw string read from the database that did not parse.
  final String rawValue;

  @override
  String toString() {
    final known = PendingProfileSaveStatus.values.map((e) => e.name).join(', ');
    return 'UnknownPendingProfileSaveStatusException: '
        'unrecognised pending_profile_saves status "$rawValue"; '
        'expected one of $known';
  }
}

/// Domain model for the single queued profile save of one account.
///
/// Independent of [PendingProfileSaveRow] (the Drift-generated row) so
/// callers at the repository / service / bloc layers don't import Drift
/// types. [payloadJson] is opaque here — the repository owns its shape.
@immutable
class PendingProfileSaveEntry {
  const PendingProfileSaveEntry({
    required this.userPubkey,
    required this.payloadJson,
    required this.queuedAt,
    this.claimConfirmed = false,
    this.status = PendingProfileSaveStatus.pending,
    this.retryCount = 0,
    this.lastAttemptAt,
    this.lastError,
  });

  final String userPubkey;
  final String payloadJson;
  final bool claimConfirmed;
  final PendingProfileSaveStatus status;
  final int retryCount;
  final DateTime? lastAttemptAt;
  final DateTime queuedAt;
  final String? lastError;
}

@DriftAccessor(tables: [PendingProfileSaves])
class PendingProfileSavesDao extends DatabaseAccessor<AppDatabase>
    with _$PendingProfileSavesDaoMixin {
  PendingProfileSavesDao(super.attachedDatabase);

  // ---------------------------------------------------------------------
  // Mapping
  // ---------------------------------------------------------------------

  PendingProfileSavesCompanion _modelToCompanion(PendingProfileSaveEntry e) {
    return PendingProfileSavesCompanion.insert(
      userPubkey: e.userPubkey,
      payloadJson: e.payloadJson,
      claimConfirmed: Value(e.claimConfirmed),
      status: Value(e.status.name),
      retryCount: Value(e.retryCount),
      lastAttemptAt: Value(e.lastAttemptAt),
      queuedAt: e.queuedAt,
      lastError: Value(e.lastError),
    );
  }

  PendingProfileSaveEntry _rowToModel(PendingProfileSaveRow row) {
    return PendingProfileSaveEntry(
      userPubkey: row.userPubkey,
      payloadJson: row.payloadJson,
      claimConfirmed: row.claimConfirmed,
      status: _parseStatus(row.status),
      retryCount: row.retryCount,
      lastAttemptAt: row.lastAttemptAt,
      queuedAt: row.queuedAt,
      lastError: row.lastError,
    );
  }

  /// Parse a persisted status string back to [PendingProfileSaveStatus].
  ///
  /// Throws [UnknownPendingProfileSaveStatusException] on an unrecognised
  /// value rather than coercing it to [PendingProfileSaveStatus.pending].
  PendingProfileSaveStatus _parseStatus(String raw) {
    for (final status in PendingProfileSaveStatus.values) {
      if (status.name == raw) return status;
    }
    throw UnknownPendingProfileSaveStatusException(raw);
  }

  // ---------------------------------------------------------------------
  // Writes
  // ---------------------------------------------------------------------

  /// Upsert the pending save for one account — **latest intent wins**.
  ///
  /// Uses `INSERT OR REPLACE` on the `user_pubkey` primary key, so a fresh
  /// save replaces any in-flight row and resets its retry budget/status to
  /// the new [entry]'s values. Correct because kind 0 is replaceable: only
  /// the newest edit matters.
  Future<void> upsert(PendingProfileSaveEntry entry) async {
    await into(pendingProfileSaves).insert(
      _modelToCompanion(entry),
      mode: InsertMode.insertOrReplace,
    );
  }

  /// Update the status for [userPubkey]. Pass [lastError] when moving to
  /// [PendingProfileSaveStatus.failed]. Stamps `last_attempt_at`.
  Future<bool> markStatus({
    required String userPubkey,
    required PendingProfileSaveStatus status,
    String? lastError,
  }) async {
    final rows =
        await (update(
          pendingProfileSaves,
        )..where((t) => t.userPubkey.equals(userPubkey))).write(
          PendingProfileSavesCompanion(
            status: Value(status.name),
            lastError: lastError != null
                ? Value(lastError)
                : const Value.absent(),
            lastAttemptAt: Value(DateTime.now()),
          ),
        );
    return rows > 0;
  }

  /// Mark the claim confirmed for [userPubkey] so re-drives skip the
  /// (idempotent) HTTP claim round-trip.
  Future<bool> markClaimConfirmed(String userPubkey) async {
    final rows =
        await (update(
          pendingProfileSaves,
        )..where((t) => t.userPubkey.equals(userPubkey))).write(
          const PendingProfileSavesCompanion(claimConfirmed: Value(true)),
        );
    return rows > 0;
  }

  /// Increment the retry count for [userPubkey] and stamp `last_attempt_at`.
  /// Read-then-write inside a transaction so the [DateTime] write goes
  /// through the same codec as [markStatus] (seconds-since-epoch).
  Future<bool> incrementRetry(String userPubkey) async {
    return transaction(() async {
      final row = await (select(
        pendingProfileSaves,
      )..where((t) => t.userPubkey.equals(userPubkey))).getSingleOrNull();
      if (row == null) return false;
      final affected =
          await (update(
            pendingProfileSaves,
          )..where((t) => t.userPubkey.equals(userPubkey))).write(
            PendingProfileSavesCompanion(
              retryCount: Value(row.retryCount + 1),
              lastAttemptAt: Value(DateTime.now()),
            ),
          );
      return affected > 0;
    });
  }

  /// Reset a `syncing` row back to `pending` on cold start, so a save that
  /// was mid-flight when the app was killed is retried. Mirrors
  /// `PendingActionService`'s reset-on-init.
  Future<int> resetSyncingToPending(String userPubkey) {
    return (update(pendingProfileSaves)..where(
          (t) =>
              t.userPubkey.equals(userPubkey) &
              t.status.equals(PendingProfileSaveStatus.syncing.name),
        ))
        .write(
          const PendingProfileSavesCompanion(
            status: Value('pending'),
          ),
        );
  }

  /// Delete the pending save for [userPubkey] — called once a relay
  /// confirms the publish (or on an explicit user discard).
  Future<int> clear(String userPubkey) {
    return (delete(
      pendingProfileSaves,
    )..where((t) => t.userPubkey.equals(userPubkey))).go();
  }

  // ---------------------------------------------------------------------
  // Reads
  // ---------------------------------------------------------------------

  /// The pending save for [userPubkey], or null if none is queued.
  Future<PendingProfileSaveEntry?> get(String userPubkey) async {
    final row = await (select(
      pendingProfileSaves,
    )..where((t) => t.userPubkey.equals(userPubkey))).getSingleOrNull();
    return row == null ? null : _rowToModel(row);
  }

  /// Reactive stream of the pending save for [userPubkey]. Emits null when
  /// no row exists (e.g. after a confirmed publish clears it).
  Stream<PendingProfileSaveEntry?> watch(String userPubkey) {
    return (select(pendingProfileSaves)
          ..where((t) => t.userPubkey.equals(userPubkey)))
        .watchSingleOrNull()
        .map((row) => row == null ? null : _rowToModel(row));
  }
}
