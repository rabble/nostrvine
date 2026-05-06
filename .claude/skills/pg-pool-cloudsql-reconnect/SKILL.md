---
name: pg-pool-cloudsql-reconnect
description: |
  Fix Node.js pg-pool not reconnecting after CloudSQL connection reset (ECONNRESET).
  Use when: (1) Retries fail with same ECONNRESET error despite retry logic,
  (2) "Connection terminated" or "connection already closed" errors persist across retries,
  (3) "remaining connection slots are reserved" errors in CloudSQL,
  (4) High-concurrency Node.js app with pg-pool and CloudSQL/managed PostgreSQL.
  The pool caches dead connections - you must recreate the pool, not just retry.
author: Claude Code
version: 1.0.0
date: 2026-01-30
---

# pg-pool CloudSQL Reconnection

## Problem

Node.js applications using `pg-pool` with CloudSQL (or other managed PostgreSQL) fail to
recover from connection resets. Retry logic appears to work but keeps failing with the
same ECONNRESET error because the pool caches dead connections.

## Context / Trigger Conditions

- ECONNRESET errors that persist despite retry logic
- Error messages like:
  - `read ECONNRESET`
  - `Connection terminated`
  - `connection already closed`
  - `remaining connection slots are reserved for non-replication superuser connections`
- High-concurrency applications (parallel batch processing)
- CloudSQL with small instance tiers (db-f1-micro, db-g1-small)
- Long-running scripts with periods of inactivity followed by bursts

## Root Cause

pg-pool maintains a pool of database connections. When CloudSQL resets connections
(due to timeout, maintenance, or connection limits), the pool still holds references
to those dead connections. Simply retrying the operation uses the same dead connection
from the pool.

## Solution

Instead of just retrying, **recreate the entire pool** on connection reset errors:

```typescript
export class PostgresDatabase {
  private pool: Pool;
  private config: PostgresConfig;

  constructor(config: PostgresConfig) {
    this.config = config;
    this.pool = this.createPool();
  }

  private createPool(): Pool {
    const pool = new Pool({
      ...this.config,
      max: 25,                          // Adequate for concurrency
      idleTimeoutMillis: 30000,         // Close idle connections
      connectionTimeoutMillis: 10000,   // Timeout for new connections
      keepAlive: true,                  // TCP keepalive
    });

    pool.on('error', (err) => {
      console.error('Pool error:', err.message);
    });

    return pool;
  }

  private async reconnect(): Promise<void> {
    console.log("Reconnecting to database...");
    try {
      await this.pool.end();
    } catch {
      // Ignore cleanup errors
    }
    this.pool = this.createPool();
    await this.pool.query("SELECT 1"); // Verify connection
    console.log("Database reconnected");
  }

  private async withRetry<T>(
    operation: () => Promise<T>,
    maxRetries = 3
  ): Promise<T> {
    for (let attempt = 0; attempt < maxRetries; attempt++) {
      try {
        return await operation();
      } catch (error) {
        const msg = error instanceof Error ? error.message : String(error);
        const needsReconnect =
          msg.includes("ECONNRESET") ||
          msg.includes("Connection terminated") ||
          msg.includes("connection already closed") ||
          msg.includes("remaining connection slots");

        if (!needsReconnect || attempt === maxRetries - 1) {
          throw error;
        }

        const delay = 1000 * Math.pow(2, attempt);
        console.log(`Connection error, reconnecting in ${delay}ms...`);
        await new Promise(r => setTimeout(r, delay));

        // KEY: Recreate the pool, don't just retry
        await this.reconnect();
      }
    }
    throw new Error("Max retries exceeded");
  }
}
```

## Key Insight

**Retrying with the same pool uses cached dead connections.** The fix is to:
1. Detect connection reset errors
2. Call `pool.end()` to close all connections
3. Create a new pool instance
4. Verify the new connection works
5. Then retry the operation

## CloudSQL-Specific Considerations

1. **Instance tier matters**: db-f1-micro only supports ~25 connections. Use db-g1-small or larger for concurrent workloads.

2. **Check max_connections**:
   ```bash
   gcloud sql instances describe INSTANCE --format='value(settings.tier)'
   ```

3. **Cloud SQL Proxy**: Doesn't help with connection pooling - it just tunnels TCP. Consider PgBouncer for true connection pooling.

## Verification

After implementing:
1. Run high-concurrency workload
2. Intentionally cause connection reset (restart proxy, wait for idle timeout)
3. Verify operations resume with "Reconnecting to database..." log
4. No more cascading failures

## Notes

- This pattern applies to any managed PostgreSQL, not just CloudSQL
- Consider PgBouncer for production workloads with very high concurrency
- The `pool.on('error')` handler prevents uncaught exceptions from crashing the app
- Set `max` pool size to match your concurrency level plus headroom
