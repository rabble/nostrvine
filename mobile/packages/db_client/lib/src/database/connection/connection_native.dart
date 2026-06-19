// ABOUTME: Native platform database connection using SQLite
// ABOUTME: Provides file-based SQLite storage for iOS, Android, macOS, etc.

import 'dart:io';
import 'package:collection/collection.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/common.dart' show CommonDatabase;
import 'package:sqlite3/sqlite3.dart';

/// Open a database connection for native platforms
/// Uses file-based SQLite through drift's native implementation
QueryExecutor openConnection() {
  if (_isFlutterTestProcess) {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    return NativeDatabase.memory();
  }

  return LazyDatabase(() async {
    final dbPath = await getSharedDatabasePath();
    final dbFile = prepareDatabaseFile(dbPath);
    return NativeDatabase(dbFile);
  });
}

bool get _isFlutterTestProcess =>
    Platform.executable.contains('flutter_tester');

// ---------------------------------------------------------------------------
// SQLite3MultipleCiphers at-rest encryption (#570, finding C2).
//
// db_client stays low-level: it never reads the platform keystore. The app
// layer resolves the 64-hex (raw 32-byte) cipher key and injects it here. The
// real encrypted open + the plaintext→encrypted migration require the
// sqlite3mc native build selected by package:sqlite3 hooks. See
// `mobile/docs/sqlcipher_at_rest_plan.md`.
// ---------------------------------------------------------------------------

/// Opens an at-rest-encrypted database connection for native platforms.
///
/// [rawKeyHex] is a 64-character hex (raw 32-byte) cipher key supplied by
/// the app layer. The key is applied in [applyCipherKey], which **fails
/// closed**: if SQLite3MultipleCiphers is not the active SQLite build the open
/// throws
/// rather than silently writing plaintext.
///
/// Throws [ArgumentError] if [rawKeyHex] is malformed (the error never embeds
/// the key — see [formatCipherKeyPragma]).
QueryExecutor openEncryptedConnection({required String rawKeyHex}) {
  // Validate eagerly so a malformed key fails fast at construction time.
  _rawKeyLiteral(rawKeyHex);

  return LazyDatabase(() async {
    final dbPath = await getSharedDatabasePath();
    final dbFile = prepareDatabaseFile(dbPath);
    return NativeDatabase(
      dbFile,
      setup: (rawDb) {
        applyCipherKey(rawDb, rawKeyHex);
        cleanUpPreCipherMigrationBackups(dbPath);
      },
    );
  });
}

/// Returns whether the shared encrypted database opens with [rawKeyHex].
///
/// This is a startup guard for the app layer: a valid-looking key can remain
/// in secure storage while the database file belongs to a different key
/// (backup/restore drift, partial reinstall, manual sandbox surgery). In that
/// case the DB is just as unrecoverable as a missing key and should be backed
/// up/recreated before the first Drift provider touches it.
Future<bool> encryptedDatabaseOpensWithKey({
  required String rawKeyHex,
  String? databasePath,
}) async {
  _rawKeyLiteral(rawKeyHex);

  final dbPath = databasePath ?? await getSharedDatabasePath();
  if (!File(dbPath).existsSync()) return true;

  Database? db;
  try {
    db = sqlite3.open(dbPath);
    applyCipherKey(db, rawKeyHex);
    return true;
  } on SqliteException catch (e) {
    if (e.resultCode == _sqliteNotADb) return false;
    rethrow;
  } finally {
    db?.close();
  }
}

