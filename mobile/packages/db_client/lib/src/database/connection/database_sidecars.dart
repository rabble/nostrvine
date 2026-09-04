/// SQLite files whose lifecycle is coupled to the main database file.
///
/// A rollback journal is recovery data. It must move with its database and
/// must only be deleted when the corresponding database is deleted too.
const String rollbackJournalSuffix = '-journal';
const List<String> databaseSidecarSuffixes = [
  rollbackJournalSuffix,
  '-wal',
  '-shm',
];
