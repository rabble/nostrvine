import 'dart:io';

import 'package:db_client/src/database/connection/connection_native.dart';
import 'package:drift/drift.dart' show QueryExecutor;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/common.dart' show CommonDatabase;
import 'package:sqlite3/sqlite3.dart';

class _MockCipherDb extends Mock implements CommonDatabase {}

void main() {
  group('prepareDatabaseFile', () {
    late Directory tempRoot;

    setUp(() {
      tempRoot = Directory.systemTemp.createTempSync(
        'db_client_connection_native_test_',
      );
    });

    tearDown(() {
      if (tempRoot.existsSync()) {
        tempRoot.deleteSync(recursive: true);
      }
    });

    test('creates the parent database directory tree when missing', () {
      final dbPath = p.join(
        tempRoot.path,
        'openvine',
        'database',
        'divine_db.db',
      );

      final dbFile = prepareDatabaseFile(dbPath);

      expect(dbFile.path, equals(dbPath));
      expect(dbFile.parent.existsSync(), isTrue);
    });
  });

  group('buildSharedDatabasePath', () {
    test('uses Application Support-style base path with openvine/database', () {
      final path = buildSharedDatabasePath('/tmp/app-support');

      expect(path, equals('/tmp/app-support/openvine/database/divine_db.db'));
    });
  });

  group('applyDbCacheVersionReset', () {
    late Directory tempRoot;
    late String dbPath;
    late String dbDir;

    setUp(() {
      tempRoot = Directory.systemTemp.createTempSync(
        'db_client_cache_version_test_',
      );
      dbDir = p.join(tempRoot.path, 'openvine', 'database');
      dbPath = p.join(dbDir, 'divine_db.db');
    });

    tearDown(() {
      if (tempRoot.existsSync()) {
        tempRoot.deleteSync(recursive: true);
      }
    });

    test('writes current version on first run without deleting DB', () {
      Directory(dbDir).createSync(recursive: true);
      File(dbPath).writeAsBytesSync(const [1, 2, 3]);

      applyDbCacheVersionReset(dbPath);

      expect(File(dbPath).existsSync(), isTrue);
      expect(File(dbPath).readAsBytesSync(), equals(const [1, 2, 3]));
      expect(readDbCacheVersion(dbDir), equals(dbCacheVersion));
    });

    test('preserves existing DB and sidecars when stored version is stale', () {
      Directory(dbDir).createSync(recursive: true);
      File(dbPath).writeAsBytesSync(const [1]);
      File('$dbPath-wal').writeAsBytesSync(const [2]);
      File('$dbPath-shm').writeAsBytesSync(const [3]);
      writeDbCacheVersion(dbDir, 1);

      applyDbCacheVersionReset(dbPath);

      expect(File(dbPath).readAsBytesSync(), equals(const [1]));
      expect(File('$dbPath-wal').readAsBytesSync(), equals(const [2]));
      expect(File('$dbPath-shm').readAsBytesSync(), equals(const [3]));
      expect(readDbCacheVersion(dbDir), equals(dbCacheVersion));
    });

    test('no-op when stored version matches current', () {
      Directory(dbDir).createSync(recursive: true);
      File(dbPath).writeAsBytesSync(const [9, 9]);
      writeDbCacheVersion(dbDir, dbCacheVersion);

      applyDbCacheVersionReset(dbPath);

      expect(File(dbPath).existsSync(), isTrue);
      expect(File(dbPath).readAsBytesSync(), equals(const [9, 9]));
    });

    test('no-op when DB does not exist and no version file', () {
      applyDbCacheVersionReset(dbPath);

      expect(readDbCacheVersion(dbDir), equals(dbCacheVersion));
    });
  });

  group('readDbCacheVersion / writeDbCacheVersion', () {
    late Directory tempRoot;
    late String dbDir;

    setUp(() {
      tempRoot = Directory.systemTemp.createTempSync(
        'db_client_version_rw_test_',
      );
      dbDir = p.join(tempRoot.path, 'openvine', 'database');
    });

    tearDown(() {
      if (tempRoot.existsSync()) {
        tempRoot.deleteSync(recursive: true);
      }
    });

    test('returns null when version file does not exist', () {
      expect(readDbCacheVersion(dbDir), isNull);
    });

    test('round-trips a version number', () {
      writeDbCacheVersion(dbDir, 42);

      expect(readDbCacheVersion(dbDir), equals(42));
    });

    test('returns null for corrupt version file content', () {
      Directory(dbDir).createSync(recursive: true);
      File(p.join(dbDir, dbVersionFileName)).writeAsStringSync('not-a-number');

      expect(readDbCacheVersion(dbDir), isNull);
    });
  });

  group('migrateLegacyDatabase', () {
    late Directory tempRoot;
    late String legacyPath;
    late String newPath;

    setUp(() {
      tempRoot = Directory.systemTemp.createTempSync(
        'db_client_migrate_legacy_test_',
      );
      legacyPath = p.join(
        tempRoot.path,
        'legacy',
        'openvine',
        'database',
        'divine_db.db',
      );
      newPath = p.join(
        tempRoot.path,
        'support',
        'openvine',
        'database',
        'divine_db.db',
      );
    });

    tearDown(() {
      if (tempRoot.existsSync()) {
        tempRoot.deleteSync(recursive: true);
      }
    });

    test('moves the legacy database when the new location is empty', () async {
      final legacyFile = File(legacyPath);
      legacyFile.parent.createSync(recursive: true);
      legacyFile.writeAsBytesSync(const [1, 2, 3, 4]);

      await migrateLegacyDatabase(legacyPath: legacyPath, newPath: newPath);

      expect(File(newPath).existsSync(), isTrue);
      expect(File(newPath).readAsBytesSync(), equals(const [1, 2, 3, 4]));
      expect(File(legacyPath).existsSync(), isFalse);
    });

    test('creates the destination directory tree when missing', () async {
      final legacyFile = File(legacyPath);
      legacyFile.parent.createSync(recursive: true);
      legacyFile.writeAsBytesSync(const [42]);

      expect(Directory(p.dirname(newPath)).existsSync(), isFalse);

      await migrateLegacyDatabase(legacyPath: legacyPath, newPath: newPath);

      expect(Directory(p.dirname(newPath)).existsSync(), isTrue);
      expect(File(newPath).existsSync(), isTrue);
    });

    test('preserves new DB when both legacy and new databases exist', () async {
      final legacyFile = File(legacyPath);
      legacyFile.parent.createSync(recursive: true);
      legacyFile.writeAsBytesSync(const [1, 2, 3]);

      final newFile = File(newPath);
      newFile.parent.createSync(recursive: true);
      newFile.writeAsBytesSync(const [9, 9, 9]);

      await migrateLegacyDatabase(legacyPath: legacyPath, newPath: newPath);

      expect(File(legacyPath).existsSync(), isFalse);
      expect(File(newPath).readAsBytesSync(), equals(const [9, 9, 9]));
      expect(
        File(_legacyConflictBackupPath(newPath)).readAsBytesSync(),
        equals(const [1, 2, 3]),
      );
    });

    test(
      'restores legacy DB when destination exists but has no local data',
      () async {
        _createSqliteDatabase(legacyPath, draftCount: 1);
        _createSqliteDatabase(newPath);

        await migrateLegacyDatabase(legacyPath: legacyPath, newPath: newPath);

        expect(_draftCount(newPath), equals(1));
        expect(File(legacyPath).existsSync(), isFalse);
      },
    );

    test(
      'restores legacy DB when destination has only replaceable cache rows',
      () async {
        _createSqliteDatabase(legacyPath, draftCount: 1);
        File('$legacyPath-wal').writeAsBytesSync(const [4]);
        File('$legacyPath-shm').writeAsBytesSync(const [5]);
        _createSqliteDatabase(newPath, eventCount: 1);

        expect(File('$legacyPath-wal').existsSync(), isTrue);

        await migrateLegacyDatabase(legacyPath: legacyPath, newPath: newPath);

        expect(_draftCount(newPath), equals(1));
        expect(File(legacyPath).existsSync(), isFalse);
        expect(File('$legacyPath-wal').existsSync(), isFalse);
        expect(File('$legacyPath-shm').existsSync(), isFalse);
        expect(File(_destinationBackupPath(newPath)).existsSync(), isTrue);
        expect(_eventCount(_destinationBackupPath(newPath)), equals(1));
      },
    );

    test(
      'restores legacy DB when destination only has empty sidecars',
      () async {
        _createSqliteDatabase(legacyPath, draftCount: 1);
        _createSqliteDatabase(newPath);
        File('$newPath-wal').createSync();
        File('$newPath-shm').createSync();

        await migrateLegacyDatabase(legacyPath: legacyPath, newPath: newPath);

        expect(_draftCount(newPath), equals(1));
        expect(File(legacyPath).existsSync(), isFalse);
        expect(File('$newPath-wal').existsSync(), isFalse);
        expect(File('$newPath-shm').existsSync(), isFalse);
      },
    );

    test(
      'backs up sidecars when destination has no actionable local rows',
      () async {
        _createSqliteDatabase(legacyPath, draftCount: 1);
        _createSqliteDatabase(
          newPath,
          pendingUploadStatuses: const ['published'],
          pendingActionStatuses: const ['completed'],
        );
        File('$newPath-wal').writeAsBytesSync(const [7]);
        File('$newPath-shm').writeAsBytesSync(const [8]);

        await migrateLegacyDatabase(legacyPath: legacyPath, newPath: newPath);

        final backupPath = _destinationBackupPath(newPath);
        expect(_draftCount(newPath), equals(1));
        expect(File(legacyPath).existsSync(), isFalse);
        expect(File('$newPath-wal').existsSync(), isFalse);
        expect(File('$newPath-shm').existsSync(), isFalse);
        expect(File(backupPath).existsSync(), isTrue);
        expect(File('$backupPath-wal').existsSync(), isTrue);
        expect(File('$backupPath-shm').existsSync(), isTrue);
        expect(File('$backupPath-wal').lengthSync(), greaterThan(0));
        expect(File('$backupPath-shm').lengthSync(), greaterThan(0));
      },
    );

    test(
      'preserves destination when queue rows still require action',
      () async {
        _createSqliteDatabase(legacyPath, draftCount: 1);
        _createSqliteDatabase(
          newPath,
          pendingUploadStatuses: const ['uploading'],
          pendingActionStatuses: const ['pending'],
        );

        await migrateLegacyDatabase(legacyPath: legacyPath, newPath: newPath);

        final legacyBackupPath = _legacyConflictBackupPath(newPath);
        expect(File(legacyPath).existsSync(), isFalse);
        expect(_draftCount(legacyBackupPath), equals(1));
        expect(_pendingUploadCount(newPath), equals(1));
        expect(_pendingActionCount(newPath), equals(1));
        expect(File(_destinationBackupPath(newPath)).existsSync(), isFalse);
      },
    );

    test(
      'backs up legacy beside destination when both DBs have local data',
      () async {
        _createSqliteDatabase(legacyPath, draftCount: 1);
        File('$legacyPath-wal').writeAsBytesSync(const [4]);
        File('$legacyPath-shm').writeAsBytesSync(const [5]);

        _createSqliteDatabase(newPath, draftCount: 1);
        File('$newPath-wal').writeAsBytesSync(const [2]);
        File('$newPath-shm').writeAsBytesSync(const [3]);

        expect(File('$legacyPath-wal').readAsBytesSync(), equals([4]));
        expect(File('$legacyPath-shm').readAsBytesSync(), equals([5]));

        await migrateLegacyDatabase(legacyPath: legacyPath, newPath: newPath);

        expect(File(newPath).existsSync(), isTrue);
        expect(_draftCount(newPath), equals(1));
        expect(File(legacyPath).existsSync(), isFalse);
        expect(File('$legacyPath-wal').existsSync(), isFalse);
        expect(File('$legacyPath-shm').existsSync(), isFalse);
        expect(File(_destinationBackupPath(newPath)).existsSync(), isFalse);

        final legacyBackupPath = _legacyConflictBackupPath(newPath);
        expect(File(legacyBackupPath).existsSync(), isTrue);
        expect(File('$legacyBackupPath-wal').readAsBytesSync(), equals([4]));
        expect(File('$legacyBackupPath-shm').existsSync(), isTrue);
        expect(File('$legacyBackupPath-shm').lengthSync(), greaterThan(0));
        expect(_draftCount(legacyBackupPath), equals(1));
      },
    );

    test(
      'deletes orphaned legacy database when neither side has actionable data',
      () async {
        _createSqliteDatabase(legacyPath);
        File('$legacyPath-wal').writeAsBytesSync(const [4]);
        File('$legacyPath-shm').writeAsBytesSync(const [5]);
        _createSqliteDatabase(newPath, eventCount: 1);

        await migrateLegacyDatabase(legacyPath: legacyPath, newPath: newPath);

        expect(File(newPath).existsSync(), isTrue);
        expect(_eventCount(newPath), equals(1));
        expect(File(legacyPath).existsSync(), isFalse);
        expect(File('$legacyPath-wal').existsSync(), isFalse);
        expect(File('$legacyPath-shm').existsSync(), isFalse);
      },
    );

    test('no-op when no legacy database exists (fresh install)', () async {
      expect(File(legacyPath).existsSync(), isFalse);
      expect(File(newPath).existsSync(), isFalse);

      await migrateLegacyDatabase(legacyPath: legacyPath, newPath: newPath);

      expect(File(newPath).existsSync(), isFalse);
      expect(Directory(p.dirname(newPath)).existsSync(), isFalse);
    });

    test('migrates WAL and SHM sidecar files alongside the database', () async {
      final legacyFile = File(legacyPath);
      legacyFile.parent.createSync(recursive: true);
      legacyFile.writeAsBytesSync(const [1]);
      File('$legacyPath-wal').writeAsBytesSync(const [2]);
      File('$legacyPath-shm').writeAsBytesSync(const [3]);

      await migrateLegacyDatabase(legacyPath: legacyPath, newPath: newPath);

      expect(File(newPath).readAsBytesSync(), equals(const [1]));
      expect(File('$newPath-wal').readAsBytesSync(), equals(const [2]));
      expect(File('$newPath-shm').readAsBytesSync(), equals(const [3]));
      expect(File('$legacyPath-wal').existsSync(), isFalse);
      expect(File('$legacyPath-shm').existsSync(), isFalse);
    });

    test('migrates database even when no sidecar files are present', () async {
      final legacyFile = File(legacyPath);
      legacyFile.parent.createSync(recursive: true);
      legacyFile.writeAsBytesSync(const [7]);

      await migrateLegacyDatabase(legacyPath: legacyPath, newPath: newPath);

      expect(File(newPath).readAsBytesSync(), equals(const [7]));
      expect(File('$newPath-wal').existsSync(), isFalse);
      expect(File('$newPath-shm').existsSync(), isFalse);
    });
  });

  group('formatCipherKeyPragma', () {
    const validKey =
        '2dd29ca851e7b56e4697b0e1f08507293d761a05ce4d1b628663f411a8086d99';

    test('wraps a 64-hex key in the SQLCipher raw-key PRAGMA form', () {
      expect(
        formatCipherKeyPragma(validKey),
        equals('PRAGMA key = "x\'$validKey\'";'),
      );
    });

    test('accepts upper-case hex', () {
      expect(
        formatCipherKeyPragma(validKey.toUpperCase()),
        equals('PRAGMA key = "x\'${validKey.toUpperCase()}\'";'),
      );
    });

    test('rejects a key that is too short', () {
      expect(() => formatCipherKeyPragma('abcd'), throwsArgumentError);
    });

    test('rejects a key with non-hex characters', () {
      expect(() => formatCipherKeyPragma('z' * 64), throwsArgumentError);
    });

    test('rejects an empty key (no accidental plaintext open)', () {
      expect(() => formatCipherKeyPragma(''), throwsArgumentError);
    });

    test('thrown ArgumentError never embeds the key material', () {
      // Regression for the #4945 review finding: ArgumentError.value embeds the
      // invalid value in toString(), which would leak cipher key material.
      const malformedKey = 'deadbeef$validKey'; // 72 hex chars => invalid
      expect(
        () => formatCipherKeyPragma(malformedKey),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.toString(),
            'toString',
            isNot(contains(malformedKey)),
          ),
        ),
      );
    });
  });

  group('applyCipherKey', () {
    const validKey =
        '2dd29ca851e7b56e4697b0e1f08507293d761a05ce4d1b628663f411a8086d99';

    test('fails closed when SQLCipher is not the linked library', () {
      // The host test VM links plain sqlite3, on which PRAGMA cipher_version
      // returns no rows. The connection must refuse rather than silently
      // storing plaintext.
      final db = sqlite3.openInMemory();
      addTearDown(db.dispose);
      expect(() => applyCipherKey(db, validKey), throwsStateError);
    });

    test('rejects a malformed key before touching the database', () {
      final db = sqlite3.openInMemory();
      addTearDown(db.dispose);
      expect(() => applyCipherKey(db, 'not-a-key'), throwsArgumentError);
    });

    test('never leaks the key when the keying statement throws (#4945)', () {
      // SqliteException.toString() appends the causing statement, which is the
      // PRAGMA key containing the raw key. applyCipherKey must convert that to
      // a key-free error before it can escape to Crashlytics.
      final leaky = SqliteException(
        26,
        'file is not a database',
        null,
        formatCipherKeyPragma(validKey), // causing statement embeds the key
      );
      expect(leaky.toString(), contains(validKey)); // the source really leaks

      final db = _MockCipherDb();
      when(() => db.execute(any())).thenThrow(leaky);

      expect(
        () => applyCipherKey(db, validKey),
        throwsA(
          isA<StateError>().having(
            (e) => e.toString(),
            'toString',
            isNot(contains(validKey)),
          ),
        ),
      );
    });
  });

  group('openEncryptedConnection', () {
    const validKey =
        '2dd29ca851e7b56e4697b0e1f08507293d761a05ce4d1b628663f411a8086d99';

    test('throws ArgumentError for a malformed key at construction time', () {
      expect(
        () => openEncryptedConnection(rawKeyHex: 'too-short'),
        throwsArgumentError,
      );
    });

    test('returns a lazily-opened QueryExecutor for a well-formed key', () {
      expect(
        openEncryptedConnection(rawKeyHex: validKey),
        isA<QueryExecutor>(),
      );
    });
  });

  group('migratePlaintextToEncrypted', () {
    const validKey =
        '2dd29ca851e7b56e4697b0e1f08507293d761a05ce4d1b628663f411a8086d99';
    late Directory tempRoot;
    late String dbPath;

    setUp(() {
      tempRoot = Directory.systemTemp.createTempSync(
        'db_client_cipher_migration_test_',
      );
      dbPath = p.join(tempRoot.path, 'divine_db.db');
    });

    tearDown(() {
      if (tempRoot.existsSync()) {
        tempRoot.deleteSync(recursive: true);
      }
    });

    test('returns noDatabase when no file exists', () async {
      expect(
        await migratePlaintextToEncrypted(
          rawKeyHex: validKey,
          databasePath: dbPath,
        ),
        equals(CipherMigrationOutcome.noDatabase),
      );
    });

    test('removes an empty plaintext database so a fresh encrypted one is '
        'created on first open', () async {
      sqlite3.open(dbPath).dispose(); // empty database, no user tables
      expect(File(dbPath).existsSync(), isTrue);

      final outcome = await migratePlaintextToEncrypted(
        rawKeyHex: validKey,
        databasePath: dbPath,
      );

      expect(outcome, equals(CipherMigrationOutcome.removedEmptyPlaintext));
      expect(File(dbPath).existsSync(), isFalse);
    });

    test('classifies a non-database file as already encrypted', () async {
      File(dbPath).writeAsBytesSync(List<int>.generate(64, (i) => i));

      expect(
        await migratePlaintextToEncrypted(
          rawKeyHex: validKey,
          databasePath: dbPath,
        ),
        equals(CipherMigrationOutcome.alreadyEncrypted),
      );
    });

    test('fails safely and preserves a populated plaintext DB when SQLCipher '
        'is not linked', () async {
      _createSqliteDatabase(dbPath, draftCount: 3);

      final outcome = await migratePlaintextToEncrypted(
        rawKeyHex: validKey,
        databasePath: dbPath,
      );

      // No cipher library on the host VM, so the rekey cannot complete — the
      // plaintext source must stay intact for retry on the next launch.
      expect(outcome, equals(CipherMigrationOutcome.failed));
      expect(File(dbPath).existsSync(), isTrue);
      expect(_draftCount(dbPath), equals(3));
    });

    test('rejects a malformed key', () async {
      _createSqliteDatabase(dbPath, draftCount: 1);
      await expectLater(
        migratePlaintextToEncrypted(rawKeyHex: 'bad', databasePath: dbPath),
        throwsArgumentError,
      );
    });

    test('resumes an interrupted swap (verified encrypted artifact present, '
        'db absent)', () async {
      // Simulate a force-kill after the plaintext was renamed to its backup
      // but before the verified encrypted copy was moved into place: the
      // .sqlcipher_migrating artifact exists and the db path is absent.
      final encryptedPath = '$dbPath.sqlcipher_migrating';
      _createSqliteDatabase(encryptedPath, draftCount: 2);
      expect(File(dbPath).existsSync(), isFalse);

      final outcome = await migratePlaintextToEncrypted(
        rawKeyHex: validKey,
        databasePath: dbPath,
      );

      expect(outcome, equals(CipherMigrationOutcome.migrated));
      expect(File(dbPath).existsSync(), isTrue);
      expect(File(encryptedPath).existsSync(), isFalse);
      expect(_draftCount(dbPath), equals(2));
    });
  });

  group('promoteEncryptedMigrationArtifact', () {
    late Directory tempRoot;
    late String dbPath;
    late String encryptedPath;

    setUp(() {
      tempRoot = Directory.systemTemp.createTempSync(
        'db_client_promote_cipher_artifact_test_',
      );
      dbPath = p.join(tempRoot.path, 'divine_db.db');
      encryptedPath = '$dbPath.sqlcipher_migrating';
    });

    tearDown(() {
      if (tempRoot.existsSync()) {
        tempRoot.deleteSync(recursive: true);
      }
    });

    test('moves the encrypted artifact and WAL/SHM sidecars into place', () {
      File(encryptedPath).writeAsBytesSync(const [1]);
      File('$encryptedPath-wal').writeAsBytesSync(const [2]);
      File('$encryptedPath-shm').writeAsBytesSync(const [3]);

      promoteEncryptedMigrationArtifact(
        encryptedPath: encryptedPath,
        dbPath: dbPath,
      );

      expect(File(dbPath).readAsBytesSync(), equals(const [1]));
      expect(File('$dbPath-wal').readAsBytesSync(), equals(const [2]));
      expect(File('$dbPath-shm').readAsBytesSync(), equals(const [3]));
      expect(File(encryptedPath).existsSync(), isFalse);
      expect(File('$encryptedPath-wal').existsSync(), isFalse);
      expect(File('$encryptedPath-shm').existsSync(), isFalse);
    });
  });

  group('cleanUpPreCipherMigrationBackups', () {
    late Directory tempRoot;
    late String dbPath;

    setUp(() {
      tempRoot = Directory.systemTemp.createTempSync(
        'db_client_cipher_backup_cleanup_test_',
      );
      dbPath = p.join(tempRoot.path, 'divine_db.db');
      File(dbPath).writeAsBytesSync(const [0]);
    });

    tearDown(() {
      if (tempRoot.existsSync()) {
        tempRoot.deleteSync(recursive: true);
      }
    });

    test(
      'deletes only pre-cipher plaintext migration backups and sidecars',
      () {
        final backupPath = '$dbPath.pre_cipher_migration_backup';
        final indexedBackupPath = '$dbPath.pre_cipher_migration_backup.1';
        final keyLossBackupPath = '$dbPath.pre_key_loss_wipe_backup';
        File(backupPath).writeAsBytesSync(const [1]);
        File('$backupPath-wal').writeAsBytesSync(const [2]);
        File('$backupPath-shm').writeAsBytesSync(const [3]);
        File(indexedBackupPath).writeAsBytesSync(const [4]);
        File('$indexedBackupPath-wal').writeAsBytesSync(const [5]);
        File(keyLossBackupPath).writeAsBytesSync(const [6]);
        File(
          '$dbPath.pre_cipher_migration_backup_notes',
        ).writeAsBytesSync(const [7]);

        cleanUpPreCipherMigrationBackups(dbPath);

        expect(File(dbPath).existsSync(), isTrue);
        expect(File(backupPath).existsSync(), isFalse);
        expect(File('$backupPath-wal').existsSync(), isFalse);
        expect(File('$backupPath-shm').existsSync(), isFalse);
        expect(File(indexedBackupPath).existsSync(), isFalse);
        expect(File('$indexedBackupPath-wal').existsSync(), isFalse);
        expect(File(keyLossBackupPath).existsSync(), isTrue);
        expect(
          File('$dbPath.pre_cipher_migration_backup_notes').existsSync(),
          isTrue,
        );
      },
    );
  });
}

