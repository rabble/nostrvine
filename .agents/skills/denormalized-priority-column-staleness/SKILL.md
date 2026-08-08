---
name: denormalized-priority-column-staleness
description: |
  Fix incorrect priority ordering when using denormalized aggregate columns. Use when:
  (1) Records are processed in wrong order despite ORDER BY on count/sum columns,
  (2) Top items by some metric aren't being selected first, (3) Aggregate columns
  show 0 or NULL for records that should have high values, (4) Priority queue
  processes low-value items before high-value ones. The root cause is often that
  denormalized columns (vine_count, loop_count, total_orders, etc.) weren't
  backfilled or maintained properly. Solution: JOIN with source tables to compute
  actual aggregates at query time.
author: Claude Code
version: 1.0.0
date: 2026-01-28
---

# Denormalized Priority Column Staleness

## Problem
When ordering records by denormalized aggregate columns (like `total_loops`, `vine_count`,
`order_count`), the query returns items in the wrong priority order because the
denormalized values are stale, unpopulated, or incorrect.

## Context / Trigger Conditions
- A batch job processes items in unexpected order
- Top items (by some aggregate metric) are processed last or skipped
- `ORDER BY aggregate_column DESC` doesn't return expected results
- Aggregate columns show 0 or NULL for records that should have high values
- Only a subset of records have the aggregate column populated
- Backfill scripts may have run for some records but not others

## Root Cause
Denormalized columns (copies of aggregated data stored for query performance) can become
stale when:
1. Initial data migration didn't populate them
2. Backfill scripts only ran for some records
3. New source records were added without updating the denormalized column
4. The aggregation logic changed but the column wasn't recalculated

## Solution

### Option 1: Compute at Query Time (Immediate Fix)
Join with the source table to compute actual aggregates:

```sql
-- BEFORE (broken): Uses potentially stale denormalized column
SELECT user_id, username
FROM users
WHERE status = 'pending'
ORDER BY total_loops DESC NULLS LAST;

-- AFTER (fixed): Computes actual aggregate from source
SELECT u.user_id, u.username,
       COALESCE(SUM(vm.loops), 0) as actual_total_loops
FROM users u
LEFT JOIN vine_metadata vm ON u.user_id = vm.user_id
WHERE u.status = 'pending'
GROUP BY u.user_id, u.username
ORDER BY actual_total_loops DESC;
```

### Option 2: Backfill the Denormalized Column (Permanent Fix)
Update the denormalized column from the source data:

```sql
UPDATE users u
SET total_loops = subq.actual_loops
FROM (
    SELECT user_id, COALESCE(SUM(loops), 0) as actual_loops
    FROM vine_metadata
    GROUP BY user_id
) subq
WHERE u.user_id = subq.user_id;
```

### Option 3: Use Materialized Views (Best of Both)
Create a materialized view for the aggregates:

```sql
CREATE MATERIALIZED VIEW user_stats AS
SELECT user_id,
       COUNT(*) as item_count,
       SUM(loops) as total_loops
FROM vine_metadata
GROUP BY user_id;

-- Refresh periodically
REFRESH MATERIALIZED VIEW user_stats;
```

## Verification
After applying the fix, verify the query returns expected results:

```sql
-- Check that top items are actually top items
SELECT user_id, username, actual_total_loops
FROM (your_fixed_query)
LIMIT 10;

-- Compare against direct aggregate
SELECT user_id, SUM(loops) as loops
FROM source_table
GROUP BY user_id
ORDER BY loops DESC
LIMIT 10;
```

## Example

**Scenario**: Avatar fetcher should process top Viners first (by total loops), but
instead processes users with ID prefix "10" (effectively random order).

**Investigation**:
```sql
-- Check if denormalized column is populated
SELECT
    COUNT(*) as total,
    SUM(CASE WHEN loop_count > 0 THEN 1 ELSE 0 END) as has_loop_count
FROM users;
-- Result: Only 29,878 of 119,785 users have loop_count populated

-- Check top users by denormalized vs actual
SELECT u.user_id, u.username, u.loop_count as denormalized,
       SUM(vm.loops) as actual
FROM users u
JOIN vine_metadata vm ON u.user_id = vm.user_id
GROUP BY u.user_id, u.username, u.loop_count
ORDER BY SUM(vm.loops) DESC
LIMIT 5;
-- Result: Top creators show loop_count=0 but actual=1,281,730,353
```

**Fix**: Changed the query to JOIN with vine_metadata and ORDER BY the computed sum.

## Notes
- This is a classic denormalization trade-off: faster reads vs. stale data
- When denormalizing, always implement triggers or application-level updates to keep in sync
- Consider whether the aggregate query is fast enough to compute at runtime
- LEFT JOIN ensures records without source data still appear (with 0 values)
- Use `COALESCE(SUM(...), 0)` to handle NULL aggregates properly
- `NULLS LAST` in ORDER BY prevents NULL values from sorting first in DESC order

## Related Patterns
- Event sourcing: Keep source events, compute aggregates as needed
- CQRS: Separate read models that are explicitly updated
- Triggers: Automatically update denormalized columns on source changes
