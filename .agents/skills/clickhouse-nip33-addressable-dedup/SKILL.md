---
name: clickhouse-nip33-addressable-dedup
description: |
  Fix duplicate Nostr events in ClickHouse when using ReplacingMergeTree for NIP-33
  addressable events (Kind 30000+). Use when: (1) Edited videos/events appear as duplicates,
  (2) Same d_tag shows multiple events with different IDs, (3) FINAL keyword doesn't
  deduplicate properly for parameterized replaceable events. The issue is that FINAL
  deduplicates by ORDER BY key (typically `id`), not by (pubkey, kind, d_tag).
author: Claude Code
version: 1.0.0
date: 2026-01-30
---

# ClickHouse NIP-33 Addressable Event Deduplication

## Problem
When storing Nostr events in ClickHouse using ReplacingMergeTree, edited addressable events
(Kind 30000-39999) appear as duplicates. Users edit their video/event, a new event ID is
created with the same d_tag, but both versions are shown instead of just the latest.

## Context / Trigger Conditions
- Nostr relay storing events in ClickHouse with ReplacingMergeTree
- Users report seeing duplicate videos/events after editing
- Query returns multiple events with same `(pubkey, kind, d_tag)` but different `id` values
- Using `FINAL` keyword but duplicates still appear
- Kind 30000+ events (NIP-33 parameterized replaceable events like Kind 34236 videos)

## Root Cause
The `FINAL` keyword in ClickHouse deduplicates based on the table's `ORDER BY` key. If
your table is defined as:

```sql
ENGINE = ReplacingMergeTree(indexed_at)
ORDER BY (id)
```

Then `FINAL` deduplicates by `id`. Two events with different IDs are NOT considered
duplicates, even if they represent the same addressable "slot" per NIP-33.

For NIP-33 addressable events, the replacement key should be `(pubkey, kind, d_tag)`,
not `id`.

## Solution

### Option 1: Fix at View Level (Recommended)

Change your videos view to use `LIMIT 1 BY` instead of `FINAL`:

```sql
CREATE VIEW videos AS
SELECT
    id,
    pubkey,
    created_at,
    kind,
    content,
    tags,
    d_tag,
    title,
    thumbnail,
    video_url
FROM events_local
WHERE kind IN (34235, 34236)
ORDER BY pubkey, kind, d_tag, created_at DESC
LIMIT 1 BY pubkey, kind, d_tag;
```

The `LIMIT 1 BY` clause keeps only the first row (latest by created_at) for each
unique combination of `(pubkey, kind, d_tag)`.

### Option 2: Fix at Table Level (Breaking Change)

If you can recreate the table, use a composite ORDER BY:

```sql
CREATE TABLE events_addressable (
    ...
) ENGINE = ReplacingMergeTree(created_at)
ORDER BY (pubkey, kind, d_tag);
```

This makes `FINAL` work correctly for NIP-33 events but may not work for all event types.

### Migration Example

```sql
-- Drop dependent views first
DROP VIEW IF EXISTS trending_videos;
DROP VIEW IF EXISTS video_stats;
DROP VIEW IF EXISTS videos;

-- Recreate with proper deduplication
CREATE VIEW videos AS
SELECT *
FROM events_local
WHERE kind IN (34235, 34236)
ORDER BY pubkey, kind, d_tag, created_at DESC
LIMIT 1 BY pubkey, kind, d_tag;

-- Recreate dependent views...
```

## Verification

Query for a specific user's videos and confirm no duplicates:

```sql
SELECT id, d_tag, created_at
FROM videos
WHERE pubkey = 'user_pubkey_here'
ORDER BY created_at DESC;
```

Each `d_tag` should appear only once, with the highest `created_at` value.

## Example

**Before (broken):**
```
| id       | d_tag    | created_at |
|----------|----------|------------|
| abc123   | video1   | 1769697188 | ← Newer edit
| def456   | video1   | 1769697150 | ← Original (should be hidden)
```

**After (fixed):**
```
| id       | d_tag    | created_at |
|----------|----------|------------|
| abc123   | video1   | 1769697188 | ← Only latest shown
```

## Notes
- This applies to all NIP-33 addressable events (Kind 30000-39999), not just videos
- The `LIMIT 1 BY` approach is query-time deduplication, not storage deduplication
- Old event versions remain in storage but won't appear in query results
- Consider periodic cleanup of old event versions if storage is a concern
- Don't forget to recreate dependent views in the correct order

## References
- [NIP-33: Parameterized Replaceable Events](https://github.com/nostr-protocol/nips/blob/master/33.md)
- [ClickHouse LIMIT BY clause](https://clickhouse.com/docs/en/sql-reference/statements/select/limit-by)
- [ClickHouse ReplacingMergeTree](https://clickhouse.com/docs/en/engines/table-engines/mergetree-family/replacingmergetree)
