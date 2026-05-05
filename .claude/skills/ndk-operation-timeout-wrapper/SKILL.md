---
name: ndk-operation-timeout-wrapper
description: |
  Fix NDK (Nostr Dev Kit) operations hanging indefinitely when relay connections stall.
  Use when: (1) App freezes during fetchEvents or publish calls, (2) No timeout errors
  despite network issues, (3) Relay connection appears stuck, (4) Using NDK with unstable
  or slow relays. NDK operations have no built-in timeout - wrap with Promise.race.
author: Claude Code
version: 1.0.0
date: 2026-01-31
---

# NDK Operation Timeout Wrapper

## Problem
NDK (nostr-dev-kit) operations like `fetchEvents()` and `ndkEvent.publish()` have no
built-in timeout. When relay connections stall or become unresponsive, these operations
hang indefinitely, causing the application to freeze without any error message.

## Context / Trigger Conditions
- Application freezes during Nostr operations
- No timeout error thrown despite minutes of waiting
- Works sometimes, hangs randomly (relay-dependent)
- Log shows operation started but never completes
- Using NDK with multiple relays where some may be unreliable

## Solution

Create a timeout wrapper function:

```typescript
const NDK_TIMEOUT_MS = 30000; // 30 seconds

async function withTimeout<T>(
  promise: Promise<T>,
  ms: number,
  operation: string
): Promise<T> {
  let timeoutId: ReturnType<typeof setTimeout>;
  const timeoutPromise = new Promise<never>((_, reject) => {
    timeoutId = setTimeout(
      () => reject(new Error(`${operation} timed out after ${ms}ms`)),
      ms
    );
  });

  try {
    const result = await Promise.race([promise, timeoutPromise]);
    clearTimeout(timeoutId!);
    return result;
  } catch (error) {
    clearTimeout(timeoutId!);
    throw error;
  }
}
```

Wrap all NDK operations:

```typescript
// Connect with timeout
await withTimeout(ndk.connect(), NDK_TIMEOUT_MS, "NDK connect");

// Fetch events with timeout
const events = await withTimeout(
  ndk.fetchEvents({ kinds: [0], authors: [pubkey] }),
  NDK_TIMEOUT_MS,
  "fetch profile"
);

// Publish with timeout
const relaySet = NDKRelaySet.fromRelayUrls(relayUrls, ndk);
await withTimeout(
  ndkEvent.publish(relaySet),
  NDK_TIMEOUT_MS,
  "relay publish"
);
```

Also ensure timeout errors are retryable:

```typescript
function isRetryableError(error: unknown): boolean {
  if (error instanceof Error) {
    const message = error.message.toLowerCase();
    const errorName = error.name.toLowerCase();
    if (
      message.includes("timeout") ||
      message.includes("aborted") ||
      errorName.includes("timeout") ||
      errorName.includes("abort")
    ) {
      return true;
    }
  }
  return false;
}
```

## Verification
After implementing, operations that previously hung should now:
1. Throw a timeout error after the specified duration
2. Allow retry logic to attempt the operation again
3. Log the specific operation that timed out

## Example

**Before (hangs forever):**
```typescript
const events = await ndk.fetchEvents({ kinds: [34236], "#d": [vineId] });
```

**After (times out and can retry):**
```typescript
const events = await withTimeout(
  ndk.fetchEvents({ kinds: [34236], "#d": [vineId] }),
  30000,
  "check video exists"
);
```

## Notes
- 30 seconds is a reasonable default; adjust based on expected operation duration
- Consider shorter timeouts for existence checks, longer for batch operations
- Wrap ALL NDK operations, not just problematic ones (any can hang)
- This pattern applies to any async library without built-in timeouts
- For AbortController support (if library supports it), prefer that over Promise.race

## References
- NDK GitHub: https://github.com/nostr-dev-kit/ndk
- Promise.race pattern: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Promise/race