/// Keys [rawDb] with [rawKeyHex] and verifies SQLite3MultipleCiphers is active.
///
/// The cipher selection pragmas and `PRAGMA key` must run before any real
/// database use. On plain SQLite these pragmas are unknown no-ops and
/// `PRAGMA cipher` returns no rows — meaning the database would be
/// **unencrypted**. We refuse to open in that case (fail closed) instead of
/// silently storing plaintext.
@visibleForTesting
void applyCipherKey(CommonDatabase rawDb, String rawKeyHex) {
  _rawKeyLiteral(rawKeyHex);
  _applySqlCipherCompatibility(rawDb);
  try {
    rawDb.execute(formatCipherKeyPragma(rawKeyHex));
  } on SqliteException {
    // Never rethrow the original: SqliteException.toString() appends the
    // causing statement, which is the `PRAGMA key` containing the raw key.
    throw StateError('Failed to apply the local database cipher key.');
  }

  if (!_isMultipleCiphersAvailable(rawDb)) {
    throw StateError(
      'SQLite3MultipleCiphers is not the active SQLite library; refusing to '
      'open the database unencrypted. Ensure package:sqlite3 hooks select '
      'sqlite3mc and no dependency links plain sqlite3.',
    );
  }

  // `PRAGMA key` is processed lazily, so an incorrect key surfaces as
  // SQLITE_NOTADB on the first real read rather than above. Probe the schema
  // so a wrong key fails deterministically at open time.
  rawDb.execute('SELECT count(*) FROM sqlite_master;');
}

void _applySqlCipherCompatibility(CommonDatabase rawDb) {
  rawDb
    ..execute("PRAGMA cipher = 'sqlcipher';")
    ..execute('PRAGMA legacy = 4;');
}

bool _isMultipleCiphersAvailable(CommonDatabase rawDb) =>
    rawDb.select('PRAGMA cipher;').isNotEmpty;

/// Builds the SQLCipher `PRAGMA key` statement for a **raw** 32-byte key.
///
/// [rawKeyHex] is 64 hex characters, wrapped in SQLCipher's raw-key form
/// (`x'...'`) so SQLCipher uses the bytes verbatim and skips PBKDF2 — correct
/// for a CSPRNG-generated 32-byte key held in the platform keystore, not a
/// human passphrase.
///
/// Throws [ArgumentError] if [rawKeyHex] is not exactly 64 hex characters.
/// The thrown error deliberately does **not** include [rawKeyHex]: it is
/// secret key material and must never reach logs, Crashlytics, or test output.
@visibleForTesting
String formatCipherKeyPragma(String rawKeyHex) =>
    'PRAGMA key = ${_rawKeyLiteral(rawKeyHex)};';

/// Returns the SQLCipher-compatible raw-key literal (`"x'<hex>'"`) for use in
/// `PRAGMA key` and `PRAGMA rekey` clauses. Inlining the validated hex is
/// injection-safe because the value is constrained to `[0-9a-fA-F]{64}`.
String _rawKeyLiteral(String rawKeyHex) {
  if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(rawKeyHex)) {
    throw ArgumentError(
      'rawKeyHex must be exactly 64 hex characters '
      '(a raw 32-byte database cipher key)',
    );
  }
  return '"x\'$rawKeyHex\'"';
}

/// Outcome of [migratePlaintextToEncrypted].
enum CipherMigrationOutcome {
  /// No database file existed (fresh install) — nothing to migrate.
  noDatabase,

  /// The existing database was already encrypted — nothing to do.
  alreadyEncrypted,

  /// An empty plaintext database was removed so a fresh encrypted one is
  /// created on first open.
  removedEmptyPlaintext,

  /// A populated plaintext database was rekeyed into an encrypted file.
  migrated,

  /// Migration was attempted but could not complete; the plaintext source is
  /// left intact and the caller should retry on the next launch.
  failed,
}

