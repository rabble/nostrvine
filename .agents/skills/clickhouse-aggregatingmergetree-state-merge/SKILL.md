---
name: clickhouse-aggregatingmergetree-state-merge
description: |
  Fix ClickHouse query errors when querying AggregatingMergeTree tables that use state functions.
  Use when: (1) Query fails with type mismatch on AggregateFunction columns, (2) Using sum/count
  on columns created with sumState/countState/uniqState, (3) Creating views that JOIN with
  materialized views using AggregatingMergeTree, (4) Getting unexpected results from aggregate
  columns that show as AggregateFunction(sum, ...) type. The *State() functions store intermediate
  aggregate states, not final values - you must use *Merge() functions to finalize them.
author: Claude Code
version: 1.0.0
date: 2026-01-30
---

# ClickHouse AggregatingMergeTree State/Merge Pattern

## Problem
When querying tables or materialized views that use AggregatingMergeTree with state functions
(`sumState`, `uniqState`, `countState`), queries fail or return wrong results because the
columns contain aggregate state objects, not regular numeric values.

## Context / Trigger Conditions
- Query fails with type errors when using `sum()` on AggregateFunction columns
- Creating views that query AggregatingMergeTree materialized views
- Column types show as `AggregateFunction(sum, UInt64)` instead of `UInt64`
- Migration creates a view joining with an existing aggregating materialized view
- Getting NULL or unexpected values when aggregating pre-aggregated columns

## Root Cause
AggregatingMergeTree stores **intermediate aggregate states**, not final values. When you define:

```sql
CREATE MATERIALIZED VIEW stats
ENGINE = AggregatingMergeTree()
ORDER BY (user_id)
AS SELECT
    user_id,
    sumState(amount) as total_amount,      -- AggregateFunction(sum, UInt64)
    uniqState(session_id) as unique_sessions, -- AggregateFunction(uniq, String)
    countState() as event_count           -- AggregateFunction(count)
FROM events
GROUP BY user_id;
```

The columns `total_amount`, `unique_sessions`, and `event_count` are NOT regular numbers.
They're binary blobs representing the intermediate state of the aggregation.

**Wrong:**
```sql
SELECT user_id, sum(total_amount) FROM stats GROUP BY user_id;
-- Error: cannot use sum() on AggregateFunction type
```

**Correct:**
```sql
SELECT user_id, sumMerge(total_amount) FROM stats GROUP BY user_id;
-- Returns the finalized numeric value
```

## Solution

### Mapping State Functions to Merge Functions

| State Function | Merge Function | Purpose |
|----------------|----------------|---------|
| `sumState(x)` | `sumMerge(x)` | Sum aggregation |
| `countState()` | `countMerge(x)` | Count aggregation |
| `uniqState(x)` | `uniqMerge(x)` | Unique count (HyperLogLog) |
| `avgState(x)` | `avgMerge(x)` | Average |
| `minState(x)` | `minMerge(x)` | Minimum |
| `maxState(x)` | `maxMerge(x)` | Maximum |
| `anyState(x)` | `anyMerge(x)` | Any value |
| `groupArrayState(x)` | `groupArrayMerge(x)` | Array aggregation |

### Example Fix

**Before (broken):**
```sql
CREATE VIEW leaderboard AS
SELECT
    stats.user_id,
    sum(stats.daily_views) AS views,        -- WRONG
    sum(stats.daily_unique) AS uniques,     -- WRONG
    sum(stats.videos_watched) AS videos     -- WRONG
FROM daily_stats stats
GROUP BY stats.user_id;
```

**After (fixed):**
```sql
CREATE VIEW leaderboard AS
SELECT
    stats.user_id,
    sumMerge(stats.daily_views) AS views,        -- Correct
    uniqMerge(stats.daily_unique) AS uniques,    -- Correct
    countMerge(stats.videos_watched) AS videos   -- Correct
FROM daily_stats stats
GROUP BY stats.user_id;
```

### Identifying Affected Columns

Check the table schema to see which columns are aggregate states:

```sql
DESCRIBE TABLE your_table;
```

Output shows column types like:
```
daily_views       AggregateFunction(sum, UInt64)
daily_unique      AggregateFunction(uniq, String)
videos_watched    AggregateFunction(count)
```

Any column with `AggregateFunction(...)` type requires the corresponding `*Merge()` function.

## Verification

1. Check your materialized view definition for `*State()` functions
2. Ensure all queries use matching `*Merge()` functions
3. Test the query returns expected numeric values, not NULL or binary blobs

```sql
-- Should return actual numbers
SELECT sumMerge(total_views), uniqMerge(unique_visitors)
FROM aggregated_stats
WHERE stat_date >= today() - 7;
```

## Example

**Migration 020 (creates the aggregating table):**
```sql
CREATE MATERIALIZED VIEW creator_daily_stats
ENGINE = AggregatingMergeTree()
ORDER BY (video_author_pubkey, stat_date)
AS SELECT
    video_author_pubkey,
    toDate(created_at) as stat_date,
    sumState(view_count) as daily_views,           -- State function
    uniqState(viewer_hash) as daily_unique_viewers, -- State function
    sumState(toFloat64(total_loops)) as daily_loops,-- State function
    countState() as videos_watched                  -- State function
FROM view_counts
GROUP BY video_author_pubkey, toDate(created_at);
```

**Migration 033 (queries the aggregating table - FIXED):**
```sql
CREATE VIEW leaderboard_creators_day AS
SELECT
    cds.video_author_pubkey AS pubkey,
    p.name,
    sumMerge(cds.daily_views) AS views,            -- Merge function
    uniqMerge(cds.daily_unique_viewers) AS unique_viewers, -- Merge function
    sumMerge(cds.daily_loops) AS loops,            -- Merge function
    countMerge(cds.videos_watched) AS videos_with_views -- Merge function
FROM creator_daily_stats cds
LEFT JOIN user_profiles p ON cds.video_author_pubkey = p.pubkey
WHERE cds.stat_date >= today() - 1
GROUP BY cds.video_author_pubkey, p.name
ORDER BY views DESC;
```

## Notes

- **SummingMergeTree is different**: It stores regular values and sums them during merges.
  With SummingMergeTree, you use regular `sum()` in queries. Only AggregatingMergeTree uses
  the State/Merge pattern.

- **Why use AggregatingMergeTree?**: For unique counts (`uniq`), you can't simply sum the
  counts from different parts—that would overcount. AggregatingMergeTree preserves the
  HyperLogLog state so merging gives correct unique counts across partitions.

- **Performance**: The `*Merge()` functions are efficient—they're designed to combine
  pre-computed aggregate states, not reprocess raw data.

- **Migration ordering matters**: If migration A creates an AggregatingMergeTree view, and
  migration B creates a view that queries it, migration B must use `*Merge()` functions.

## References

- [ClickHouse AggregatingMergeTree](https://clickhouse.com/docs/en/engines/table-engines/mergetree-family/aggregatingmergetree)
- [ClickHouse Aggregate Function Combinators](https://clickhouse.com/docs/en/sql-reference/aggregate-functions/combinators)
- [ClickHouse -State and -Merge combinators](https://clickhouse.com/docs/en/sql-reference/aggregate-functions/combinators#-state)
