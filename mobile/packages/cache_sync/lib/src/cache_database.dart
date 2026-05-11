// ignore_for_file: public_member_api_docs // internal implementation, not re-exported by the package
import 'package:cache_sync/src/cache_entries_table.dart';
import 'package:cache_sync/src/connection/connection.dart';
import 'package:drift/drift.dart';

part 'cache_database.g.dart';

@DriftDatabase(tables: [CacheEntries])
class CacheDatabase extends _$CacheDatabase {
  /// Creates the database backed by the platform's preferred storage.
  CacheDatabase() : super(openConnection()); // coverage:ignore-line

  /// In-memory database for tests.
  CacheDatabase.test(super.e);

  @override
  int get schemaVersion => 1;
}
