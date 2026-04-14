import 'dart:io';

import 'package:db_client/src/database/connection/connection_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as raw_sqlite;

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

      expect(
        path,
        equals('/tmp/app-support/openvine/database/divine_db.db'),
      );
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

    test(
      'replaces near-empty new DB with legacy when both exist',
      () async {
        // Legacy DB with conversations (the user's real data).
        final legacyDb = _createDatabaseWithConversations(legacyPath, 20);
        legacyDb.dispose();

        // New DB with 0 conversations (artifact of relay re-fetch).
        final newDb = _createDatabaseWithConversations(newPath, 0);
        newDb.dispose();

        await migrateLegacyDatabase(
          legacyPath: legacyPath,
          newPath: newPath,
        );

        // Legacy replaced the new DB.
        expect(File(legacyPath).existsSync(), isFalse);
        final resultDb = raw_sqlite.sqlite3.open(newPath);
        final count =
            resultDb
                    .select(
                      'SELECT COUNT(*) AS cnt FROM conversations',
                    )
                    .first['cnt']
                as int;
        resultDb.dispose();
        expect(count, equals(20));
      },
    );

    test(
      'keeps new DB and deletes legacy when new has data above threshold',
      () async {
        final legacyDb = _createDatabaseWithConversations(legacyPath, 50);
        legacyDb.dispose();

        // New DB with conversations above threshold — real user data.
        final newDb = _createDatabaseWithConversations(
          newPath,
          maxConversationsForReplacement + 1,
        );
        newDb.dispose();

        await migrateLegacyDatabase(
          legacyPath: legacyPath,
          newPath: newPath,
        );

        // New DB kept, legacy cleaned up.
        expect(File(newPath).existsSync(), isTrue);
        expect(File(legacyPath).existsSync(), isFalse);
        final resultDb = raw_sqlite.sqlite3.open(newPath);
        final count =
            resultDb
                    .select(
                      'SELECT COUNT(*) AS cnt FROM conversations',
                    )
                    .first['cnt']
                as int;
        resultDb.dispose();
        expect(count, equals(maxConversationsForReplacement + 1));
      },
    );

    test(
      'treats new DB without conversations table as empty and replaces it',
      () async {
        final legacyDb = _createDatabaseWithConversations(legacyPath, 10);
        legacyDb.dispose();

        // New DB exists but has no conversations table (incomplete init).
        final newFile = File(newPath);
        newFile.parent.createSync(recursive: true);
        final newDb = raw_sqlite.sqlite3.open(newPath);
        newDb.execute('CREATE TABLE other_table (id TEXT PRIMARY KEY)');
        newDb.dispose();

        await migrateLegacyDatabase(
          legacyPath: legacyPath,
          newPath: newPath,
        );

        expect(File(legacyPath).existsSync(), isFalse);
        final resultDb = raw_sqlite.sqlite3.open(newPath);
        final count =
            resultDb
                    .select(
                      'SELECT COUNT(*) AS cnt FROM conversations',
                    )
                    .first['cnt']
                as int;
        resultDb.dispose();
        expect(count, equals(10));
      },
    );

    test(
      'cleans up sidecars of the replaced new DB before renaming legacy',
      () async {
        final legacyDb = _createDatabaseWithConversations(legacyPath, 15);
        legacyDb.dispose();

        final newDb = _createDatabaseWithConversations(newPath, 0);
        newDb.dispose();
        // Simulate stale sidecars on the new DB.
        File('$newPath-wal').writeAsBytesSync(const [1]);
        File('$newPath-shm').writeAsBytesSync(const [2]);

        await migrateLegacyDatabase(
          legacyPath: legacyPath,
          newPath: newPath,
        );

        expect(File(newPath).existsSync(), isTrue);
        // Stale sidecars from the replaced new DB should be gone.
        // (Legacy sidecars are migrated by the existing logic if present.)
        expect(File(legacyPath).existsSync(), isFalse);
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
}

/// Creates a real SQLite database at [path] with a conversations table
/// containing [count] rows. Returns the open database handle so the
/// caller can dispose it after setup.
raw_sqlite.Database _createDatabaseWithConversations(String path, int count) {
  File(path).parent.createSync(recursive: true);
  final db = raw_sqlite.sqlite3.open(path);
  db.execute('''
    CREATE TABLE conversations (
      id TEXT PRIMARY KEY,
      participant_pubkeys TEXT NOT NULL DEFAULT '[]',
      is_group INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL DEFAULT 0,
      last_message_content TEXT,
      last_message_timestamp INTEGER,
      last_message_sender_pubkey TEXT,
      subject TEXT,
      is_read INTEGER NOT NULL DEFAULT 1,
      current_user_has_sent INTEGER NOT NULL DEFAULT 0,
      owner_pubkey TEXT,
      dm_protocol TEXT
    )
  ''');
  for (var i = 0; i < count; i++) {
    db.execute(
      "INSERT INTO conversations (id, created_at) VALUES ('conv_$i', $i)",
    );
  }
  return db;
}
