# FunnelCake API Reference

REST API for Divine video platform analytics and user data, built on Nostr protocol.

**Base URL:** `https://relay.dvines.org` (production) or `http://localhost:8080` (local dev)

---

## Nostr Protocol Context

FunnelCake is the REST API layer for a Nostr-based video platform. Understanding these Nostr concepts is essential:

### Identifiers
- **pubkey**: 64-character hex string representing a user's public key (e.g., `9989500413fb756d8437912cc32be0730dbe1bfc6b5d2eef759e1456c239f905`)
- **event ID**: 64-character hex string uniquely identifying a Nostr event (e.g., `a1b2c3d4...`)
- **d_tag**: Identifier for addressable/replaceable events, allowing updates to the same logical content

### Event Kinds (relevant to this API)
| Kind | Name | Description |
|------|------|-------------|
| 0 | Metadata | User profile (name, picture, bio) |
| 1 | Short Text Note | Text posts, replies |
| 3 | Contact List | Who a user follows (p-tags list pubkeys) |
| 6 | Repost | Resharing another event |
| 7 | Reaction | Like/emoji reaction to content |
| 9735 | Zap Receipt | Lightning payment confirmation |
| 30005 | Curation Set | List of curated content (videos, articles) |
| 34235 | Horizontal Video | Landscape video event (NIP-71) |
| 34236 | Short Vertical Video | Portrait/short-form video (NIP-71, like TikTok/Vine) |

### Video Event Structure (Kind 34235/34236)
Videos are Nostr events with specific tags:
```json
{
  "id": "abc123...",
  "pubkey": "def456...",
  "created_at": 1704067200,
  "kind": 34236,
  "tags": [
    ["d", "my-video-slug"],
    ["title", "My Cool Video"],
    ["thumb", "https://cdn.example.com/thumb.jpg"],
    ["url", "https://cdn.example.com/video.mp4"],
    ["t", "nostr"],
    ["t", "comedy"]
  ],
  "content": "Video description here",
  "sig": "signature..."
}
```

### Engagement Events
- **Reactions (kind 7)**: Reference video via `e` tag
- **Replies (kind 1)**: Reference video via `e` tag with `root` marker
- **Reposts (kind 6)**: Contain the original event in content
- **Zaps (kind 9735)**: Lightning payments with `e` tag reference

---

## Architecture Overview

```
┌─────────────────┐     ┌─────────────────┐
│  Mobile/Web App │     │  Other Clients  │
└────────┬────────┘     └────────┬────────┘
         │                       │
         ▼                       ▼
┌─────────────────────────────────────────┐
│         relay.dvines.org:443            │
│              (Reverse Proxy)            │
├─────────────────┬───────────────────────┤
│   WebSocket     │        REST API       │
│   (Nostr Relay) │      (FunnelCake)     │
│                 │                       │
│ - Publish events│ - Query analytics     │
│ - Subscribe     │ - User profiles       │
│ - Real-time     │ - Video stats         │
└────────┬────────┴───────────┬───────────┘
         │                    │
         └─────────┬──────────┘
                   ▼
          ┌─────────────────┐
          │   ClickHouse    │
          │   (Storage)     │
          └─────────────────┘
```

