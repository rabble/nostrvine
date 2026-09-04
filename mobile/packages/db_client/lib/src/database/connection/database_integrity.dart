import 'package:sqlite3/common.dart' show CommonDatabase;
import 'package:sqlite3/sqlite3.dart';

/// Returns whether [database] passes SQLite's `PRAGMA quick_check` — i.e. every
/// table and index b-tree is structurally sound.
///
/// `quick_check` walks the page structure of all b-trees (skipping only the
/// slower row-content and foreign-key validation that `integrity_check` adds),
/// so it detects malformed indexes and pages while staying cheap enough for a
/// startup probe. Any thrown SQLite error is treated as corruption.
bool databasePassesIntegrityCheck(CommonDatabase database) {
  try {
    return databaseQuickCheckPasses(database);
  } on SqliteException {
    return false;
  }
}

/// Runs the shared quick check while preserving SQLite errors for diagnostics.
bool databaseQuickCheckPasses(CommonDatabase database) {
  final rows = database.select('PRAGMA quick_check;');
  if (rows.length != 1) return false;
  final result = rows.first.values.first;
  return result is String && result.toLowerCase() == 'ok';
}
