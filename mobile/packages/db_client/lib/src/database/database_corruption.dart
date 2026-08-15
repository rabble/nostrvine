// ABOUTME: Runtime SQLITE_CORRUPT detection: the shared signature classifier
// ABOUTME: plus a Drift interceptor that reports corruption surfacing on any
// ABOUTME: statement, so the next launch can salvage instead of re-throwing.

import 'package:drift/drift.dart';

/// SQLITE_CORRUPT — structural damage on disk.
const _sqliteCorrupt = 11;

/// SQLITE_NOTADB — the key cannot decrypt the file.
const _sqliteNotADb = 26;

/// The `SqliteException(<extendedResultCode>)` header that sqlite3 writes ahead
/// of the message, the causing statement and its bound parameters.
final _sqliteExceptionHeader = RegExp(r'SqliteException\((\d+)\)');

/// Whether [error] is on-disk corruption or an undecryptable database file.
///
/// The database runs on a background isolate, so a failing statement arrives
/// wrapped in drift's `DriftRemoteException`, which serialises the cause with
/// `toString()` and forwards it verbatim. Reading the result code back out of
/// that text avoids importing drift's experimental `remote.dart` (or its
/// web-unsafe `isolate.dart`) purely for the wrapper type.
///
/// Only the header line is classified, and only by result code. `toString()`
/// appends the causing statement and its bound parameters on the lines below,
/// and those carry user content: a Nostr event whose text quotes SQLite's
/// corruption message must never convince us to salvage a healthy database.
bool indicatesDatabaseCorruption(Object error) {
  final header = error.toString().split('\n').first;
  final extendedCode = int.tryParse(
    _sqliteExceptionHeader.firstMatch(header)?.group(1) ?? '',
  );
  if (extendedCode == null) return false;
  return _isCorruptionResultCode(extendedCode);
}

/// Whether [error] mentions on-disk corruption **anywhere** in its text,
/// including inside a wrapper that prints its cause below its own first line.
///
/// Deliberately looser than [indicatesDatabaseCorruption], which reads the
/// header line only. Most wrappers a downstream caller sees keep the SQLite
/// header on line 1, so the strict classifier already covers them:
/// `DriftRemoteException` forwards `remoteCause.toString()` verbatim,
/// `DriftWrappedException` opens with `'$cause at …'`, and `ParallelWaitError`
/// prints only its *default* error — the first leg to fail — never its
/// `values` or `errors` records.
///
/// `CouldNotRollBackException` is the shape that defeats it: it prints the
/// failure raised by the `ROLLBACK` itself first, and the error that triggered
/// the rollback on the line below. A transaction aborted by corruption whose
/// rollback then fails for some other reason therefore carries the SQLite
/// header on line 2, where only this classifier can see it. drift transactions
/// are used in `event_router.dart` and the DM/conversation DAOs, so the shape
/// is reachable rather than hypothetical.
///
/// The stricter classifier is not merely stricter, it protects a different
/// decision. It gates the salvage/wipe of a database, where a false positive
/// destroys a healthy one, and bound parameters below the header carry user
/// content: a Nostr event quoting SQLite's corruption message must never
/// convince the app to recover. **Never use this function for that decision.**
///
/// Use it only where a false positive is harmless — specifically, to drop a
/// duplicate report about a database some other code has already classified as
/// corrupt via [indicatesDatabaseCorruption]. The looseness is bounded by that
/// precondition, not by the text match.
bool mentionsDatabaseCorruption(Object error) {
  return _sqliteExceptionHeader
      .allMatches(error.toString())
      .map((match) => int.tryParse(match.group(1)!))
      .any(
        (extendedCode) =>
            extendedCode != null && _isCorruptionResultCode(extendedCode),
      );
}

/// Every extended code carries its primary code in the low byte, so 779
/// (SQLITE_CORRUPT_INDEX) and 11 (SQLITE_CORRUPT) both reduce to 11.
bool _isCorruptionResultCode(int extendedCode) {
  final primaryCode = extendedCode & 0xFF;
  return primaryCode == _sqliteCorrupt || primaryCode == _sqliteNotADb;
}

/// Signature for the app-layer sink notified when a statement fails with
/// on-disk corruption.
///
/// db_client stays low-level: it neither persists the recovery flag nor talks
/// to Crashlytics. The app layer injects this reporter (see the reporter-port
/// pattern in `.claude/rules/error_handling.md`) and owns both.
typedef DatabaseCorruptionReporter =
    void Function(Object error, StackTrace stackTrace);

/// Returns [executor] wrapped so on-disk corruption surfacing on any statement
/// is reported to [reporter] before the original error propagates.
///
/// This exists so the app layer can enable corruption reporting without
/// importing drift itself — it composes the executor and the interceptor here,
/// where drift is already a direct dependency.
QueryExecutor reportCorruptionFrom(
  QueryExecutor executor,
  DatabaseCorruptionReporter reporter,
) => executor.interceptWith(DatabaseCorruptionInterceptor(reporter));

/// Reports SQLITE_CORRUPT / SQLITE_NOTADB surfacing on any statement, then
/// rethrows so callers still see the original failure.
///
/// The startup gate (`encryptedDatabaseOpensCleanly`) is deliberately reactive:
/// it forces Drift's `beforeOpen` cleanup rather than pre-scanning the whole
/// database with `PRAGMA quick_check` on every launch. That cleanup only reads
/// the rows it deletes, so corruption confined to pages a *later* query is the
/// first to touch sails past the gate — and, with nothing watching the runtime
/// path, throws on every launch forever. This interceptor closes that gap: it
/// turns the first corrupt statement into a signal the next launch can act on.
///
/// It never swallows or rewrites an error, and it never reports a healthy
/// statement, so wrapping the executor is transparent to every caller.
class DatabaseCorruptionInterceptor extends QueryInterceptor {
  /// Creates an interceptor reporting corruption to [reporter].
  DatabaseCorruptionInterceptor(this.reporter);

  /// Notified once per corrupt statement. Deduplication and persistence are the
  /// app layer's job.
  final DatabaseCorruptionReporter reporter;

  /// Runs [action], reporting a corruption failure before rethrowing it.
  Future<T> _report<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (error, stackTrace) {
      if (indicatesDatabaseCorruption(error)) {
        reporter(error, stackTrace);
      }
      rethrow;
    }
  }

  @override
  Future<bool> ensureOpen(QueryExecutor executor, QueryExecutorUser user) =>
      _report(() => executor.ensureOpen(user));

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) => _report(() => executor.runSelect(statement, args));

  @override
  Future<int> runInsert(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) => _report(() => executor.runInsert(statement, args));

  @override
  Future<int> runUpdate(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) => _report(() => executor.runUpdate(statement, args));

  @override
  Future<int> runDelete(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) => _report(() => executor.runDelete(statement, args));

  @override
  Future<void> runCustom(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) => _report(() => executor.runCustom(statement, args));

  @override
  Future<void> runBatched(
    QueryExecutor executor,
    BatchedStatements statements,
  ) => _report(() => executor.runBatched(statements));

  @override
  Future<void> commitTransaction(TransactionExecutor inner) =>
      _report(inner.send);

  @override
  Future<void> rollbackTransaction(TransactionExecutor inner) =>
      _report(inner.rollback);
}
