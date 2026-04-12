# divine-invite-darshan: Grant-on-Read for `/v1/invite-status`

## What to change

Modify the `GET /v1/invite-status` handler so that it evaluates whether to auto-grant new invite codes each time an authenticated user checks their status.

## Current behavior

1. User calls `GET /v1/invite-status` with NIP-98 auth
2. Server looks up their invite allocation by pubkey
3. Returns `{ canInvite, remaining, total, codes[] }`

## New behavior (grant-on-read)

1. User calls `GET /v1/invite-status` with NIP-98 auth
2. Server looks up their invite allocation by pubkey
3. **NEW:** If the user has no allocation OR all codes are claimed, evaluate the grant policy:
   - Check when the user first consumed an invite (account age) — skip if too new
   - Check when invites were last granted to this user (cooldown) — skip if too recent
   - Check total codes ever auto-granted to this user — skip if at max
   - Apply any other server-configured rules
4. **NEW:** If policy says yes: generate N new codes, associate them with the user's pubkey, persist to KV store
5. Return the full invite status including any newly granted codes

The response shape does NOT change:

```json
{
  "canInvite": true,
  "remaining": 3,
  "total": 5,
  "codes": [
    {
      "code": "AB23-EF7K",
      "claimed": false,
      "claimedAt": null,
      "claimedBy": null
    }
  ]
}
```

## Grant policy configuration

Add these keys to the `invite_config` config store so policy can be tuned without redeployment:

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `grant_cooldown_hours` | int | 168 (1 week) | Minimum hours between auto-grants for a single user |
| `grant_count` | int | 3 | Number of codes to grant per auto-grant |
| `min_account_age_hours` | int | 48 | Minimum account age before eligible for auto-grants |
| `max_total_grants` | int | 15 | Maximum total codes a user can be auto-granted (lifetime) |
| `auto_grant_enabled` | bool | true | Kill switch for the entire auto-grant feature |

## Per-user tracking

The server needs to track per user (by pubkey):

- `first_joined_at` — already tracked (from consume-invite)
- `last_auto_grant_at` — **NEW** — timestamp of last auto-grant
- `total_auto_granted` — **NEW** — lifetime count of auto-granted codes

Store these in the existing user record in the `invite_data` KV store.

## What NOT to change

- Response shape of `GET /v1/invite-status` — stays identical
- `POST /v1/generate-invite` — unchanged, still generates from existing allocation
- `POST /v1/consume-invite` — unchanged
- Admin endpoints — unchanged
- No new endpoints needed

## Edge cases

- If the user has never consumed an invite (e.g., imported nsec, bypassed gate), `first_joined_at` may not exist. In that case, skip auto-granting — the user isn't in the invite graph.
- If KV write fails during grant, return the pre-grant status (don't error the request). The next check will retry.
- If `auto_grant_enabled` is false, skip evaluation entirely and just return current status.

## Testing

- User with no allocation, meets policy → gets N new codes in response
- User with no allocation, too new (< min_account_age_hours) → no grant
- User with no allocation, granted recently (< grant_cooldown_hours) → no grant
- User at max_total_grants → no grant
- User with existing unclaimed codes → no grant (they still have codes to share)
- auto_grant_enabled = false → no grant regardless of eligibility
- KV write failure during grant → returns pre-grant status, no error
