# cache_sync Database Migrations

`cache_sync` persists cache entries in a single Drift table (`CacheEntries`) in
a local, unencrypted SQLite file (`cache_sync.db`). It is a **disposable
cache** — nothing here is a source of truth. Schema and data changes are
handled through Drift's [`MigrationStrategy`](https://drift.simonbinder.eu/docs/advanced-features/migrations/).

## Current schema version

**Version 1** — see `lib/src/cache_database.dart`.

| Version | Change |
|---------|--------|
| 1 | Initial `CacheEntries` table (#4251). |

`cache_database.dart` declares an explicit `MigrationStrategy` (currently just
`onCreate: createAll`). This is the deliberate anchor point for the first real
migration; the recipes below describe how to add one.

> **#4382 note:** #4382 evaluated a v1 → v2 data-only migration to delete the
> short-lived legacy `my_followers_${pubkey}` / `my_following_${pubkey}` rows
> that `follow_repository` wrote between #4251 and #4361 (before RFC #4244's
> `${pubkey}:operation` key shape landed). That cohort never reached a tagged
> native release — the first release containing `cache_sync` already shipped
> the colon-scoped shape — so no data migration was shipped. The colon-scoped
> key shape is instead guarded by a `follow_repository` regression test that
> fails if a key builder ever re-emits the legacy prefix.

## How migrations run

`MigrationStrategy.onUpgrade(m, from, to)` fires **once per existing install**
when the stored `user_version` is below `schemaVersion`. Fresh installs run
`onCreate` (which calls `createAll()`) and never run `onUpgrade`.

Because `onUpgrade` never re-runs once `user_version` reaches the target, each
step must be self-contained: a step that ships incomplete cannot be corrected
in place — it requires a *further* version bump with a new step.

## Adding a future migration

### Data-only change (delete/rewrite rows, no schema change)

1. Bump `schemaVersion` in `lib/src/cache_database.dart`.
2. Extend `onUpgrade` with a guarded block for the new step, e.g.
   `if (from < 2) { … }`. Keep each step idempotent and gated on `from`.
3. Create `test/cache_migration_test.dart` with a test following the two-phase
   pattern: open at the new version to create the schema, seed rows, stamp the
   DB back to the previous `user_version`, close, then reopen so `onUpgrade`
   runs — and assert the data effect. Use the `NativeDatabase.opened` shared
   in-memory connection idiom (`closeUnderlyingOnClose: false`) so table and
   data survive the drift close between phases. The test must be able to fail:
   seed a row that is *present at the lower version* and assert it is
   deleted/rewritten, not one inserted after the upgrade hook could touch it.
4. Run `dart run build_runner build` and confirm `cache_database.g.dart` is
   unchanged (a data-only bump does not regenerate it).

### Schema-shape change (add/alter/drop a column or table)

This package does not yet ship generated schema snapshots. The first
schema-shape change should introduce them so migrations can be verified
against exported schemas (mirroring `db_client`):

1. Edit the table in `lib/src/cache_entries_table.dart`, then bump
   `schemaVersion` in `lib/src/cache_database.dart`.
2. `dart run build_runner build` to regenerate `cache_database.g.dart`.
3. `dart run drift_dev make-migrations` — this uses the `schema_dir` /
   `test_dir` already declared in `build.yaml` to write
   `drift_schemas/cache_database/drift_schema_v*.json`,
   `cache_database.steps.dart`, and generated migration-test helpers.
4. Implement the step in `onUpgrade` and add migration tests.
