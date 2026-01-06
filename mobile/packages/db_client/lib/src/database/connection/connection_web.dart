// ABOUTME: Web-specific database connection using WASM-based SQLite
// ABOUTME: Provides web-compatible storage through drift's wasm implementation

import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

/// Open a database connection for web platform
/// Uses WASM-based SQLite through drift's modern wasm implementation
QueryExecutor openConnection() {
  return DatabaseConnection.delayed(
    Future(() async {
      final result = await WasmDatabase.open(
        databaseName: 'divine_db',
        sqlite3Uri: Uri.parse('sqlite3.wasm'),
        driftWorkerUri: Uri.parse('drift_worker.js'),
      );

      if (result.missingFeatures.isNotEmpty) {
        // Log missing browser features for debugging WASM database fallback
        // ignore: avoid_print
        print(
          'Using ${result.chosenImplementation} due to missing '
          'browser features: ${result.missingFeatures}',
        );
      }

      return result.resolvedExecutor;
    }),
  );
}

/// Get path to shared database file
/// On web, this returns a logical name for the WASM database
Future<String> getSharedDatabasePath() async {
  return 'divine_db'; // Database name for WASM storage
}
