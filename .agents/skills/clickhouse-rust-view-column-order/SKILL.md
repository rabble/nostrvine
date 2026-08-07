---
name: clickhouse-rust-view-column-order
description: |
  Debug ClickHouse deserialization errors in Rust caused by column ORDER mismatch
  when using SELECT alias.* on a VIEW that adds computed columns. Use when:
  (1) Some query variants (e.g. sort=trending) return 500 but others (sort=recent) succeed,
  (2) Queries use SELECT view_alias.*, extra_cols FROM view JOIN ...,
  (3) The Rust Row struct has the right number and types of fields but deserialization
  fails anyway (wrong type error, not "not enough data"),
  (4) The VIEW was recently extended with a computed column (e.g. trending_score).
author: Claude Code
version: 1.0.0
date: 2026-02-25
---

# ClickHouse Rust: View Computed Column Ordering

## Problem

When using `SELECT alias.* , extra_col FROM my_view alias LEFT JOIN ...`, ClickHouse
expands `alias.*` to include ALL columns defined in the view — including any computed
columns added by the view itself (e.g. `SELECT *, expr AS trending_score FROM base`).
Those computed columns appear INSIDE the `alias.*` expansion, BEFORE any columns
appended after it in the outer query.

The `clickhouse` Rust crate (`#[derive(Row)]`) deserializes **positionally** — field N
in the Rust struct receives column N from the query result. If the struct field order
doesn't match the actual SQL column order, the wrong bytes land in the wrong fields,
causing type errors at deserialization even though the column count is correct.

## Symptoms

- HTTP 500 on one sort variant (e.g. `sort=trending`, `sort=popular`) but not others
  (e.g. `sort=recent`) that query a different view or table
- Error like: `"cannot decode Float64 from String"` or similar type mismatch
- Column COUNT is correct (no "not enough data" error)
- Bug appears after adding a computed column to an existing view

## Root Cause Explained

Suppose `trending_videos` is defined as:
```sql
CREATE VIEW trending_videos AS
SELECT
    *,                                          -- all base columns
    (views * 0.5 + likes * 2.0) AS trending_score  -- computed column APPENDED HERE
FROM video_stats;
```

An outer query then does:
```sql
SELECT
    tv.*,                   -- expands to: base_cols..., trending_score
    text_track_ref,         -- subtitle columns come AFTER
    text_track_content
FROM trending_videos tv
LEFT JOIN subtitle_subquery USING (id);
```

The actual SQL result column order is:
```
[...base_cols, trending_score, text_track_ref, text_track_content]
```

But if the Rust struct was written with subtitle fields before trending_score:
```rust
pub struct TrendingVideo {
    // ...base fields...
    pub text_track_ref: String,      // position N   <- WRONG: gets trending_score bytes
    pub text_track_content: String,  // position N+1 <- WRONG: gets text_track_ref bytes
    pub trending_score: f64,         // position N+2 <- WRONG: gets text_track_content bytes
}
```

ClickHouse sends a `Float64` where Rust expects a `String` → deserialization error → 500.

## Why Only Some Queries Fail

The `sort=recent` variant queries `video_stats` directly with `vs.*` — that view has
no extra computed columns, so subtitle columns land at the same relative position the
struct expects. Only the `trending_videos` view adds `trending_score` inside `vs.*`,
shifting everything after it.

## Debugging Steps

1. **Identify which query variants fail vs. succeed.** Failing ones likely use a
   different view or have a different `SELECT *` source.

2. **Expand the failing `SELECT alias.*`** — run the inner view query directly:
   ```bash
   curl -u 'user:pass' 'https://clickhouse-host:8443' \
     --data-binary "SELECT * FROM trending_videos LIMIT 0 FORMAT TabSeparated"
   ```
   Or use `DESCRIBE TABLE trending_videos` to see declared column order.

3. **List actual column order** of the full outer query:
   ```bash
   curl ... --data-binary \
     "SELECT tv.*, '' as text_track_ref, '' as text_track_content
      FROM trending_videos tv LIMIT 0 FORMAT TabSeparatedWithNames"
   ```

4. **Compare with Rust struct field order** line by line — they must match exactly.

5. **Find the misplaced field** — look for computed columns added to the view that
   appear inside `alias.*` but after columns that appear in the outer SELECT.

## Fix

Reorder the Rust struct fields to match the actual SQL column order — computed
VIEW columns belong before any columns appended in the outer SELECT:

```rust
pub struct TrendingVideo {
    // ...base fields in same order as base table...

    // trending_score comes from tv.* (view-computed), so it appears
    // BEFORE the subtitle columns we append in the outer query
    pub trending_score: f64,

    // Subtitle columns are appended after tv.* in the outer SELECT
    pub text_track_ref: String,
    pub text_track_content: String,
}
```

Do NOT change the SQL query or the view — just align the struct field order.

## Key Rule

> When a ClickHouse VIEW adds a computed column via `SELECT *, expr AS col FROM base`,
> that column becomes part of the view's column list. Any `SELECT alias.*` in an outer
> query will emit it in the view's declared order — BEFORE any extra columns appended
> after `alias.*` in the outer SELECT. The Rust `#[derive(Row)]` struct must reflect
> this exact order.

## Prevention

- When adding a computed column to a ClickHouse view, immediately check ALL Rust
  structs that query that view with `SELECT alias.*` and update field ordering.
- Add an integration test that queries the affected endpoint; CI will catch future
  ordering drift before staging.
- Consider using `SELECT col1, col2, ..., trending_score, text_track_ref, text_track_content`
  (explicit column list instead of `*`) in the outer query to make ordering explicit
  and immune to view schema changes.

## Related Skills

- `clickhouse-rust-type-mismatches` — covers "not enough data" (column COUNT mismatch),
  FixedString encoding, Option vs String nullability issues. This skill covers column
  ORDER mismatch (column count is correct, types match, but positional order is wrong).

## References

- [clickhouse crate Row derive macro](https://docs.rs/clickhouse/latest/clickhouse/derive.Row.html)
- ClickHouse `SELECT *` expansion: follows column declaration order of the source table/view
