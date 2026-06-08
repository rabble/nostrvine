// ABOUTME: No-op SQLCipher runtime for platforms without dart:ffi (web).
// ABOUTME: SQLCipher is native-only; web at-rest encryption is out of scope (#373).

/// Ensures `package:sqlite3` loads the SQLCipher build. No-op on web.
Future<void> ensureSqlCipherRuntime() async {}

/// Whether SQLCipher is the active SQLite library. Always `false` on web.
bool isSqlCipherAvailable() => false;
