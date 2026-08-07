---
name: proxy-range-header-forwarding
description: |
  Fix iOS AVPlayer "CoreMediaErrorDomain error -12939 - byte range length mismatch"
  or similar video streaming failures when a proxy/edge/CDN service sits between the
  client and object storage (GCS, S3, R2). Use when: (1) iOS video fails with -12939
  "byte range length mismatch - should be length 2 is length N", (2) curl with
  Range: bytes=0-1 returns full file instead of 2 bytes, (3) one URL path works with
  Range but another path to the same storage doesn't, (4) proxy advertises
  Accept-Ranges: bytes but returns 200 with full file for range requests. The root
  cause is typically a proxy handler that constructs a new request to the backend
  without forwarding the client's Range header.
author: Claude Code
version: 1.0.0
date: 2026-02-22
---

# Proxy Range Header Forwarding for Video Streaming

## Problem
A proxy/edge service (Fastly Compute, Cloudflare Workers, custom reverse proxy) sits
between clients and object storage. Some routes correctly forward HTTP Range headers
to the storage backend, but other routes (added later or by different developers)
construct backend requests from scratch without forwarding Range headers. This causes
iOS AVPlayer to fail because it probes with `Range: bytes=0-1` and rejects responses
where the body size doesn't match the requested range.

## Context / Trigger Conditions
- iOS error: `CoreMediaErrorDomain error -12939 - byte range length mismatch - should be length 2 is length N`
- `PlatformException(VideoError, Failed to load video: Operation Stopped)`
- `curl -H "Range: bytes=0-1"` on the failing URL returns `200` with `Content-Length` equal to full file size
- The same curl test on a different URL path to the same storage returns `206` with `Content-Length: 2`
- The proxy/edge code has multiple route handlers that independently construct backend requests
- Response headers include `Accept-Ranges: bytes` (misleadingly advertising support)

## Root Cause Pattern

In proxy architectures, each route handler independently constructs requests to the
storage backend. It's common for the "original" handler to properly forward Range
headers while variant handlers (quality variants, thumbnails, transcoded versions)
build requests from scratch without considering Range.

```rust
// BROKEN: Handler ignores client Range header
fn handle_variant(req: Request, path: &str) -> Response {
    let gcs_path = resolve_variant(path);
    let backend_req = Request::new(Method::GET, &gcs_url);  // No Range header!
    backend_req.send("storage")
}

// WORKING: Handler forwards Range header
fn handle_original(req: Request, path: &str) -> Response {
    let range = req.get_header("Range");  // Extracts Range
    let backend_req = Request::new(Method::GET, &gcs_url);
    if let Some(r) = range {
        backend_req.set_header("Range", r);  // Forwards it
    }
    backend_req.send("storage")
}
```

## Solution

Three things must all be fixed in the proxy handler:

### 1. Extract Range header from client request
```rust
let range = req
    .get_header(header::RANGE)
    .and_then(|h| h.to_str().ok())
    .map(|s| s.to_string());
```

### 2. Forward Range header to storage backend
```rust
if let Some(range_value) = range {
    backend_req.set_header("Range", range_value);
}
```

### 3. Accept 206 responses from the backend
```rust
// BEFORE (broken): only accepts 200
match resp.get_status() {
    StatusCode::OK => Ok(resp),
    ...
}

// AFTER (fixed): accepts both 200 and 206
match resp.get_status() {
    StatusCode::OK | StatusCode::PARTIAL_CONTENT => Ok(resp),
    ...
}
```

GCS/S3/R2 natively handle Range headers and return proper `206 Partial Content` with
correct `Content-Range` and `Content-Length` headers, so once forwarded, the response
can be passed through directly to the client.

## Verification

```bash
# Test the failing endpoint with a range probe (what iOS does)
curl -sv -H "Range: bytes=0-1" "https://cdn.example.com/hash/variant" \
  -o /dev/null 2>&1 | grep -iE "< HTTP|content-length|content-range"

# Expected AFTER fix:
# < HTTP/2 206
# < content-range: bytes 0-1/TOTAL_SIZE
# < content-length: 2

# Test mid-file range
curl -sv -H "Range: bytes=1000-1999" "https://cdn.example.com/hash/variant" \
  -o /dev/null 2>&1 | grep -iE "< HTTP|content-length|content-range"

# Expected: 206, content-length: 1000, content-range: bytes 1000-1999/TOTAL

# Test full download still works (no Range header)
curl -sv "https://cdn.example.com/hash/variant" \
  -o /dev/null 2>&1 | grep -iE "< HTTP|content-length"

# Expected: 200, content-length: TOTAL_SIZE
```

## Example

**Real case**: Fastly Compute edge service proxying to GCS. The `/{hash}` route (original
blob) forwarded Range headers via `download_blob(hash, range)`. The `/{hash}/720p` route
(transcoded quality variant) called `download_hls_from_gcs(gcs_key)` with no range parameter.

Fix required changes in three layers:
1. Storage function: added `range: Option<&str>` parameter
2. Wrapper function: passed range through
3. Route handler: extracted Range from client request

## Notes

- **Audit all route handlers**: If one handler is missing Range forwarding, others likely are too.
  Search for all places that construct backend requests and verify Range is forwarded.
- **Don't just set Accept-Ranges**: Adding `Accept-Ranges: bytes` to responses without actually
  handling ranges is worse than not advertising it - clients will expect it to work.
- **iOS is strict**: Safari/AVPlayer always probes with `Range: bytes=0-1` before streaming.
  Chrome/Android are more forgiving and may work without proper Range support.
- **HEAD requests**: HEAD handlers don't need Range forwarding (they return metadata only),
  but GET handlers absolutely do.
- **Cache layers**: If a caching proxy sits in front, it may cache the full 200 response and
  serve it for Range requests. Purge cache after deploying the fix.

## References
- [MDN: HTTP Range Requests](https://developer.mozilla.org/en-US/docs/Web/HTTP/Range_requests)
- [GCS: Resumable Downloads](https://cloud.google.com/storage/docs/resumable-downloads)
- [Apple: AVPlayer HTTP Live Streaming](https://developer.apple.com/documentation/avfoundation/avplayer)
