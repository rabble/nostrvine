---
name: clickhouse-system-log-disk-exhaustion
description: |
  Fix ClickHouse "Code: 243 Cannot reserve 1.00 MiB, not enough space" errors caused by
  system log tables (text_log, trace_log, processors_profile_log, query_log) filling the disk.
  Use when: (1) ClickHouse inserts fail with NOT_ENOUGH_SPACE error, (2) Disk is 100% full
  but application tables are small, (3) system database is 10-100x larger than user databases,
  (4) Sentry shows batch insert/commit failures across multiple tables simultaneously.
  Covers both self-hosted ClickHouse (Altinity operator on K8s) and ClickHouse Cloud with
  different remediation paths for each.
author: Claude Code
version: 1.0.0
date: 2026-03-01
---

# ClickHouse System Log Disk Exhaustion

## Problem
ClickHouse internal system log tables (`text_log`, `trace_log`, `processors_profile_log`,
`query_log`, `metric_log`, `asynchronous_metric_log`) grow unbounded with a default TTL of
180 days, eventually filling the entire disk. This causes all INSERT operations to fail with
`Code: 243 - Cannot reserve 1.00 MiB, not enough space`, cascading across all application
tables simultaneously.

## Context / Trigger Conditions
- **Error message**: `Code: 243. DB::Exception: Cannot reserve 1.00 MiB, not enough space. (NOT_ENOUGH_SPACE)`
- **Symptoms**: All writes fail simultaneously across multiple tables; reads may still work
- **Sentry pattern**: Multiple batch insert/commit failure issues appearing at the same time
- **Diagnosis query**: `SELECT database, formatReadableSize(sum(total_bytes)) FROM system.tables WHERE total_bytes > 0 GROUP BY database ORDER BY sum(total_bytes) DESC`
  - If `system` database is 10x+ larger than application databases, this is the cause
- **ClickHouse Cloud additional symptom**: Numbered suffix tables (`trace_log_16`, `text_log_19`)
  from decommissioned server nodes accumulate and never get cleaned up within the TTL window

## Solution

### Diagnosis
```sql
-- Check database sizes
SELECT database, formatReadableSize(sum(total_bytes)) as size
FROM system.tables WHERE total_bytes > 0
GROUP BY database ORDER BY sum(total_bytes) DESC;

-- Find biggest system tables
SELECT name, formatReadableSize(total_bytes) as size
FROM system.tables
WHERE database = 'system' AND total_bytes > 100000000
ORDER BY total_bytes DESC LIMIT 20;

-- Check disk usage
SELECT name, formatReadableSize(free_space) as free, formatReadableSize(total_space) as total
FROM system.disks WHERE name = 'default';
```

### Fix: Self-Hosted ClickHouse (kubectl access)

**Step 1: If disk is 100% full (TRUNCATE itself fails with NOT_ENOUGH_SPACE)**

TRUNCATE needs some temporary disk space. When disk is truly 100% full, you must free space
at the filesystem level first:

```bash
# Find and remove orphaned _N suffix tables (from old replicas)
kubectl exec $CH_POD -- du -sh /var/lib/clickhouse/data/system/*_0/

# Detach them first (important!), then remove data
kubectl exec $CH_POD -- clickhouse-client --query "DETACH TABLE system.text_log_0 PERMANENTLY"
kubectl exec $CH_POD -- bash -c "rm -rf /var/lib/clickhouse/data/system/text_log_0/"
# Repeat for other _N tables until you have ~100MB+ free
```

**Step 2: Drop partitions or truncate tables**

System log tables are partitioned by `toYYYYMM(event_date)`. Drop older partitions first
(smaller operations), then truncate:

```sql
-- Check partitions
SELECT partition, formatReadableSize(sum(bytes_on_disk)) as size
FROM system.parts
WHERE database = 'system' AND table = 'text_log' AND active
GROUP BY partition ORDER BY partition;

-- Drop old partitions one at a time
ALTER TABLE system.text_log DROP PARTITION 202601 SETTINGS max_partition_size_to_drop = 0;
ALTER TABLE system.text_log DROP PARTITION 202602 SETTINGS max_partition_size_to_drop = 0;

-- Or truncate entire tables (needs max_table_size_to_drop override if > 50GB)
TRUNCATE TABLE system.text_log SETTINGS max_table_size_to_drop = 0;
TRUNCATE TABLE system.trace_log SETTINGS max_table_size_to_drop = 0;
TRUNCATE TABLE system.processors_profile_log SETTINGS max_table_size_to_drop = 0;
TRUNCATE TABLE system.query_log SETTINGS max_table_size_to_drop = 0;
TRUNCATE TABLE system.metric_log SETTINGS max_table_size_to_drop = 0;
TRUNCATE TABLE system.asynchronous_metric_log SETTINGS max_table_size_to_drop = 0;
```