void _createSqliteDatabase(
  String path, {
  int draftCount = 0,
  int eventCount = 0,
  List<String> pendingUploadStatuses = const [],
  List<String> pendingActionStatuses = const [],
}) {
  File(path).parent.createSync(recursive: true);
  final db = sqlite3.open(path);
  try {
    db.execute('CREATE TABLE drafts (id TEXT PRIMARY KEY)');
    for (var i = 0; i < draftCount; i += 1) {
      db.execute('INSERT INTO drafts (id) VALUES (?)', ['draft_$i']);
    }

    db.execute('CREATE TABLE event (id TEXT PRIMARY KEY)');
    for (var i = 0; i < eventCount; i += 1) {
      db.execute('INSERT INTO event (id) VALUES (?)', ['event_$i']);
    }

    db.execute('''
      CREATE TABLE pending_uploads (
        id TEXT PRIMARY KEY,
        status TEXT NOT NULL
      )
    ''');
    for (var i = 0; i < pendingUploadStatuses.length; i += 1) {
      db.execute('INSERT INTO pending_uploads (id, status) VALUES (?, ?)', [
        'upload_$i',
        pendingUploadStatuses[i],
      ]);
    }

    db.execute('''
      CREATE TABLE pending_actions (
        id TEXT PRIMARY KEY,
        status TEXT NOT NULL
      )
    ''');
    for (var i = 0; i < pendingActionStatuses.length; i += 1) {
      db.execute('INSERT INTO pending_actions (id, status) VALUES (?, ?)', [
        'action_$i',
        pendingActionStatuses[i],
      ]);
    }
  } finally {
    db.dispose();
  }
}

int _draftCount(String path) {
  final db = sqlite3.open(path);
  try {
    return db.select('SELECT COUNT(*) AS count FROM drafts').first['count']
        as int;
  } finally {
    db.dispose();
  }
}

int _eventCount(String path) {
  final db = sqlite3.open(path);
  try {
    return db.select('SELECT COUNT(*) AS count FROM event').first['count']
        as int;
  } finally {
    db.dispose();
  }
}

int _pendingUploadCount(String path) => _tableCount(path, 'pending_uploads');

int _pendingActionCount(String path) => _tableCount(path, 'pending_actions');

int _tableCount(String path, String table) {
  final db = sqlite3.open(path);
  try {
    return db.select('SELECT COUNT(*) AS count FROM $table').first['count']
        as int;
  } finally {
    db.dispose();
  }
}

String _destinationBackupPath(String path) =>
    '$path.pre_legacy_migration_backup';

String _legacyConflictBackupPath(String path) => '$path.legacy_conflict_backup';
