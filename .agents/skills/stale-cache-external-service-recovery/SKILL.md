---
name: stale-cache-external-service-recovery
description: |
  Handle stale local cache when external service loses/resets data. Use when:
  (1) Token refresh fails with "not found" or 404 errors, (2) Cached identifiers
  (pubkeys, user IDs) don't exist on external service anymore, (3) External service
  was reset/migrated but local cache has old values. Pattern: detect 404 specifically,
  delete stale cache entry, recreate on external service, update cache with new values.
  Complements local-cache-idempotency-fallback skill.
author: Claude Code
version: 1.0.0
date: 2026-01-25
---

# Stale Cache Recovery When External Service Loses Data

## Problem

When using your database as a cache/idempotency layer (see `local-cache-idempotency-fallback`),
a new failure mode emerges: the external service loses or resets its data, but your
cache still has the old values. Operations fail with misleading errors because the cached
identifiers don't exist on the external service anymore.

## Context / Trigger Conditions

- Token refresh fails with 404 "User with pubkey/id not found"
- Operations fail with "Invalid or expired token" but the real issue is missing user
- External service was reset, migrated, or lost data
- Cached identifiers (pubkeys, API keys, user IDs) are valid in cache but not on service
- Error message is misleading - suggests token issue when it's actually a missing resource

## Solution

Detect the specific "not found" case and handle it separately from other errors:

```typescript
if (cached) {
  pubkey = cached.pubkey;
  token = cached.token;

  try {
    // Try to refresh/validate the cached credentials
    const freshToken = await externalApi.getTokenByPubkey(pubkey);
    token = freshToken;
    console.log(`Pubkey: ${pubkey} (token refreshed)`);
  } catch (error) {
    const errMsg = error instanceof Error ? error.message : String(error);

    // CRITICAL: Detect "not found" specifically - cache is stale
    if (errMsg.includes("not found") || response.status === 404) {
      console.log(`Cached identifier not on external service, recreating...`);

      // 1. Delete stale cache entry
      await db.deleteUser(userId);

      // 2. Create fresh resource on external service
      const result = await externalApi.createUser(userId, username);
      pubkey = result.pubkey;
      token = result.token;
      console.log(`Pubkey: ${pubkey} (recreated)`);

      // 3. Cache new values
      await db.saveUser({ userId, pubkey, token });
    } else {
      // Other error (e.g., user claimed account, rate limit) - can't proceed
      console.log(`Refresh failed: ${errMsg}`);
      continue; // or throw
    }
  }
}
```

### Key Pattern

1. **Attempt normal refresh first**: Try to validate/refresh cached credentials
2. **Detect 404 specifically**: Check for "not found" in error message or 404 status
3. **Delete stale entry**: Remove the invalid cache entry before recreating
4. **Recreate on external**: Create fresh resource with same input identifiers
5. **Update cache**: Store new values for future runs
6. **Distinguish from other errors**: Only handle 404; other errors may need different handling

## Verification

1. Simulate external service data loss (or clear its database)
2. Run script with stale local cache
3. Should see "recreating" message, not crash with 401/404
4. New values cached and used for subsequent operations
5. Script completes successfully

## Example

Real-world application - Keycast pubkey cache recovery:

```typescript
const cached = await pgDb.getImportedUser(creator.user_id);
let pubkey: string;
let token: string;

if (cached) {
  pubkey = cached.pubkey;
  token = cached.token;

  try {
    const freshToken = await keycast.getTokenByPubkey(pubkey);
    token = freshToken;
    await pgDb.saveImportedUser({ ...cached, token: freshToken });
    console.log(`Pubkey: ${pubkey} (token refreshed)`);
  } catch (refreshError) {
    const errMsg = refreshError instanceof Error ? refreshError.message : String(refreshError);

    if (errMsg.includes("not found")) {
      // Keycast doesn't have this pubkey - cache is stale
      console.log(`Cached pubkey not on Keycast, recreating user...`);

      // Delete stale entry
      await pgDb.deleteImportedUser(creator.user_id);

      // Create fresh user
      const result = await keycast.createPreloadedUser(
        creator.user_id,
        username,
        displayName
      );
      pubkey = result.pubkey;
      token = result.token;
      console.log(`Pubkey: ${pubkey} (recreated)`);

      // Cache new account
      await pgDb.saveImportedUser({
        vine_user_id: creator.user_id,
        username: creator.username,
        pubkey,
        token,
        events_published: 0,
      });
    } else {
      // Other error - user may have claimed account, can't proceed
      console.log(`Token refresh failed: ${errMsg}`);
      console.log(`Skipping ${creator.username} - cannot sign events`);
      continue;
    }
  }
}
```

## Notes

- This complements `local-cache-idempotency-fallback` - use both together
- The misleading error chain: 404 "not found" → continue with stale token → 401 "invalid token"
- Always delete before recreate to avoid accumulating orphan cache entries
- Consider logging which entries were stale for debugging/monitoring
- If external service is frequently losing data, investigate root cause
- The new pubkey will be different from the old one - downstream systems may need updates

## Related Skills

- `local-cache-idempotency-fallback`: The base pattern this skill extends
- Database retry logic for connection resets (separate concern)
