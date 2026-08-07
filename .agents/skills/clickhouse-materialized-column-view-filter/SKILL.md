---
name: clickhouse-materialized-column-view-filter
description: |
  Fix HTTP 500 / ClickHouse "column not found" errors when filtering by a MATERIALIZED
  column through a VIEW that doesn't expose it. Use when: (1) a WHERE clause references
  alias.column on a view but the column is MATERIALIZED on the underlying table, (2) the
  query works on the raw table but fails through the view, (3) adding a new filter param
  to an API causes 500 even though the column exists in the base table. Fix by using a
  subquery against the base table instead of referencing the column directly on the view.
  Applies to ClickHouse views over tables with MATERIALIZED or ALIAS columns.
author: Claude Code
version: 1.0.0
date: 2026-03-01
---

# ClickHouse: MATERIALIZED Column Not Accessible Through VIEW

## Problem
When a ClickHouse `VIEW` selects specific columns from a table (not `SELECT *`), any
`MATERIALIZED` or `ALIAS` columns not explicitly included in the view's SELECT list are
invisible to queries through the view. Attempting `WHERE v.materialized_col = ?` on such
a view produces a "column not found" error, which surfaces as an HTTP 500 in API layers.

## Context / Trigger Conditions
- You add a new query filter (e.g., `?platform=vine`) that references a column via a view alias
- The column is defined as `String MATERIALIZED ...` on the underlying table
- The VIEW was created with an explicit column list (not `SELECT *`)
- The column works fine when querying the base table directly
- The API returns HTTP 500 with no useful error message to the client
- Server logs show a ClickHouse "column not found" or similar schema error

## Solution

### Option A: Subquery (No migration required)
Replace direct column reference with a subquery against the base table:

```sql
-- BROKEN: view doesn't expose 'platform'
WHERE v.platform = ?

-- FIXED: subquery against the base table where MATERIALIZED column exists
WHERE v.id IN (
  SELECT id FROM events_deduped
  WHERE platform = ? AND kind IN (34235, 34236)
)
```

### Option B: Migration (Cleaner long-term)
Create a new migration that drops and recreates the view to include the column:

```sql
DROP VIEW IF EXISTS nostr.videos;
CREATE VIEW nostr.videos AS
SELECT
    id, pubkey, created_at, kind, content, tags, sig, indexed_at,
    d_tag, title, thumbnail, video_url, author_name, loops,
    platform,  -- ADD THE MATERIALIZED COLUMN
    if(published_at > 0, published_at, toUnixTimestamp(created_at)) AS published_at,
    expiration_at
FROM nostr.events_deduped FINAL
WHERE kind IN (34235, 34236);
```

**Warning**: Dropping a view cascades — any dependent views (video_stats, trending_videos,
videos_with_loops, etc.) must also be dropped and recreated in the correct dependency order.

## Verification
1. Query the view directly: `SELECT platform FROM videos LIMIT 1` — should return data (or empty string for non-vine)
2. API call with the filter param returns 200 instead of 500
3. Run full smoke test suite to confirm no regressions

## Example (Funnelcake)
The `nostr.videos` view (migration 000060) selects a fixed column list from `events_deduped`.
The `platform` column is `String MATERIALIZED` on `events_deduped` but not in the view.

PR #85 added `v.platform = ?` to `get_recent_videos_with_events()` and
`get_trending_videos_with_events()`, both of which query `FROM videos v`. This caused
HTTP 500 for any request with `?platform=vine`.

Fix (PR #86): Changed to subquery approach. Note that `videos_with_loops` (a different view)
DOES include `platform` — queries through that view (like `get_videos_filtered`) work fine.

## Notes
- `MATERIALIZED` columns are physically stored but only accessible if explicitly selected
- `ALIAS` columns are computed on read and have the same visibility constraint in views
- Always check the view definition before adding WHERE conditions on columns
- The `videos_with_loops` view includes more columns than `videos` — consider which view
  your query is actually using
- In Funnelcake: `videos` view = minimal columns; `videos_with_loops` = full columns including platform
