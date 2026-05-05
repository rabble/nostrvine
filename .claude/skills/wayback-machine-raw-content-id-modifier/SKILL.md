---
name: wayback-machine-raw-content-id-modifier
description: |
  Fix JSON parse errors when fetching archived API responses from Wayback Machine. Use when:
  (1) Getting "Expecting value: line 1 column 1 (char 0)" JSON decode errors from archived URLs,
  (2) Wayback returns HTML instead of expected JSON/raw content, (3) Crawling archived REST APIs
  or JSON endpoints from web.archive.org. The `id_` modifier returns raw content without the
  Wayback toolbar wrapper.
author: Claude Code
version: 1.0.0
date: 2026-01-20
---

# Wayback Machine Raw Content with id_ Modifier

## Problem
When fetching archived JSON API endpoints from the Wayback Machine, you get HTML-wrapped
content with the Wayback toolbar instead of the raw JSON response. This causes JSON parse
errors like "Expecting value: line 1 column 1 (char 0)" because the response starts with
`<!DOCTYPE html>` instead of valid JSON.

## Context / Trigger Conditions
- Fetching archived API endpoints from `web.archive.org/web/{timestamp}/{url}`
- JSON parsing fails with "Expecting value: line 1 column 1 (char 0)"
- Response content starts with HTML instead of expected JSON
- Crawling archived REST APIs, JSON feeds, or any non-HTML content from Wayback
- Using Python `json.loads()`, `response.json()`, or similar JSON parsing

## Solution
Add `id_` after the timestamp in the Wayback URL to get raw content:

**Default (HTML-wrapped):**
```
https://web.archive.org/web/20170112012313/https://vine.co/api/users/profiles/123
```

**Raw content (add `id_`):**
```
https://web.archive.org/web/20170112012313id_/https://vine.co/api/users/profiles/123
```

### Code Fix Pattern
```python
# BEFORE (broken - returns HTML)
url = f"https://web.archive.org/web/{timestamp}/https://example.com/api/data"

# AFTER (works - returns raw JSON)
url = f"https://web.archive.org/web/{timestamp}id_/https://example.com/api/data"
```

### Other Wayback Modifiers
- `id_` - Raw/identity (no modifications, returns original content)
- `if_` - Iframe embed mode
- `js_` - JavaScript rewriting mode
- `cs_` - CSS rewriting mode
- `im_` - Image mode

## Verification
1. Test the URL with curl to see actual response:
   ```bash
   # Without id_ - shows HTML with Wayback toolbar
   curl -s "https://web.archive.org/web/20170112012313/https://example.com/api/data" | head -5

   # With id_ - shows raw JSON
   curl -s "https://web.archive.org/web/20170112012313id_/https://example.com/api/data" | head -5
   ```

2. Verify JSON parsing works:
   ```python
   import json
   import urllib.request

   url = f"https://web.archive.org/web/{timestamp}id_/{api_url}"
   with urllib.request.urlopen(url) as resp:
       data = json.loads(resp.read())  # Should work now
   ```

## Example
Crawling archived Vine API profiles:

```python
WAYBACK_BASE = "https://web.archive.org/web"

def fetch_profile(user_id: str, timestamp: str):
    # Use id_ modifier to get raw JSON instead of HTML-wrapped content
    url = f"{WAYBACK_BASE}/{timestamp}id_/https://vine.co/api/users/profiles/{user_id}"

    with urllib.request.urlopen(url) as resp:
        data = json.loads(resp.read())
        return data['data']  # Now works correctly
```

## Notes
- The `id_` modifier works for any content type, not just JSON (images, CSS, JS, etc.)
- Some archived content may still fail if it was never properly captured
- CDX API queries (for finding archived URLs) don't need the modifier
- Rate limit requests to archive.org (5+ seconds between requests recommended)
- Empty responses (0 bytes) indicate the archive entry exists but content wasn't captured

## References
- [Wayback Machine URL Modifiers](https://archive.org/help/wayback-api/)
- [CDX Server API](https://github.com/internetarchive/wayback/tree/master/wayback-cdx-server)
