---
name: vine-oembed-metadata-recovery
description: |
  Recover Vine video metadata (author, user ID, title, thumbnail) from vine.co oembed endpoint
  even though the Vine API and pages are dead. Use when: (1) you have Vine shortcode URLs
  (vine.co/v/XXXXX) and need to identify the creator, (2) the Vine page only shows a loading
  spinner, (3) archive-api.vineapp.com returns 404, (4) need to map Vine shortcodes to user IDs
  for cross-referencing against the divine.video database. The oembed endpoint is a still-live
  metadata oracle for the otherwise-dead Vine platform.
author: Claude Code
version: 1.0.0
date: 2026-03-22
---

# Vine oEmbed Metadata Recovery

## Problem
Vine.co pages no longer render content — the SPA shell loads but the backend API
(`archive-api.vineapp.com`) returns 404, so pages just show a loading spinner. However,
the **oembed endpoint is still live** and returns structured metadata for any valid Vine URL.

## Context / Trigger Conditions
- You have Vine URLs in the format `vine.co/v/{shortcode}`
- The Vine page shows only a loading spinner (SPA shell loads, API calls fail)
- `archive-api.vineapp.com/timelines/posts/s/{shortcode}` returns 404
- You need to identify which creator made a specific Vine
- You need to map Vine shortcodes to Vine user IDs

## Solution

### Single Lookup
Query the oembed endpoint:
```
GET https://vine.co/oembed.json?url=https://vine.co/v/{SHORTCODE}
```

### Response Fields
The oembed response provides:
- **`author_name`** — Vine username (e.g., "Kenrealdihboss")
- **`author_url`** — Profile URL containing the Vine user ID (e.g., `https://vine.co/u/1306031740015583232`)
- **`title`** — Post description/caption
- **`thumbnail_url`** — 480x480 thumbnail (may still resolve on Vine CDN)
- **`thumbnail_width`** / **`thumbnail_height`** — Always 480x480
- **`width`** / **`height`** — Embed dimensions (600x600)
- **`html`** — Iframe embed code
- **`provider_name`** — "Vine"
- **`type`** — "video"
- **`version`** — "1.0"
- **`cache_age`** — Cache duration in seconds

### Extract User ID
The Vine numeric user ID is in the `author_url` path:
```
author_url: "https://vine.co/u/1306031740015583232"
→ user_id: 1306031740015583232
```

### Bulk Recovery Pattern
If you have a list of Vine shortcodes (from Wayback CDX crawls, social media embeds, etc.):

```python
import requests
import time

def get_vine_oembed(shortcode):
    url = f"https://vine.co/oembed.json?url=https://vine.co/v/{shortcode}"
    resp = requests.get(url, timeout=10)
    if resp.status_code == 200:
        data = resp.json()
        user_id = data.get("author_url", "").split("/u/")[-1]
        return {
            "shortcode": shortcode,
            "username": data.get("author_name"),
            "user_id": user_id,
            "title": data.get("title"),
            "thumbnail_url": data.get("thumbnail_url"),
        }
    return None

# Rate-limit to be respectful
for shortcode in shortcodes:
    result = get_vine_oembed(shortcode)
    if result:
        print(f"{result['shortcode']} → {result['username']} (ID: {result['user_id']})")
    time.sleep(0.5)
```

### Cross-Reference with Database
Once you have the user ID, look up in the divine.video database:
```sql
SELECT * FROM users WHERE id = '1306031740015583232';
SELECT * FROM outreach_contacts WHERE user_id = '1306031740015583232';
```

## Verification
```bash
curl -s "https://vine.co/oembed.json?url=https://vine.co/v/iLrDJJWn9e6" | python3 -m json.tool
```
Should return JSON with `author_name`, `author_url`, `title`, `thumbnail_url`, etc.

## Sources of Vine Shortcodes
- Wayback Machine CDX API: `http://web.archive.org/cdx/search/cdx?url=vine.co/v/*&output=json`
- Embedded Vine tweets on Twitter/X
- Reddit posts linking to vine.co/v/
- Tumblr embeds (many Vine creators cross-posted)
- Blog posts and news articles embedding Vines

## Notes
- The oembed endpoint appears to be served separately from the main Vine API infrastructure,
  which is why it survived while everything else died
- Thumbnail CDN URLs from oembed may or may not still resolve — worth checking
- This works for individual Vine posts but NOT for user profile lookups
- The `author_url` format `vine.co/u/{numeric_id}` gives you the same user ID used in
  the divine.video database's `users` and `imported_users` tables
- Be respectful with rate limits — this endpoint is still running and we don't want to
  overwhelm it