**Step 3: Set TTL to prevent recurrence**

```sql
-- Set 3-day TTL on all major system log tables
ALTER TABLE system.text_log MODIFY TTL event_date + INTERVAL 3 DAY SETTINGS materialize_ttl_after_modify = 0;
ALTER TABLE system.trace_log MODIFY TTL event_date + INTERVAL 3 DAY SETTINGS materialize_ttl_after_modify = 0;
ALTER TABLE system.processors_profile_log MODIFY TTL event_date + INTERVAL 3 DAY SETTINGS materialize_ttl_after_modify = 0;
ALTER TABLE system.query_log MODIFY TTL event_date + INTERVAL 7 DAY SETTINGS materialize_ttl_after_modify = 0;
ALTER TABLE system.metric_log MODIFY TTL event_date + INTERVAL 3 DAY SETTINGS materialize_ttl_after_modify = 0;
ALTER TABLE system.asynchronous_metric_log MODIFY TTL event_date + INTERVAL 3 DAY SETTINGS materialize_ttl_after_modify = 0;
ALTER TABLE system.part_log MODIFY TTL event_date + INTERVAL 3 DAY SETTINGS materialize_ttl_after_modify = 0;
ALTER TABLE system.query_views_log MODIFY TTL event_date + INTERVAL 3 DAY SETTINGS materialize_ttl_after_modify = 0;
```

### Fix: ClickHouse Cloud (no shell access)

ClickHouse Cloud revokes all modify permissions on `system.*` from user-created roles:
```
REVOKE INSERT, ALTER, CREATE TABLE, DROP TABLE, TRUNCATE, OPTIMIZE ON system.* FROM default_role
```

**You CANNOT fix this via SQL.** The only options are:

1. **ClickHouse Cloud Console** (https://clickhouse.cloud/): Go to service settings and
   reduce system log TTLs to 3-7 days
2. **Get the `default` user password** from the console, then run the ALTER TTL commands
3. **ClickHouse Cloud Support**: Request system log cleanup

To identify ClickHouse Cloud: check for numbered suffix tables (e.g., `trace_log_16`,
`text_log_19`) which are from rotated server pods. Also, `system.disks` will show
`system-tables/mergetree/` paths with 16 EiB (object storage).

## Verification
```sql
-- After cleanup, verify disk usage
-- Self-hosted:
SELECT formatReadableSize(free_space) FROM system.disks WHERE name = 'default';

-- Both: verify system database is now small
SELECT database, formatReadableSize(sum(total_bytes)) as size
FROM system.tables WHERE total_bytes > 0 GROUP BY database;

-- Test that writes work
INSERT INTO your_table (...) VALUES (...);
```

## Notes
- The `max_table_size_to_drop` safety limit defaults to 50 GB. Tables larger than this
  require `SETTINGS max_table_size_to_drop = 0` to truncate/drop.
- When disk is truly 100% full, even DDL operations fail. You MUST free space at the
  filesystem level first (detach+remove orphaned tables, or delete tmp files).
- `DETACH TABLE ... PERMANENTLY` is important before removing data files - it prevents
  ClickHouse from trying to access the removed files.
- `materialize_ttl_after_modify = 0` prevents ClickHouse from immediately trying to
  rewrite all data to apply TTL (which would need disk space you don't have).
- On ClickHouse Cloud, each server node rotation leaves behind numbered system log tables
  (e.g., `_16`, `_19`) that accumulate over time. With 65+ nodes over months, this adds
  up to tens of GB.
- The `text_log` is typically the largest offender because it logs at trace/debug level
  by default and includes every log line from the ClickHouse server.

## References
- ClickHouse system tables documentation: https://clickhouse.com/docs/en/operations/system-tables
- ClickHouse TTL documentation: https://clickhouse.com/docs/en/engines/table-engines/mergetree-family/mergetree#table_engine-mergetree-ttl
- ClickHouse max_table_size_to_drop: https://clickhouse.com/docs/en/operations/settings/settings#max-table-size-to-drop
