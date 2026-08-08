---
name: psycopg2-batch-insert-optimization
description: |
  Optimize slow PostgreSQL inserts in Python using psycopg2. Use when: (1) Row-by-row
  inserts are taking too long over network, (2) executemany() isn't providing speedup,
  (3) Migrating large datasets to PostgreSQL, (4) Network latency making individual
  INSERT statements impractical. The key is using execute_values() from psycopg2.extras
  instead of executemany() or individual execute() calls.
author: Claude Code
version: 1.0.0
date: 2025-01-20
---

# psycopg2 Batch Insert Optimization

## Problem
When inserting thousands of rows into PostgreSQL over a network connection, row-by-row
inserts are extremely slow. Each INSERT requires a round-trip, and with network latency
of ~50-100ms, inserting 10,000 rows takes 10+ minutes.

The naive approach of using `cursor.executemany()` doesn't help much—it still sends
individual statements.

## Context / Trigger Conditions
- Inserting >100 rows into PostgreSQL via psycopg2
- Each insert taking ~1 second or more
- Network latency to database (especially Cloud SQL, RDS, remote databases)
- Migration scripts running for hours
- `executemany()` not providing expected speedup

## Solution

Use `execute_values()` from `psycopg2.extras`:

```python
from psycopg2.extras import execute_values

# Instead of this (SLOW):
for row in data:
    cursor.execute("INSERT INTO table (a, b, c) VALUES (%s, %s, %s)", row)

# Or this (STILL SLOW):
cursor.executemany("INSERT INTO table (a, b, c) VALUES (%s, %s, %s)", data)

# Use this (FAST):
execute_values(cursor, """
    INSERT INTO table (a, b, c)
    VALUES %s
    ON CONFLICT (id) DO NOTHING
""", data, page_size=500)
conn.commit()
```

### Key Parameters:
- `page_size`: Number of rows per batch (default 100, try 500-1000)
- The `VALUES %s` placeholder is replaced with multiple value tuples

### For UPSERT operations:
```python
execute_values(cursor, """
    INSERT INTO users (user_id, username, email)
    VALUES %s
    ON CONFLICT (user_id) DO UPDATE SET
        username = EXCLUDED.username,
        email = COALESCE(EXCLUDED.email, users.email)
""", user_data, page_size=500)
```

### Progress Monitoring for Long Migrations:
```python
import sys
sys.stdout.reconfigure(line_buffering=True)  # Force unbuffered output

BATCH_SIZE = 500
for i in range(0, len(data), BATCH_SIZE):
    batch = data[i:i+BATCH_SIZE]
    execute_values(cursor, query, batch)
    conn.commit()
    print(f"Processed {min(i+BATCH_SIZE, len(data))}/{len(data)} rows...")
```

## Verification
- Migration that previously took hours completes in minutes
- You can see batches being processed in real-time with progress output
- Check row counts after: `SELECT COUNT(*) FROM table`

## Example

Real-world migration of 9,563 users from SQLite to PostgreSQL:

```python
from psycopg2.extras import execute_values
import sys

sys.stdout.reconfigure(line_buffering=True)
BATCH_SIZE = 500

# Fetch from SQLite
sqlite_cur.execute('SELECT user_id, username, avatar_url, verified FROM users')
rows = sqlite_cur.fetchall()
data = [(r['user_id'], r['username'], r['avatar_url'], bool(r['verified']))
        for r in rows]

# Batch insert to PostgreSQL
for i in range(0, len(data), BATCH_SIZE):
    batch = data[i:i+BATCH_SIZE]
    execute_values(pg_cur, '''
        INSERT INTO users (user_id, username, avatar_url, verified)
        VALUES %s
        ON CONFLICT (user_id) DO UPDATE SET
            username = COALESCE(EXCLUDED.username, users.username),
            avatar_url = COALESCE(EXCLUDED.avatar_url, users.avatar_url)
    ''', batch)
    pg_conn.commit()
    print(f"Processed {min(i+BATCH_SIZE, len(data))}/{len(data)} users...")
```

**Result**: 9,563 users migrated in ~20 seconds instead of ~2.5 hours.

## Notes

- `execute_values()` constructs a single INSERT with multiple VALUES, drastically
  reducing round-trips
- `executemany()` is deceptively slow—it still sends individual statements
- For very large datasets (>100k rows), consider `COPY` command or `copy_expert()`
- The `page_size` parameter controls memory usage vs. batch efficiency
- Always commit after each batch for long migrations (allows progress tracking and
  partial recovery)

### SQLite to PostgreSQL Syntax Differences:
When migrating, also watch for these SQL differences:
- `INSERT OR IGNORE` → `ON CONFLICT DO NOTHING`
- `INSERT OR REPLACE` → `ON CONFLICT DO UPDATE SET ...`
- `MAX(a, b)` (SQLite) → `GREATEST(a, b)` (PostgreSQL)
- `MIN(a, b)` (SQLite) → `LEAST(a, b)` (PostgreSQL)
- `?` placeholders → `%s` placeholders
- `AUTOINCREMENT` → `SERIAL` or `GENERATED ALWAYS AS IDENTITY`

## References
- [psycopg2 execute_values documentation](https://www.psycopg.org/docs/extras.html#psycopg2.extras.execute_values)
- [PostgreSQL COPY for bulk loading](https://www.postgresql.org/docs/current/sql-copy.html)
