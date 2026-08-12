// dart format width=80
import 'package:db_client/src/database/app_database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated/schema.dart';
import 'generated/schema_v2.dart' as v2;
import 'generated/schema_v3.dart' as v3;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  group('schema validation', () {
    test('current schema version is 3', () {
      expect(AppDatabase(NativeDatabase.memory()).schemaVersion, 3);
    });

    test('v3 schema is valid and up to date', () async {
      final schema = await verifier.schemaAt(3);
      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 3);
      await db.close();
    });

    test('v2 schema migrates to v3', () async {
      final schema = await verifier.schemaAt(2);
      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 3);
      await db.close();
    });

    test('legacy v1 schema migrates to v3', () async {
      final schema = await verifier.schemaAt(1);
      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 3);
      await db.close();
    });

    test('v2 identity_events rows survive the v3 upgrade unstamped', () async {
      await verifier.testWithDataIntegrity(
        oldVersion: 2,
        newVersion: 3,
        createOld: v2.DatabaseAtV2.new,
        createNew: v3.DatabaseAtV3.new,
        openTestedDatabase: AppDatabase.new,
        createItems: (batch, oldDb) => batch.insert(
          oldDb.identityEvents,
          v2.IdentityEventsData(
            pubkey: 'a' * 64,
            tagsJson: '[["i","github:alice","proof-a"]]',
            sourceKind: 10011,
          ),
        ),
        validateItems: (newDb) async {
          final row = await newDb.select(newDb.identityEvents).getSingle();
          expect(row.tagsJson, '[["i","github:alice","proof-a"]]');
          expect(row.sourceKind, 10011);
          // Nothing knows which event a pre-upgrade row came from, so it
          // stays out of the staleness comparison until the next read
          // stamps it.
          expect(row.sourceCreatedAt, null);
          expect(row.sourceEventId, null);
        },
      );
    });
  });
}
