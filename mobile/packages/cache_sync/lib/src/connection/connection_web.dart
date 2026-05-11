// ABOUTME: Web-specific database connection for cache_sync.
// ABOUTME: Provides web-compatible storage through drift's WasmDatabase.
// coverage:ignore-file

import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

/// Opens a database connection for the web platform.
QueryExecutor openConnection() {
  return LazyDatabase(() async {
    final result = await WasmDatabase.open(
      databaseName: 'cache_sync_db',
      sqlite3Uri: Uri.parse('sqlite3.wasm'),
      driftWorkerUri: Uri.parse('drift_worker.js'),
    );
    return result.resolvedExecutor;
  });
}
