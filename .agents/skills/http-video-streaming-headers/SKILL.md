---
name: http-video-streaming-headers
description: |
  Fix "Failed to load video" errors when network requests succeed (200/206 status).
  Use when: (1) Video element shows error but DevTools shows successful requests,
  (2) Videos download correctly via curl but fail in browser, (3) Range requests
  work but video won't play, (4) Building CDN/media server for video streaming.
  The root cause is often missing Accept-Ranges header which browsers need for
  video seeking and streaming.
author: Claude Code
version: 1.0.0
date: 2026-01-29
---

# HTTP Video Streaming Header Requirements

## Problem
HTML5 video elements fail to play with "Failed to load video" error even though
network requests show successful 200/206 responses. The video file downloads
correctly when tested with curl, but browsers refuse to play it.

## Context / Trigger Conditions
- Video element fires `onerror` event despite network success
- DevTools Network tab shows 200 or 206 status for video requests
- `curl -O <video-url>` downloads a valid MP4 file
- Video plays locally when downloaded
- Error message is generic: "Failed to load video" or media error code 4

## Solution

### Required Headers for Video Streaming

1. **`Accept-Ranges: bytes`** (CRITICAL)
   - Tells browser that range requests are supported
   - Without this, browsers may not attempt range requests for seeking
   - Add to ALL video responses, even full (200) responses

2. **`Content-Type: video/mp4`** (or appropriate MIME type)
   - Must match actual video format
   - Browser uses this to select decoder

3. **`Content-Length`** (for full responses)
   - Required for browser to know file size
   - Enables progress indicators and seeking calculations
   - Note: For 206 responses, this should be partial content size

4. **For Range Requests (206 Partial Content)**:
   - `Content-Range: bytes START-END/TOTAL`
   - Status code MUST be 206, not 200

### Server Implementation

```rust
// Fastly Compute@Edge example
resp.set_header("Accept-Ranges", "bytes");
resp.set_header("Content-Type", "video/mp4");

// For full responses only (not 206):
if resp.get_status() != StatusCode::PARTIAL_CONTENT {
    resp.set_header("Content-Length", file_size.to_string());
}
```

### CDN Considerations

- Edge caches may strip or modify headers
- Verify headers reach the client, not just origin
- Fastly/CloudFront can serve range requests from cached full content
- Test with `curl -I -H "Range: bytes=0-1023"` to verify 206 response

## Verification

```bash
# Check Accept-Ranges header
curl -I https://cdn.example.com/video.mp4 | grep -i accept-ranges
# Expected: accept-ranges: bytes

# Test range request support
curl -I -H "Range: bytes=0-1023" https://cdn.example.com/video.mp4
# Expected: HTTP/2 206 with Content-Range header

# Verify partial download works
curl -H "Range: bytes=0-100" https://cdn.example.com/video.mp4 | wc -c
# Expected: 101 (bytes 0-100 inclusive)
```

## Example

**Before (broken)**:
```
HTTP/2 200
content-type: video/mp4
x-custom-header: value
```
Video fails to load in browser.

**After (working)**:
```
HTTP/2 200
content-type: video/mp4
content-length: 1443199
accept-ranges: bytes
```
Video plays correctly with seeking support.

## Notes

- Even if your CDN handles range requests automatically, you should still
  include `Accept-Ranges: bytes` in the response headers
- Some browsers are more forgiving than others; Safari often requires
  proper range support while Chrome may work without
- HTTP/2 responses may have headers lowercased (this is normal)
- For HLS/DASH streaming, the manifest and segments all need proper headers
- Mobile browsers are particularly strict about video headers

## References
- [MDN: Range Requests](https://developer.mozilla.org/en-US/docs/Web/HTTP/Range_requests)
- [MDN: Accept-Ranges](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Accept-Ranges)
- [HTTP 206 Partial Content](https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/206)
