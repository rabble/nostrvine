---
name: curl-head-vs-get-header-debugging
description: |
  Fix misleading HTTP response header values when debugging with curl -I or curl -sI.
  Use when: (1) Response headers differ between curl testing and actual browser/client behavior,
  (2) Cache-Control or other headers show unexpected values despite correct middleware code,
  (3) Server-side middleware that only applies to GET requests appears to not work when testing
  with curl -I. The -I flag sends HEAD requests, and middleware that checks for GET method will
  skip processing, returning handler-level headers instead of middleware-overridden ones.
author: Claude Code
version: 1.0.0
date: 2026-03-31
---

# curl -I Sends HEAD, Not GET — Header Debugging Trap

## Problem
When debugging HTTP response headers with `curl -I` or `curl -sI`, the response may show
different header values than what actual GET requests receive. This is because `-I` sends
a HEAD request, and server middleware that only processes GET requests will be skipped.

## Context / Trigger Conditions
- Testing cache headers with `curl -sI` and seeing unexpected values
- Middleware that checks `method == GET` before setting headers (common in cache middleware)
- Headers appear correct in automated tests but wrong in manual curl testing
- `Cache-Control`, `Surrogate-Control`, or `Surrogate-Key` values don't match expectations
- Axum/Express/any framework middleware with method guards

## Solution
Use `curl -s -D - -o /dev/null` instead of `curl -I` to get response headers from a **GET** request:

```bash
# WRONG — sends HEAD request, middleware may skip processing
curl -sI https://example.com/api/endpoint

# CORRECT — sends GET request, dumps headers, discards body
curl -s -D - -o /dev/null https://example.com/api/endpoint
```

If you need just specific headers:
```bash
curl -s -D - -o /dev/null https://example.com/api/endpoint | grep -iE 'cache-control|surrogate'
```

## Verification
Compare output from both methods:
```bash
echo "=== HEAD (curl -I) ===" 
curl -sI https://example.com/api/endpoint | grep cache-control

echo "=== GET (curl -D) ==="
curl -s -D - -o /dev/null https://example.com/api/endpoint | grep cache-control
```

If the values differ, your middleware has a GET-only guard (which is correct behavior).

## Example
Axum middleware that only sets cache headers for GET requests:
```rust
async fn cache_middleware(request: Request, next: Next) -> Response {
    let method = request.method().clone();
    let mut response = next.run(request).await;
    
    // HEAD requests skip this — curl -I won't see these headers!
    if method != Method::GET {
        return response;
    }
    
    response.headers_mut().insert("cache-control", ...);
    response.headers_mut().insert("surrogate-control", ...);
    response
}
```

## Notes
- This is NOT a bug — it's correct behavior. Cache headers should only apply to cacheable GET responses.
- HTTP spec says HEAD responses SHOULD include the same headers as GET, but middleware implementations
  often don't replicate this because HEAD is rarely used by CDNs or browsers for caching decisions.
- Fastly, Cloudflare, and other CDNs send GET requests to origins, so the cache behavior is correct
  even if `curl -I` shows different headers.
- This trap is especially insidious because `curl -I` is the most common way to check headers.
