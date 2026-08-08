---
name: fastly-compute-async-request-reliability
description: |
  Fix silent failures in Fastly Compute@Edge when using send_async for fire-and-forget
  requests. Use when: (1) Background tasks (migrations, webhooks, notifications) triggered
  from Compute never complete, (2) send_async PendingRequest is immediately dropped,
  (3) Fire-and-forget pattern works locally but fails in production, (4) An async trigger
  "logs as triggered" but the target service never receives the request (especially after
  renaming backend constants — the URL hostname is cosmetic, the backend name determines
  routing, so a global rename can silently reroute calls to the wrong service). Also covers
  silent backend-not-found errors when FALLBACK_BACKENDS or other backend constants
  reference names not configured in the Fastly dashboard.
author: Claude Code
version: 1.1.0
date: 2026-04-05
---

# Fastly Compute Async Request Reliability

## Problem
Fire-and-forget HTTP requests from Fastly Compute@Edge using `send_async` silently fail
because the worker process can terminate before the async request reaches the backend.
Additionally, backend names referenced in code but not configured in the Fastly dashboard
cause silent failures that are easy to miss.

## Context / Trigger Conditions
- Background migration, webhook, or notification triggered via `req.send_async(backend)`
- The `PendingRequest` returned by `send_async` is immediately dropped (not awaited)
- The main response is sent to the client, causing the Compute worker to terminate
- Error is swallowed with `let _ = ...` or `match ... { Err(_) => ... }`
- Works in local testing (`fastly compute serve`) but fails in production
- Backend name in code doesn't match any backend in `fastly backend list --service-id`

## Solution

### 1. Use synchronous `send()` instead of `send_async()` for critical operations

```rust
// BAD: Fire-and-forget — worker terminates before request completes
match req.send_async(BACKEND) {
    Ok(_pending) => {
        // PendingRequest dropped here — request likely never completes!
        Ok(())
    }
    Err(e) => { /* ... */ }
}

// GOOD: Synchronous send — waits for response
match req.send(BACKEND) {
    Ok(resp) => {
        let status = resp.get_status();
        if status.is_success() {
            eprintln!("[MIGRATE] Success for {}", hash);
        } else {
            eprintln!("[MIGRATE] Backend returned {}", status);
        }
        Ok(())
    }
    Err(e) => {
        eprintln!("[MIGRATE] Failed: {}", e);
        Ok(()) // Don't fail the main request
    }
}
```

### 2. When synchronous is too slow, use a caching layer

If a VCL caching layer fronts Compute (service chaining), the extra latency from
synchronous send only affects cache misses. Subsequent requests hit the cache.
This makes synchronous send acceptable for operations like migration triggers.

### 3. Always verify backend existence

```bash
# List backends configured on the service
fastly backend list --service-id YOUR_SERVICE_ID --version latest

# Add missing backend
fastly backend create --service-id YOUR_SERVICE_ID --version latest --autoclone \
  --name cdn_divine --address cdn.divine.video --port 443 \
  --use-ssl --ssl-sni-hostname cdn.divine.video --override-host cdn.divine.video
```

Check that every backend name in your Rust code (`req.send("backend_name")`) has a
corresponding entry in the Fastly dashboard. The `fastly.toml` `[local_server.backends]`
section is for local dev only — it does NOT create production backends.

### 4. Beware: the URL hostname is cosmetic — the backend name decides routing

In Fastly Compute, `req.send(backend_name)` / `req.send_async(backend_name)` ignores the
URL's hostname for routing purposes. The backend's dashboard configuration (address,
override_host, TLS SNI) determines where the request actually lands. This means two
different Cloud Run services that happen to share a backend constant will both deliver
to whichever address that one backend is wired to — and the call site that looked
correct because its URL said `service-A.run.app` will actually hit `service-B`.

This bites hardest after a global rename. Example: a refactor replaces
`CLOUD_RUN_BACKEND` with `UPLOAD_SERVICE_BACKEND` across the whole file via sed-style
search-and-replace. Most call sites were legitimately targeting the upload service, so
they still work. But one call site was doing `POST https://divine-transcoder-XXXX.run.app/transcode`
and the rename points it at the upload service backend — the request gets a nginx 404
from the upload service, `send_async` returns Ok (backend accepted the connection), and
the `eprintln!("[HLS] Triggered on-demand transcoding for {}", hash)` log line is a
false positive. The transcoder never sees the request. Videos pile up in an "in
progress" state for days.

**How to catch this class of bug:**

1. When you see a rename of a backend constant, grep for every call site and verify
   the URL hostname matches what the new backend is configured to route to:
   ```bash
   grep -n "send(\|send_async(" src/*.rs
   grep -n "BACKEND: &str" src/*.rs  # find constant definitions
   ```
   Any call site where `format!("https://{}/...", SOMETHING_ELSE)` doesn't match
   the backend's dashboard `address`/`override_host` is a silent misroute.

2. Probe the "wrong" destination directly from the outside with curl using a
   synthetic payload. If you get a 404 or 405 from nginx/the wrong service, you've
   found a misroute. Example:
   ```bash
   curl -X POST https://upload.divine.video/transcode -H 'Content-Type: application/json' -d '{"hash":"0"*64}'
   # HTTP 404 <- wrong service, backend misrouted
   ```

3. If you own more than one Cloud Run service, define **one backend per service**
   (`transcoder_backend`, `upload_service`, `transcriber_backend`) and never
   collapse them just because both are `*.run.app`. The `override_host` on each
   backend pins its destination regardless of URL.

4. Switch fire-and-forget triggers that you care about to synchronous `send()` at
   least during investigation — a real non-2xx response from the wrong service
   makes the bug visible immediately instead of hiding behind `send_async`.

### 5. Never silently swallow backend errors for important operations

```rust
// BAD: Silent failure
let _ = trigger_migration(&hash, &source);

// GOOD: Log the error even if you don't fail the request
if let Err(e) = trigger_migration(&hash, &source) {
    eprintln!("[MIGRATE] Failed for {}: {}", hash, e);
}
```

## Verification
1. Check Compute logs for the migration/webhook success messages
2. Verify the side effect actually happened (e.g., blob exists in GCS after migration)
3. `fastly backend list --service-id ID --version latest` shows all expected backends

## Example
In Divine Blossom, the on-demand migration from Bunny CDN to GCS never worked because:
1. `cdn_divine` backend was never configured in the Fastly dashboard (only in `fastly.toml`)
2. `send_async` for the Cloud Run migration request was dropped before completion
3. Both errors were silently swallowed with `let _ = ...`

Fix: Added `cdn_divine` backend via CLI, changed `send_async` to `send`, added logging.

## Notes
- `fastly.toml` `[local_server.backends]` only configures backends for `fastly compute serve`
- Production backends must be configured via dashboard or CLI (`fastly backend create`)
- In Fastly Compute, once the main response body starts streaming to the client, the worker
  can be terminated at any time — async requests in flight may be cancelled
- If you need true fire-and-forget, consider calling an external queue (Cloud Tasks, PubSub)
  instead of direct HTTP
