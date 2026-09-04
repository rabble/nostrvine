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
    this.extendedResultCode,
  });

  final DatabaseHotJournalRecoveryStage stage;
  final int? extendedResultCode;

  int? get resultCode =>
      extendedResultCode == null ? null : extendedResultCode! & 0xff;

  @override
  String toString() =>
      'DatabaseHotJournalRecoveryError: stage=${stage.name}, '
      'resultCode=$resultCode, extendedResultCode=$extendedResultCode; '
      'automatic reset was refused.';
}