/// One-time in-place rekey of the existing **plaintext** `divine_db.db` into a
/// SQLite3MultipleCiphers-encrypted database.
///
/// Safe by construction: a plaintext side-file copy is encrypted and verified
/// (key opens it; table/row counts match the source) **before** the plaintext
/// original is swapped out, and the original is renamed to a backup rather
/// than deleted. On any failure the plaintext database is left exactly as it
/// was so the app keeps working and the migration retries next launch.
///
/// Wipe-and-resync is intentionally rejected: `divine_db.db` is shared with
/// drafts, pending uploads/actions, reactions, reposts, etc., which cannot be
/// re-fetched. See `mobile/docs/sqlcipher_at_rest_plan.md`.
///
/// Requires SQLite3MultipleCiphers; returns [CipherMigrationOutcome.failed]
/// when it is not linked, leaving the source intact.
Future<CipherMigrationOutcome> migratePlaintextToEncrypted({
  required String rawKeyHex,
  String? databasePath,
}) async {
  _rawKeyLiteral(rawKeyHex); // validate shape up front (never embeds the key)

  final dbPath = databasePath ?? await getSharedDatabasePath();
  final encryptedPath = '$dbPath$_migratingSuffix';

  // Resume an interrupted swap. A force-kill between renaming the plaintext
  // original to its backup and moving the verified encrypted copy into place
  // leaves the (already-verified) encrypted file at [encryptedPath] with no
  // file at [dbPath]. Completing the rename is the lossless recovery.
  if (!File(dbPath).existsSync() && File(encryptedPath).existsSync()) {
    promoteEncryptedMigrationArtifact(
      encryptedPath: encryptedPath,
      dbPath: dbPath,
    );
    return CipherMigrationOutcome.migrated;
  }

  if (!File(dbPath).existsSync()) return CipherMigrationOutcome.noDatabase;

  switch (_classifyDatabase(dbPath)) {
    case _DbClassification.encrypted:
      return CipherMigrationOutcome.alreadyEncrypted;
    case _DbClassification.indeterminate:
      // A transient or unreadable error (busy, locked, I/O, corrupt) — do NOT
      // assume "encrypted", which would trigger the key-loss recovery path
      // on a readable plaintext DB. Leave everything intact and retry next
      // launch.
      return CipherMigrationOutcome.failed;
    case _DbClassification.emptyPlaintext:
      _deleteDatabaseAndSidecars(dbPath);
      return CipherMigrationOutcome.removedEmptyPlaintext;
    case _DbClassification.populatedPlaintext:
      return _rekeyPlaintextInPlace(dbPath: dbPath, rawKeyHex: rawKeyHex);
  }
}

const _migratingSuffix = '.sqlcipher_migrating';
const _sqliteNotADb = 26; // SQLITE_NOTADB

enum _DbClassification {
  encrypted,
  emptyPlaintext,
  populatedPlaintext,
  indeterminate,
}

/// Classifies [dbPath] by opening it **without** a key. A plaintext database
/// reads its schema fine. Only `SQLITE_NOTADB` is treated as a positive
/// "encrypted" signal; any other error is [_DbClassification.indeterminate] so
/// a transient failure on a readable plaintext DB never masquerades as
/// encrypted (which would trigger the destructive key-loss path).
_DbClassification _classifyDatabase(String dbPath) {
  Database db;
  try {
    db = sqlite3.open(dbPath, mode: OpenMode.readOnly);
  } on SqliteException catch (e) {
    return _encryptedOrIndeterminate(e);
  }

  try {
    final rows = db.select(
      "SELECT count(*) AS c FROM sqlite_master WHERE type = 'table' "
      "AND name NOT LIKE 'sqlite_%';",
    );
    final tableCount = rows.first['c'] as int;
    return tableCount == 0
        ? _DbClassification.emptyPlaintext
        : _DbClassification.populatedPlaintext;
  } on SqliteException catch (e) {
    return _encryptedOrIndeterminate(e);
  } finally {
    db.close();
  }
}

_DbClassification _encryptedOrIndeterminate(SqliteException e) =>
    e.resultCode == _sqliteNotADb
    ? _DbClassification.encrypted
    : _DbClassification.indeterminate;