**When to use WebSocket vs REST:**
- **WebSocket (wss://relay.dvines.org)**: Publishing events, real-time subscriptions, live feeds
- **REST API**: Analytics, aggregated stats, bulk queries, user data, search

---

## Authentication

### Bearer Token (Optional)

Most endpoints are public. Optional bearer token authentication can be enabled via `API_TOKEN` environment variable.

```
Authorization: Bearer <token>
```

### NIP-98 Authentication (Required for Private Data)

Some endpoints require NIP-98 HTTP authentication. These endpoints verify that the request is signed by the pubkey being accessed.

**NIP-98 Authenticated Endpoints:**
| Endpoint | Requirement |
|----------|-------------|
| `GET /api/users/{pubkey}/notifications` | Must be authenticated as `{pubkey}` |
| `POST /api/users/{pubkey}/notifications/read` | Must be authenticated as `{pubkey}` |
| `GET /api/users/{pubkey}/analytics` | Must be authenticated as `{pubkey}` |

**NIP-98 Auth Header Format:**
```
Authorization: Nostr <base64-encoded-signed-event>
```

The signed event must be kind 27235 with:
- `u` tag: The full URL being requested
- `method` tag: HTTP method (GET, POST)
- `created_at`: Within 60 seconds of current time

**Note:** These endpoints are conditionally deployed. If NIP-98 is not configured on the relay, these endpoints will return 404.

---

## Common Patterns

### Pagination
Cursor-based pagination using Unix timestamps:

```
# First page
GET /api/users/{pubkey}/feed?limit=20

# Response includes next_cursor
{
  "videos": [...],
  "next_cursor": "1704067200",
  "has_more": true
}

# Next page
GET /api/users/{pubkey}/feed?limit=20&before=1704067200
```

### Bulk Requests
For efficiency, use bulk endpoints instead of multiple single requests:

```json
// Instead of 10 separate GET /api/users/{pubkey} calls:
POST /api/users/bulk
{
  "pubkeys": ["pubkey1", "pubkey2", "pubkey3", ...]
}
```

### Resolving Related Data
Bulk endpoints can resolve data from Nostr events:

```json
// Get all users from someone's contact list (kind 3)
POST /api/users/bulk
{
  "from_event": {
    "pubkey": "user_pubkey_here",
    "kind": 3
  }
}

// Get all videos from a curation list (kind 30005)
POST /api/videos/bulk
{
  "from_event": {
    "pubkey": "curator_pubkey",
    "kind": 30005,
    "d_tag": "favorites"
  }
}
```

---

## Caching

All successful responses include `Cache-Control` headers:
- Public data: `public, max-age=30-300` (varies by endpoint)
- Private data (notifications): `private, max-age=30`
- Errors: `no-store`

---

## Health & Monitoring Endpoints

> **Note:** These endpoints are intended for internal infrastructure monitoring and may not be publicly exposed via the reverse proxy in production.

### GET /health
Basic health check.

**Response:** `200 OK`
```json
{ "status": "ok" }
```

### GET /livez
Kubernetes liveness probe. Returns 200 if process is alive.

**Response:** `200 OK` - `"OK"`

### GET /readyz
Kubernetes readiness probe. Returns 503 during shutdown or if ClickHouse is unavailable.

**Response:** `200 OK` - `"OK"` or `503 Service Unavailable`

### GET /metrics
Prometheus metrics endpoint for monitoring.

---

## Video Endpoints

### GET /api/videos
List videos with optional filtering and sorting.

**Query Parameters:**
| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `sort` | string | `recent` | Sort order: `recent`, `trending`, `popular`, or `loops` |
| `kind` | u16 | - | Filter by event kind: `34235` (horizontal) or `34236` (vertical/short) |
| `limit` | u32 | 50 | Max results (1-100) |
| `tag` | string | - | Filter by hashtag (without #) |
| `before` | i64 | - | Videos created before this Unix timestamp |
| `after` | i64 | - | Videos created after this Unix timestamp |
| `platform` | string | - | Filter by platform (e.g., `vine` for imported Vines) |
| `has_embedded_stats` | bool | - | Only videos with embedded loop counts |
| `classic` | bool | - | Shortcut: older videos sorted by loops |

**Example Requests:**
```bash
# Recent vertical videos
GET /api/videos?kind=34236&sort=recent&limit=20

# Trending videos with #nostr hashtag
GET /api/videos?tag=nostr&sort=trending

# Classic Vines sorted by loop count
GET /api/videos?classic=true&platform=vine&limit=50

# Videos from last 24 hours
GET /api/videos?after=1704067200
```

**Response:** `200 OK`
```json
[
  {
    "id": "a1b2c3d4e5f6...",
    "pubkey": "9989500413fb756d8437912cc32be0730dbe1bfc6b5d2eef759e1456c239f905",
    "created_at": 1704067200,
    "kind": 34236,
    "d_tag": "my-funny-video",
    "title": "When the code finally compiles",
    "thumbnail": "https://cdn.example.com/thumb.jpg",
    "video_url": "https://cdn.example.com/video.mp4",
    "reactions": 142,
    "comments": 23,
    "reposts": 7,
    "engagement_score": 172.0,
    "trending_score": 85.5
  }
]
```

### GET /api/videos/{id}/stats
Get statistics for a specific video.

**Path Parameters:**
- `id` - Nostr event ID (64 character hex)

**Response:** `200 OK`
```json
{
  "id": "a1b2c3d4e5f6...",
  "pubkey": "9989500413fb756d8437912cc32be0730dbe1bfc6b5d2eef759e1456c239f905",
  "created_at": 1704067200,
  "kind": 34236,
  "d_tag": "my-funny-video",
  "title": "When the code finally compiles",
  "thumbnail": "https://cdn.example.com/thumb.jpg",
  "video_url": "https://cdn.example.com/video.mp4",
  "reactions": 142,
  "comments": 23,
  "reposts": 7,
  "engagement_score": 172.0
}
```

**Errors:**
- `404` - Video not found

### GET /api/videos/{id}/views
Get view analytics for a specific video (requires view tracking events).

**Path Parameters:**
- `id` - Nostr event ID (64 character hex)

**Response:** `200 OK`
```json
{
  "views": 1234,
  "unique_viewers": 567,
  "total_watch_time": 45678,
  "avg_completion": 0.75
}
```

**Note:** Returns zeros if no view data exists (view tracking is optional).

### POST /api/videos/bulk
Get multiple videos in a single request. Max 100 videos.

**Request Body:**
```json
{
  "event_ids": ["a1b2c3...", "d4e5f6..."]
}
```

Or resolve from a curation list:
```json
{
  "from_event": {
    "pubkey": "curator_pubkey_here",
    "kind": 30005,
    "d_tag": "my-favorites"
  }
}
```

**Response:** `200 OK`
```json
{
  "videos": [
    { "id": "a1b2c3...", ... },
    { "id": "d4e5f6...", ... }
  ],
  "missing": ["x7y8z9..."],
  "source_event_id": "curator_pubkey_here"
}
```

### GET /api/videos/events
List videos with full raw Nostr events and computed stats. This is the preferred endpoint for clients that need to verify event signatures.

**Query Parameters:**
| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `sort` | string | `recent` | Sort order: `recent` or `trending` |
| `kind` | u16 | - | Filter by event kind: `34235` (horizontal) or `34236` (vertical) |
| `limit` | u32 | 50 | Max results (1-100) |
| `before` | i64 | - | Videos created before this Unix timestamp (for pagination) |

**Response:** `200 OK`
```json
{
  "videos": [
    {
      "event": {
        "id": "a1b2c3d4...",
        "pubkey": "9989500413fb...",
        "created_at": 1704067200,
        "kind": 34236,
        "tags": [
          ["d", "my-video"],
          ["title", "My Video Title"],
          ["thumb", "https://cdn.example.com/thumb.jpg"],
          ["url", "https://cdn.example.com/video.mp4"]
        ],
        "content": "Video description",
        "sig": "signature..."
      },
      "stats": {
        "reactions": 142,
        "comments": 23,
        "reposts": 7,
        "engagement_score": 172,
        "trending_score": 85.5,
        "embedded_loops": 50000,
        "computed_loops": 1234.5
      }
    }
  ],
  "next_cursor": "1704067200",
  "has_more": true
}
```

### POST /api/videos/stats/bulk
Get engagement stats for multiple videos in a single request. Max 100 videos.

**Request Body:**
```json
{
  "event_ids": ["a1b2c3...", "d4e5f6..."]
}
```

**Response:** `200 OK`
```json
{
  "stats": {
    "a1b2c3...": {
      "reactions": 142,
      "comments": 23,
      "reposts": 7,
      "engagement_score": 172,
      "embedded_loops": 50000
    },
    "d4e5f6...": {
      "reactions": 50,
      "comments": 10,
      "reposts": 2,
      "engagement_score": 62
    }
  },
  "missing": ["x7y8z9..."]
}
```

**Errors:**
- `400` - Empty event_ids or more than 100 IDs

### GET /api/videos/categories
> **Note:** This endpoint is not yet available - the required database views have not been deployed.

Get video categories with counts, or videos by category.

**Query Parameters:**
| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `category` | string | - | Optional: filter to get videos in this category |
| `limit` | u32 | 50 | Max results when filtering by category (1-100) |

**Response (no category param):** `200 OK`
```json
{
  "categories": [
    { "category": "kpop", "video_count": 5000 },
    { "category": "comedy", "video_count": 3200 },
    { "category": "sports", "video_count": 1500 }
  ],
  "total_videos": 27000
}
```

**Response (with category param):** `200 OK`
```json
{
  "category": "kpop",
  "videos": [
    { "id": "...", "pubkey": "...", "title": "...", ... }
  ],
  "count": 50
}
```

### GET /api/videos/{id}/live-views
Server-Sent Events (SSE) stream of real-time view count updates. Emits events every 2-3 seconds.

**Path Parameters:**
- `id` - Nostr event ID (64 character hex)

**Response:** `200 OK` (Content-Type: text/event-stream)
```
event: view_update
data: {"views": 1234, "loops": 567.5, "viewers_now": 12}

event: view_update
data: {"views": 1236, "loops": 568.0, "viewers_now": 14}
```

**Event Fields:**
| Field | Description |
|-------|-------------|
| `views` | Total view count |
| `loops` | Total computed loops (fractional) |
| `viewers_now` | Current active viewers (5-minute TTL) |

---

## User Endpoints

### GET /api/users/{pubkey}
Get comprehensive user data including profile, social stats, content stats, and engagement metrics.

**Path Parameters:**
- `pubkey` - Nostr public key (64 character hex)

**Response:** `200 OK`
```json
{
  "pubkey": "9989500413fb756d8437912cc32be0730dbe1bfc6b5d2eef759e1456c239f905",
  "profile": {
    "name": "alice",
    "display_name": "Alice",
    "about": "Video creator and Nostr enthusiast",
    "picture": "https://cdn.example.com/alice.jpg",
    "banner": "https://cdn.example.com/alice-banner.jpg",
    "nip05": "alice@example.com",
    "lud16": "alice@getalby.com"
  },
  "social": {
    "follower_count": 1234,
    "following_count": 567
  },
  "stats": {
    "video_count": 42,
    "total_reactions": 5000,
    "total_comments": 200,
    "total_reposts": 50
  },
  "engagement": {
    "total_views": 100000,
    "total_watch_time": 500000,
    "avg_completion_rate": 0.72
  }
}
```

**Note:** Missing data returns defaults (nulls for profile, zeros for stats). The endpoint always returns 200.

### GET /api/users/{pubkey}/videos
Get videos created by a specific user.

**Path Parameters:**
- `pubkey` - Nostr public key (64 character hex)

**Query Parameters:**
| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `limit` | u32 | 50 | Max results (1-100) |

**Response:** `200 OK` - Array of video stats (same format as `/api/videos`)

### GET /api/users/{pubkey}/followers
Get paginated list of pubkeys that follow this user.

**Path Parameters:**
- `pubkey` - Nostr public key (64 character hex)

**Query Parameters:**
| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `limit` | u32 | 50 | Max results (1-100) |
| `offset` | u32 | 0 | Pagination offset |

**Response:** `200 OK`
```json
{
  "followers": [
    "pubkey1...",
    "pubkey2...",
    "pubkey3..."
  ],
  "total": 1234
}
```

### GET /api/users/{pubkey}/following
Get list of pubkeys this user follows (from their kind 3 contact list).

**Path Parameters:**
- `pubkey` - Nostr public key (64 character hex)

**Response:** `200 OK`
```json
{
  "following": [
    "pubkey1...",
    "pubkey2...",
    "pubkey3..."
  ],
  "count": 567
}
```

### GET /api/users/{pubkey}/social
Get social statistics only (lighter than full user endpoint).

**Path Parameters:**
- `pubkey` - Nostr public key (64 character hex)

**Response:** `200 OK`
```json
{
  "follower_count": 1234,
  "following_count": 567
}
```

**Errors:**
- `404` - User not found (no social connections exist)

### GET /api/users/{pubkey}/feed
Get personalized video feed from accounts this user follows.

**Path Parameters:**
- `pubkey` - Nostr public key (64 character hex)

**Query Parameters:**
| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `sort` | string | `recent` | Sort order: `recent` or `trending` |
| `limit` | u32 | 50 | Max results (1-1000) |
| `before` | i64 | - | Pagination cursor (Unix timestamp) |

**Response:** `200 OK`
```json
{
  "videos": [
    { "id": "...", "pubkey": "...", ... }
  ],
  "next_cursor": "1704067200",
  "has_more": true
}
```

**Errors:**
- `404` - User not found (no contact list)

### GET /api/users/{pubkey}/analytics
Get comprehensive analytics for a creator. **Requires NIP-98 authentication.**

**Path Parameters:**
- `pubkey` - Nostr public key (64 character hex)

**Query Parameters:**
| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `period` | string | `30d` | Time period: `7d`, `30d`, `90d`, or `all` |

**Response:** `200 OK`
```json
{
  "total_views": 50000,
  "total_loops": 12500.5,
  "total_watch_time": 180000,
  "unique_viewers": 8500,
  "videos": [
    {
      "id": "abc123...",
      "title": "My Top Video",
      "views": 10000,
      "loops": 2500.0,
      "watch_time": 45000,
      "unique_viewers": 3000
    }
  ],
  "daily_stats": [
    {
      "date": "2024-01-15",
      "views": 1200,
      "loops": 300.0,
      "unique_viewers": 400
    }
  ],
  "period": "30d"
}
```

**Errors:**
- `401` - Missing or invalid NIP-98 auth header
- `403` - Authenticated user doesn't match requested pubkey

### GET /api/users/{pubkey}/notifications
Get notifications for interactions with user's content. **Requires NIP-98 authentication.**

**Path Parameters:**
- `pubkey` - Nostr public key (64 character hex)

**Query Parameters:**
| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `types` | string | - | Filter by types (comma-separated): `reaction`, `reply`, `repost`, `mention`, `follow`, `zap` |
| `unread_only` | bool | false | Only show unread notifications |
| `limit` | u32 | 50 | Max results (1-100) |
| `before` | i64 | - | Pagination cursor (Unix timestamp) |

**Example Requests:**
```bash
# All notifications
GET /api/users/{pubkey}/notifications

# Only reactions and zaps
GET /api/users/{pubkey}/notifications?types=reaction,zap

# Unread only
GET /api/users/{pubkey}/notifications?unread_only=true
```

**Response:** `200 OK`
```json
{
  "notifications": [
    {
      "source_pubkey": "abc123...",
      "source_event_id": "def456...",
      "source_kind": 7,
      "source_created_at": 1704067200,
      "referenced_event_id": "ghi789...",
      "notification_type": "reaction",
      "created_at": 1704067200,
      "read": false
    }
  ],
  "unread_count": 15,
  "next_cursor": "1704067200",
  "has_more": true
}
```

**Notification Types:**
| Type | Source Kind | Description |
|------|-------------|-------------|
| `reaction` | 7 | Someone liked/reacted to your content |
| `reply` | 1 | Someone replied to your video |
| `repost` | 6 | Someone reposted your content |
| `mention` | * | Someone mentioned you via p-tag |
| `follow` | 3 | Someone added you to their contact list |
| `zap` | 9735 | Someone sent you a Lightning payment |

**Errors:**
- `401` - Missing or invalid NIP-98 auth header
- `403` - Authenticated user doesn't match requested pubkey

### POST /api/users/{pubkey}/notifications/read
Mark notifications as read. **Requires NIP-98 authentication.**

**Path Parameters:**
- `pubkey` - Nostr public key (64 character hex)

**Request Body:**
```json
{
  "notification_ids": ["id1...", "id2..."]
}
```

If `notification_ids` is empty, all notifications will be marked as read.

**Response:** `200 OK`
```json
{
  "marked_count": 5,
  "marked_all": false
}
```

**Errors:**
- `401` - Missing or invalid NIP-98 auth header
- `403` - Authenticated user doesn't match requested pubkey

### POST /api/users/bulk
Get multiple users in a single request. Max 100 users.

**Request Body:**
```json
{
  "pubkeys": ["pubkey1...", "pubkey2..."]
}
```

Or resolve from a contact list:
```json
{
  "from_event": {
    "pubkey": "user_pubkey_here",
    "kind": 3
  }
}
```

**Response:** `200 OK`
```json
{
  "users": [
    { "pubkey": "...", "profile": {...}, "social": {...}, ... }
  ],
  "missing": ["pubkey_not_found..."],
  "source_event_id": "user_pubkey_here"
}
```

---

## Search Endpoints

### GET /api/search
Search videos by hashtag or full-text query.

**Query Parameters:**
| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `tag` | string | - | Search by hashtag (without #) |
| `q` | string | - | Full-text search query |
| `limit` | u32 | 50 | Max results (1-100) |

**Note:** Either `tag` or `q` must be provided, not both.

**Example Requests:**
```bash
# Search by hashtag
GET /api/search?tag=nostr&limit=20

# Full-text search
GET /api/search?q=bitcoin+lightning&limit=20
```

**Response:** `200 OK` - Array of video stats

**Errors:**
- `400` - Missing search parameter (`tag` or `q` required)

---

## Hashtag Endpoints

### GET /api/hashtags
Get popular hashtags ranked by total video count.

**Query Parameters:**
| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `limit` | u32 | 50 | Max results (1-100) |

**Response:** `200 OK`
```json
[
  { "tag": "nostr", "count": 1234 },
  { "tag": "bitcoin", "count": 987 },
  { "tag": "comedy", "count": 654 }
]
```

### GET /api/hashtags/trending
Get trending hashtags weighted by recent activity.

**Query Parameters:**
| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `limit` | u32 | 50 | Max results (1-100) |

**Response:** `200 OK`
```json
[
  {
    "tag": "nostr",
    "count_24h": 50,
    "count_7d": 200,
    "total_count": 1234,
    "trending_score": 85.5
  }
]
```

**Trending Score Calculation:** Weighted combination of 24h activity (highest weight), 7d activity, and total count.

---

## Stats Endpoints

### GET /api/stats
Get platform-wide statistics.

**Response:** `200 OK`
```json
{
  "total_events": 1000000,
  "total_videos": 50000
}
```

---

## Error Handling

All error responses follow this format:

```json
{
  "error": "Error message description"
}
```

| Status | Description | Common Causes |
|--------|-------------|---------------|
| `400` | Bad Request | Missing required parameters, invalid values |
| `404` | Not Found | Video/user doesn't exist |
| `500` | Internal Server Error | Database issues, unexpected errors |
| `503` | Service Unavailable | Shutdown in progress, ClickHouse down |

**Handling Tips:**
- Always check for `error` field in response
- 404 for users may just mean they haven't posted yet
- 500 errors are retriable after a delay
- 503 during shutdown will resolve when new instance is ready

---

## Integration Examples

### Building a Video Feed Screen

```python
# 1. Get user's personalized feed
feed = GET /api/users/{my_pubkey}/feed?limit=20

# 2. Display videos, handle pagination
while feed.has_more:
    # User scrolls to bottom
    feed = GET /api/users/{my_pubkey}/feed?limit=20&before={feed.next_cursor}
```

### Building a Profile Screen

```python
# 1. Get user data (profile + stats in one call)
user = GET /api/users/{pubkey}

# 2. Get their videos
videos = GET /api/users/{pubkey}/videos?limit=20

# 3. Check if current user follows them
my_following = GET /api/users/{my_pubkey}/following
is_following = pubkey in my_following.following
```

### Building a Notifications Screen

```python
# 1. Get notifications with unread count
notifs = GET /api/users/{my_pubkey}/notifications?limit=50

# 2. Display unread_count as badge
badge_count = notifs.unread_count

# 3. Load more on scroll
if notifs.has_more:
    more = GET /api/users/{my_pubkey}/notifications?before={notifs.next_cursor}
```

### Efficient Bulk Loading

```python
# Bad: N+1 queries
for video in videos:
    author = GET /api/users/{video.pubkey}  # Slow!

# Good: Single bulk query
pubkeys = [v.pubkey for v in videos]
authors = POST /api/users/bulk { "pubkeys": pubkeys }
```

---

## OpenAPI Documentation

Interactive API documentation available at:
- **Swagger UI:** `https://relay.dvines.org/swagger-ui/`
- **OpenAPI JSON:** `https://relay.dvines.org/openapi.json`

---

## Related Systems

### WebSocket Relay (Same Host)
The REST API runs alongside a Nostr WebSocket relay on the same domain:
- **WebSocket:** `wss://relay.dvines.org` - For publishing events and real-time subscriptions
- **REST:** `https://relay.dvines.org/api/*` - For queries and analytics

### Publishing Content
To publish videos or other events, use the WebSocket relay with standard Nostr protocol:
```json
["EVENT", {
  "id": "...",
  "pubkey": "...",
  "created_at": 1704067200,
  "kind": 34236,
  "tags": [...],
  "content": "...",
  "sig": "..."
}]
```

The REST API will reflect new content after ClickHouse ingestion (typically < 1 second).
