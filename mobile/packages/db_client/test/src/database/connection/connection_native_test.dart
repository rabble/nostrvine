import 'dart:io';

import 'package:db_client/src/database/connection/connection_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

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
      expect(
        File(dbPath).readAsBytesSync(),
        equals(const [1, 2, 3]),
      );
      expect(readDbCacheVersion(dbDir), equals(dbCacheVersion));
    });

    test('deletes DB and sidecars when stored version is stale', () {
      Directory(dbDir).createSync(recursive: true);
      File(dbPath).writeAsBytesSync(const [1]);
      File('$dbPath-wal').writeAsBytesSync(const [2]);
      File('$dbPath-shm').writeAsBytesSync(const [3]);
      writeDbCacheVersion(dbDir, 1);

      applyDbCacheVersionReset(dbPath);

      expect(File(dbPath).existsSync(), isFalse);
      expect(File('$dbPath-wal').existsSync(), isFalse);
      expect(File('$dbPath-shm').existsSync(), isFalse);
      expect(readDbCacheVersion(dbDir), equals(dbCacheVersion));
    });

    test('no-op when stored version matches current', () {
      Directory(dbDir).createSync(recursive: true);
      File(dbPath).writeAsBytesSync(const [9, 9]);
      writeDbCacheVersion(dbDir, dbCacheVersion);

      applyDbCacheVersionReset(dbPath);

      expect(File(dbPath).existsSync(), isTrue);
      expect(
        File(dbPath).readAsBytesSync(),
        equals(const [9, 9]),
      );
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

    test(
      'replaces new DB with legacy when both exist',
      () async {
        final legacyFile = File(legacyPath);
        legacyFile.parent.createSync(recursive: true);
        legacyFile.writeAsBytesSync(const [1, 2, 3]);

        final newFile = File(newPath);
        newFile.parent.createSync(recursive: true);
        newFile.writeAsBytesSync(const [9, 9, 9]);

        await migrateLegacyDatabase(
          legacyPath: legacyPath,
          newPath: newPath,
        );

        // Legacy always wins — it predates the path change.
        expect(File(legacyPath).existsSync(), isFalse);
        expect(File(newPath).readAsBytesSync(), equals(const [1, 2, 3]));
      },
    );

    test(
      'cleans up new DB sidecars before replacing with legacy',
      () async {
        final legacyFile = File(legacyPath);
        legacyFile.parent.createSync(recursive: true);
        legacyFile.writeAsBytesSync(const [1]);

        final newFile = File(newPath);
        newFile.parent.createSync(recursive: true);
        newFile.writeAsBytesSync(const [9]);
        File('$newPath-wal').writeAsBytesSync(const [2]);
        File('$newPath-shm').writeAsBytesSync(const [3]);

        await migrateLegacyDatabase(
          legacyPath: legacyPath,
          newPath: newPath,
        );

        expect(File(newPath).existsSync(), isTrue);
        expect(File(newPath).readAsBytesSync(), equals(const [1]));
        expect(File('$newPath-wal').existsSync(), isFalse);
        expect(File('$newPath-shm').existsSync(), isFalse);
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
