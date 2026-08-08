---
name: cloudsql-idle-connection-timeout
description: |
  Fix psycopg2 "could not receive data from server: Operation timed out" or
  "connection already closed" errors when using Cloud SQL with long-running Python scripts.
  Use when: (1) psycopg2.OperationalError after a period of no DB activity, (2) DB connection
  works initially but fails after a non-DB phase (API calls, file processing, CDX scans),
  (3) Cloud SQL managed PostgreSQL kills idle connections. The fix is to defer DB connection
  opening until needed, or add reconnection logic for long-running batch processes.
author: Claude Code
version: 1.0.0
date: 2025-05-15
---

# Cloud SQL Idle Connection Timeout Fix

## Problem
Cloud SQL (and other managed PostgreSQL services) kill idle connections after a timeout
(typically 10 minutes). Long-running scripts that open a DB connection early, then perform
non-DB work (HTTP requests, file I/O, CDX scanning), then try to use the DB connection
again will get a misleading error.

## Context / Trigger Conditions
- `psycopg2.OperationalError: could not receive data from server: Operation timed out`
- `psycopg2.InterfaceError: connection already closed`
- Script has phases: DB setup → long non-DB work → DB writes
- Using Google Cloud SQL, AWS RDS, or Azure Database for PostgreSQL
- Connection was working initially, fails after idle period
- The error appears AFTER a phase that doesn't use the DB (e.g., API crawling, file processing)

## Solution

### Pattern 1: Defer DB Connection (Preferred)

Structure code so the DB connection opens AFTER the non-DB phase:

```python
# BAD: Connection opens before long CDX scan
with VineDatabase() as db:
    ensure_schema(db)
    results = long_running_api_scan()  # 5-10 minutes, no DB needed
    process_results(db, results)  # Connection dead here!

# GOOD: CDX scan first, then fresh DB connection
results = long_running_api_scan()  # No DB connection open

with VineDatabase() as db:  # Fresh connection when actually needed
    ensure_schema(db)
    process_results(db, results)
```

### Pattern 2: Reconnection Logic (For Long Batch Operations)

For operations that DO use the DB but might exceed the idle timeout between writes:

```python
import psycopg2

def reconnect_db():
    """Create a fresh database connection."""
    db = VineDatabase()
    cursor = db._cursor()
    return db, cursor

def process_batch(db, cursor, items):
    for item in items:
        data = fetch_from_api(item)  # Slow network call
        try:
            cursor.execute("INSERT INTO ...", data)
            db.conn.commit()
        except (psycopg2.OperationalError, psycopg2.InterfaceError):
            # Connection died, reconnect and retry
            try:
                db.close()
            except Exception:
                pass
            db, cursor = reconnect_db()
            cursor.execute("INSERT INTO ...", data)
            db.conn.commit()
```

### Pattern 3: TCP Keepalive (Alternative)

Configure psycopg2 to send TCP keepalive packets:

```python
conn = psycopg2.connect(
    database_url,
    keepalives=1,
    keepalives_idle=60,
    keepalives_interval=10,
    keepalives_count=5
)
```

Note: This may not work with all Cloud SQL proxy configurations.

## Verification

1. Run the script with the long non-DB phase
2. Confirm no `OperationalError` or `InterfaceError` after the idle period
3. Verify data is being written to the DB during the fetch phase:
   ```sql
   SELECT COUNT(*) FROM your_table WHERE created_at > NOW() - INTERVAL '5 minutes';
   ```

## Example

A Vine archive crawler that:
1. Scans Wayback Machine CDX for archived profiles (107 pages, ~6 minutes)
2. Then fetches and stores each profile in Cloud SQL

The CDX scan doesn't need the DB, so opening the connection before it means the
connection sits idle for 6 minutes and gets killed by Cloud SQL. Fix: run CDX scan
first, then open DB connection for the fetch-and-store phase.

## Notes
- Cloud SQL default idle timeout is ~10 minutes but can vary
- The error message "could not receive data from server: Operation timed out" is
  misleading—it sounds like a network issue but is actually an idle timeout
- `psycopg2.InterfaceError: connection already closed` often follows the OperationalError
- For very long batch operations (hours), combine Pattern 1 and Pattern 2
- Also check Cloud SQL authorized networks if connection fails immediately (different error)
- When using `nohup` or background processes, ensure output is unbuffered (`PYTHONUNBUFFERED=1`)
