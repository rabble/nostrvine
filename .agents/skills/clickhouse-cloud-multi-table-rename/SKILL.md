---
name: clickhouse-cloud-multi-table-rename
description: |
  Fix ClickHouse Cloud migration failures caused by multi-table RENAME statements.
  Use when: (1) Migration fails with "Database X is Shared, it does not support renaming
  of multiple tables in single query", (2) golang-migrate or other migration tools show
  dirty database version after a table-swap migration on ClickHouse Cloud,
  (3) Schema migration works on self-hosted ClickHouse but fails on ClickHouse Cloud.
  ClickHouse Cloud uses SharedMergeTree engine which has restrictions not present in
  regular MergeTree.
author: Claude Code
version: 1.0.0
date: 2026-02-22
---

# ClickHouse Cloud Multi-Table RENAME Limitation

## Problem
ClickHouse Cloud (SharedMergeTree engine) does not support renaming multiple tables
in a single `RENAME TABLE` statement, which is a common pattern for atomic table swaps
in schema migrations. Self-hosted ClickHouse supports this, so migrations that work
locally or on self-hosted instances will fail on ClickHouse Cloud.

## Context / Trigger Conditions
- Error message: `"Database X is Shared, it does not support renaming of multiple tables in single query"`
- Error code: 48
- Using golang-migrate (or similar) with ClickHouse Cloud
- Migration SQL contains a pattern like:
  ```sql
  RENAME TABLE db.original TO db.original_old,
               db.new_version TO db.original;
  ```
- Migration works in staging (self-hosted ClickHouse) but fails in production (ClickHouse Cloud)

## Solution

### Prevention: Write ClickHouse Cloud-compatible migrations

Instead of multi-table RENAME:
```sql
-- BAD: This fails on ClickHouse Cloud
RENAME TABLE nostr.my_table TO nostr.my_table_old,
             nostr.my_table_v2 TO nostr.my_table;
```

Use separate RENAME statements:
```sql
-- GOOD: Split into individual operations
RENAME TABLE nostr.my_table TO nostr.my_table_old;
RENAME TABLE nostr.my_table_v2 TO nostr.my_table;
```

Note: This loses atomicity, but ClickHouse Cloud doesn't support the atomic version anyway.

### Recovery: Fix a dirty migration that already failed

1. **Check the current state** — identify which tables exist and what state they're in:
   ```sql
   SHOW TABLES LIKE '%my_table%';
   DESCRIBE TABLE nostr.my_table;       -- Check if it has old or new schema
   DESCRIBE TABLE nostr.my_table_v2;    -- Check if the new table was created
   ```

2. **Complete the migration manually** with separate renames:
   ```sql
   -- If both original and v2 exist (RENAME never executed):
   RENAME TABLE nostr.my_table TO nostr.my_table_old;
   RENAME TABLE nostr.my_table_v2 TO nostr.my_table;
   DROP TABLE IF EXISTS nostr.my_table_old;
   -- Recreate any views that were dropped
   ```

3. **Force the migration version** to mark it as completed:
   ```bash
   # Using golang-migrate
   migrate -path=/migrations -database "clickhouse://..." force VERSION
   ```

4. **If using K8s jobs**, recreate the job with `force VERSION` args:
   ```yaml
   containers:
     - name: migrate
       image: my-migrate-image:tag
       args: ["force", "65"]  # The migration number that was applied manually
   ```

## Verification

After manual migration, verify:
```sql
-- Check table has new schema
DESCRIBE TABLE nostr.my_table;

-- Check migration version is clean (not dirty)
SELECT version, dirty FROM schema_migrations ORDER BY version DESC LIMIT 5;

-- Check old/temp tables are cleaned up
SHOW TABLES LIKE '%my_table%';
```

## Example

Migration 65 for funnelcake needed to change `view_traffic_sources.source` from
`Enum8` to `String`. The migration:
1. Dropped a dependent view
2. Created `view_traffic_sources_v2` with new schema
3. Copied data
4. Tried `RENAME TABLE original TO old, v2 TO original` — FAILED on ClickHouse Cloud

Recovery:
```bash
# Via HTTP API from a curl pod in the cluster:
curl -s "$CH_URL/?database=nostr&user=$USER&password=$PASS" \
  --data-binary 'RENAME TABLE nostr.view_traffic_sources TO nostr.view_traffic_sources_old'
curl -s "$CH_URL/?database=nostr&user=$USER&password=$PASS" \
  --data-binary 'RENAME TABLE nostr.view_traffic_sources_v2 TO nostr.view_traffic_sources'
curl -s "$CH_URL/?database=nostr&user=$USER&password=$PASS" \
  --data-binary 'DROP TABLE IF EXISTS nostr.view_traffic_sources_old'
# Recreate the summary view...
# Then force migration version to 65
```

## Notes
- SharedMergeTree is the default engine on ClickHouse Cloud — you cannot switch to regular MergeTree
- Other SharedMergeTree limitations exist (e.g., some ALTER operations behave differently)
- When writing migrations for dual self-hosted/cloud environments, always use separate RENAME statements
- The golang-migrate ClickHouse driver uses `x-multi-statement=true` which splits statements on `;`, but the RENAME with commas is still a single statement
- If a failed migration left a `_v2` table behind, you must `DROP TABLE IF EXISTS` it before re-running the migration, or `CREATE TABLE IF NOT EXISTS` will silently skip creation and the INSERT will duplicate data into the existing v2 table
- Use `SET alter_sync = 2; SET mutations_sync = 2;` in migrations to ensure synchronous execution on ClickHouse Cloud

## References
- ClickHouse Cloud SharedMergeTree differences: SharedMergeTree engine has restrictions on operations that require cross-shard coordination
- golang-migrate ClickHouse driver: github.com/golang-migrate/migrate with clickhouse driver
