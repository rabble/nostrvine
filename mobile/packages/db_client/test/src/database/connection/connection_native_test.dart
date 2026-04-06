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
}
