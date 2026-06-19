// ABOUTME: No-op SQLite3MultipleCiphers runtime for platforms without dart:ffi (web).
// ABOUTME: Native at-rest encryption is out of scope on web (#373).

/// Ensures `package:sqlite3` loads the sqlite3mc build. No-op on web.
Future<void> ensureSqlCipherRuntime() async {}

/// Whether SQLite3MultipleCiphers is the active SQLite library. Always `false`
/// on web.
bool isSqlCipherAvailable() => false;
