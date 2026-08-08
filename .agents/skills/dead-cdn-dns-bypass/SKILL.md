---
name: dead-cdn-dns-bypass
description: |
  Recover content from "dead" CDNs where DNS no longer resolves but servers still respond.
  Use when: (1) A service shut down but you have URLs to their CDN, (2) DNS lookups fail
  but you suspect the CDN provider (Fastly, CloudFront, Akamai) still has the content,
  (3) Archiving content from defunct services like Vine, Tumblr, etc. The key insight:
  CDN providers often keep serving content long after DNS dies - hit the IP directly
  with the original Host header.
author: Claude Code
version: 1.0.0
date: 2026-01-27
---

# Dead CDN DNS Bypass - Recovering Content from Defunct Services

## Problem
When a service shuts down, their DNS records stop resolving, making URLs appear
completely dead. However, the actual content often still exists on CDN servers
(Fastly, CloudFront, Akamai, etc.) that continue serving it - the servers just
aren't reachable via normal DNS resolution.

## Context / Trigger Conditions
- Service has shut down (Vine, defunct startups, etc.)
- Original CDN URLs return DNS resolution errors
- Content was hosted on a major CDN provider
- You need to recover/archive historical content
- Wayback Machine doesn't have the specific content

## Solution

### Step 1: Identify the CDN Provider
Look at the original URL hostname to identify the CDN:
- `*.cdn.vine.co` → Fastly
- `*.cloudfront.net` → AWS CloudFront
- `*.akamaized.net` → Akamai
- `*.fastly.net` → Fastly

### Step 2: Find CDN IP Addresses
For Fastly (common for many defunct services):
```bash
# Fastly's anycast IPs
151.101.1.6
151.101.65.6
151.101.129.6
151.101.193.6
```

For other CDNs, check their documentation or try known IP ranges.

### Step 3: Test with Host Header
```bash
# Test if content is still served
curl -sI \
  -H "Host: original-cdn-hostname.com" \
  "http://FASTLY_IP/path/to/content"

# Example for Vine:
curl -sI \
  -H "Host: mtc.cdn.vine.co" \
  "http://151.101.1.6/r/videos/ABC123.mp4"
```

### Step 4: Download Content
```python
import requests

def download_via_cdn_ip(original_url: str, cdn_ip: str) -> bytes:
    """Download content bypassing dead DNS."""
    import re

    # Extract host and path from URL
    match = re.match(r'https?://([^/]+)(/.+)', original_url)
    if not match:
        return None

    host = match.group(1)
    path = match.group(2)

    # Hit IP directly with Host header
    response = requests.get(
        f"http://{cdn_ip}{path}",
        headers={"Host": host},
        timeout=30
    )

    if response.status_code == 200:
        return response.content
    return None

# Example usage
content = download_via_cdn_ip(
    "http://mtc.cdn.vine.co/r/videos/ABC123.mp4",
    "151.101.1.6"
)
```

## Verification
1. Check for HTTP 200 response (not 403 or 404)
2. Verify content-type header matches expected type
3. Validate file integrity (check magic bytes, file size > 0)

## Example: Vine CDN Recovery

The Vine CDN shut down with DNS in 2017, but as of 2026, Fastly still serves
the video files:

```python
# Vine CDN hosts and their Fastly IP
VINE_CDN_HOSTS = {
    "mtc.cdn.vine.co": "151.101.1.6",
    "v.cdn.vine.co": "151.101.1.6",
}

# Original URL from archived metadata
video_url = "http://mtc.cdn.vine.co/r/videos/ABC123.mp4?versionId=xyz"

# Download via IP bypass
import requests
import re

match = re.match(r'https?://([^/]+)(/.+)', video_url)
host, path = match.groups()

response = requests.get(
    f"http://151.101.1.6{path}",
    headers={"Host": host}
)

# Save the recovered video
with open("recovered_video.mp4", "wb") as f:
    f.write(response.content)
```

**Result**: Recovered 121,149 Vine videos that Wayback Machine didn't archive.

## Notes

- **CDN caching behavior**: Content may be cached indefinitely on CDN edge servers
  even after the origin server is gone
- **Version IDs**: Some CDNs (like S3-backed ones) use versionId parameters -
  keep these in your requests
- **Rate limiting**: CDNs may still enforce rate limits even for "dead" domains
- **HTTPS**: May need to use HTTP instead of HTTPS since SSL certs have expired
- **Time-sensitive**: This won't work forever - CDNs eventually purge old content
- **Legal considerations**: Ensure you have rights to archive the content

## Common CDN IP Ranges

| CDN | IP Range | Notes |
|-----|----------|-------|
| Fastly | 151.101.0.0/16 | Anycast, try .1.6, .65.6, .129.6, .193.6 |
| CloudFront | Varies | Check AWS IP ranges JSON |
| Akamai | Varies | Use GTM lookup tools |

## Related Techniques

- Use Wayback Machine CDX API to find archived metadata with CDN URLs
- Combine with web.archive.org for content they did capture
- Check Internet Archive's "Save Page Now" for triggering archival
