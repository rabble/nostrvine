---
name: local-cache-idempotency-fallback
description: |
  Use database cache when external APIs aren't reliably idempotent. Use when:
  (1) External API claims idempotency but returns different values for same input,
  (2) Re-running a script creates duplicate resources, (3) Need stable identifiers
  across runs but external service generates new ones. Pattern: check database cache
  first, only call external API for genuinely new items, cache the result.
author: Claude Code
version: 1.0.0
date: 2026-01-25
---

# Local Cache as Idempotency Fallback

## Problem

External APIs that should be idempotent (same input = same output) sometimes aren't.
This causes problems when re-running scripts:
- Duplicate resources created
- Identifiers change between runs
- State becomes inconsistent across systems

## Context / Trigger Conditions

- Re-running a script creates new resources instead of finding existing ones
- External API "fixed" idempotency but still returns different values
- Need stable identifiers (pubkeys, user IDs, resource IDs) across runs
- Script works once but fails on subsequent runs due to changed IDs

## Solution

Use database cache as the source of truth for idempotency:

```typescript
// BEFORE: Always calls external API (brittle)
const { pubkey, token } = await externalApi.createUser(userId, username);
await db.saveUser({ userId, pubkey, token });

// AFTER: Check cache first (robust)
const cached = await db.getUser(userId);
let pubkey: string;
let token: string;

if (cached) {
  // Use cached values - stable across runs
  pubkey = cached.pubkey;
  token = cached.token;
  console.log(`Using cached pubkey: ${pubkey}`);
} else {
  // Only call external API for genuinely new items
  const result = await externalApi.createUser(userId, username);
  pubkey = result.pubkey;
  token = result.token;

  // Cache immediately for next run
  await db.saveUser({ userId, pubkey, token });
  console.log(`Created new pubkey: ${pubkey}`);
}
```

### Key Pattern

1. **Check local first**: Always query your database before calling external API
2. **Use cached values**: If found, use local values even if stale
3. **Only create when missing**: External API called only for genuinely new items
4. **Cache immediately**: Save result right after successful API call
5. **Log the source**: Indicate whether value is "(cached)" or "(new)" for debugging

## Verification

- Re-run script multiple times
- Same identifier used each time (from cache)
- No duplicate resources created in external system
- Script is idempotent regardless of external API behavior

## Example

Real-world application - Keycast account creation:

```typescript
// Check if we have a cached account first (local DB is source of truth)
const cached = await db.getImportedUser(creator.user_id);
let pubkey: string;
let token: string;

if (cached) {
  // Use cached account - pubkey is stable
  pubkey = cached.pubkey;
  token = cached.token;
  console.log(`Pubkey: ${pubkey} (cached)`);
} else {
  // Create new account via external API
  const result = await keycast.createPreloadedUser(
    creator.user_id,
    username,
    displayName
  );
  pubkey = result.pubkey;
  token = result.token;
  console.log(`Pubkey: ${pubkey} (new)`);

  // Cache account in database immediately
  await db.saveImportedUser({
    vine_user_id: creator.user_id,
    username: creator.username,
    pubkey,
    token,
  });
}
```

## Notes

- This pattern works even when the external API claims to be idempotent
- Database schema should use the input identifier as primary key (prevents duplicates)
- Consider adding timestamps to track when cached values were created
- For critical systems, add reconciliation logic to detect/fix drift
- The cache becomes your source of truth - treat it accordingly

## Related Patterns

- **Upsert on conflict**: Use `ON CONFLICT DO UPDATE` to handle race conditions
- **Soft delete**: Keep old records to track history of changes
- **Cache invalidation**: Add TTL or manual refresh if external values can legitimately change

## Related Skills

- `stale-cache-external-service-recovery`: What to do when external service loses data and
  cached identifiers no longer exist (detect 404, delete cache, recreate)
