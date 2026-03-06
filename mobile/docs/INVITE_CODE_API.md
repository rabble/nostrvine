# Invite System API

## Principles

- Invites gate **new Nostr identity creation only**, not app access.
- Existing Nostr users (import nsec, bunker, Keycast, Amber) **bypass invites entirely and MUST NOT call these endpoints**.
- Invites are a **growth valve and community-shaping tool, not a security wall**.
- The invitation graph tracks who invited whom for **growth analytics and cohort quality**, not for access control.
- Once a user has an npub and can authenticate via Nostr, invites are never re-checked for that user.

---

## Authentication

Authenticated endpoints use **NIP-98 HTTP Auth** (kind `27235`):

```
Authorization: Nostr <base64-encoded-signed-event>
```

The signed event proves ownership of a Nostr pubkey. The server validates the event ID (NIP-01 serialized SHA-256), verifies the BIP-340 Schnorr signature, checks expiration, and verifies the `u` (URL) and `method` tags match the actual request to prevent replay across endpoints.

The caller's pubkey is extracted from the verified event — it is never sent in the request body.

---

## Code Format

Invite codes use the format `XXXX-YYYY` — two groups of 4 alphanumeric characters from a reduced charset that excludes ambiguous characters (`0`/`O`, `1`/`I`/`L`). This gives 31^8 (~852 billion) possible codes.

Codes are **case-insensitive** on input (normalized to uppercase server-side).

---

## Mobile-Facing Endpoints

### 1. POST `/v1/consume-invite` (NIP-98 authenticated)

Atomically claim an invite code **during new identity creation**.

#### Flow

1. App generates nsec in memory (not yet persisted to secure storage).
2. App derives the pubkey from that nsec.
3. App creates a NIP-98 auth event signed with the new nsec.
4. App sends the code to this endpoint with the auth header.
5. If success: app persists nsec to secure storage, user proceeds.
6. If failure: app discards in-memory nsec, user stays at invite gate.

**MUST NOT be called for:**

- Users importing an existing nsec.
- Users logging in via bunker, Amber, or Keycast / external Nostr signer.
- Legacy account reclaim flows.

#### Request

```json
{
  "code": "AB23-EF7K"
}
```

| Field | Type | Description |
|-------|------|-------------|
| `code` | string | Invite code (case-insensitive, normalized to uppercase) |

The claiming pubkey is extracted from the NIP-98 auth header.

#### Responses

**Success (`200`):**

```json
{
  "message": "Welcome to diVine!",
  "codesAllocated": 5
}
```

New users receive a default allocation of invite codes to share.

**Code not found (`404`):**

```json
{
  "error": "Invite code not found"
}
```

**Already claimed or user already joined (`409`):**

```json
{
  "error": "Invite code is already used or revoked"
}
```

```json
{
  "error": "User has already joined"
}
```

#### Idempotency

- Same `code + pubkey` combination returns `200` success (retry-safe on network issues).
- A different pubkey on an already-claimed code returns `409`.

---

### 2. GET `/v1/invite-status` (NIP-98 authenticated)

Check whether the **current authenticated user** can generate invites and how many they have left.

The app uses this to decide **whether to show invite generation UI** and to display pending/claimed invites.

#### Responses

**Eligible inviter (`200`):**

```json
{
  "canInvite": true,
  "remaining": 3,
  "total": 5,
  "codes": [
    {
      "code": "AB23-EF7K",
      "claimed": true,
      "claimedAt": "2025-01-15T10:30:00Z",
      "claimedBy": "64_HEX_PUBKEY"
    },
    {
      "code": "HN4P-QR56",
      "claimed": false,
      "claimedAt": null,
      "claimedBy": null
    }
  ]
}
```

**Not eligible (default for most users) (`200`):**

```json
{
  "canInvite": false,
  "remaining": 0,
  "total": 0,
  "codes": []
}
```

If the user has no invite allocation, return `canInvite: false`.

---

### 3. POST `/v1/generate-invite` (NIP-98 authenticated)

Generate an invite code to share with others.

Eligibility is **NOT tied to how the user joined diVine**. Any authenticated user may generate invites **if** the server has granted them inviter status. This is controlled server-side by admins or policy, not automatic.

