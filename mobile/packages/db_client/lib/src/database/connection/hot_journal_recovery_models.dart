enum DatabaseHotJournalRecoveryStage {
  inspectHeader,
  validateCipherKey,
  createSnapshot,
  replayJournal,
  validateIntegrity,
  restoreSnapshot,
  retryClassification,
}

/// SQLite found a hot rollback journal, but safe recovery could not complete.
///
/// The diagnostic deliberately excludes paths, SQL text, and key material.
class DatabaseHotJournalRecoveryError implements Exception {
  const DatabaseHotJournalRecoveryError({
    required this.stage,
    this.resultCode = 8,
    this.extendedResultCode = 776,
  });

  final DatabaseHotJournalRecoveryStage stage;
  final int resultCode;
  final int extendedResultCode;

  @override
  String toString() =>
      'DatabaseHotJournalRecoveryError: stage=${stage.name}, '
      'resultCode=$resultCode, extendedResultCode=$extendedResultCode; '
      'automatic reset was refused.';
}
