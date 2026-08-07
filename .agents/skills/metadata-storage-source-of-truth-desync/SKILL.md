---
name: metadata-storage-source-of-truth-desync
description: |
  Fix content serving failures caused by metadata (KV store, database) being out of sync
  with actual storage (GCS, S3, filesystem). Use when: (1) Content exists in storage but
  API returns "processing" or "not ready", (2) Webhook callbacks that update metadata
  failed silently, (3) Backfill scripts generated content but didn't update status records,
  (4) HLS/transcoded content exists but transcode_status is not "Complete", (5) Handler
  checks metadata status BEFORE checking if content actually exists in storage.
author: Claude Code
version: 1.0.0
date: 2026-02-27
---

# Metadata-Storage Source of Truth Desync

## Problem
When a system has both metadata (KV store, database status field) and actual content
in object storage, the metadata can become stale. If the serving handler gates on
metadata status before checking storage, content that exists becomes inaccessible.

Common causes:
- Webhook callbacks (transcode complete, migration done) failed silently
- Backfill scripts created content but didn't update metadata
- Race conditions between metadata write and storage write
- Manual operations that bypassed the normal status update flow

## Context / Trigger Conditions
- API returns "processing" or "202 Accepted" for content that actually exists in storage
- `transcode_status` is Processing/Pending/None but HLS files exist in GCS
- Content works when accessed directly via storage URL but not through the API
- Backfill script ran successfully (content in bucket) but metadata wasn't updated
- Webhook endpoint had downtime or returned errors during batch processing

## Solution

### Pattern: Storage-First with Metadata Auto-Repair

Check storage (source of truth) BEFORE checking metadata status. If content exists,
serve it and fix metadata as a side effect.

```rust
// BAD: Metadata-first (blocks access when metadata is stale)
match metadata.transcode_status {
    Some(Complete) => { /* serve from storage */ }
    Some(Processing) => { return 202; }  // Blocks even if content exists!
    _ => { trigger_transcoding(); return 202; }
}

// GOOD: Storage-first with auto-repair
match download_from_storage(&path) {
    Ok(content) => {
        // Content exists — serve it and fix metadata if needed
        if metadata.transcode_status != Some(Complete) {
            eprintln!("[FIX] {} has content but status was {:?}", id, metadata.transcode_status);
            update_status(id, Complete);  // Auto-repair
        }
        serve(content)
    }
    Err(NotFound) => {
        // Content truly doesn't exist — now check metadata for status
        match metadata.transcode_status {
            Some(Processing) => return 202,
            _ => { trigger_processing(); return 202; }
        }
    }
}
```

### Key Principles

1. **Storage is the source of truth** — if the file exists, serve it regardless of metadata
2. **Auto-repair metadata** — when you find a desync, fix it inline (best-effort, don't fail if update fails)
3. **Log desyncs** — track how often metadata is wrong to find the root cause
4. **Don't block on metadata** — metadata status should be advisory, not a gate

### Apply to HEAD requests too

HEAD handlers often have the same bug. Apply the same storage-first pattern:

```rust
// HEAD: Check storage, not just metadata
match check_storage_exists(&path) {
    Ok(true) => {
        if metadata.status != Complete {
            update_status(id, Complete);
        }
        return 200;
    }
    Ok(false) | Err(_) => {
        // Fall back to metadata-based response
    }
}
```

## Verification
1. Request content that previously returned 202 — should now return 200 with content
2. Check logs for "[FIX]" messages showing auto-repair in action
3. After warming traffic, verify metadata has been corrected

## Example
In Divine Blossom, the HLS handler checked `transcode_status` in KV before GCS:
- ~57,000 objects in GCS bucket, most with HLS transcodes
- Many had `transcode_status: None` or `Processing` in KV (webhooks failed during backfill)
- Handler returned "202 transcoding in progress" for content that was already in GCS
- Fix: Check GCS first, serve if exists, auto-repair KV metadata as side effect

## Notes
- The auto-repair is best-effort — if the metadata update fails, don't fail the request
- This pattern works well with caching layers (CDN, VCL) because the repair only runs
  on cache misses, and subsequent requests hit the cache
- Consider running a batch metadata-repair script to fix all desynced records at once,
  rather than relying solely on on-demand repair
- Root cause should still be investigated (why did webhooks fail?) to prevent future desyncs
