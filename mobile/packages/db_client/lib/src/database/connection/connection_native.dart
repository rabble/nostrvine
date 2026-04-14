// ABOUTME: Native platform database connection using SQLite
// ABOUTME: Provides file-based SQLite storage for iOS, Android, macOS, etc.

import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' as raw_sqlite;

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

/// If the new DB has at most this many conversations it is considered an
/// artifact of the relay re-fetch (`limit: 50`) and is safe to replace
/// with the legacy database that contains the user's real history.
@visibleForTesting
const int maxConversationsForReplacement = 5;

/// One-time migration from the pre-PR #2840 Documents-directory location
/// to the current Application Support location.
///
/// Handles three cases:
/// 1. New DB does not exist, legacy exists → rename legacy to new.
/// 2. Both exist but new DB is near-empty (≤ [maxConversationsForReplacement]
///    conversations) → replace new with legacy. This covers users who went
///    through the intermediate build that created an empty DB at the new path.
/// 3. Both exist and new DB has data → keep new, delete legacy as cleanup.
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
    // Both databases exist. Check whether the new DB is near-empty
    // (artifact of the intermediate build) or has real user data.
    if (_isNearEmptyDatabase(newPath)) {
      _deleteDatabaseAndSidecars(newPath);
    } else {
      // New DB has real data — keep it, discard orphaned legacy.
      _deleteDatabaseAndSidecars(legacyPath);
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

/// Returns `true` when the database at [dbPath] has at most
/// [maxConversationsForReplacement] conversations, meaning it was likely
/// created by the relay re-fetch and does not contain meaningful user data.
///
/// Returns `true` (treat as empty) when the conversations table does not
/// exist or the database cannot be opened — both indicate an incomplete
/// or corrupt database that is safe to replace.
bool _isNearEmptyDatabase(String dbPath) {
  try {
    final db = raw_sqlite.sqlite3.open(dbPath);
    try {
      final result = db.select(
        'SELECT COUNT(*) AS cnt FROM conversations',
      );
      final count = result.first['cnt'] as int;
      return count <= maxConversationsForReplacement;
    } on raw_sqlite.SqliteException {
      // Table does not exist or DB is corrupt — treat as empty.
      return true;
    } finally {
      db.dispose();
    }
  } on raw_sqlite.SqliteException {
    // Cannot open the database — treat as empty.
    return true;
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
