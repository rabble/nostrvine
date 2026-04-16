// ABOUTME: Native platform database connection using SQLite
// ABOUTME: Provides file-based SQLite storage for iOS, Android, macOS, etc.

import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Open a database connection for native platforms
/// Uses file-based SQLite through drift's native implementation
QueryExecutor openConnection() {
  return LazyDatabase(() async {
    final dbPath = await getSharedDatabasePath();
    final dbFile = prepareDatabaseFile(dbPath);
    return NativeDatabase(
      dbFile,
    );
  });
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

/// Bump this version to force a full database reset on next app launch.
///
/// All local data is re-fetchable from Nostr relays, so the database is
/// effectively a cache. When a schema change, path migration, or data
/// corruption requires a clean slate, increment this constant.
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

/// Deletes the database and its `-wal` / `-shm` sidecars when the stored
/// cache version is stale. Writes the current [dbCacheVersion] afterwards.
///
/// On first run (no version file), writes the current version without
/// deleting anything — existing users are not wiped by the mechanism's
/// introduction.
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
    _deleteDatabaseAndSidecars(dbPath);
    writeDbCacheVersion(dbDir, dbCacheVersion);
  }
}

/// One-time migration from the pre-PR #2840 Documents-directory location
/// to the current Application Support location.
///
/// Handles three cases:
/// 1. Legacy does not exist → no-op (fresh install or already migrated).
/// 2. Legacy exists, new does not → rename legacy to new.
/// 3. Both exist → the legacy DB predates the path change and contains the
///    user's real history. Replace the new DB with the legacy one.
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
    // Both databases exist. The legacy DB predates the path change and
    // has more history — always prefer it.
    _deleteDatabaseAndSidecars(newPath);
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

/// Deletes a database file and its `-wal` / `-shm` sidecars.
void _deleteDatabaseAndSidecars(String dbPath) {
  for (final suffix in const ['', '-wal', '-shm']) {
    final file = File('$dbPath$suffix');
    if (file.existsSync()) file.deleteSync();
  }
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
