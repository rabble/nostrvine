// ABOUTME: Loads sqlite3mc so the native-asset hook runs before Mobile CI tests.
// ABOUTME: Lets warmup_sqlite3mc.sh retry a dropped GitHub Releases download (#7197).

import 'package:sqlite3/sqlite3.dart';

void main() {
  final db = sqlite3.openInMemory();
  try {
    db.select('SELECT 1;');
  } finally {
    db.close();
  }
}
