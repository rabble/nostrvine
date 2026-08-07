---
name: fastly-kv-concurrent-write-retry
description: |
  Fix intermittent 500 errors with "Failed to store" in Fastly KV Store during concurrent
  writes. Use when: (1) Batch operations fail with ~10-20% error rate, (2) Error contains
  "Failed to store list" or similar KV write failures, (3) Multiple requests updating the
  same KV key simultaneously, (4) Read-modify-write pattern without locking. The fix is
  adding a retry loop that re-reads before each write attempt.
author: Claude Code
version: 1.0.0
date: 2026-01-28
---

# Fastly KV Store Concurrent Write Race Condition

## Problem
When multiple concurrent requests perform read-modify-write operations on the same
Fastly KV Store key, writes can fail with intermittent 500 errors. This commonly
occurs during batch uploads where each request updates a shared list or counter.

## Context / Trigger Conditions
- Error message contains "Failed to store list:" or similar KV write failure
- ~10-20% failure rate during concurrent operations
- Multiple requests from the same user/session updating shared state
- Pattern: `read key → modify data → write key` without any locking

Example error:
```json
{"error":"Failed to store list:"}
```

## Solution

Add a retry loop that re-reads the data before each write attempt:

```rust
/// Add item to list with retry for concurrent writes
pub fn add_to_list(key: &str, item: &str) -> Result<()> {
    // Retry up to 5 times for concurrent write conflicts
    for attempt in 0..5 {
        // Re-read current state on each attempt
        let mut items = get_list(key)?;

        if items.contains(&item.to_string()) {
            return Ok(()); // Already exists, done
        }

        items.push(item.to_string());

        match put_list(key, &items) {
            Ok(()) => return Ok(()),
            Err(e) if attempt < 4 => {
                eprintln!("[KV] Retry {} for list update: {}", attempt + 1, e);
                // Re-read picks up concurrent writes
                continue;
            }
            Err(e) => return Err(e),
        }
    }

    Err(Error::new("Max retries exceeded for list update"))
}
```

Key points:
1. **Re-read on each retry** - The fresh read picks up changes from concurrent writes
2. **Check for duplicates** - Avoid adding the same item twice
3. **Log retries** - Helps debug if issues persist
4. **Limit retries** - 5 attempts is usually sufficient

## Verification
- Batch operations that previously failed ~16% should now succeed ~100%
- Retry log messages (`[KV] Retry N for...`) indicate the mechanism is working
- If still failing after 5 retries, there may be a deeper issue

## Example

Before (race condition):
```rust
pub fn add_to_user_list(pubkey: &str, hash: &str) -> Result<()> {
    let mut hashes = get_user_blobs(pubkey)?;  // Read
    if !hashes.contains(&hash) {
        hashes.push(hash.to_string());         // Modify
        put_user_list(pubkey, &hashes)?;       // Write - CONFLICT!
    }
    Ok(())
}
```

After (with retry):
```rust
pub fn add_to_user_list(pubkey: &str, hash: &str) -> Result<()> {
    for attempt in 0..5 {
        let mut hashes = get_user_blobs(pubkey)?;
        if hashes.contains(&hash) {
            return Ok(());
        }
        hashes.push(hash.to_string());
        match put_user_list(pubkey, &hashes) {
            Ok(()) => return Ok(()),
            Err(e) if attempt < 4 => continue,
            Err(e) => return Err(e),
        }
    }
    Err(Error::new("Max retries exceeded"))
}
```

## Notes
- Fastly Compute doesn't have `sleep()`, so retries happen immediately
- The re-read is what provides the "delay" by picking up concurrent changes
- Consider using atomic operations if available (Fastly KV doesn't support CAS)
- For high-contention scenarios, consider sharding the key space
- This pattern also applies to remove operations (read-filter-write)

## References
- [Fastly KV Store Documentation](https://developer.fastly.com/reference/compute/kv-store/)
