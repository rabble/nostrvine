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

/// Resolves the SQLCipher key for the local database before the first
/// `AppDatabase` open and performs the one-time plaintext→encrypted migration.
///
/// db_client stays keystore-free: this app-layer service reads/generates the
/// key from [FlutterSecureStorage] and injects it via `db_cipher_key_provider`.
/// Native runtime hooks (the Android library override, the cipher-availability
/// probe, the migration, the key-loss backup/recreate path) are injected so
/// the orchestration is unit-testable on the host VM, which links plain sqlite3.
class DatabaseEncryptionBootstrap {
  DatabaseEncryptionBootstrap({
    required FlutterSecureStorage secureStorage,
    Future<void> Function()? ensureRuntime,
    bool Function()? isCipherAvailable,
    Future<CipherMigrationOutcome> Function(String rawKeyHex)? migrate,
    Future<void> Function()? deleteDatabase,
  }) : _secureStorage = secureStorage,
       _ensureRuntime = ensureRuntime ?? ensureSqlCipherRuntime,
       _isCipherAvailable = isCipherAvailable ?? isSqlCipherAvailable,
       _migrate =
           migrate ??
           ((rawKeyHex) => migratePlaintextToEncrypted(rawKeyHex: rawKeyHex)),
       _deleteDatabase = deleteDatabase ?? backUpAndRemoveSharedDatabase;

  final FlutterSecureStorage _secureStorage;
  final Future<void> Function() _ensureRuntime;
  final bool Function() _isCipherAvailable;
  final Future<CipherMigrationOutcome> Function(String rawKeyHex) _migrate;
  final Future<void> Function() _deleteDatabase;

  static const _logName = 'DatabaseEncryptionBootstrap';

  /// Resolves the cipher key for the database provider, or `null` when the
  /// database should open unencrypted.
  ///
  /// Returns `null` for web (SQLCipher is native-only, #373) and when a
  /// populated plaintext database could not be migrated this launch (the
  /// migration left it intact and retries on the next launch).
  ///
  /// Throws [StateError] when SQLCipher is not the linked SQLite library — a
  /// build misconfiguration that must fail loudly rather than silently ship an
  /// unencrypted database.
  ///
  /// Must run before the first `AppDatabase` open.
  Future<String?> resolveCipherKey() async {
    if (kIsWeb) return null;

    await _ensureRuntime();
    if (!_isCipherAvailable()) {
      throw StateError(
        'SQLCipher is not linked; refusing to start with an unencrypted local '
        'database. Verify sqlcipher_flutter_libs replaced sqlite3_flutter_libs '
        'and that no dependency links plain sqlite3.',
      );
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
          // Key-loss recovery (#570 §6): the keystore was cleared but an
          // encrypted database remains. It is cryptographically unrecoverable,
          // so it is backed up (not hard-deleted) and recreated under the
          // freshly generated key. Local-only data is preserved in the backup;
          // DMs resync from relays. Accepted tradeoff for the rare
          // keystore-reset case — pending product signoff on the user-facing
          // notice.
          Log.warning(
            'Cipher key was missing but an encrypted database exists '
            '(keystore reset). Backing up the unrecoverable database and '
            'recreating under a new key.',
            name: _logName,
          );
          await _deleteDatabase();
        }
        return key;
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
}

/// Resolves the startup DB cipher key and fails closed on bootstrap errors.
///
/// Native app startup must not continue with a `null` cipher key after a
/// secure-storage or SQLCipher bootstrap failure: an existing encrypted DB
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
    await recordError(error, stack);
    Error.throwWithStackTrace(error, stack);
  }
}

bool _isValidCipherKey(String value) =>
    RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(value);

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