#### Request

No JSON body. Auth is via NIP-98 header proving pubkey ownership.

#### Responses

**Success (`201`):**

```json
{
  "code": "WX56-3MKT",
  "remaining": 4
}
```

**Not eligible (`403`):**

```json
{
  "error": "Not eligible to generate invites"
}
```

**Limit reached (`429`):**

```json
{
  "error": "Invite limit reached",
  "remaining": 0
}
```

---

### 4. POST `/v1/validate` (public)

Check if a code is valid without consuming it. No authentication required.

#### Request

```json
{
  "code": "AB23-EF7K"
}
```

#### Responses (`200`)

```json
{
  "valid": true,
  "code": "AB23-EF7K",
  "used": false
}
```

```json
{
  "valid": false,
  "code": null,
  "used": false
}
```

---

## Growth Endpoints

### 5. POST `/v1/waitlist` (public)

Join the invite waitlist. Complementary to direct code distribution — useful for organic signups before they have a code.

#### Request

```json
{
  "contact": "user@example.com",
  "pubkey": "64_HEX_OPTIONAL"
}
```

| Field | Type | Description |
|-------|------|-------------|
| `contact` | string | Email, social handle, or other contact info (required) |
| `pubkey` | string? | Optional Nostr pubkey if the user already has one |

#### Response (`201`)

```json
{
  "id": "a1b2c3d4e5f6g7h8",
  "message": "You're on the waitlist!"
}
```

---

### 6. POST `/v1/buy` (public)

Purchase an invite code with a [Cashu](https://cashu.space) ecash token. Enables permissionless onboarding via Lightning/Bitcoin payments.

#### Request

```json
{
  "token": "cashuA...",
  "pubkey": "64_HEX_OPTIONAL"
}
```

| Field | Type | Description |
|-------|------|-------------|
| `token` | string | Cashu token (cashuA-prefixed, base64url encoded) |
| `pubkey` | string? | Optional Nostr pubkey to associate with the purchased code |

The token must meet the configured minimum sats price and come from the accepted mint.

#### Response (`201`)

```json
{
  "code": "QR78-VBND",
  "amountSats": 1000
}
```

**Insufficient amount (`400`):**

```json
{
  "error": "Token amount 500 sats is less than required 1000 sats"
}
```

**Already redeemed (`409`):**

```json
{
  "error": "Cashu token has already been redeemed"
}
```

---

## Admin Endpoints (Server-Side Management)

These endpoints require NIP-98 auth from a pubkey in the server's admin allowlist. They are not called by the mobile app.

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/v1/admin/grant` | Allocate N invite codes to a user's pubkey |
| `POST` | `/v1/admin/approve-waitlist` | Approve a waitlist entry and issue a code |
| `POST` | `/v1/admin/revoke` | Revoke an invite code |
| `GET` | `/v1/admin/tree` | View the full invitation graph |
| `GET` | `/v1/admin/waitlist` | List all waitlist entries |
| `GET` | `/v1/admin/stats` | Global stats (codes created/used, users, waitlist size) |

---

## What Changed from v1 Spec

### Dropped

- **verify-npub** — existing Nostr users bypass the invite gate entirely.
- **deviceId** — replaced by pubkey association in the invite graph.
- **verify stored code on startup** — invite is a one-time identity creation gate, not a continuous entitlement check.
- **200-for-everything responses** — use proper HTTP status codes.

### Added

- **NIP-98 auth on consume** — proves key ownership instead of trusting a pubkey in the body.
- **validate** — public code validation without consuming.
- **waitlist** — organic signup funnel for users without a code.
- **buy** — Cashu ecash payments for permissionless onboarding.
- **Admin endpoints** — server-side management for granting, revoking, and monitoring.
- **XXXX-YYYY code format** — human-readable, ambiguous-char-free, ~40 bits of entropy.

### Changed

- **consume-invite** requires NIP-98 auth and maps `code → authenticated pubkey` (not body pubkey).
- **consume-invite** returns allocated code count on success (users get 5 codes by default).
- **invite-status** returns full code objects with claim details.
- **generate-invite** returns `201` on success.
