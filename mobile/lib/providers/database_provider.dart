// ABOUTME: Provides singleton AppDatabase instance with proper lifecycle management
// ABOUTME: Database auto-closes when provider container is disposed
import 'package:db_client/db_client.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'database_provider.g.dart';

@Riverpod(keepAlive: true) // Singleton - lives for app lifetime
AppDatabase database(Ref ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
}

/// AppDbClient wrapping the database for NostrClient integration.
/// Enables optimistic caching of Nostr events in the local database.
@Riverpod(keepAlive: true)
AppDbClient appDbClient(Ref ref) {
  final db = ref.watch(databaseProvider);
  // Note: DbClient constructor with generatedDatabase is @visibleForTesting
  // but works correctly for production use
  final dbClient = DbClient(generatedDatabase: db);
  return AppDbClient(dbClient, db);
}