CipherMigrationOutcome _rekeyPlaintextInPlace({
  required String dbPath,
  required String rawKeyHex,
}) {
  final encryptedPath = '$dbPath$_migratingSuffix';
  // Remove any partial artifact from an interrupted previous attempt.
  _deleteDatabaseAndSidecars(encryptedPath);

  Database source;
  try {
    // The source must be opened UNKEYED. It remains untouched until a verified
    // encrypted side-file is ready to promote.
    source = sqlite3.open(dbPath);
  } on SqliteException {
    return CipherMigrationOutcome.failed;
  }

  try {
    if (!_isMultipleCiphersAvailable(source)) {
      // SQLite3MultipleCiphers not linked — cannot encrypt. Leave plaintext
      // intact.
      return CipherMigrationOutcome.failed;
    }
    source.execute('VACUUM INTO ?;', [encryptedPath]);
  } on SqliteException {
    _deleteDatabaseAndSidecars(encryptedPath);
    return CipherMigrationOutcome.failed;
  } finally {
    source.close();
  }

  if (!_encryptPlaintextMigrationArtifact(
    encryptedPath: encryptedPath,
    rawKeyHex: rawKeyHex,
  )) {
    _deleteDatabaseAndSidecars(encryptedPath);
    return CipherMigrationOutcome.failed;
  }

  if (!_encryptedCopyMatchesSource(
    plaintextPath: dbPath,
    encryptedPath: encryptedPath,
    rawKeyHex: rawKeyHex,
  )) {
    _deleteDatabaseAndSidecars(encryptedPath);
    return CipherMigrationOutcome.failed;
  }

  // Keep the plaintext original as a backup until the next successful launch,
  // then move the verified encrypted copy into place.
  final backupPath = _nextDatabaseBackupPath(
    dbPath,
    suffix: '.pre_cipher_migration_backup',
  );
  File(dbPath).renameSync(backupPath);
  _moveSidecars(fromPath: dbPath, toPath: backupPath);
  promoteEncryptedMigrationArtifact(
    encryptedPath: encryptedPath,
    dbPath: dbPath,
  );
  return CipherMigrationOutcome.migrated;
}

bool _encryptPlaintextMigrationArtifact({
  required String encryptedPath,
  required String rawKeyHex,
}) {
  Database? db;
  try {
    db = sqlite3.open(encryptedPath);
    _applySqlCipherCompatibility(db);
    db
      ..execute('PRAGMA rekey = ${_rawKeyLiteral(rawKeyHex)};')
      ..execute('SELECT count(*) FROM sqlite_master;');
    return true;
  } on SqliteException {
    return false;
  } finally {
    db?.close();
  }
}

/// Promotes the verified encrypted migration artifact into the canonical DB
/// path, carrying WAL/SHM sidecars with it.
@visibleForTesting
void promoteEncryptedMigrationArtifact({
  required String encryptedPath,
  required String dbPath,
}) {
  File(encryptedPath).renameSync(dbPath);
  _moveSidecars(fromPath: encryptedPath, toPath: dbPath);
}

/// Verifies the encrypted copy opens with [rawKeyHex] and that its
/// `user_version` (drift's schema version) and user-table row counts match the
/// plaintext source — the gate before swapping files.
bool _encryptedCopyMatchesSource({
  required String plaintextPath,
  required String encryptedPath,
  required String rawKeyHex,
}) {
  Database? encrypted;
  Database? plaintext;
  try {
    encrypted = sqlite3.open(encryptedPath);
    applyCipherKey(encrypted, rawKeyHex);

    plaintext = sqlite3.open(plaintextPath, mode: OpenMode.readOnly);

    if (_userVersion(encrypted) != _userVersion(plaintext)) return false;

    return const MapEquality<String, int>().equals(
      _userTableRowCounts(encrypted),
      _userTableRowCounts(plaintext),
    );
  } on SqliteException {
    return false;
  } finally {
    encrypted?.close();
    plaintext?.close();
  }
}

int _userVersion(Database db) =>
    db.select('PRAGMA user_version;').first['user_version'] as int? ?? 0;

/// Backs up (rather than hard-deletes) the shared database for the #570 §6
/// key-loss recovery.
///
/// When the platform keystore is cleared (OS reset / restore without keychain
/// migration) the cipher key is gone and the encrypted database is
/// cryptographically unrecoverable, so it must be replaced. It is renamed to a
/// timestamped backup (with its `-wal`/`-shm` sidecars) rather than deleted, so
/// a misclassification or a future recovery path is never catastrophic. A fresh
/// encrypted database is created under the new key on first open; DMs resync
/// from relays. See `mobile/docs/sqlcipher_at_rest_plan.md`.
Future<void> backUpAndRemoveSharedDatabase() async {
  final dbPath = await getSharedDatabasePath();
  if (!File(dbPath).existsSync()) return;
  final backupPath = _nextDatabaseBackupPath(
    dbPath,
    suffix: '.pre_key_loss_wipe_backup',
  );
  File(dbPath).renameSync(backupPath);
  _moveSidecars(fromPath: dbPath, toPath: backupPath);
}

