# ClickHouse Relay Backend Schema Design

## Document Purpose

This document outlines the design for a ClickHouse-backed Nostr relay for the Divine video sharing application. It is intended for review by engineering teams and AI assistants to validate the approach, identify gaps, and refine the schema before implementation.

---

## Table of Contents

1. [Project Context](#project-context)
2. [Nostr Protocol Overview](#nostr-protocol-overview)
3. [Divine Application Data Requirements](#divine-application-data-requirements)
4. [Query Patterns Analysis](#query-patterns-analysis)
5. [ClickHouse Schema Design](#clickhouse-schema-design)
6. [Open Questions](#open-questions)
7. [Alternative Approaches](#alternative-approaches)
8. [Performance Considerations](#performance-considerations)
9. [Implementation Roadmap](#implementation-roadmap)

---

## 1. Project Context

### What is Divine?

Divine (OpenVine) is a decentralized Vine-like video sharing application built on the Nostr protocol. Users can:

- Capture and share short looping videos (6 seconds typical)
- Follow other users and see their content in a personalized feed
- Like, comment on, and repost videos
- Browse videos by hashtag or explore trending content
- View user profiles with their video history

### Current Architecture

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  Flutter App    │────▶│  Embedded Relay  │────▶│ External Relays │
│  (iOS/Android)  │     │  (SQLite local)  │     │ (wss://...)     │
└─────────────────┘     └──────────────────┘     └─────────────────┘
```

### Proposed Architecture

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  Flutter App    │────▶│  Relay Server    │────▶│   ClickHouse    │
│  (iOS/Android)  │     │  (WebSocket)     │     │   (Storage)     │
└─────────────────┘     └──────────────────┘     └─────────────────┘
                                │
                                ▼
                        ┌──────────────────┐
                        │ Other Relays     │
                        │ (Federation)     │
                        └──────────────────┘
```

### Why ClickHouse?

- **Column-oriented storage**: Efficient for analytical queries over event data
- **High write throughput**: Can handle millions of events per second
- **Compression**: Excellent compression ratios for repetitive data (pubkeys, kinds)
- **Real-time queries**: Sub-second query latency even on large datasets
- **Materialized views**: Pre-compute aggregations (reaction counts, trending scores)
- **Scalability**: Horizontal scaling with sharding/replication

---

## 2. Nostr Protocol Overview

### Event Structure (NIP-01)

Every Nostr event is a JSON object with this structure:

```json
{
  "id": "64-char-hex-sha256-of-serialized-event",
  "pubkey": "64-char-hex-public-key-of-author",
  "created_at": 1234567890,
  "kind": 1,
  "tags": [
    ["e", "referenced-event-id", "relay-hint", "marker"],
    ["p", "referenced-pubkey", "relay-hint"],
    ["t", "hashtag"],
    ["d", "identifier-for-addressable-events"]
  ],
  "content": "arbitrary string content",
  "sig": "128-char-hex-schnorr-signature"
}
```

### Field Specifications

| Field | Type | Size | Description |
|-------|------|------|-------------|
| `id` | hex string | 64 chars | SHA256 hash, unique identifier |
| `pubkey` | hex string | 64 chars | Author's public key |
| `created_at` | integer | 4 bytes | Unix timestamp (seconds) |
| `kind` | integer | 2 bytes | Event type (0-65535) |
| `tags` | array | variable | Array of string arrays |
| `content` | string | variable | Event payload |
| `sig` | hex string | 128 chars | Schnorr signature |

### Event Kinds Used by Divine

| Kind | Name | Description | Replaceability |
|------|------|-------------|----------------|
| **0** | Metadata | User profile (name, picture, bio) | Replaceable by `(pubkey)` |
| **3** | Contacts | Follow list (p-tags for followed users) | Replaceable by `(pubkey)` |
| **6** | Repost | Reshare of another event | Regular (immutable) |
| **7** | Reaction | Like/heart on an event | Regular (immutable) |
| **21** | Video | Normal-length video | Regular (immutable) |
| **22** | Short Video | Vine-like short video | Regular (immutable) |
| **34235** | Addressable Video | Editable normal video | Param. replaceable by `(pubkey, kind, d)` |
| **34236** | Addressable Short Video | Editable short video | Param. replaceable by `(pubkey, kind, d)` |

### Event Replaceability Rules

1. **Regular Events** (most kinds): Immutable, identified by `id`
2. **Replaceable Events** (kinds 0, 3, 10000-19999): Latest event per `(pubkey, kind)` wins
3. **Parameterized Replaceable** (kinds 30000-39999): Latest per `(pubkey, kind, d-tag)` wins

### Tag Types Used

| Tag | Name | Format | Purpose |
|-----|------|--------|---------|
| `e` | Event | `["e", "<event-id>", "<relay>", "<marker>"]` | Reference another event |
| `p` | Pubkey | `["p", "<pubkey>", "<relay>"]` | Reference a user |
| `t` | Topic | `["t", "<hashtag>"]` | Hashtag/topic (lowercase) |
| `d` | Identifier | `["d", "<unique-id>"]` | Dedup key for addressable events |
| `a` | Address | `["a", "<kind>:<pubkey>:<d>", "<relay>"]` | Reference addressable event |
| `title` | Title | `["title", "<video-title>"]` | Video title |
| `imeta` | Media | `["imeta", "url <url>", "m <mime>", ...]` | Media metadata (NIP-92) |
| `published_at` | Publish Time | `["published_at", "<timestamp>"]` | Original publish time |
| `duration` | Duration | `["duration", "<seconds>"]` | Video duration |
| `alt` | Alt Text | `["alt", "<description>"]` | Accessibility text |
| `blurhash` | Blurhash | `["blurhash", "<hash>"]` | Image placeholder hash |

### Filter Structure (REQ Messages)

Clients query relays using filters:

```json
{
  "ids": ["<event-id>", ...],
  "authors": ["<pubkey>", ...],
  "kinds": [0, 1, 7, 34236],
  "#e": ["<event-id>", ...],
  "#p": ["<pubkey>", ...],
  "#t": ["hashtag", ...],
  "#d": ["identifier", ...],
  "#a": ["<kind>:<pubkey>:<d>", ...],
  "since": 1672531200,
  "until": 1672617600,
  "limit": 100
}
```

**Filter Logic:**
- Within a filter: AND logic (all conditions must match)
- Multiple filters in one REQ: OR logic (match any filter)
- Array values within a condition: OR logic (match any value)

---

## 3. Divine Application Data Requirements

### Subscription Types

The app maintains separate event streams for different UI contexts:

| Subscription Type | Description | Primary Filters |
|-------------------|-------------|-----------------|
| `discovery` | All public videos | `kinds: [21,22,34235,34236]`, sorted by `created_at` |
| `homeFeed` | Videos from followed users | `kinds: [21,22,34235,34236]`, `authors: [followed...]` |
| `profile` | Videos by a specific user | `kinds: [21,22,34235,34236,6]`, `authors: [pubkey]` |
| `hashtag` | Videos with specific hashtag | `kinds: [21,22,34235,34236]`, `#t: [tag]` |
| `editorial` | Curated/featured videos | Special curation logic |
| `popularNow` | Recent popular videos | Recent + high engagement |
| `trending` | Trending by loop count | Sorted by engagement metrics |
| `search` | NIP-50 text search | Full-text search on content/tags |

### Video Event Structure

A typical video event (kind 34236) looks like:

```json
{
  "id": "abc123...",
  "pubkey": "def456...",
  "created_at": 1699000000,
  "kind": 34236,
  "content": "Check out this perfect loop! 🔄",
  "tags": [
    ["d", "unique-video-id"],
    ["title", "Perfect soup stirring loop"],
    ["imeta", "url https://cdn.example.com/video.mp4", "m video/mp4", "dim 480x480", "image https://cdn.example.com/thumb.jpg", "blurhash eNH_0EI..."],
    ["published_at", "1699000000"],
    ["duration", "6"],
    ["alt", "A pot of soup being stirred"],
    ["t", "perfectloops"],
    ["t", "satisfying"],
    ["t", "cooking"]
  ],
  "sig": "..."
}
```

### Engagement Metrics

The app tracks these metrics per video:

| Metric | Source | Query Pattern |
|--------|--------|---------------|
| **Loops** | External analytics API | `GET /analytics/loops/{videoId}` |
| **Likes** | Kind 7 events with `#e` or `#a` tag | `COUNT WHERE kind=7 AND #e=videoId` |
| **Comments** | Kind 1 events with `#e` tag (root marker) | `COUNT WHERE kind=1 AND #e=videoId` |
| **Reposts** | Kind 6 events with `#e` or `#a` tag | `COUNT WHERE kind=6 AND #e=videoId` |

### User Profile Structure

Kind 0 events contain JSON in the `content` field:

```json
{
  "name": "alice",
  "display_name": "Alice",
  "about": "Video creator",
  "picture": "https://example.com/avatar.jpg",
  "banner": "https://example.com/banner.jpg",
  "nip05": "alice@example.com",
  "lud16": "alice@getalby.com",
  "website": "https://alice.example.com"
}
```

### Follow List Structure

Kind 3 events contain followed pubkeys in tags:

```json
{
  "kind": 3,
  "pubkey": "alice-pubkey",
  "tags": [
    ["p", "followed-pubkey-1", "wss://relay1.com"],
    ["p", "followed-pubkey-2", "wss://relay2.com"],
    ["p", "followed-pubkey-3"]
  ],
  "content": ""
}
```

---

## 4. Query Patterns Analysis

### High-Frequency Queries

#### 1. Discovery Feed (Most Common)

```sql
-- Get recent videos, paginated
SELECT * FROM events
WHERE kind IN (21, 22, 34235, 34236)
ORDER BY created_at DESC
LIMIT 50;

-- With pagination (cursor-based using 'until')
SELECT * FROM events
WHERE kind IN (21, 22, 34235, 34236)
  AND created_at < :cursor_timestamp
ORDER BY created_at DESC
LIMIT 50;
```

**Requirements:**
- Sub-100ms latency
- Support for `since`/`until` pagination
- Real-time streaming of new events

#### 2. Home Feed (Personalized)

```sql
-- Get videos from followed users
SELECT * FROM events
WHERE kind IN (21, 22, 34235, 34236)
  AND pubkey IN (:followed_pubkeys)  -- Could be 100s of pubkeys
ORDER BY created_at DESC
LIMIT 50;
```

**Requirements:**
- Efficient filtering by large author list (100-1000 pubkeys)
- Same pagination as discovery

#### 3. Hashtag Feed

```sql
-- Get videos with specific hashtag
SELECT e.* FROM events e
JOIN event_tags t ON e.id = t.event_id
WHERE t.tag_type = 't'
  AND t.tag_value = :hashtag
  AND e.kind IN (21, 22, 34235, 34236)
ORDER BY e.created_at DESC
LIMIT 50;
```

**Requirements:**
- Case-insensitive hashtag matching (stored lowercase)
- Efficient tag lookups

#### 4. Profile Videos

```sql
-- Get all videos by a user (including reposts)
SELECT * FROM events
WHERE pubkey = :user_pubkey
  AND kind IN (21, 22, 34235, 34236, 6)
ORDER BY created_at DESC
LIMIT 50;
```

#### 5. Reaction Counts

```sql
-- Count likes for a video
SELECT COUNT(*) FROM events
WHERE kind = 7
  AND id IN (
    SELECT event_id FROM event_tags
    WHERE tag_type = 'e' AND tag_value = :video_id
  );

-- Or for addressable videos
SELECT COUNT(*) FROM events
WHERE kind = 7
  AND id IN (
    SELECT event_id FROM event_tags
    WHERE tag_type = 'a' AND tag_value = :address_coordinate
  );
```

#### 6. User Profile Lookup

```sql
-- Get latest profile for a user
SELECT * FROM events
WHERE kind = 0 AND pubkey = :user_pubkey
ORDER BY created_at DESC
LIMIT 1;
```

#### 7. Followers List

```sql
-- Get users who follow a specific pubkey
SELECT DISTINCT e.pubkey FROM events e
JOIN event_tags t ON e.id = t.event_id
WHERE e.kind = 3
  AND t.tag_type = 'p'
  AND t.tag_value = :target_pubkey;
```

#### 8. Following List

```sql
-- Get pubkeys that a user follows
SELECT t.tag_value as followed_pubkey
FROM events e
JOIN event_tags t ON e.id = t.event_id
WHERE e.kind = 3
  AND e.pubkey = :user_pubkey
  AND t.tag_type = 'p'
ORDER BY e.created_at DESC
LIMIT 1;  -- Only latest contact list
```

### Analytics Queries

#### Trending Videos (by engagement)

```sql
-- Get trending videos in last 24 hours
SELECT
  v.id,
  v.pubkey,
  v.created_at,
  COUNT(DISTINCT r.id) as like_count,
  COUNT(DISTINCT rp.id) as repost_count
FROM events v
LEFT JOIN event_tags vt ON v.id = vt.event_id AND vt.tag_type = 'e'
LEFT JOIN events r ON r.kind = 7 AND r.id IN (
  SELECT event_id FROM event_tags WHERE tag_type = 'e' AND tag_value = v.id
)
LEFT JOIN events rp ON rp.kind = 6 AND rp.id IN (
  SELECT event_id FROM event_tags WHERE tag_type = 'e' AND tag_value = v.id
)
WHERE v.kind IN (21, 22, 34235, 34236)
  AND v.created_at > :since_24h_ago
GROUP BY v.id, v.pubkey, v.created_at
ORDER BY (like_count + repost_count * 2) DESC
LIMIT 50;
```

#### Popular Hashtags

```sql
-- Get most used hashtags in recent videos
SELECT
  t.tag_value as hashtag,
  COUNT(*) as video_count
FROM event_tags t
JOIN events e ON t.event_id = e.id
WHERE t.tag_type = 't'
  AND e.kind IN (21, 22, 34235, 34236)
  AND e.created_at > :since_7d_ago
GROUP BY t.tag_value
ORDER BY video_count DESC
LIMIT 20;
```

---

## 5. ClickHouse Schema Design

### Core Tables

#### events (Primary Event Storage)

```sql
CREATE TABLE events (
    -- Core Nostr fields
    id FixedString(64),                    -- Event ID (64-char hex)
    pubkey FixedString(64),                -- Author pubkey (64-char hex)
    created_at UInt32,                     -- Unix timestamp
    kind UInt16,                           -- Event kind (0-65535)
    content String,                        -- Event content
    sig FixedString(128),                  -- Signature (128-char hex)

    -- Raw tags for reconstruction
    tags String,                           -- JSON array of tags

    -- Extracted fields for query optimization
    d_tag String DEFAULT '',               -- d-tag value for addressable events

    -- Relay metadata
    received_at DateTime64(3) DEFAULT now64(3),
    first_seen_relay LowCardinality(String) DEFAULT '',

    -- For ReplacingMergeTree deduplication
    _version UInt64 DEFAULT toUInt64(created_at) * 1000000 + rand() % 1000000

) ENGINE = ReplacingMergeTree(_version)
PARTITION BY toYYYYMM(toDateTime(created_at))
ORDER BY (kind, pubkey, created_at, id)
SETTINGS index_granularity = 8192;

-- Secondary index for id lookups
ALTER TABLE events ADD INDEX idx_id (id) TYPE bloom_filter() GRANULARITY 4;

-- Secondary index for d_tag lookups (addressable events)
ALTER TABLE events ADD INDEX idx_d_tag (d_tag) TYPE bloom_filter() GRANULARITY 4;
```

**Design Rationale:**
- `ORDER BY (kind, pubkey, created_at, id)`: Optimizes the most common query patterns (filter by kind, then by author, then by time)
- `ReplacingMergeTree`: Handles deduplication for replaceable events
- `FixedString(64)`: Optimal for hex IDs (no length prefix overhead)
- `PARTITION BY month`: Allows efficient pruning of old data and time-range queries
- Bloom filter indexes: Fast existence checks for `id` and `d_tag`

#### event_tags (Tag Index)

```sql
CREATE TABLE event_tags (
    event_id FixedString(64),
    event_pubkey FixedString(64),
    event_kind UInt16,
    event_created_at UInt32,

    tag_type LowCardinality(String),       -- 'e', 'p', 't', 'd', 'a', etc.
    tag_value String,                       -- The tag value
    tag_relay String DEFAULT '',            -- Optional relay hint
    tag_marker LowCardinality(String) DEFAULT '',  -- Optional marker (reply, root, etc.)
    tag_index UInt8                         -- Position in tags array

) ENGINE = MergeTree()
PARTITION BY toYYYYMM(toDateTime(event_created_at))
ORDER BY (tag_type, tag_value, event_created_at, event_id)
SETTINGS index_granularity = 8192;
```

**Design Rationale:**
- Separate table for efficient tag-based queries
- `ORDER BY (tag_type, tag_value, ...)`: Optimizes `#e`, `#p`, `#t` filter queries
- Denormalized `event_pubkey`, `event_kind`, `event_created_at` to avoid joins in simple queries
- `LowCardinality`: Efficient for low-cardinality columns like `tag_type`

#### profiles (Materialized View)

```sql
CREATE TABLE profiles (
    pubkey FixedString(64),
    created_at UInt32,

    -- Parsed profile fields
    name String DEFAULT '',
    display_name String DEFAULT '',
    about String DEFAULT '',
    picture String DEFAULT '',
    banner String DEFAULT '',
    nip05 String DEFAULT '',
    lud16 String DEFAULT '',
    website String DEFAULT '',

    -- Raw content for full profile data
    raw_content String,

    -- Deduplication
    _version UInt64 DEFAULT toUInt64(created_at) * 1000000 + rand() % 1000000

) ENGINE = ReplacingMergeTree(_version)
ORDER BY pubkey
SETTINGS index_granularity = 8192;

-- Materialized view to auto-populate from events
CREATE MATERIALIZED VIEW profiles_mv TO profiles AS
SELECT
    pubkey,
    created_at,
    JSONExtractString(content, 'name') as name,
    JSONExtractString(content, 'display_name') as display_name,
    JSONExtractString(content, 'about') as about,
    JSONExtractString(content, 'picture') as picture,
    JSONExtractString(content, 'banner') as banner,
    JSONExtractString(content, 'nip05') as nip05,
    JSONExtractString(content, 'lud16') as lud16,
    JSONExtractString(content, 'website') as website,
    content as raw_content,
    toUInt64(created_at) * 1000000 + rand() % 1000000 as _version
FROM events
WHERE kind = 0;
```

#### video_metrics (Engagement Aggregates)

```sql
CREATE TABLE video_metrics (
    video_id FixedString(64),              -- Event ID of the video
    video_pubkey FixedString(64),
    video_kind UInt16,
    video_created_at UInt32,

    -- Engagement counts
    like_count UInt64 DEFAULT 0,
    comment_count UInt64 DEFAULT 0,
    repost_count UInt64 DEFAULT 0,
    loop_count UInt64 DEFAULT 0,           -- From external analytics

    -- Computed score for ranking
    engagement_score Float64 DEFAULT 0,

    -- Freshness
    updated_at DateTime64(3) DEFAULT now64(3),
    _version UInt64 DEFAULT toUnixTimestamp64Milli(now64(3))

) ENGINE = ReplacingMergeTree(_version)
ORDER BY video_id
SETTINGS index_granularity = 8192;

-- Index for trending queries
ALTER TABLE video_metrics ADD INDEX idx_engagement (engagement_score) TYPE minmax GRANULARITY 4;
ALTER TABLE video_metrics ADD INDEX idx_created (video_created_at) TYPE minmax GRANULARITY 4;
```

#### follows (Contact List Cache)

```sql
CREATE TABLE follows (
    follower_pubkey FixedString(64),       -- The user who follows
    followed_pubkey FixedString(64),       -- The user being followed
    relay_hint String DEFAULT '',
    created_at UInt32,                     -- When this follow relationship was established
    _version UInt64 DEFAULT toUInt64(created_at) * 1000000 + rand() % 1000000

) ENGINE = ReplacingMergeTree(_version)
ORDER BY (follower_pubkey, followed_pubkey)
SETTINGS index_granularity = 8192;

-- Secondary index for reverse lookups (who follows X)
CREATE TABLE followers (
    followed_pubkey FixedString(64),
    follower_pubkey FixedString(64),
    created_at UInt32,
    _version UInt64
) ENGINE = ReplacingMergeTree(_version)
ORDER BY (followed_pubkey, follower_pubkey);
```

### Materialized Views for Real-Time Aggregates

#### Like Counts

```sql
CREATE MATERIALIZED VIEW like_counts_mv
ENGINE = SummingMergeTree()
ORDER BY (video_id)
AS SELECT
    tag_value as video_id,
    count() as like_count
FROM event_tags
WHERE tag_type IN ('e', 'a')
  AND event_kind = 7
GROUP BY tag_value;
```

#### Repost Counts

```sql
CREATE MATERIALIZED VIEW repost_counts_mv
ENGINE = SummingMergeTree()
ORDER BY (video_id)
AS SELECT
    tag_value as video_id,
    count() as repost_count
FROM event_tags
WHERE tag_type IN ('e', 'a')
  AND event_kind = 6
GROUP BY tag_value;
```

#### Comment Counts

```sql
CREATE MATERIALIZED VIEW comment_counts_mv
ENGINE = SummingMergeTree()
ORDER BY (video_id)
AS SELECT
    tag_value as video_id,
    count() as comment_count
FROM event_tags
WHERE tag_type = 'e'
  AND event_kind = 1
  AND tag_marker = 'root'
GROUP BY tag_value;
```

### Optimized Query Examples

#### Discovery Feed with Metrics

```sql
SELECT
    e.id,
    e.pubkey,
    e.created_at,
    e.kind,
    e.content,
    e.tags,
    p.name,
    p.display_name,
    p.picture,
    COALESCE(m.like_count, 0) as likes,
    COALESCE(m.repost_count, 0) as reposts,
    COALESCE(m.loop_count, 0) as loops
FROM events e
LEFT JOIN profiles p ON e.pubkey = p.pubkey
LEFT JOIN video_metrics m ON e.id = m.video_id
WHERE e.kind IN (21, 22, 34235, 34236)
ORDER BY e.created_at DESC
LIMIT 50;
```

#### Home Feed

```sql
WITH followed AS (
    SELECT followed_pubkey
    FROM follows
    WHERE follower_pubkey = :user_pubkey
)
SELECT
    e.id,
    e.pubkey,
    e.created_at,
    e.kind,
    e.content,
    e.tags
FROM events e
WHERE e.kind IN (21, 22, 34235, 34236)
  AND e.pubkey IN (SELECT followed_pubkey FROM followed)
  AND e.created_at < :cursor_until
ORDER BY e.created_at DESC
LIMIT 50;
```

#### Hashtag Search

```sql
SELECT
    e.id,
    e.pubkey,
    e.created_at,
    e.kind,
    e.content,
    e.tags
FROM events e
INNER JOIN event_tags t ON e.id = t.event_id
WHERE t.tag_type = 't'
  AND t.tag_value = lower(:hashtag)
  AND e.kind IN (21, 22, 34235, 34236)
ORDER BY e.created_at DESC
LIMIT 50;
```

#### Trending Videos

```sql
SELECT
    e.id,
    e.pubkey,
    e.created_at,
    m.like_count,
    m.repost_count,
    m.loop_count,
    m.engagement_score
FROM events e
INNER JOIN video_metrics m ON e.id = m.video_id
WHERE e.kind IN (21, 22, 34235, 34236)
  AND e.created_at > now() - INTERVAL 24 HOUR
ORDER BY m.engagement_score DESC
LIMIT 50;
```

---

## 6. Open Questions

### Architecture Questions

1. **Real-time vs Batch Updates**
   - Should engagement metrics be updated in real-time via materialized views, or batch-computed periodically?
   - Real-time: Lower latency, higher write amplification
   - Batch: Lower write load, stale counts possible

2. **Sharding Strategy**
   - Single node vs distributed cluster?
   - Shard by `pubkey` (co-locate user's events) or by time (easier pruning)?

3. **Replication**
   - What replication factor for durability?
   - Read replicas for query scaling?

4. **Data Retention**
   - How long to keep events? (Nostr events are meant to be permanent)
   - Tiered storage for old events?

### Schema Questions

5. **Tag Storage**
   - Separate `event_tags` table (proposed) vs Array columns in `events` table?
   - Array: Simpler inserts, harder queries
   - Separate: More storage, easier queries

6. **Addressable Event Deduplication**
   - `ReplacingMergeTree` handles deduplication at query time (FINAL)
   - Alternative: Application-level upsert logic before insert
   - Question: Performance impact of `FINAL` on read queries?

7. **Full-Text Search (NIP-50)**
   - ClickHouse has basic full-text support
   - Should we integrate with external search (Elasticsearch, Meilisearch)?

8. **JSON Content Parsing**
   - Parse kind 0 content (profiles) at insert time?
   - Parse video metadata (imeta tags) at insert time?
   - Trade-off: Insert complexity vs query complexity

### Operational Questions

9. **Write Path**
   - Batch inserts (higher throughput) vs single inserts (lower latency)?
   - Buffer size and flush interval?

10. **Compaction**
    - How often to run OPTIMIZE for ReplacingMergeTree deduplication?
    - Impact on query performance during compaction?

11. **Backup Strategy**
    - Full backups vs incremental?
    - Point-in-time recovery requirements?

12. **Monitoring**
    - Key metrics to track?
    - Alerting thresholds?

---

## 7. Alternative Approaches

### Alternative 1: Single Events Table with Array Columns

```sql
CREATE TABLE events_alt (
    id FixedString(64),
    pubkey FixedString(64),
    created_at UInt32,
    kind UInt16,
    content String,
    sig FixedString(128),

    -- Tags as arrays
    e_tags Array(FixedString(64)),         -- Event references
    p_tags Array(FixedString(64)),         -- Pubkey references
    t_tags Array(String),                   -- Hashtags
    d_tag String DEFAULT '',
    a_tags Array(String),                   -- Address references
    other_tags String                       -- JSON for remaining tags

) ENGINE = ReplacingMergeTree(created_at)
ORDER BY (kind, pubkey, created_at, id);

-- Array indexes
ALTER TABLE events_alt ADD INDEX idx_e_tags (e_tags) TYPE bloom_filter() GRANULARITY 4;
ALTER TABLE events_alt ADD INDEX idx_p_tags (p_tags) TYPE bloom_filter() GRANULARITY 4;
ALTER TABLE events_alt ADD INDEX idx_t_tags (t_tags) TYPE bloom_filter() GRANULARITY 4;
```

**Pros:**
- Simpler writes (single table)
- No joins needed for basic queries
- Tags always co-located with event

**Cons:**
- Array queries (`has()`, `hasAny()`) can be slower than indexed lookups
- Bloom filter indexes have false positives
- Harder to query specific tag positions or markers

### Alternative 2: Hybrid with Kafka

```
Events → Kafka → ClickHouse (batch inserts)
              → Redis (real-time cache)
              → Search Index (full-text)
```

**Pros:**
- Decoupled write and read paths
- Real-time cache for hot data
- Specialized systems for each query type

**Cons:**
- Much more operational complexity
- More failure points
- Higher infrastructure cost

### Alternative 3: PostgreSQL + TimescaleDB

Use PostgreSQL with TimescaleDB extension for time-series optimization.

**Pros:**
- More familiar SQL semantics
- ACID transactions
- Better JSON support (JSONB)

**Cons:**
- Lower write throughput than ClickHouse
- More expensive at scale
- Less efficient compression

---

## 8. Performance Considerations

### Expected Scale

| Metric | Estimate | Notes |
|--------|----------|-------|
| Events/day | 1-10 million | Depends on user growth |
| Total events | 100M - 1B | Long-term storage |
| Active users | 10K - 100K | Concurrent connections |
| Queries/second | 1K - 10K | Read-heavy workload |

### Bottleneck Analysis

1. **Writes**: ClickHouse excels here; batch inserts of 10K+ events are efficient
2. **Point lookups by ID**: Bloom filter index helps, but not as fast as KV store
3. **Author feed queries**: ORDER BY clause optimizes this
4. **Tag queries**: Separate table with proper ordering is efficient
5. **Aggregations**: Materialized views pre-compute expensive counts
6. **JOIN queries**: Can be slow; denormalization helps

### Optimization Strategies

1. **Prewhere Clause**: Use PREWHERE for highly selective filters
   ```sql
   SELECT * FROM events
   PREWHERE kind IN (21, 22, 34235, 34236)
   WHERE pubkey = :author
   ```

2. **Projection Tables**: Create projections for common query patterns
   ```sql
   ALTER TABLE events ADD PROJECTION videos_by_author (
       SELECT * ORDER BY pubkey, created_at, id
   );
   ```

3. **Query Cache**: Enable ClickHouse query cache for repeated queries
   ```sql
   SET use_query_cache = 1;
   ```

4. **Sampling**: For approximate trending queries on large datasets
   ```sql
   SELECT * FROM events SAMPLE 0.1
   WHERE kind IN (21, 22, 34235, 34236)
   ORDER BY created_at DESC
   ```

---

## 9. Implementation Roadmap

### Phase 1: Core Schema (Week 1-2)

- [ ] Set up ClickHouse cluster (single node initially)
- [ ] Create `events` table
- [ ] Create `event_tags` table
- [ ] Implement basic write path (insert events + tags)
- [ ] Implement basic Nostr filter queries

### Phase 2: Optimizations (Week 3-4)

- [ ] Create `profiles` materialized view
- [ ] Create engagement count materialized views
- [ ] Create `follows`/`followers` tables
- [ ] Add secondary indexes
- [ ] Benchmark query performance

### Phase 3: Advanced Features (Week 5-6)

- [ ] Implement NIP-50 search (or external search integration)
- [ ] Add real-time WebSocket relay layer
- [ ] Implement subscription management
- [ ] Add metrics/monitoring

### Phase 4: Scaling (Week 7+)

- [ ] Evaluate sharding requirements
- [ ] Set up replication
- [ ] Implement backup strategy
- [ ] Load testing at scale

---

## Appendix A: Sample Data

### Sample Video Event (Kind 34236)

```json
{
  "id": "a1b2c3d4e5f6789012345678901234567890123456789012345678901234abcd",
  "pubkey": "fedcba9876543210fedcba9876543210fedcba9876543210fedcba98765432ba",
  "created_at": 1699000000,
  "kind": 34236,
  "content": "Perfect loop of soup being stirred 🍜",
  "tags": [
    ["d", "video-2024-001"],
    ["title", "Satisfying Soup Stir"],
    ["imeta", "url https://cdn.divine.video/videos/abc123.mp4", "m video/mp4", "dim 480x480", "duration 6", "image https://cdn.divine.video/thumbs/abc123.jpg", "blurhash eNH_0EI"],
    ["published_at", "1699000000"],
    ["duration", "6"],
    ["alt", "A wooden spoon stirring a pot of tomato soup in a perfect circular motion"],
    ["t", "satisfying"],
    ["t", "soup"],
    ["t", "perfectloops"],
    ["t", "cooking"]
  ],
  "sig": "0123456789abcdef..."
}
```

### Sample Profile Event (Kind 0)

```json
{
  "id": "1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef",
  "pubkey": "fedcba9876543210fedcba9876543210fedcba9876543210fedcba98765432ba",
  "created_at": 1698900000,
  "kind": 0,
  "content": "{\"name\":\"soupmaster\",\"display_name\":\"Soup Master Chef\",\"about\":\"Making perfect loops since 2024\",\"picture\":\"https://cdn.example.com/avatar.jpg\",\"nip05\":\"soup@divine.video\",\"lud16\":\"soup@getalby.com\"}",
  "tags": [],
  "sig": "abcdef0123456789..."
}
```

### Sample Reaction Event (Kind 7)

```json
{
  "id": "reaction123...",
  "pubkey": "reactor-pubkey...",
  "created_at": 1699001000,
  "kind": 7,
  "content": "+",
  "tags": [
    ["e", "a1b2c3d4e5f6789012345678901234567890123456789012345678901234abcd", "wss://relay.divine.video"],
    ["p", "fedcba9876543210fedcba9876543210fedcba9876543210fedcba98765432ba"]
  ],
  "sig": "..."
}
```

### Sample Repost Event (Kind 6)

```json
{
  "id": "repost456...",
  "pubkey": "reposter-pubkey...",
  "created_at": 1699002000,
  "kind": 6,
  "content": "",
  "tags": [
    ["e", "a1b2c3d4e5f6789012345678901234567890123456789012345678901234abcd", "wss://relay.divine.video"],
    ["p", "fedcba9876543210fedcba9876543210fedcba9876543210fedcba98765432ba"]
  ],
  "sig": "..."
}
```

### Sample Contact List Event (Kind 3)

```json
{
  "id": "contacts789...",
  "pubkey": "user-pubkey...",
  "created_at": 1698800000,
  "kind": 3,
  "content": "",
  "tags": [
    ["p", "followed-1...", "wss://relay1.com"],
    ["p", "followed-2...", "wss://relay2.com"],
    ["p", "followed-3..."]
  ],
  "sig": "..."
}
```

---

## Appendix B: ClickHouse Configuration

### Recommended Server Settings

```xml
<clickhouse>
    <profiles>
        <default>
            <!-- Memory limits -->
            <max_memory_usage>10000000000</max_memory_usage>
            <max_memory_usage_for_user>20000000000</max_memory_usage_for_user>

            <!-- Query limits -->
            <max_execution_time>30</max_execution_time>
            <max_rows_to_read>1000000000</max_rows_to_read>

            <!-- JOIN settings -->
            <join_use_nulls>1</join_use_nulls>
            <max_bytes_in_join>1000000000</max_bytes_in_join>

            <!-- Aggregation settings -->
            <group_by_two_level_threshold>100000</group_by_two_level_threshold>
            <group_by_two_level_threshold_bytes>50000000</group_by_two_level_threshold_bytes>
        </default>
    </profiles>

    <merge_tree>
        <!-- Background merges -->
        <max_bytes_to_merge_at_max_space_in_pool>161061273600</max_bytes_to_merge_at_max_space_in_pool>
        <max_bytes_to_merge_at_min_space_in_pool>1048576</max_bytes_to_merge_at_min_space_in_pool>

        <!-- Parts settings -->
        <parts_to_delay_insert>150</parts_to_delay_insert>
        <parts_to_throw_insert>300</parts_to_throw_insert>
        <max_parts_in_total>100000</max_parts_in_total>
    </merge_tree>
</clickhouse>
```

### Table-Level Settings

```sql
-- For events table
ALTER TABLE events MODIFY SETTING
    index_granularity = 8192,
    min_bytes_for_wide_part = 10485760,
    min_rows_for_wide_part = 0,
    compress_block_size = 65536;

-- For event_tags table (more granular for better filter performance)
ALTER TABLE event_tags MODIFY SETTING
    index_granularity = 4096;
```

---

## Appendix C: Relay Protocol Integration

### NIP-01 REQ Message Handling

```python
# Pseudocode for converting Nostr filter to ClickHouse query

def filter_to_query(filter: dict) -> str:
    conditions = []

    if 'ids' in filter:
        ids = ', '.join(f"'{id}'" for id in filter['ids'])
        conditions.append(f"id IN ({ids})")

    if 'authors' in filter:
        authors = ', '.join(f"'{a}'" for a in filter['authors'])
        conditions.append(f"pubkey IN ({authors})")

    if 'kinds' in filter:
        kinds = ', '.join(str(k) for k in filter['kinds'])
        conditions.append(f"kind IN ({kinds})")

    if 'since' in filter:
        conditions.append(f"created_at >= {filter['since']}")

    if 'until' in filter:
        conditions.append(f"created_at <= {filter['until']}")

    # Tag filters require JOIN with event_tags
    tag_filters = {k: v for k, v in filter.items() if k.startswith('#')}
    if tag_filters:
        for tag_type, values in tag_filters.items():
            tag = tag_type[1:]  # Remove '#' prefix
            values_str = ', '.join(f"'{v}'" for v in values)
            conditions.append(
                f"id IN (SELECT event_id FROM event_tags "
                f"WHERE tag_type = '{tag}' AND tag_value IN ({values_str}))"
            )

    where_clause = ' AND '.join(conditions) if conditions else '1=1'
    limit = filter.get('limit', 100)

    return f"""
        SELECT id, pubkey, created_at, kind, content, tags, sig
        FROM events
        WHERE {where_clause}
        ORDER BY created_at DESC
        LIMIT {limit}
    """
```

### Subscription Management

For real-time subscriptions, the relay needs to:

1. Execute initial query against ClickHouse
2. Return matching events as EVENT messages
3. Send EOSE (End of Stored Events)
4. Monitor new inserts and push matching events

Options for monitoring new events:
- **Polling**: Periodically query for events > last_seen_timestamp
- **Kafka**: Insert to Kafka topic, relay consumes and filters
- **ClickHouse Live View**: Use LIVE VIEW for reactive queries (experimental)

---

## Document Metadata

- **Created**: 2024-11-24
- **Author**: Claude (AI Assistant) with Rabble
- **Status**: Draft for Review
- **Version**: 1.0

### Review Checklist

For reviewers, please consider:

- [ ] Is the schema normalized appropriately for the query patterns?
- [ ] Are the ClickHouse engine choices optimal?
- [ ] Are there missing indexes or projections?
- [ ] Is the partitioning strategy appropriate?
- [ ] Are the materialized views correctly designed?
- [ ] What are the failure modes and how to handle them?
- [ ] What's missing from the operational considerations?
- [ ] Are there security considerations not addressed?
