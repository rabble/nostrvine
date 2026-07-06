// ABOUTME: Resolves the at-rest DB cipher key + runs the one-time plaintext→encrypted migration.
// ABOUTME: App-layer bootstrap; db_client never reads the keystore, so the key is injected here.

import 'dart:math';

import 'package:db_client/db_client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:openvine/database/sqlcipher_runtime.dart';
import 'package:unified_logger/unified_logger.dart';

/// Secure-storage key for the at-rest DB cipher key. Versioned so a future
/// rotation can introduce `.v2` without colliding.
@visibleForTesting
const dbCipherKeyStorageKey = 'db.cipher.key.v1';

/// Resolves the SQLite3MultipleCiphers key for the local database before the first
/// `AppDatabase` open and performs the one-time plaintext→encrypted migration.
///
/// db_client stays keystore-free: this app-layer service reads/generates the
/// key from [FlutterSecureStorage] and injects it via `db_cipher_key_provider`.
/// Native runtime hooks (the cipher-availability probe, the migration, the
/// key-loss backup/recreate path) are injected so the orchestration is
/// unit-testable.
class DatabaseEncryptionBootstrap {
  DatabaseEncryptionBootstrap({
    required FlutterSecureStorage secureStorage,
    Future<void> Function()? ensureRuntime,
    bool Function()? isCipherAvailable,
    Future<CipherMigrationOutcome> Function(String rawKeyHex)? migrate,
    Future<void> Function()? deleteDatabase,
    Future<void> Function()? onDatabaseReset,
    Future<bool> Function(String rawKeyHex)? canOpenEncryptedDatabase,
    Future<bool> Function(String rawKeyHex)? salvageDatabase,
    Future<bool> Function(String rawKeyHex)? encryptedKeyMatches,
    Future<void> Function(Object error, StackTrace stack)? recordRecovery,
  }) : _secureStorage = secureStorage,
       _recordRecovery = recordRecovery,
       _ensureRuntime = ensureRuntime ?? ensureSqlCipherRuntime,
       _isCipherAvailable = isCipherAvailable ?? isSqlCipherAvailable,
       _migrate =
           migrate ??
           ((rawKeyHex) => migratePlaintextToEncrypted(rawKeyHex: rawKeyHex)),
       _deleteDatabase = deleteDatabase ?? backUpAndRemoveSharedDatabase,
       _onDatabaseReset = onDatabaseReset,
       _canOpenEncryptedDatabase =
           canOpenEncryptedDatabase ??
           ((rawKeyHex) => encryptedDatabaseOpensCleanly(rawKeyHex: rawKeyHex)),
       _salvageDatabase =
           salvageDatabase ??
           ((rawKeyHex) =>
               salvageCorruptEncryptedDatabase(rawKeyHex: rawKeyHex)),
       _encryptedKeyMatches =
           encryptedKeyMatches ??
           ((rawKeyHex) => encryptedDatabaseKeyDecrypts(rawKeyHex: rawKeyHex));

  final FlutterSecureStorage _secureStorage;
  final Future<void> Function() _ensureRuntime;
  final bool Function() _isCipherAvailable;
  final Future<CipherMigrationOutcome> Function(String rawKeyHex) _migrate;
  final Future<void> Function() _deleteDatabase;
  final Future<bool> Function(String rawKeyHex) _canOpenEncryptedDatabase;

  /// Attempts to salvage the local-only data from a corrupt encrypted database
  /// (rebuilding it in place under the same key) before the destructive wipe.
  /// Returns `false` on key loss or when a sound copy could not be rebuilt;
  /// [_encryptedKeyMatches] then decides whether the wipe rotates the key.
  final Future<bool> Function(String rawKeyHex) _salvageDatabase;

  /// Whether the key still decrypts the corrupt DB's schema page. Used only
  /// when salvage fails, to keep a still-valid key (so the backup stays
  /// readable) instead of rotating it. Returns `false` on genuine key loss.
  final Future<bool> Function(String rawKeyHex) _encryptedKeyMatches;

  /// Records a startup DB recovery (salvage or wipe) as a non-fatal so the
  /// corruption rate — and a device recovering on every launch — is observable
  /// in Crashlytics. Recovery succeeds silently otherwise: it does not throw,
  /// so it never reaches the startup error reporter. Best-effort; `null` in
  /// tests that don't assert on it.
  final Future<void> Function(Object error, StackTrace stack)? _recordRecovery;

  /// Invoked after the key-loss recreate wipes the Drift DB, so callers can
  /// clear local state that lives OUTSIDE the database (e.g. the DM sync
  /// cursors / `historyDrainComplete` flag in SharedPreferences). Without this
  /// the next inbox open would skip the full DM re-drain ("already complete")
  /// and leave recovered chats stranded under "Message requests". See #5304.
  final Future<void> Function()? _onDatabaseReset;

