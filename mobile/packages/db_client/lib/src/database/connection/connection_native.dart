// ABOUTME: Native platform database connection using SQLite
// ABOUTME: Provides file-based SQLite storage for iOS, Android, macOS, etc.

import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
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
    return NativeDatabase(
      dbFile,
    );
  });
}

bool get _isFlutterTestProcess =>
    Platform.executable.contains('flutter_tester');

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
/// 3. Both exist → migrate legacy only if the destination has no local-only
///    rows and no non-empty sidecars. Otherwise preserve both; replacing a
///    populated destination can discard local-only data.
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

  final newFile = File(newPath);
  if (newFile.existsSync()) {
    if (!_hasNonEmptyDatabaseSidecars(newPath) &&
        !_databaseHasLocalOnlyData(newPath) &&
        _databaseHasLocalOnlyData(legacyPath)) {
      _backupDestinationDatabase(newPath);
    } else {
      return;
    }
  }

  Directory(p.dirname(newPath)).createSync(recursive: true);
  legacyFile.renameSync(newPath);

  for (final suffix in const ['-wal', '-shm']) {
    final legacySidecar = File('$legacyPath$suffix');
    if (legacySidecar.existsSync()) {
      legacySidecar.renameSync('$newPath$suffix');
    }
  }
}

bool _hasNonEmptyDatabaseSidecars(String dbPath) {
  for (final suffix in const ['-wal', '-shm']) {
    final sidecar = File('$dbPath$suffix');
    if (sidecar.existsSync() && sidecar.lengthSync() > 0) return true;
  }
  return false;
}

void _backupDestinationDatabase(String dbPath) {
  final backupPath = _nextDestinationBackupPath(dbPath);

  File(dbPath).renameSync(backupPath);
  for (final suffix in const ['-wal', '-shm']) {
    final sidecar = File('$dbPath$suffix');
    if (sidecar.existsSync()) {
      sidecar.renameSync('$backupPath$suffix');
    }
  }
}

String _nextDestinationBackupPath(String dbPath) {
  const backupSuffix = '.pre_legacy_migration_backup';
  var candidate = '$dbPath$backupSuffix';
  var index = 1;
  while (File(candidate).existsSync() ||
      File('$candidate-wal').existsSync() ||
      File('$candidate-shm').existsSync()) {
    candidate = '$dbPath$backupSuffix.$index';
    index += 1;
  }
  return candidate;
}

bool _databaseHasLocalOnlyData(String dbPath) {
  Database db;
  try {
    db = sqlite3.open(dbPath, mode: OpenMode.readOnly);
  } catch (_) {
    return true;
  }

  try {
    for (final tableName in _localOnlyTableNames) {
      if (!_databaseHasTable(db, tableName)) continue;

      final rows = db.select(
        'SELECT 1 FROM "${tableName.replaceAll('"', '""')}" LIMIT 1',
      );
      if (rows.isNotEmpty) return true;
    }
    return false;
  } catch (_) {
    return true;
  } finally {
    db.dispose();
  }
}

bool _databaseHasTable(Database db, String tableName) {
  final rows = db.select(
    "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ? LIMIT 1",
    [tableName],
  );
  return rows.isNotEmpty;
}

const _localOnlyTableNames = [
  'pending_uploads',
  'personal_reactions',
  'personal_reposts',
  'pending_actions',
  'drafts',
  'clips',
  'direct_messages',
  'conversations',
  'outgoing_dms',
];

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
