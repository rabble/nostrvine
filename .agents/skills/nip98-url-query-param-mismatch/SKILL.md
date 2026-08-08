---
name: nip98-url-query-param-mismatch
description: |
  Fix NIP-98 HTTP authentication 401 errors caused by URL mismatch between the `u` tag
  and what the server expects. Use when: (1) NIP-98 auth returns 401 with "URL mismatch" error,
  (2) Token creation succeeds but server rejects authentication, (3) Server logs show
  expected vs actual URL difference. CRITICAL: Server implementations vary - some strip
  query params, some don't. Check the actual error message to determine which behavior applies.
author: Claude Code
version: 1.1.0
date: 2026-02-01
---

# NIP-98 URL Query Parameter Mismatch

## Problem
NIP-98 HTTP authentication fails with 401 Unauthorized even though the token is created
successfully and the signature is valid. The actual cause is a URL mismatch between
the `u` tag in the signed event and what the server expects.

## Context / Trigger Conditions
- Server returns 401 Unauthorized for NIP-98 protected endpoints
- Logs show token creation succeeded (event signed and validated)
- Error response contains "URL mismatch" with expected vs actual URLs
- The URLs differ only by query parameters

Example error response:
```json
{"error":"Auth failed: URL mismatch: expected .../notifications, got .../notifications?limit=50"}
```

## Root Cause

**The NIP-98 spec says:**
> The `u` tag MUST be exactly the same as the absolute request URL (including query parameters).

**But server implementations vary:**
- Some servers follow the spec strictly (require query params in `u` tag)
- Some servers normalize URLs by stripping query params before validation
- You MUST match what your specific server does

## Solution

**Step 1: Add logging to see the actual error**
```dart
} else if (response.statusCode == 401) {
  Log.error(
    'NIP-98 auth failed (401)\n'
    'URL: $url\n'
    'Response: ${response.body}',  // <-- This reveals the actual issue
    ...
  );
}
```

**Step 2: Check the error message**
- If error says "expected .../path?params, got .../path" → Include query params
- If error says "expected .../path, got .../path?params" → Strip query params

**Step 3: Adjust URL normalization accordingly**

For servers that STRIP query params (like Divine Relay):
```dart
final uri = Uri.parse(url);
// Server strips query params before NIP-98 validation
final normalizedUrl = '${uri.scheme}://${uri.host}${uri.path}';
```

For servers that REQUIRE query params (per NIP-98 spec):
```dart
final uri = Uri.parse(url);
final normalizedUrl = uri.hasQuery
    ? '${uri.scheme}://${uri.host}${uri.path}?${uri.query}'
    : '${uri.scheme}://${uri.host}${uri.path}';
```

## Verification
1. After the fix, the URLs in the `u` tag should match what server expects
2. The 401 error should be replaced by successful authentication (200)
3. Check logs to confirm URL matching

## Example

**Divine Relay behavior (strips query params):**
- Request URL: `https://relay.dvines.org/api/users/abc/notifications?limit=50`
- Server validates against: `https://relay.dvines.org/api/users/abc/notifications`
- `u` tag must be: `https://relay.dvines.org/api/users/abc/notifications`

## Notes
- The NIP-98 spec is clear about including query params, but not all servers follow it
- Always check the actual error response to determine server behavior
- When in doubt, try both approaches and see which works
- Consider filing a bug with servers that don't follow the spec

## References
- [NIP-98 HTTP Auth Specification](https://github.com/nostr-protocol/nips/blob/master/98.md)
- Spec quote: "The `u` tag MUST be exactly the same as the absolute request URL (including query parameters)"
- Reality: Server implementations vary, always check actual behavior
