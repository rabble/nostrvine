// ABOUTME: Native SQLite3MultipleCiphers runtime availability probe.
// ABOUTME: sqlite3 3.x loads the selected native SQLite build through hooks.

import 'package:sqlite3/sqlite3.dart';

/// Ensures `package:sqlite3` has initialized its hook-selected native library.
///
/// sqlite3 3.x uses build hooks for Android/iOS/macOS/Linux/Windows native
/// assets, so the legacy sqlcipher_flutter_libs Android workaround and
/// `open.overrideFor` path are intentionally gone.
Future<void> ensureSqlCipherRuntime() async {}

/// Probes whether SQLite3MultipleCiphers is the active SQLite implementation.
///
/// Upstream SQLite returns no rows for `PRAGMA cipher`; MC returns at least the
/// currently selected cipher. This is the fail-closed guard before the app can
/// open or migrate an encrypted local database.
bool isSqlCipherAvailable() {
  final db = sqlite3.openInMemory();
  try {
    return db.select('PRAGMA cipher;').isNotEmpty;
  } on SqliteException {
    return false;
  } finally {
    db.close();
  }
}
