# Drift Database Migrations

This document describes how to manage database migrations for the `db_client` package using [Drift](https://drift.simonbinder.eu/).

## Current Schema Version

**Version: 3** (see `app_database.dart`).

Version 2 is the legacy-normalization baseline. Earlier releases kept Drift's
user-version at 1 while startup repair SQL added tables, columns, indexes, and
backfills in `beforeOpen`. The v1 -> v2 migration is intentionally idempotent so
any shipped v1 database shape can be brought to the current schema.

Version 3 adds `identity_events.source_created_at` and
`identity_events.source_event_id` (#7081), so a cached kind-10011 identity
event can be recognised as newer than the one a later relay read returns. The
v2 -> v3 step rebuilds the table from its current definition, which lands on
the same shape whether v1 normalization created the legacy three-column table
or the current one.

Going forward, schema changes must be versioned Drift migrations. Do not add new
tables, columns, indexes, or schema backfills to `beforeOpen`; that hook is only
for startup cleanup and guarded recovery of damaged local databases.

## Project Structure

```
db_client/
├── lib/src/database/
│   ├── app_database.dart       # Main database class with schema version
│   ├── app_database.g.dart     # Generated code (build_runner)
│   ├── app_database.steps.dart # Generated migration steps (make-migrations)
│   └── tables.dart             # Table definitions
├── drift_schemas/
│   └── app_database/
│       ├── drift_schema_v1.json
│       ├── drift_schema_v2.json
│       └── drift_schema_v3.json
├── test/drift/
│   └── app_database/
│       ├── migration_test.dart
│       └── generated/
│           ├── schema.dart
│           ├── schema_v1.dart
│           ├── schema_v2.dart
│           └── schema_v3.dart
└── build.yaml                  # Drift build configuration
```

## Migration Workflow

### Step 1: Modify the Schema

Edit `lib/src/database/tables.dart` to add/modify/remove columns or tables.

```dart
// Example: Adding a new column
class NostrEvents extends Table {
  // ... existing columns ...
  IntColumn get newColumn => integer().nullable()();  // NEW
}
```

### Step 2: Increment Schema Version

In `lib/src/database/app_database.dart`, increment `schemaVersion`:

```dart
@override
int get schemaVersion => 3;  // Was 2, now 3
```

### Step 3: Run Build Runner

Generate the updated `app_database.g.dart`:

```bash
cd mobile/packages/db_client
dart run build_runner build --delete-conflicting-outputs
```

### Step 4: Export Schema Snapshot

Save the new schema version for migration testing:

```bash
cd mobile/packages/db_client
dart run drift_dev make-migrations
```

This command:
- Reads the `databases` config from `build.yaml`
- Creates `drift_schemas/app_database/drift_schema_v3.json`
- Regenerates `app_database.steps.dart` with new migration steps
- Updates `test/drift/app_database/generated/` files

### Step 5: Write the Migration Logic

Edit `lib/src/database/app_database.dart` to add the migration step:

```dart
MigrationStrategy get migration => MigrationStrategy(
  onCreate: (m) async {
    await m.createAll();
    await _normalizeLegacyV1Schema();
  },
  onUpgrade: (m, from, to) async {
    if (from < 3) {
      await m.alterTable(
        TableMigration(
          nostrEvents,
          newColumns: [nostrEvents.newColumn],
        ),
      );
    }
  },
  beforeOpen: (details) async {
    // Keep startup cleanup and guarded recovery here.
  },
);
```

For schema changes that need custom SQL or idempotent repair, add that logic to
the versioned `onUpgrade` path for the new version. Keep it covered by migration
tests and avoid making `beforeOpen` the primary schema evolution mechanism.

### Step 6: Run Migration Tests

Verify migrations work correctly:

```bash
cd mobile/packages/db_client
dart test test/drift/app_database/migration_test.dart
```

Or using the Dart MCP tool:
```
mcp__dart__run_tests with paths: ["test/drift/"]
```

### Step 7: Update Data Integrity Tests (Optional)

For migrations that modify existing data, update `migration_test.dart`:

```dart
test('migration from v2 to v3 does not corrupt data', () async {
  final oldEventData = <v2.EventData>[
    // Add test data...
  ];
  final expectedNewEventData = <v3.EventData>[
    // Expected data after migration...
  ];

  await verifier.testWithDataIntegrity(
    oldVersion: 2,
    newVersion: 3,
    // ...
  );
});
```

## Quick Reference Commands

| Task | Command |
|------|---------|
| Generate code | `dart run build_runner build --delete-conflicting-outputs` |
| Export schema | `dart run drift_dev make-migrations` |
| Run migration tests | `dart test test/drift/app_database/migration_test.dart` |
| Run all tests | `dart test` |
| Analyze | `dart analyze` |
| Format | `dart format lib test` |

## Common Migration Operations

### Adding a Column

```dart
from2To3: (m, schema) async {
  await m.alterTable(
    TableMigration(
      schema.tableName,
      newColumns: [schema.tableName.newColumn],
    ),
  );
}
```

### Adding a Table

```dart
from2To3: (m, schema) async {
  await m.createTable(schema.newTable);
}
```

### Dropping a Column

```dart
from2To3: (m, schema) async {
  await m.alterTable(
    TableMigration(
      schema.tableName,
      columnTransformer: {
        // Map old columns to new schema (excluding dropped column)
      },
    ),
  );
}
```

### Renaming a Column

```dart
from2To3: (m, schema) async {
  await m.alterTable(
    TableMigration(
      schema.tableName,
      columnTransformer: {
        schema.tableName.newName: schema.tableName.oldName,
      },
    ),
  );
}
```

### Adding an Index

```dart
from2To3: (m, schema) async {
  await m.createIndex(schema.indexName);
}
```

## Troubleshooting

### "make-migrations" fails with "database not configured"

Ensure `build.yaml` has the correct configuration:

```yaml
targets:
  $default:
    builders:
      drift_dev:
        options:
          databases:
            app_database: lib/src/database/app_database.dart
          schema_dir: drift_schemas/
          test_dir: test/drift/
```

### Migration tests fail

1. Ensure schema version matches the latest `drift_schema_vN.json`
2. Run `dart run drift_dev make-migrations` to regenerate files
3. Check that migration logic in `MigrationStrategy.onUpgrade` handles all versions

### Generated files out of date

Always run both commands after schema changes:

```bash
dart run build_runner build --delete-conflicting-outputs
dart run drift_dev make-migrations
```

## References

- [Drift Migrations Documentation](https://drift.simonbinder.eu/migrations/)
- [Migration Tests](https://drift.simonbinder.eu/migrations/tests/)
- [Step-by-Step Migrations](https://drift.simonbinder.eu/migrations/step_by_step/)
