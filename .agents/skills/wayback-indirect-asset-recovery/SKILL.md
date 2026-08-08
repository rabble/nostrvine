---
name: wayback-indirect-asset-recovery
description: |
  Recover assets (images, videos, data) that weren't directly archived by Wayback Machine
  by crawling archived pages that reference them. Use when: (1) Direct asset URL returns
  404/503 from Wayback, (2) Asset was hosted on CDN that Wayback didn't crawl, (3) You
  have the page URL but not the asset URL, (4) Recovering avatars, thumbnails, or embedded
  media from defunct services. The key insight: pages often got archived even when their
  assets didn't - extract URLs from archived HTML, then try alternative fetch methods.
author: Claude Code
version: 1.0.0
date: 2026-01-28
---

# Wayback Indirect Asset Recovery

## Problem
When archiving content from defunct services, direct asset URLs (images, videos, avatars)
often return 404/503 from Wayback Machine even when the pages referencing them were archived.
The assets themselves may not have been crawled, but their URLs exist in archived HTML.

## Context / Trigger Conditions
- Direct Wayback URL for asset returns 404 or 503
- You have a profile/page URL but not the asset URL
- Recovering media from defunct services (Vine, Tumblr, defunct startups)
- Wayback has the page but not the embedded assets
- CDN-hosted assets that weren't in Wayback's crawl scope

## Solution

### Step 1: Fetch the Archived Page
```python
import requests
import re

session = requests.Session()
session.headers['User-Agent'] = 'YourCrawler/0.1 (archival research)'

# Fetch archived profile/page
page_url = f"https://web.archive.org/web/20170110/https://example.com/user/{username}"
resp = session.get(page_url, timeout=20, allow_redirects=True)
```

### Step 2: Extract Asset URLs from HTML
```python
# Try multiple patterns - pages structure varies
patterns = [
    # Open Graph image
    (r'og:image["\s]+content="([^"]+)"', 'og:image'),
    # JSON data in page
    (r'"avatarUrl"\s*:\s*"([^"]+)"', 'JSON avatarUrl'),
    (r'"imageUrl"\s*:\s*"([^"]+)"', 'JSON imageUrl'),
    # CDN URLs
    (r'(https?://[^"\s]+cdn\.[^"\s]+\.(jpg|png|mp4))', 'CDN URL'),
    # S3 URLs
    (r'(https?://[^"\s]+\.s3\.amazonaws\.com/[^"\s]+)', 'S3 URL'),
]

for pattern, name in patterns:
    match = re.search(pattern, html)
    if match:
        asset_url = match.group(1).replace('&amp;', '&')
        break
```

### Step 3: Handle Wayback-Wrapped URLs
URLs extracted from archived pages are often already Wayback URLs:
```python
# If URL is already wrapped, convert im_ to id_ for raw content
if 'web.archive.org/web/' in asset_url:
    # Replace /web/TIMESTAMP/ or /web/TIMESTAMPim_/ with /web/TIMESTAMPid_/
    download_url = re.sub(r'/web/(\d+)(im_)?/', r'/web/\1id_/', asset_url)
else:
    # Wrap raw URL in Wayback
    download_url = f"https://web.archive.org/web/{timestamp}id_/{asset_url}"
```

### Step 4: Fallback Methods if Wayback Fails
If Wayback returns 404/503 for the asset, try alternatives:

```python
# Extract original CDN URL
cdn_match = re.search(r'(https?://[^/]+cdn\.[^"\s]+)', asset_url)
if cdn_match:
    original_url = cdn_match.group(1)

    # Method 1: Try live CDN via IP (if DNS is dead but servers live)
    # See: dead-cdn-dns-bypass skill

    # Method 2: Try different Wayback timestamps
    for ts in ['20170110', '20160601', '20150601']:
        alt_url = f"https://web.archive.org/web/{ts}id_/{original_url}"
        resp = session.get(alt_url, timeout=30)
        if resp.status_code == 200:
            break

    # Method 3: Check if asset exists on successor platform
    # (e.g., user migrated to Twitter/TikTok with same username)
```

## Verification
1. Check HTTP 200 response from final download URL
2. Validate content-type matches expected type
3. Verify file magic bytes (JPEG: `\xff\xd8\xff`, PNG: `\x89PNG`)
4. Confirm file size > minimum threshold

## Example: Recovering Vine Avatars

```python
def recover_avatar_from_profile(vanity_url: str, user_id: str, session) -> bool:
    """Recover avatar by crawling archived Vine profile."""
    timestamps = ['20170110', '20161201', '20160601', '20150601']

    for ts in timestamps:
        # Fetch archived profile page
        profile_url = f"https://web.archive.org/web/{ts}/https://vine.co/{vanity_url}"
        resp = session.get(profile_url, timeout=20)

        if resp.status_code != 200:
            continue

        # Extract avatar URL from page
        match = re.search(r'og:image["\s]+content="([^"]+)"', resp.text)
        if not match:
            match = re.search(r'"avatarUrl"\s*:\s*"([^"]+)"', resp.text)

        if match:
            avatar_url = match.group(1).replace('&amp;', '&')

            # Convert to raw content URL
            if 'web.archive.org/web/' in avatar_url:
                download_url = re.sub(r'/web/(\d+)(im_)?/', r'/web/\1id_/', avatar_url)
            else:
                download_url = f"https://web.archive.org/web/{ts}id_/{avatar_url}"

            # Download
            img_resp = session.get(download_url, timeout=30)
            if img_resp.status_code == 200 and len(img_resp.content) > 100:
                # Validate and save
                if img_resp.content[:3] == b'\xff\xd8\xff':  # JPEG
                    save_avatar(user_id, img_resp.content, 'jpg')
                    return True

    return False
```

**Result**: Recovered avatars for 95% of top Vine creators (including Logan Paul, Nash Grier,
Lele Pons) whose direct avatar URLs weren't archived.

## Notes

- **Wayback im_ vs id_ modifiers**: `im_` returns image with Wayback toolbar, `id_` returns raw bytes
- **Rate limiting**: Respect Wayback's servers - add 1-2 second delays between requests
- **Multiple timestamps**: Try several archive dates - some may have the asset, others may not
- **HTML entity decoding**: Always decode `&amp;` to `&` in extracted URLs
- **Redirect handling**: Use `allow_redirects=True` - Wayback often redirects to nearest snapshot

## Related Skills

- `dead-cdn-dns-bypass` - For when CDN DNS is dead but servers still respond
- `wayback-api-archive-recovery` - For discovering what was archived via CDX API
- `wayback-machine-raw-content-id-modifier` - For fetching raw content without Wayback wrapper
