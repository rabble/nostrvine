import 'dart:convert';
import 'dart:io';

import 'package:db_client/src/database/connection/hot_journal_recovery_models.dart';
import 'package:sqlite3/common.dart' show CommonDatabase;
import 'package:sqlite3/sqlite3.dart';

const sqliteReadOnly = 8;
const sqliteReadOnlyRollback = 776;

const _sqliteHeader = 'SQLite format 3\x00';

/// Replays a hot rollback journal through SQLite without ever editing the
/// journal directly.
///
/// Non-plaintext files must first open under [configureEncryptedDatabase]
/// through an immutable view. That proves the existing key can decrypt the
/// database before the writable connection is allowed to begin rollback.
void recoverHotRollbackJournal({
  required String databasePath,
  required void Function(CommonDatabase db) configureEncryptedDatabase,
}) {
  final isPlaintext = _hasPlaintextHeader(databasePath);
  if (!isPlaintext) {
    _validateEncryptedDatabaseIgnoringJournal(
      databasePath,
      configureEncryptedDatabase,
    );
  }

  final snapshot = _HotJournalSnapshot.create(databasePath);
  try {
    _replayJournal(
      databasePath,
      isPlaintext: isPlaintext,
      configureEncryptedDatabase: configureEncryptedDatabase,
    );
    _validateRecoveredDatabase(
      databasePath,
      isPlaintext: isPlaintext,
      configureEncryptedDatabase: configureEncryptedDatabase,
    );
  } on DatabaseHotJournalRecoveryError {
    snapshot.restore(databasePath);
    rethrow;
  } finally {
    snapshot.dispose();
  }
}

void _replayJournal(
  String databasePath, {
  required bool isPlaintext,
  required void Function(CommonDatabase db) configureEncryptedDatabase,
}) {
  Database? database;
  try {
    database = sqlite3.open(databasePath, mode: OpenMode.readWrite);
    if (!isPlaintext) configureEncryptedDatabase(database);
    database.select('SELECT count(*) FROM sqlite_master;');
  } on Object {
    throw const DatabaseHotJournalRecoveryError(
      stage: DatabaseHotJournalRecoveryStage.replayJournal,
    );
  } finally {
    database?.close();
  }
}

bool _hasPlaintextHeader(String databasePath) {
  try {
    final file = File(databasePath);
    if (file.lengthSync() < _sqliteHeader.length) {
      throw const DatabaseHotJournalRecoveryError(
        stage: DatabaseHotJournalRecoveryStage.inspectHeader,
      );
    }
    final bytes = file.openSync()..setPositionSync(0);
    try {
      return ascii.decode(bytes.readSync(_sqliteHeader.length)) ==
          _sqliteHeader;
    } on FormatException {
      return false;
    } finally {
      bytes.closeSync();
    }
  } on DatabaseHotJournalRecoveryError {
    rethrow;
  } on Object {
    throw const DatabaseHotJournalRecoveryError(
      stage: DatabaseHotJournalRecoveryStage.inspectHeader,
    );
  }
}

void _validateEncryptedDatabaseIgnoringJournal(
  String databasePath,
  void Function(CommonDatabase db) configureEncryptedDatabase,
) {
  Database? database;
  try {
    final uri = Uri.file(
      databasePath,
    ).replace(queryParameters: const {'immutable': '1'}).toString();
    database = sqlite3.open(uri, mode: OpenMode.readOnly, uri: true);
    configureEncryptedDatabase(database);
    database.select('SELECT count(*) FROM sqlite_master;');
  } on Object {
    throw const DatabaseHotJournalRecoveryError(
      stage: DatabaseHotJournalRecoveryStage.validateCipherKey,
    );
  } finally {
    database?.close();
  }
}

void _validateRecoveredDatabase(
  String databasePath, {
  required bool isPlaintext,
  required void Function(CommonDatabase db) configureEncryptedDatabase,
}) {
  Database? database;
  try {
    database = sqlite3.open(databasePath, mode: OpenMode.readOnly);
    if (!isPlaintext) configureEncryptedDatabase(database);
    final result = database.select('PRAGMA integrity_check;');
    if (result.length != 1 || result.first.values.single != 'ok') {
      throw const DatabaseHotJournalRecoveryError(
        stage: DatabaseHotJournalRecoveryStage.validateIntegrity,
      );
    }
  } on DatabaseHotJournalRecoveryError {
    rethrow;
  } on Object {
    throw const DatabaseHotJournalRecoveryError(
      stage: DatabaseHotJournalRecoveryStage.validateIntegrity,
    );
  } finally {
    database?.close();
  }
}

class _HotJournalSnapshot {
  _HotJournalSnapshot._({
    required this.directory,
    required this.database,
    required this.journal,
  });

  final Directory directory;
  final File database;
  final File journal;

  static _HotJournalSnapshot create(String databasePath) {
    Directory? directory;
    try {
      directory = Directory.systemTemp.createTempSync(
        'divine_hot_journal_recovery_',
      );
      return _HotJournalSnapshot._(
        directory: directory,
        database: File(databasePath).copySync('${directory.path}/database'),
        journal: File(
          '$databasePath-journal',
        ).copySync('${directory.path}/journal'),
      );
    } on Object {
      if (directory?.existsSync() ?? false) {
        directory!.deleteSync(recursive: true);
      }
      throw const DatabaseHotJournalRecoveryError(
        stage: DatabaseHotJournalRecoveryStage.createSnapshot,
      );
    }
  }

  void restore(String databasePath) {
    try {
      database.copySync(databasePath);
      journal.copySync('$databasePath-journal');
    } on Object {
      throw const DatabaseHotJournalRecoveryError(
        stage: DatabaseHotJournalRecoveryStage.restoreSnapshot,
      );
    }
  }

  void dispose() {
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  }
}