  static const _logName = 'DatabaseEncryptionBootstrap';

  /// Resolves the cipher key for the database provider, or `null` when the
  /// database should open unencrypted.
  ///
  /// Returns `null` for web (native DB encryption is out of scope, #373) and when a
  /// populated plaintext database could not be migrated this launch (the
  /// migration left it intact and retries on the next launch).
  ///
  /// Throws [StateError] when SQLite3MultipleCiphers is not the active SQLite
  /// build — a build misconfiguration that must fail loudly rather than
  /// silently ship an unencrypted database.
  ///
  /// Must run before the first `AppDatabase` open.
  Future<String?> resolveCipherKey() async {
    if (kIsWeb) return null;

    await _ensureRuntime();
    if (!_isCipherAvailable()) {
      throw DatabaseCipherUnavailableError();
    }

    final (key, wasGenerated) = await _readOrCreateKey();
    final outcome = await _migrate(key);

    switch (outcome) {
      case CipherMigrationOutcome.noDatabase:
      case CipherMigrationOutcome.removedEmptyPlaintext:
      case CipherMigrationOutcome.migrated:
        return key;
      case CipherMigrationOutcome.alreadyEncrypted:
        if (wasGenerated) {
          return _recoverUnusableEncryptedDatabase(key, reason: 'missing');
        }
        if (await _canOpenEncryptedDatabase(key)) {
          return key;
        }
        // The key either no longer opens the DB (stale) or opens it but
        // on-disk corruption surfaced when the Drift startup cleanup ran. Before
        // the destructive wipe, try to salvage the local-only data (drafts,
        // clips, pending queues) into a fresh DB rebuilt in place under the SAME
        // key. Local-only data cannot be re-fetched from relays, so preserving
        // it matters. Salvage returns false on key loss (nothing decryptable)
        // or a failure to rebuild a sound copy; the wipe below handles both.
        if (await _salvageDatabase(key)) {
          Log.warning(
            'Recovered a corrupt encrypted database by salvaging local-only '
            'data into a fresh database; the corrupt file was backed up. DMs '
            'and relay-backed caches resync.',
            name: _logName,
          );
          await _reportRecovery('salvaged local-only data into a fresh DB');
          await _runPostDatabaseReset(_onDatabaseReset);
          return key;
        }
        // Salvage failed. Only rotate the cipher key when it genuinely cannot
        // decrypt the file: rotating a still-valid key would overwrite the only
        // key that can read the `.pre_key_loss_wipe_backup` we are about to
        // create, silently breaking the "backup stays readable" guarantee. A
        // decryptable-but-unsalvageable DB (transient salvage failure, or a
        // rebuilt copy that failed its own integrity check) is recreated under
        // the SAME key so the backup stays recoverable.
        if (await _encryptedKeyMatches(key)) {
          return _recoverUnusableEncryptedDatabase(
            key,
            reason: 'corrupt and unsalvageable (key still valid)',
          );
        }
        final replacementKey = generateCipherKeyHex();
        await _secureStorage.write(
          key: dbCipherKeyStorageKey,
          value: replacementKey,
        );
        return _recoverUnusableEncryptedDatabase(
          replacementKey,
          reason: 'key loss',
        );
      case CipherMigrationOutcome.failed:
        Log.warning(
          'At-rest DB migration did not complete; opening plaintext this '
          'launch and retrying next launch.',
          name: _logName,
        );
        return null;
    }
  }

  Future<(String, bool)> _readOrCreateKey() async {
    final existing = await _secureStorage.read(key: dbCipherKeyStorageKey);
    if (existing != null && _isValidCipherKey(existing)) {
      return (existing, false);
    }

    final key = generateCipherKeyHex();
    await _secureStorage.write(key: dbCipherKeyStorageKey, value: key);
    return (key, true);
  }

  Future<String> _recoverUnusableEncryptedDatabase(
    String key, {
    required String reason,
  }) async {
    // Terminal recovery (#570 §6): the DB could not be used and could not be
    // salvaged. It is backed up (not hard-deleted) and recreated under [key] —
    // which the caller has either rotated (genuine key loss) or kept unchanged
    // (decryptable-but-unsalvageable corruption, so the backup stays readable).
    // Local-only data is preserved in the backup; DMs resync from relays.
    Log.warning(
      'Encrypted database is unrecoverable ($reason). Backing it up and '
      'recreating.',
      name: _logName,
    );
    await _deleteDatabase();
    await _reportRecovery('backed up + recreated ($reason)');
    await _runPostDatabaseReset(_onDatabaseReset);
    return key;
  }

