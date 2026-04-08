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

/// One-time migration from the pre-PR #2840 Documents-directory location
/// to the current Application Support location.
///
/// No-op when:
/// * the new location already has a database (never clobber existing data),
/// * or the legacy file does not exist (fresh install / post-migration run).
///
/// Also migrates the SQLite `-wal` and `-shm` sidecar files if present, so
/// any unsynced writes in the write-ahead log are preserved.
@visibleForTesting
Future<void> migrateLegacyDatabase({
  required String legacyPath,
  required String newPath,
}) async {
  final newFile = File(newPath);
  if (newFile.existsSync()) {
    return;
  }

  final legacyFile = File(legacyPath);
  if (!legacyFile.existsSync()) {
    return;
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