/// Removes plaintext backups left by a successful plaintext→encrypted
/// migration once the encrypted database has opened with its key.
///
/// The migration keeps the plaintext source as
/// `.pre_cipher_migration_backup*` until a later keyed open proves the
/// encrypted database is usable. At that point the backup would otherwise
/// leave the old plaintext database readable at rest, defeating #570 C2.
/// Key-loss and legacy-migration backups use different suffixes and are
/// intentionally preserved.
@visibleForTesting
void cleanUpPreCipherMigrationBackups(String dbPath) {
  final dbFile = File(dbPath);
  final directory = dbFile.parent;
  if (!directory.existsSync()) return;

  final backupPrefix = '${p.basename(dbPath)}.pre_cipher_migration_backup';
  for (final entity in directory.listSync()) {
    if (entity is! File) continue;
    final name = p.basename(entity.path);
    if (_isPreCipherMigrationBackupName(name, backupPrefix)) {
      entity.deleteSync();
    }
  }
}

bool _isPreCipherMigrationBackupName(String name, String backupPrefix) {
  final indexedBackupPattern = RegExp(
    '^${RegExp.escape(backupPrefix)}\\.\\d+\$',
  );
  if (name == backupPrefix || indexedBackupPattern.hasMatch(name)) {
    return true;
  }

  for (final suffix in const ['-wal', '-shm']) {
    if (!name.endsWith(suffix) || name.length <= suffix.length) continue;
    final baseName = name.substring(0, name.length - suffix.length);
    if (baseName == backupPrefix || indexedBackupPattern.hasMatch(baseName)) {
      return true;
    }
  }
  return false;
}

Map<String, int> _userTableRowCounts(Database db) {
  final counts = <String, int>{};
  final tables = db.select(
    "SELECT name FROM sqlite_master WHERE type = 'table' "
    "AND name NOT LIKE 'sqlite_%' ORDER BY name;",
  );
  for (final row in tables) {
    final name = row['name'] as String;
    final result = db.select('SELECT count(*) AS c FROM "$name";');
    counts[name] = result.first['c'] as int;
  }
  return counts;
}

/// Get path to shared database file
///
/// Path: {appSupport}/openvine/database/divine_db.db
///
/// The database lived under `getApplicationDocumentsDirectory()` until the
/// change that shipped in PR #2840. When it moved to Application Support,
/// no migration was included, which orphans every user's local data on
/// upgrade (DMs, drafts, clips, upload queue, reactions, reposts,
/// notifications, bookmarks, NIP-05 verifications, etc.). This function
/// migrates the legacy file on first run after upgrade.
Future<String> getSharedDatabasePath() async {
  final appSupportDir = await getApplicationSupportDirectory();
  final newPath = buildSharedDatabasePath(appSupportDir.path);

  // Check cache version and wipe stale database if needed.
  applyDbCacheVersionReset(newPath);

  final docDir = await getApplicationDocumentsDirectory();
  final legacyPath = p.join(
    docDir.path,
    'openvine',
    'database',
    'divine_db.db',
  );
  await migrateLegacyDatabase(legacyPath: legacyPath, newPath: newPath);

  return newPath;
}

/// Bump this version when startup needs to mark that a database compatibility
/// check has run. Version adoption must not delete the database: it contains
/// local-only user data such as drafts and pending actions.
///
/// Version history:
///   1 — initial (implicit, no version file exists yet)
///   2 — force reset to recover from PR #2840 path-change data loss
@visibleForTesting
const int dbCacheVersion = 2;

/// File name written next to the database to track [dbCacheVersion].
@visibleForTesting
const String dbVersionFileName = 'divine_db.version';

/// Reads the stored cache version from a file next to the database.
/// Returns `null` when the version file does not exist (first run with
/// this mechanism).
@visibleForTesting
int? readDbCacheVersion(String dbDir) {
  final file = File(p.join(dbDir, dbVersionFileName));
  if (!file.existsSync()) return null;
  return int.tryParse(file.readAsStringSync().trim());
}

