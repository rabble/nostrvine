---
name: wayback-api-archive-recovery
description: |
  Recover data from archived REST APIs using Wayback Machine. Use when: (1) Recovering
  data from defunct services like Vine, Twitter, or other platforms, (2) Need to find
  which API endpoints were archived vs which require authentication, (3) Building data
  recovery pipelines from web.archive.org. Covers CDX API queries to discover archived
  endpoints, understanding what gets archived (public) vs what doesn't (authenticated),
  and extracting embedded JSON from archived web pages as a fallback.
author: Claude Code
version: 1.0.0
date: 2025-01-20
---

# Wayback Machine API Archive Recovery

## Problem
When recovering data from defunct services, you need to know which API endpoints were
archived by the Wayback Machine, and how to access them. Not all endpoints are archived -
authenticated endpoints typically aren't captured.

## Context / Trigger Conditions
- Recovering data from a shut-down service (Vine, old Twitter API, defunct platforms)
- Building an archive crawler for digital preservation
- Need to reconstruct engagement data (comments, likes, followers) from archives
- Getting empty results when trying to fetch archived API endpoints

## Solution

### Step 1: Discover What Was Archived

Use the CDX API to search for archived endpoints:

```bash
# Find all archived endpoints under a path prefix
curl "https://web.archive.org/cdx/search/cdx?url=vine.co/api/posts/&matchType=prefix&output=json&fl=original,timestamp&filter=statuscode:200&limit=100"

# Check total pages available
curl "https://web.archive.org/cdx/search/cdx?url=vine.co/api/&matchType=prefix&showNumPages=true"
```

Key CDX parameters:
- `matchType=prefix` - Match URL prefixes with wildcards
- `fl=original,timestamp` - Select which fields to return
- `filter=statuscode:200` - Only successful captures
- `collapse=urlkey` - Deduplicate by URL
- `limit=N` - Cap results

### Step 2: Understand What Gets Archived

**Typically archived (public endpoints):**
- Comment lists: `/api/posts/{id}/comments`
- User profiles: `/api/users/profiles/{id}`
- Timelines: `/api/timelines/users/{id}`
- Public feeds: `/api/timelines/promoted`

**Typically NOT archived (require authentication):**
- Like lists: `/api/posts/{id}/likes`
- Follower/following lists: `/api/users/{id}/followers`
- Private data: DMs, settings, notifications

### Step 3: Fetch Archived API Responses

Use the `id_` modifier to get raw JSON without the Wayback toolbar:

```bash
# Without id_ - may return HTML wrapper
curl "https://web.archive.org/web/20161209032217/https://vine.co/api/posts/123/comments"

# With id_ - returns raw JSON
curl "https://web.archive.org/web/20161209032217id_/https://vine.co/api/posts/123/comments"
```

### Step 4: Extract Embedded Data as Fallback

When API endpoints weren't archived, check if data was embedded in archived web pages:

```python
# Many SPAs embed initial data in script tags
import re
import json

html = fetch_archived_page(url)

# Look for embedded JSON (common patterns)
patterns = [
    r'window\.POST_DATA\s*=\s*({.*?});',      # Vine
    r'window\.__INITIAL_STATE__\s*=\s*({.*?});',  # Redux apps
    r'<script type="application/json"[^>]*>({.*?})</script>',
]

for pattern in patterns:
    match = re.search(pattern, html, re.DOTALL)
    if match:
        data = json.loads(match.group(1))
```

**Caveat:** Embedded data is often partial (e.g., only first 3 comments rendered).

### Step 5: Infer Missing Data from Interactions

When follower/following lists aren't available, infer relationships:

```python
# If A commented on B's post → A probably follows B
inferred_follows.append({
    'follower': commenter_id,
    'followee': post_creator_id,
    'inference_type': 'commented_on_post',
    'confidence': 0.7
})

# If A mentioned @B → A probably follows B
# If A and B mutually commented → bidirectional follow (collaborators)
```

## Verification

1. CDX query returns results with status 200
2. Fetching with `id_` modifier returns valid JSON
3. Parsing embedded data produces expected structure

## Example

```python
import urllib.request
import json

def find_archived_endpoints(base_url):
    """Find all archived API endpoints for a service."""
    cdx_url = f"https://web.archive.org/cdx/search/cdx?url={base_url}&matchType=prefix&output=json&fl=original,timestamp&filter=statuscode:200"

    with urllib.request.urlopen(cdx_url, timeout=60) as resp:
        data = json.loads(resp.read())

    # Skip header row, extract unique URLs
    endpoints = {}
    for row in data[1:]:
        url, timestamp = row[0], row[1]
        if url not in endpoints:
            endpoints[url] = timestamp

    return endpoints

def fetch_archived_json(url, timestamp):
    """Fetch archived JSON using id_ modifier."""
    archive_url = f"https://web.archive.org/web/{timestamp}id_/{url}"

    with urllib.request.urlopen(archive_url, timeout=30) as resp:
        return json.loads(resp.read())

# Usage
endpoints = find_archived_endpoints("vine.co/api/posts/")
print(f"Found {len(endpoints)} archived endpoints")

# Filter to comment endpoints
comments = {k: v for k, v in endpoints.items() if '/comments' in k}
```

## Notes

- Wayback Machine rate limits requests - add delays (1+ second) between fetches
- Archived timestamps vary - same endpoint may have captures from different dates
- Paginated APIs: check for `page`, `offset`, `cursor` parameters in archived URLs
- Some archives return 302 redirects - follow them or check for "stale" archives
- The CDX API itself can be slow for large result sets - use pagination

## References
- [Wayback Machine CDX API](https://github.com/internetarchive/wayback/tree/master/wayback-cdx-server)
- [Internet Archive APIs](https://archive.org/developers/)
