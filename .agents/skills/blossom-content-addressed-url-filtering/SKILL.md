---
name: blossom-content-addressed-url-filtering
description: |
  Fix silent video/media processing failures caused by URL extraction code that filters
  on file extensions (.mp4, .webm, .webp). Use when: (1) Media moderation, transcoding,
  or analysis silently skips files from Blossom or content-addressed storage servers,
  (2) URL extraction from Nostr event tags (imeta, r tags) drops URLs without recognized
  extensions, (3) CDN fallback URLs append .mp4 but the actual server uses extensionless
  content-addressed paths like /{sha256}. Common in Nostr video events (kind 34236)
  where different clients use different URL formats.
author: Claude Code
version: 1.0.0
date: 2026-03-05
---

# Blossom Content-Addressed URL Filtering

## Problem
Code that extracts video URLs from Nostr events (or similar tag-based metadata) silently
drops URLs from Blossom servers and other content-addressed storage because it filters on
file extensions like `.mp4`. These servers use hash-based URLs without extensions
(e.g. `https://blossom.example.com/{sha256}`), causing the URL extraction to fail and
fall back to a CDN URL that also 404s for non-CDN content.

## Context / Trigger Conditions
- Videos from certain servers are never processed (moderated, transcoded, etc.)
- URL extraction code contains patterns like `url.includes('.mp4')` or `url.includes('/video/')`
- Nostr `imeta` tag URL extraction requires `.mp4` in the URL string
- Nostr `r` tag filtering checks for `.mp4` or `/video/` in the URL
- CDN fallback constructs `https://cdn.domain/{sha256}.mp4` but server serves at `/{sha256}`
- Content-addressed storage (Blossom, IPFS gateways) uses extensionless URLs
- Failures are silent — no errors, videos just never appear in the processing pipeline

## Solution

### 1. Remove extension filtering from URL extraction

**Bad** (drops blossom URLs):
```javascript
// imeta tag extraction
if (param.startsWith('url ') && param.includes('.mp4')) {
  url = param.substring(4).trim();
}

// r tag extraction
if (url.includes('.mp4') || url.includes('/video/')) {
  return url;
}
```

**Good** (accepts any URL):
```javascript
// imeta tag extraction — accept any URL
if (param.startsWith('url ') && param.length > 4) {
  url = param.substring(4).trim();
}

// r tag extraction — accept any http URL
if (url.startsWith('http')) {
  return url;
}
```

### 2. For kind-specific events, trust the event kind

If you already know an event is a video event (e.g. kind 34236), any URL in its tags
is a video URL. Don't re-validate the media type by extension.

### 3. Use mime type from imeta instead of extension

If you need to validate media type, use the `m` field in imeta tags:
```javascript
for (const param of tag.slice(1)) {
  if (param.startsWith('m video/')) isVideo = true;
  if (param.startsWith('url ')) imetaUrl = param.substring(4).trim();
}
```

### 4. Fix CDN fallback URLs

```javascript
// Bad: appends .mp4
let videoUrl = `https://${CDN_DOMAIN}/${sha256}.mp4`;

// Good: content-addressed path (no extension)
let videoUrl = `https://${CDN_DOMAIN}/${sha256}`;
```

## Verification
- Check that videos from non-CDN blossom servers appear in the moderation/processing queue
- Verify that `extractVideoUrlFromEvent` returns URLs for events with extensionless imeta/r tags
- Confirm CDN fallback URLs resolve correctly without `.mp4` extension

## Example
A Nostr kind 34236 event with tags:
```json
["imeta", "url https://blossom.primal.net/abc123def456...", "m video/mp4", "x abc123def456..."]
```

Old code: `url.includes('.mp4')` → false → URL dropped → CDN fallback → 404 → video never moderated

New code: accepts any URL from imeta → `https://blossom.primal.net/abc123def456...` → HiveAI can fetch it → video moderated

## Notes
- This applies to ANY media processing pipeline, not just moderation
- Blossom (BUD-01) uses `/{sha256}` paths; some servers add Content-Type headers
- HLS streams (.m3u8), WebP thumbnails, and other formats also won't have .mp4 extensions
- Some rogue clients may not follow any path convention at all
- The `m` (mime type) field in imeta is the proper way to determine media type, not the URL path
- Prioritize imeta URLs over r tag URLs (imeta is more specific/reliable)