/// Writes [version] to the version file next to the database.
@visibleForTesting
void writeDbCacheVersion(String dbDir, int version) {
  final dir = Directory(dbDir);
  if (!dir.existsSync()) dir.createSync(recursive: true);
  File(p.join(dbDir, dbVersionFileName)).writeAsStringSync('$version');
}

/// Writes the current [dbCacheVersion] when the stored version is stale.
///
/// On first run (no version file), also writes the current version without
/// deleting anything.
@visibleForTesting
void applyDbCacheVersionReset(String dbPath) {
  final dbDir = p.dirname(dbPath);
  final stored = readDbCacheVersion(dbDir);

  if (stored == null) {
    // First run with version tracking — adopt current version, no wipe.
    writeDbCacheVersion(dbDir, dbCacheVersion);
    return;
  }

  if (stored < dbCacheVersion) {
    writeDbCacheVersion(dbDir, dbCacheVersion);
  }
}

/// One-time migration from the pre-PR #2840 Documents-directory location
/// to the current Application Support location.
///
/// Handles three cases:
/// 1. Legacy does not exist → no-op (fresh install or already migrated).
/// 2. Legacy exists, new does not → rename legacy to new.
/// 3. Both exist → migrate legacy only if the destination has no actionable
///    local-only rows and legacy does. If neither side has actionable local
///    data, delete the orphaned legacy file. Otherwise preserve both;
///    replacing a populated destination can discard local-only data.
///
/// Also migrates the SQLite `-wal` and `-shm` sidecar files if present, so
/// any unsynced writes in the write-ahead log are preserved.
@visibleForTesting
Future<void> migrateLegacyDatabase({
  required String legacyPath,
  required String newPath,
}) async {
  final legacyFile = File(legacyPath);
  if (!legacyFile.existsSync()) return;

  Map<String, List<int>>? legacySidecars;
  final newFile = File(newPath);
  if (newFile.existsSync()) {
    legacySidecars = _readDatabaseSidecars(legacyPath);
    final newHasActionableData = _databaseHasActionableLocalOnlyData(newPath);
    final legacyHasActionableData = _databaseHasActionableLocalOnlyData(
      legacyPath,
    );

    if (!newHasActionableData && legacyHasActionableData) {
      _backupDestinationDatabase(newPath);
    } else if (newHasActionableData && legacyHasActionableData) {
      _backupLegacyConflictDatabase(
        legacyPath: legacyPath,
        newPath: newPath,
        sidecars: legacySidecars,
      );
      return;
    } else {
      _deleteDatabaseAndSidecars(legacyPath);
      return;
    }
  }

  Directory(p.dirname(newPath)).createSync(recursive: true);
  legacyFile.renameSync(newPath);
  _moveSidecars(
    fromPath: legacyPath,
    toPath: newPath,
    preservedSidecars: legacySidecars,
  );
}

void _backupDestinationDatabase(String dbPath) {
  final backupPath = _nextDatabaseBackupPath(
    dbPath,
    suffix: '.pre_legacy_migration_backup',
  );

  File(dbPath).renameSync(backupPath);
  for (final suffix in const ['-wal', '-shm']) {
    final sidecar = File('$dbPath$suffix');
    if (sidecar.existsSync()) {
      sidecar.renameSync('$backupPath$suffix');
    }
  }
}

void _backupLegacyConflictDatabase({
  required String legacyPath,
  required String newPath,
  required Map<String, List<int>> sidecars,
}) {
  final backupPath = _nextDatabaseBackupPath(
    newPath,
    suffix: '.legacy_conflict_backup',
  );

  Directory(p.dirname(newPath)).createSync(recursive: true);
  File(legacyPath).renameSync(backupPath);
  _moveSidecars(
    fromPath: legacyPath,
    toPath: backupPath,
    preservedSidecars: sidecars,
  );
}

Map<String, List<int>> _readDatabaseSidecars(String dbPath) {
  final sidecars = <String, List<int>>{};
  for (final suffix in const ['-wal', '-shm']) {
    final sidecar = File('$dbPath$suffix');
    if (sidecar.existsSync()) {
      sidecars[suffix] = sidecar.readAsBytesSync();
    }
  }
  return sidecars;
}

