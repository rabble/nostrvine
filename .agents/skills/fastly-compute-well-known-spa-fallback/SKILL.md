---
name: fastly-compute-well-known-spa-fallback
description: |
  Fix .well-known files (apple-app-site-association, assetlinks.json) being served as HTML
  by the @fastly/compute-js-static-publish SPA fallback instead of JSON. Use when: (1) iOS
  Universal Links or Android App Links are broken because the verification files return
  text/html instead of application/json, (2) PublisherServer with spaFile config intercepts
  /.well-known/ paths and returns index.html (200, text/html) instead of 404 for missing
  files, (3) apple-app-site-association (no file extension) gets wrong content type even
  when correctly stored in KV. Covers both apex domain and subdomain handler patterns.
author: Claude Code
version: 1.0.0
date: 2026-02-23
---

# Fastly Compute: .well-known Files Intercepted by SPA Fallback

## Problem

When using `@fastly/compute-js-static-publish` with SPA fallback configured (`spaFile: "/index.html"`), the `PublisherServer.serveRequest()` returns `index.html` with status 200 and Content-Type `text/html` for ANY path not found in the KV store. This includes `/.well-known/apple-app-site-association` and `/.well-known/assetlinks.json`, which iOS and Android require to be served as `application/json`.

Symptoms:
- iOS Universal Links don't work (Apple's verification fetches `.well-known/apple-app-site-association` and gets HTML)
- Android App Links don't work (Google's verifier fetches `.well-known/assetlinks.json` and gets HTML)
- `curl -I https://yourdomain.com/.well-known/apple-app-site-association` shows `Content-Type: text/html`
- The files ARE published to KV (confirmed by `npm run fastly:publish`) but still return HTML

## Non-Obvious Root Causes

1. **SPA fallback returns 200, not 404**: The publisher's SPA mode returns `index.html` with HTTP 200 for missing paths. You cannot distinguish "file served" from "fallback served" by status code alone - you must inspect the Content-Type.

2. **`apple-app-site-association` has no file extension**: The static publisher infers MIME type from file extension. With no extension, it cannot detect `application/json`, so even when the file IS published to KV, it may get `application/octet-stream` or be served incorrectly.

3. **`includeWellKnown: true` in `publish-content.config.js` is necessary but not sufficient**: It ensures the files are uploaded to KV, but doesn't prevent the SPA fallback from intercepting the requests, and doesn't fix the content-type for extension-less files.

4. **Both apex domain and subdomain handlers need the fix**: If your Compute handler has separate code paths for subdomains vs apex, both paths must intercept `.well-known/` requests before reaching the SPA fallback.

## Solution

### Step 1: Ensure Files Are Published

In `publish-content.config.js`, confirm `includeWellKnown: true` is set:

```javascript
// publish-content.config.js
module.exports = {
  // ...
  includeWellKnown: true,   // Must be true to include /.well-known/ files
  // ...
};
```

Then publish static content:
```bash
npm run fastly:publish
```

### Step 2: Intercept .well-known Paths Before SPA Fallback

In your Compute entry point (`compute-js/src/index.js`), add a `.well-known` handler
BEFORE any call to `publisherServer.serveRequest(request)` that has SPA fallback enabled.

**Critical guard**: Check that the publisher response is NOT `text/html` - if it is,
the SPA fallback fired (file not in KV), so return 404 instead of the HTML.

```javascript
// In your main handleRequest function, BEFORE the final publisherServer.serveRequest() call:

// Handle .well-known requests (must come before SPA fallback)
if (url.pathname.startsWith('/.well-known/')) {
  // Handle NIP-05 or other dynamic .well-known endpoints first
  if (url.pathname === '/.well-known/nostr.json') {
    return handleNip05(url);  // Your custom handler
  }

  // For all other .well-known files: fetch from static publisher
  const wkResponse = await publisherServer.serveRequest(request);

  // CRITICAL: Guard against SPA fallback. The publisher returns index.html (text/html)
  // for files not in KV. We must detect this and return 404 instead.
  if (
    wkResponse != null &&
    wkResponse.status === 200 &&
    !wkResponse.headers.get('Content-Type')?.includes('text/html')
  ) {
    const headers = new Headers(wkResponse.headers);

    // Explicitly set correct content type.
    // apple-app-site-association has no extension, so the publisher may not detect JSON.
    const isJsonFile =
      url.pathname.endsWith('.json') ||
      url.pathname.endsWith('/apple-app-site-association') ||
      url.pathname === '/.well-known/apple-app-site-association';

    headers.set(
      'Content-Type',
      isJsonFile ? 'application/json' : (headers.get('Content-Type') || 'application/octet-stream')
    );
    headers.set('Cache-Control', 'public, max-age=3600');
    headers.append('Vary', 'X-Original-Host');  // If using multi-service routing

    return new Response(wkResponse.body, { status: 200, headers });
  }

  // File not in KV (or publisher returned SPA fallback) - return proper 404
  return new Response('Not Found', { status: 404 });
}
```

