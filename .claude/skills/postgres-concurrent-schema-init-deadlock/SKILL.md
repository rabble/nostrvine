---
name: postgres-concurrent-schema-init-deadlock
description: |
  Fix PostgreSQL deadlock errors caused by concurrent schema initialization in worker processes.
  Use when: (1) psycopg2.errors.DeadlockDetected during CREATE INDEX/TABLE IF NOT EXISTS,
  (2) Multiple Cloud Run jobs, Kubernetes pods, or worker processes start simultaneously,
  (3) Error shows "Process X waits for RowExclusiveLock... blocked by process Y",
  (4) init_schema() or migration code runs at worker startup. The key insight: "IF NOT EXISTS"
  is NOT truly concurrent-safe - PostgreSQL still acquires locks that can deadlock.
author: Claude Code
version: 1.0.0
date: 2026-01-29
---

# PostgreSQL Concurrent Schema Init Deadlock

## Problem
Multiple worker processes (Cloud Run jobs, K8s pods, serverless functions) starting
simultaneously all try to run schema initialization code, causing PostgreSQL deadlocks
even when using "IF NOT EXISTS" clauses.

## Context / Trigger Conditions
- Error: `psycopg2.errors.DeadlockDetected: deadlock detected`
- Log shows: `Process X waits for RowExclusiveLock on relation... blocked by process Y`
- Multiple workers/jobs starting at roughly the same time
- Each worker calls `init_schema()` or runs migrations at startup
- Using `CREATE TABLE IF NOT EXISTS` or `CREATE INDEX IF NOT EXISTS`

## Why This Happens
PostgreSQL's `IF NOT EXISTS` is **not concurrent-safe**:
1. `CREATE INDEX IF NOT EXISTS` still acquires locks before checking existence
2. Multiple processes acquiring locks on different objects can deadlock
3. Even "safe" DDL can conflict when executed concurrently

## Solution

### Option 1: Skip Init in Production (Recommended)
Schema already exists - don't run init_schema() in workers:

```python
with Database() as db:
    # Schema already exists in production - skip to avoid deadlocks
    # db.init_schema()

    # ... worker code
```

### Option 2: Use Advisory Locks
Serialize schema init with PostgreSQL advisory locks:

```python
def init_schema_safe(self):
    cursor = self._cursor()
    # Acquire advisory lock (blocks other processes)
    cursor.execute("SELECT pg_advisory_lock(12345)")
    try:
        self.init_schema()
    finally:
        cursor.execute("SELECT pg_advisory_unlock(12345)")
        self.conn.commit()
```

### Option 3: Separate Migration Step
Run migrations as a separate job before starting workers:

```bash
# In deployment pipeline
python -m src.migrate  # Single process, runs first
# Then start workers
gcloud run jobs execute worker-job
```

### Option 4: Lock Timeout + Retry
Set lock timeout and retry on deadlock:

```python
def init_schema_with_retry(self, max_retries=3):
    for attempt in range(max_retries):
        try:
            cursor = self._cursor()
            cursor.execute("SET lock_timeout = '5s'")
            self.init_schema()
            return
        except psycopg2.errors.DeadlockDetected:
            self.conn.rollback()
            if attempt == max_retries - 1:
                raise
            time.sleep(random.uniform(1, 3))
```

## Verification
After applying fix:
1. Start multiple workers simultaneously
2. Check logs for absence of deadlock errors
3. Verify all workers start successfully

## Example
Before (deadlocks with 6 concurrent Cloud Run jobs):
```python
# src/download.py
with VineDatabase() as db:
    db.init_schema()  # DEADLOCK when multiple jobs start!
    # ... download logic
```

After (no deadlocks):
```python
# src/download.py
with VineDatabase() as db:
    # Schema already exists in production - skip to avoid deadlocks
    # db.init_schema()
    # ... download logic
```

## Notes
- This applies to any concurrent worker pattern: Cloud Run, Celery, Kubernetes, Lambda
- The deadlock can be intermittent - depends on exact timing of worker starts
- `CREATE TABLE IF NOT EXISTS` is generally safer than `CREATE INDEX IF NOT EXISTS`
- Cloud Run jobs often start simultaneously when triggered, making this common
- Consider using database migration tools (Alembic, Flyway) with proper locking

## References
- [PostgreSQL Advisory Locks](https://www.postgresql.org/docs/current/explicit-locking.html#ADVISORY-LOCKS)
- [PostgreSQL Deadlock Detection](https://www.postgresql.org/docs/current/explicit-locking.html#LOCKING-DEADLOCKS)
