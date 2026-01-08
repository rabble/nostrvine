// ABOUTME: Web-specific database connection using IndexedDB
// ABOUTME: Provides web-compatible storage through drift's web implementation

import 'package:drift/drift.dart';
// TODO(any): Migrate from deprecated drift/web.dart https://github.com/divinevideo/divine-mobile/issues/373
// ignore_for_file: deprecated_member_use
import 'package:drift/web.dart';

/// Open a database connection for web platform
/// Uses IndexedDB through drift's web implementation
QueryExecutor openConnection() {
  return LazyDatabase(() async {
    return WebDatabase('divine_db');
  });
}

/// Get path to shared database file
/// On web, this returns a logical name for IndexedDB
Future<String> getSharedDatabasePath() async {
  return 'divine_db'; // IndexedDB database name
}
