// dart format width=80
// ignore_for_file: unused_local_variable
import 'package:db_client/src/database/app_database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated/schema.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  group('schema validation', () {
    test('current schema version is 2', () {
      expect(AppDatabase(NativeDatabase.memory()).schemaVersion, 2);
    });

    test('v2 schema is valid and up to date', () async {
      final schema = await verifier.schemaAt(2);
      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 2);
      await db.close();
    });

    test('legacy v1 schema migrates to v2', () async {
      final schema = await verifier.schemaAt(1);
      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 2);
      await db.close();
    });
  });
}
