---
name: rsky-pds-crawler-notify-hang
description: |
  Fix rsky-pds createRecord/putRecord hanging indefinitely with no error logs.
  Use when: (1) createSession succeeds but createRecord never returns,
  (2) No error appears in PDS logs despite request hanging for 60+ seconds,
  (3) PDS health endpoint works but write operations hang,
  (4) readiness probes intermittently fail on rsky-pds pod.
  Root cause: PDS_CRAWLERS env var configures crawler notification URLs
  that are called via reqwest HTTP client WITHOUT any timeout in crawlers.rs.
  If the crawler URL is unreachable from the cluster, every write hangs forever.
  Also: setting PDS_CRAWLERS="" produces [""] (one empty string element)
  which causes a "builder error" instead — must fully unset the env var.
author: Claude Code
version: 1.0.0
date: 2026-03-21
---

# rsky-pds Crawler Notification Hang

## Problem
All write operations on rsky-pds (createRecord, putRecord, deleteRecord) hang
indefinitely with no error output. The PDS appears healthy (health endpoint
returns 200, createSession works) but any operation that modifies the repo
never completes.

## Context / Trigger Conditions
- `createSession` returns a valid JWT instantly
- `createRecord` or `putRecord` with that JWT hangs forever (60s+ timeout)
- PDS logs show only `Rocket has launched from http://0.0.0.0:8000` with no error
- `_health` endpoint returns `{"version":"0.3.0-beta.3"}` (or similar)
- Kubernetes readiness probes may intermittently fail due to the pod being
  overwhelmed by hung requests
- The `PDS_CRAWLERS` env var is set (e.g., `https://bsky.network`)

## Solution

### Quick Fix (Runtime)
Unset the `PDS_CRAWLERS` environment variable entirely:

```bash
# IMPORTANT: Use the trailing dash to UNSET, don't set to empty string
kubectl set env deployment/rsky-pds -n <namespace> PDS_CRAWLERS-

# Wait for rollout
kubectl rollout status deployment/rsky-pds -n <namespace> --timeout=120s
```

**Do NOT** set `PDS_CRAWLERS=""` — the `env_list()` parser splits on commas,
so an empty string produces `vec![""]` (one empty-string element), which
causes a `"builder error"` when reqwest tries to build a URL from `""`.

### Code Fix (Permanent)
In `rsky-pds/src/crawlers.rs`, add a timeout to the reqwest client:

```rust
let client = reqwest::Client::builder()
    .user_agent(APP_USER_AGENT)
    .timeout(std::time::Duration::from_secs(5))  // Add this
    .connect_timeout(std::time::Duration::from_secs(3))  // Add this
    .build()?;
```

Also consider making the error non-fatal (use `let _ =` to ignore failures
instead of propagating with `?`), since crawler notification is not critical
to the write operation succeeding.

## Root Cause Analysis

The write path in rsky-pds is:
1. `createRecord` -> `process_writes` -> `format_commit` (DB, works fine)
2. `sequence_commit` -> `sequence_evt` -> `crawlers.notify_of_update()` (HANGS)

`notify_of_update()` in `crawlers.rs` creates a `reqwest::Client` with no
timeout configured and POSTs to each crawler URL. From within a GKE cluster,
the request to `https://bsky.network/xrpc/com.atproto.sync.requestCrawl` may
hang at the TCP level with no response, causing the entire write to block.

Key files:
- `rsky-pds/src/crawlers.rs:30-61` — `notify_of_update()` method
- `rsky-pds/src/sequencer/mod.rs:215` — calls `crawlers.notify_of_update()`
- `rsky-pds/src/apis/com/atproto/repo/create_record.rs:100` — acquires sequencer lock
- `rsky-common/src/env.rs:28-33` — `env_list()` parser that splits empty strings

## Verification
After unsetting `PDS_CRAWLERS`:
```bash
# Should return in <10 seconds instead of hanging
curl -X POST "$PDS_URL/xrpc/com.atproto.repo.createRecord" \
  -H "Authorization: Bearer $JWT" \
  -H "Content-Type: application/json" \
  -d '{"repo":"$DID","collection":"app.bsky.feed.post","record":{"$type":"app.bsky.feed.post","text":"test","createdAt":"2026-01-01T00:00:00Z"}}'
```

## Notes
- This affects ALL rsky-pds deployments that set PDS_CRAWLERS to an unreachable URL
- The upstream TypeScript atproto PDS has proper timeouts; this is an rsky-specific bug
- The `notify_of_update()` has a 20-minute throttle, so the first write after startup
  always triggers the notification (and hangs if unreachable)
- The sequencer write lock at line 99 means a single hung notification blocks ALL
  subsequent write requests, not just the one that triggered it
