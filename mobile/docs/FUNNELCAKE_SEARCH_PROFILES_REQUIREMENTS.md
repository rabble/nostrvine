# Funnelcake Search Profiles API Enhancement

**Endpoint:** `GET /api/search/profiles`
**Priority:** High - client code is already shipped and waiting for these features
**Mobile PR:** (pending commit)

---

## Background

User search currently returns results sorted by text relevance only. Searching for common names like "Thomas" returns 50 results with no way to distinguish active creators from inactive accounts with zero content. The mobile client has already been updated to send these new parameters and render the new response fields - once the backend adds support, everything lights up automatically.

The server already computes all the underlying data needed:
- `GET /api/users/{pubkey}` returns `follower_count`, `following_count`, `video_count`
- `GET /api/leaderboard/creators` ranks by views
- Kind 3 (contact lists) and Kind 34236 (videos) are already indexed

This is about exposing that existing data through the search endpoint.

---

## Current State

### What exists today

```
GET /api/search/profiles?q=thomas&limit=50&offset=0
```

**Supported params:** `q`, `limit` (1-100, default 50), `offset`

**Response fields per result:**
```json
{
  "pubkey": "abcdef1234...",
  "name": "thomas",
  "display_name": "Thomas",
  "nip05": "thomas@example.com",
  "about": "Bio text"
}
```

---

## Required Changes

### 1. New Query Parameters

#### `sort_by` (optional, string)

Controls result ordering. When omitted, current behavior (text relevance) is preserved.

| Value | Behavior |
|-------|----------|
| `followers` | Sort by follower count descending (most followed first) |
| `relevance` | Explicit text relevance sort (current default behavior) |

**Client sends:** `sort_by=followers`

**Example:**
```
GET /api/search/profiles?q=thomas&limit=50&sort_by=followers
```

**Implementation notes:**
- Follower count is already computed from Kind 3 contact list events
- When `sort_by=followers`, results matching the query should be ordered by `follower_count DESC`
- Ties can be broken by text relevance or `created_at DESC`
- When `sort_by` is omitted or `sort_by=relevance`, keep current behavior

#### `has_videos` (optional, boolean string)

Filters results to only users who have published at least one video event (Kind 34235 or 34236).

| Value | Behavior |
|-------|----------|
| `true` | Only return users with `video_count > 0` |
| omitted/`false` | Return all matching users (current behavior) |

**Client sends:** `has_videos=true`

**Example:**
```
GET /api/search/profiles?q=thomas&limit=50&has_videos=true&sort_by=followers
```

**Implementation notes:**
- Video count per user is already tracked (visible in `GET /api/users/{pubkey}` response)
- This is a WHERE clause filter, applied before pagination
- When `has_videos` is omitted or `false`, keep current behavior (no filter)

---

### 2. New Response Fields

Add these fields to each result object in the response array. The server already computes these values for the per-user endpoint.

#### `follower_count` (integer)

Number of unique pubkeys that have this user in their Kind 3 contact list.

```json
{
  "pubkey": "abcdef1234...",
  "name": "thomas",
  "display_name": "Thomas",
  "follower_count": 1523
}
```

**Client parsing:** Reads as `int`, falls back to parsing `String` → `int`

#### `video_count` (integer)

Total number of video events (Kind 34235 + 34236) published by this user.

```json
{
  "pubkey": "abcdef1234...",
  "name": "thomas",
  "display_name": "Thomas",
  "video_count": 42
}
```

**Client parsing:** Same as `follower_count` - reads as `int`, falls back to `String` → `int`

#### `picture` (string, nullable)

Profile avatar URL from the user's Kind 0 metadata event. This may already be returned but is not documented.

#### `banner` (string, nullable)

Profile banner URL from the user's Kind 0 metadata event.

---

### 3. Complete Request/Response Example

#### Request
```
GET /api/search/profiles?q=thomas&limit=50&offset=0&sort_by=followers&has_videos=true
```

#### Response
```json
[
  {
    "pubkey": "1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef",
    "name": "thomas",
    "display_name": "Thomas the Creator",
    "about": "Making videos about stuff",
    "picture": "https://example.com/avatar.jpg",
    "banner": "https://example.com/banner.jpg",
    "nip05": "thomas@divine.video",
    "follower_count": 1523,
    "video_count": 42
  },
  {
    "pubkey": "fedcba0987654321fedcba0987654321fedcba0987654321fedcba0987654321",
    "name": "thomasb",
    "display_name": "Thomas B",
    "about": "Another Thomas",
    "picture": "https://example.com/avatar2.jpg",
    "banner": null,
    "nip05": null,
    "follower_count": 89,
    "video_count": 3
  }
]
```

---

## Backward Compatibility

- All new query parameters are optional. Omitting them preserves current behavior exactly.
- New response fields are additive. Existing clients that don't read `follower_count`/`video_count` are unaffected.
- The mobile client already handles missing fields gracefully (parses as `null`, hides the stats UI).

---

## How the Mobile Client Uses This

### Query construction (FunnelcakeApiClient)
```
queryParams['sort_by'] = 'followers';    // always sent for user search
queryParams['has_videos'] = 'true';       // always sent for user search
queryParams['offset'] = '50';             // sent on page 2+
queryParams['limit'] = '50';              // always sent
```

### Response consumption (ProfileSearchResult.fromJson)
```dart
followerCount = json['follower_count'] as int?;   // reads from response
videoCount = json['video_count'] as int?;          // reads from response
```

### UI rendering (UserSearchView)
- Displays "1.5K followers · 42 videos" below the display name
- Compact number formatting (1000 → "1K", 1500 → "1.5K")
- Stats row only shown when at least one count is non-null
- If both are null (server hasn't added support yet), no stats row appears

### Pagination
- Page size: 50
- `hasMore` heuristic: if response contains exactly 50 results, assume more pages exist
- Infinite scroll triggers at 80% scroll position
- `offset` increments by result count on each page load

---

## Suggested Implementation Approach

Since the server already computes follower and video counts per user:

1. **Join the counts** into the search query. The search likely queries a profiles/metadata table - join or subquery against the stats that power `GET /api/users/{pubkey}` to get `follower_count` and `video_count` per result.

2. **Add the WHERE clause** for `has_videos`: `WHERE video_count > 0` when the param is present.

3. **Add the ORDER BY** for `sort_by=followers`: `ORDER BY follower_count DESC` (with a secondary sort for ties).

4. **Include the fields** in the JSON serialization of each result object.

If the counts are in a separate table/materialized view from the profile text search, a common pattern is:
```sql
SELECT p.*, COALESCE(s.follower_count, 0) as follower_count,
       COALESCE(s.video_count, 0) as video_count
FROM profiles p
LEFT JOIN user_stats s ON p.pubkey = s.pubkey
WHERE p.name ILIKE '%thomas%' OR p.display_name ILIKE '%thomas%'
  AND s.video_count > 0  -- when has_videos=true
ORDER BY s.follower_count DESC  -- when sort_by=followers
LIMIT 50 OFFSET 0
```

---

## Verification Checklist

- [ ] `GET /api/search/profiles?q=thomas` returns results with `follower_count` and `video_count` fields
- [ ] `sort_by=followers` returns results ordered by follower count descending
- [ ] `has_videos=true` excludes users with zero videos
- [ ] `offset` pagination still works correctly with new sort/filter
- [ ] Omitting new params preserves existing behavior exactly
- [ ] Response includes `picture` field from Kind 0 metadata
- [ ] Performance is acceptable (search should remain < 500ms)
- [ ] Cache headers remain appropriate (60s for search results)