  /// Records a recovery as a non-fatal Crashlytics event. Best-effort: a
  /// reporting failure must never fail startup now that recovery has succeeded.
  Future<void> _reportRecovery(String reason) async {
    try {
      await _recordRecovery?.call(
        DatabaseRecoveryEvent(reason),
        StackTrace.current,
      );
    } on Object catch (e) {
      Log.warning('Recovery reporting failed (non-fatal): $e', name: _logName);
    }
  }
}

/// Non-fatal marker recorded to Crashlytics when the startup DB recovery runs
/// (salvage or wipe), so the corruption/recovery rate — and a device recovering
/// on every launch — is observable. Not a programming error; it carries only
/// the recovery [reason] and never embeds key material or DB contents.
class DatabaseRecoveryEvent implements Exception {
  DatabaseRecoveryEvent(this.reason);

  final String reason;

  @override
  String toString() => 'DatabaseRecoveryEvent: $reason';
}

class DatabaseCipherUnavailableError extends StateError {
  DatabaseCipherUnavailableError()
    : super(
        'SQLite3MultipleCiphers is not active; refusing to start with an '
        'unencrypted local database. Verify package:sqlite3 hooks select '
        'sqlite3mc and no dependency links plain sqlite3.',
      );
}

/// Resolves the startup DB cipher key and fails closed on bootstrap errors.
///
/// Native app startup must not continue with a `null` cipher key after a
/// secure-storage or cipher bootstrap failure: an existing encrypted DB
/// would be opened as plaintext and repeatedly surface SQLITE_NOTADB. Web and
/// intentional plaintext migration deferrals still return `null` from
/// [resolveCipherKey].
Future<String?> resolveStartupDatabaseCipherKey({
  required Future<String?> Function() resolveCipherKey,
  required Future<void> Function(Object error, StackTrace stack) recordError,
}) async {
  try {
    return await resolveCipherKey();
  } catch (error, stack) {
    try {
      await recordError(error, stack);
    } catch (_) {
      // Startup still needs to fail with the bootstrap root cause even if
      // telemetry is unavailable during early app initialization.
    }
    Error.throwWithStackTrace(error, stack);
  }
}

bool _isValidCipherKey(String value) =>
    RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(value);

const _sqliteCorrupt = 11;
const _sqliteNotADb = 26;

/// Returns whether a startup bootstrap failure is safe to repair by backing up
/// the local encrypted DB cache and retrying once.
///
/// Keep this as an allowlist. Secure-storage, SQLite3MultipleCiphers linkage,
/// and other transient startup failures must fail closed because deleting or
/// rotating the DB cipher key can make an otherwise recoverable encrypted DB
/// unusable.
bool shouldRepairLocalDatabaseCacheAfterBootstrapError(Object error) {
  if (error is DatabaseCipherUnavailableError) return false;

  final message = error.toString();
  return message.contains('SqliteException($_sqliteNotADb)') ||
      message.contains('SqliteException($_sqliteCorrupt)') ||
      message.contains('SQLITE_NOTADB') ||
      message.contains('SQLITE_CORRUPT') ||
      message.contains('database disk image is malformed') ||
      message.contains('file is not a database');
}

/// Backs up the encrypted local database cache and removes only its DB cipher
/// key so the next bootstrap creates a fresh encrypted cache.
Future<void> resetEncryptedDatabaseCache({
  required FlutterSecureStorage secureStorage,
  Future<void> Function()? deleteDatabase,
  Future<void> Function()? onDatabaseReset,
}) async {
  await (deleteDatabase ?? backUpAndRemoveSharedDatabase)();
  await secureStorage.delete(key: dbCipherKeyStorageKey);
  await _runPostDatabaseReset(onDatabaseReset);
}

Future<void> _runPostDatabaseReset(
  Future<void> Function()? onDatabaseReset,
) async {
  // The Drift DB is now empty but SharedPreferences survives, so the DM sync
  // cursors / `historyDrainComplete` flag would make the next inbox open skip
  // the full re-drain and strand recovered chats under "Message requests".
  // Clear DM sync state so recovery re-runs against the fresh DB. See #5304.
  //
  // Best-effort: a SharedPreferences IO failure here only re-strands requests
  // (itself healed by the drain-version bump) and must not escalate into a hard
  // cipher-key-resolution failure now that the DB has already been recreated.
  try {
    await onDatabaseReset?.call();
  } on Object catch (e) {
    Log.warning(
      'Post-recreate DM sync-state reset failed (non-fatal): $e',
      name: DatabaseEncryptionBootstrap._logName,
    );
  }
}

/// Generates a 64-character hex (raw 32-byte) cipher key from a CSPRNG.
///
/// Uses [Random.secure]; the key is never logged or derived from anything
/// guessable.
@visibleForTesting
String generateCipherKeyHex() {
  final rng = Random.secure();
  final bytes = Uint8List(32);
  for (var i = 0; i < bytes.length; i++) {
    bytes[i] = rng.nextInt(256);
  }
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
