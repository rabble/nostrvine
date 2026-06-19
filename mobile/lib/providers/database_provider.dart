// ABOUTME: Provides singleton AppDatabase instance with proper lifecycle management
// ABOUTME: Database auto-closes when provider container is disposed
import 'package:db_client/db_client.dart';
import 'package:openvine/providers/db_cipher_key_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'database_provider.g.dart';

@Riverpod(keepAlive: true) // Singleton - lives for app lifetime
AppDatabase database(Ref ref) {
  // When a cipher key is present (resolved at startup by
  // DatabaseEncryptionBootstrap), open an at-rest-encrypted native
  // connection; otherwise (web, tests, or a deferred migration) open the
  // default connection. (#570, finding C2)
  final cipherKey = ref.watch(dbCipherKeyProvider);
  final db = cipherKey == null
      ? AppDatabase()
      : AppDatabase(openEncryptedConnection(rawKeyHex: cipherKey));
  ref.onDispose(db.close);
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