void _moveSidecars({
  required String fromPath,
  required String toPath,
  Map<String, List<int>>? preservedSidecars,
}) {
  for (final suffix in const ['-wal', '-shm']) {
    final sidecar = File('$fromPath$suffix');
    if (sidecar.existsSync()) {
      sidecar.renameSync('$toPath$suffix');
    } else if (preservedSidecars?.containsKey(suffix) ?? false) {
      File('$toPath$suffix').writeAsBytesSync(preservedSidecars![suffix]!);
    }
  }
}

void _deleteDatabaseAndSidecars(String dbPath) {
  for (final suffix in const ['', '-wal', '-shm']) {
    final file = File('$dbPath$suffix');
    if (file.existsSync()) file.deleteSync();
  }
}

String _nextDatabaseBackupPath(String dbPath, {required String suffix}) {
  var candidate = '$dbPath$suffix';
  var index = 1;
  while (File(candidate).existsSync() ||
      File('$candidate-wal').existsSync() ||
      File('$candidate-shm').existsSync()) {
    candidate = '$dbPath$suffix.$index';
    index += 1;
  }
  return candidate;
}

bool _databaseHasActionableLocalOnlyData(String dbPath) {
  Database db;
  try {
    db = sqlite3.open(dbPath, mode: OpenMode.readOnly);
  } on SqliteException {
    return true;
  }

  try {
    for (final query in _localOnlyDataQueries) {
      if (!_databaseHasTable(db, query.tableName)) continue;

      final rows = db.select(query.sql);
      if (rows.isNotEmpty) return true;
    }
    return false;
  } on SqliteException {
    return true;
  } finally {
    db.close();
  }
}

bool _databaseHasTable(Database db, String tableName) {
  final rows = db.select(
    "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ? LIMIT 1",
    [tableName],
  );
  return rows.isNotEmpty;
}

const _localOnlyDataQueries = [
  _LocalOnlyDataQuery(
    'pending_uploads',
    'SELECT 1 FROM pending_uploads WHERE status NOT IN '
        "('published', 'failed') LIMIT 1",
  ),
  _LocalOnlyDataQuery(
    'pending_actions',
    "SELECT 1 FROM pending_actions WHERE status != 'completed' LIMIT 1",
  ),
  _LocalOnlyDataQuery(
    'outgoing_dms',
    "SELECT 1 FROM outgoing_dms WHERE recipient_wrap_status != 'sent' "
        "OR self_wrap_status != 'sent' LIMIT 1",
  ),
  _LocalOnlyDataQuery(
    'personal_reactions',
    'SELECT 1 FROM personal_reactions LIMIT 1',
  ),
  _LocalOnlyDataQuery(
    'personal_reposts',
    'SELECT 1 FROM personal_reposts LIMIT 1',
  ),
  _LocalOnlyDataQuery('drafts', 'SELECT 1 FROM drafts LIMIT 1'),
  _LocalOnlyDataQuery('clips', 'SELECT 1 FROM clips LIMIT 1'),
  _LocalOnlyDataQuery(
    'direct_messages',
    'SELECT 1 FROM direct_messages LIMIT 1',
  ),
  _LocalOnlyDataQuery('conversations', 'SELECT 1 FROM conversations LIMIT 1'),
];

class _LocalOnlyDataQuery {
  const _LocalOnlyDataQuery(this.tableName, this.sql);

  final String tableName;
  final String sql;
}

/// Builds the shared database path from a platform-specific writable base.
///
/// Application Support is preferred for sandboxed app data on macOS/iOS.
@visibleForTesting
String buildSharedDatabasePath(String basePath) {
  return p.join(basePath, 'openvine', 'database', 'divine_db.db');
}

/// Ensures the database parent directory exists before SQLite opens the file.
///
/// Fresh installs and clean sandbox containers may not have the nested
/// `openvine/database` directory tree yet. Without creating it first,
/// SQLite can fail with `SqliteException(14): unable to open database file`.
@visibleForTesting
File prepareDatabaseFile(String dbPath) {
  final dbFile = File(dbPath);
  dbFile.parent.createSync(recursive: true);
  return dbFile;
}
