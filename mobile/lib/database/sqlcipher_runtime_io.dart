// ABOUTME: Native SQLCipher runtime bootstrap (Android lib override + availability probe).
// ABOUTME: Forces package:sqlite3 to load libsqlcipher.so on Android before first use.

import 'dart:io';

import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';

/// Forces `package:sqlite3` to load the SQLCipher native library.
///
/// Android ships a plain `libsqlite3.so`, so `package:sqlite3` must be told to
/// load `libsqlcipher.so` instead — before ANY sqlite3 call and before drift
/// spawns its background isolate. iOS/macOS link the SQLCipher pod
/// automatically when it is the only sqlite3 provider, so no override is
/// needed there (the runtime [isSqlCipherAvailable] probe is the safety net).
Future<void> ensureSqlCipherRuntime() async {
  if (Platform.isAndroid) {
    await applyWorkaroundToOpenSqlCipherOnOldAndroidVersions();
    open.overrideFor(OperatingSystem.android, openCipherOnAndroid);
  }
}

/// Probes whether SQLCipher is actually the linked library by opening an
/// in-memory database and checking the SQLCipher-only `cipher_version` pragma
/// (empty on plain SQLite). Guards against the iOS failure mode where the
/// system sqlite3 is linked and `PRAGMA key` silently no-ops.
bool isSqlCipherAvailable() {
  final db = sqlite3.openInMemory();
  try {
    return db.select('PRAGMA cipher_version;').isNotEmpty;
  } on SqliteException {
    return false;
  } finally {
    db.dispose();
  }
}
