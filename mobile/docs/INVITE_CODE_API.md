# Invite System API - Mobile App Endpoints

## Principles

- Invites gate **new Nostr identity creation only**, not app access.
- Existing Nostr users (import nsec, bunker, Keycast, Amber) **bypass invites entirely and MUST NOT call these endpoints**.
- Invites are a **growth valve and community-shaping tool, not a security wall**.
- The invitation graph tracks who invited whom for **growth analytics and cohort quality**, not for access control.
- Once a user has an npub and can authenticate via Nostr, invites are never re-checked for that user.

---

## 1. POST `/v1/consume-invite`

Atomically claim an invite code **during new identity creation**.

### Flow

1. App generates nsec in memory (not yet persisted to secure storage).
2. App derives the pubkey from that nsec.
3. App sends `code + pubkey` to this endpoint.
4. If success: app persists nsec to secure storage, user proceeds.
5. If failure: app discards in-memory nsec, user stays at invite gate.

**MUST NOT be called for:**

- Users importing an existing nsec.
- Users logging in via bunker, Amber, or Keycast / external Nostr signer.
- Legacy account reclaim flows.

This endpoint is only for users who **do not already have an npub** and are creating a brand-new identity.

### Request

```json
{
  "code": "ABCD1234",
  "pubkey": "64_HEX_CHARS"
}
```

| Field | Type | Description |
|-------|------|-------------|
| `code` | string | 8-character alphanumeric invite code (case-insensitive, normalized to uppercase) |
| `pubkey` | string | 64-character hex public key derived from the in-memory nsec |

### Responses (all `200`)

**Success:**

```json
{
  "valid": true,
  "code": "ABCD1234",
  "claimedAt": "2025-01-15T10:30:00Z"
}
```

**Invalid code:**

```json
{
  "valid": false,
  "message": "Invalid invite code"
}
```

**Already claimed (by a different pubkey):**

```json
{
  "valid": false,
  "message": "This code has already been claimed"
}
```

### Idempotency

- Same `code + pubkey` combination returns success (retry-safe on network issues).
- A different `pubkey` on an already-claimed `code` returns failure.

---

## 2. GET `/v1/invite-status` (NIP-98 authenticated)

Check whether the **current authenticated user** can generate invites and how many they have left.

The app uses this to decide **whether to show invite generation UI** and to display pending/claimed invites.

### Responses

**Eligible inviter:**

```json
{
  "canInvite": true,
  "remaining": 3,
  "total": 5,
  "codes": [
    {
      "code": "ABCD1234",
      "claimed": true,
      "claimedAt": "2025-01-15T10:30:00Z"
    },
    {
      "code": "EFGH5678",
      "claimed": false,
      "claimedAt": null
    }
  ]
}
```

**Not eligible (default for most users):**

```json
{
  "canInvite": false,
  "remaining": 0,
  "total": 0,
  "codes": []
}
```

If the user is not found in the inviter list, return `canInvite: false`.

---

## 3. POST `/v1/generate-invite` (NIP-98 authenticated)

Generate an invite code to share with others.

Eligibility is **NOT tied to how the user joined diVine**. Any authenticated user may generate invites **if** the server has granted them inviter status. This is controlled server-side by admins or policy, not automatic.

### Request

No JSON body. Auth is via NIP-98 header proving pubkey ownership.

### Responses

**Success (`200`):**

```json
{
  "code": "WXYZ5678",
  "remaining": 4
}
```

**Not eligible (`403`):**

```json
{
  "message": "Not eligible to generate invites"
}
```

**Limit reached (`429`):**

```json
{
  "message": "Invite limit reached",
  "remaining": 0
}
```

---

## What changed from v1 spec

### Dropped

- **verify-npub** - existing Nostr users bypass the invite gate entirely.
- **join-waitlist** - growth controlled by who gets codes and how many, not by a central waitlist gate.
- **deviceId** - replaced by pubkey association in the invite graph.
- **verify stored code on startup** - invite is a one-time identity creation gate, not a continuous entitlement check.

### Added

- **invite-status** - for the app to check if a user can generate invites and show their codes.
- **generate-invite** - for user-driven, invite-based growth.

### Changed

- **consume-invite** maps `code -> pubkey` (and inviter) instead of `code -> device`.
- **consume-invite** is only called during new identity creation, never for existing Nostr user login, nsec import, or legacy reclaim flows.