### Step 3: Apply the Same Fix in Subdomain Handlers

If you have separate handling for subdomain requests, add the same guard there too.
Subdomain paths hit a different code branch before reaching the apex domain handler:

```javascript
if (subdomain) {
  if (url.pathname.startsWith('/.well-known/')) {
    if (url.pathname === '/.well-known/nostr.json') {
      return handleSubdomainNip05(subdomain);
    }

    // Same pattern: intercept, guard against SPA fallback, force JSON content type
    const wkResponse = await publisherServer.serveRequest(request);
    if (
      wkResponse != null &&
      wkResponse.status === 200 &&
      !wkResponse.headers.get('Content-Type')?.includes('text/html')
    ) {
      const headers = new Headers(wkResponse.headers);
      const contentType =
        url.pathname.endsWith('.json') || url.pathname.endsWith('/apple-app-site-association')
          ? 'application/json'
          : headers.get('Content-Type') || 'application/octet-stream';
      headers.set('Content-Type', contentType);
      headers.set('Cache-Control', 'public, max-age=3600');
      return new Response(wkResponse.body, { status: 200, headers });
    }
    return new Response('Not Found', { status: 404 });
  }

  // ... rest of subdomain handling
}
```

## Verification

```bash
# Should return application/json, NOT text/html
curl -sI https://yourdomain.com/.well-known/apple-app-site-association | grep -i content-type

# Should return JSON body
curl -s https://yourdomain.com/.well-known/apple-app-site-association | head -c 100

# Android assetlinks.json
curl -sI https://yourdomain.com/.well-known/assetlinks.json | grep -i content-type

# Verify the SPA fallback guard works (path that does NOT exist in KV)
curl -sI https://yourdomain.com/.well-known/nonexistent-file
# Should return 404, not 200
```

## Complete Working Example

From `compute-js/src/index.js` in divine-web:

```javascript
// 4. Handle .well-known requests
if (url.pathname.startsWith('/.well-known/')) {
  // 4a. NIP-05 from KV store
  if (url.pathname === '/.well-known/nostr.json') {
    return await handleNip05(url);
  }

  // 4b. Serve other .well-known files (apple-app-site-association, assetlinks.json)
  // These must be served as JSON, not the SPA fallback.
  // apple-app-site-association has no file extension, so the static publisher
  // cannot detect its content type - we handle it explicitly here.
  const wkResponse = await publisherServer.serveRequest(request);
  // Guard: if publisher returns text/html, it's the SPA fallback, not the real file
  if (wkResponse != null && wkResponse.status === 200 && !wkResponse.headers.get('Content-Type')?.includes('text/html')) {
    const headers = new Headers(wkResponse.headers);
    // Ensure correct content type for app association files
    const contentType = url.pathname.endsWith('.json') || url.pathname.endsWith('/apple-app-site-association')
      ? 'application/json'
      : headers.get('Content-Type') || 'application/octet-stream';
    headers.set('Content-Type', contentType);
    headers.set('Cache-Control', 'public, max-age=3600');
    headers.append('Vary', 'X-Original-Host');
    return new Response(wkResponse.body, {
      status: 200,
      headers,
    });
  }
  // File not found in KV - return 404 instead of SPA fallback
  return new Response('Not Found', { status: 404 });
}
```

## Deployment Checklist

After making code changes:

```bash
# 1. Publish static content first (uploads .well-known files to KV)
npm run fastly:publish

# 2. Deploy the edge worker code (with the .well-known interception logic)
npm run fastly:deploy

# NOTE: Order matters if files weren't in KV before. If you deploy code first,
# it will correctly return 404 for missing files. Then publish uploads the files.
# Either order works - the guard handles both cases.
```

## Notes

- This pattern applies to any Fastly Compute service using `@fastly/compute-js-static-publish` with `spaFile` configured.
- The SPA fallback is intentional for client-side routing, but it breaks any path that needs a real 404 (like `.well-known` verification files).
- The content-type detection by file extension is a fundamental limitation of static publishing - extension-less files always need explicit handling.
- If you serve multiple domains (apex + subdomains), each code path that can call `publisherServer.serveRequest()` needs the `.well-known` interception guard.
- After `fastly:publish`, allow up to 2-3 minutes for KV propagation before testing.

## References

- [Apple Universal Links documentation](https://developer.apple.com/documentation/xcode/supporting-universal-links-in-your-app)
- [Android App Links documentation](https://developer.android.com/training/app-links/verify-android-applinks)
- [@fastly/compute-js-static-publish on npm](https://www.npmjs.com/package/@fastly/compute-js-static-publish)
- [Fastly Compute KV Store](https://www.fastly.com/documentation/guides/compute/javascript/working-with-kv-store/)
