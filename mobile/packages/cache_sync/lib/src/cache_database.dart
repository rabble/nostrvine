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

  /// Migration strategy for the cache store.
  ///
  /// `cache_sync` is a disposable local cache with a single [CacheEntries]
  /// table and no schema-shape migration yet. This is the explicit anchor
  /// point for the first real migration; see `MIGRATIONS.md` for the
  /// versioning path and the #4382 decision not to ship a legacy-key-residue
  /// data delete.
  @override
  MigrationStrategy get migration =>
      MigrationStrategy(onCreate: (m) => m.createAll());
}
