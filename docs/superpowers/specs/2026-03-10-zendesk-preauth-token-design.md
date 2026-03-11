# Zendesk Pre-Auth Token Hardening

**Date:** 2026-03-10
**Status:** Approved
**Repos:** divine-relay-manager, divine-mobile

## Problem

The Zendesk mobile SDK JWT flow passes a `user_token` to `Identity.createJwt(token:)`. Zendesk forwards this token verbatim to our JWT endpoint. Today, the app passes the user's raw npub as the token. Since npubs are public, anyone who knows a user's npub could hit the JWT endpoint and impersonate that user's Zendesk identity — viewing and creating support tickets containing PII, device info, and support agent responses.

Zendesk's own docs warn: "You must not use any predictable user identifiers as a user token."

## Solution

Replace the raw npub with a **nonce-bound, HMAC-signed pre-auth token**. The app proves identity via NIP-98 to obtain a short-lived token, then passes that token to the Zendesk SDK. The JWT endpoint verifies the token's HMAC signature and confirms the nonce hasn't been consumed.

## Token Structure

The token is two base64url-encoded segments joined by `.`, following JWT conventions:

```
<base64url(JSON payload)> + "." + <base64url(HMAC-SHA256(base64url(JSON payload), ZENDESK_PREAUTH_SECRET))>
```

The HMAC is computed over the base64url-encoded payload string (not the raw JSON). The HMAC output is also base64url-encoded.

Payload claims:
- `pubkey` — 64-char hex, extracted from verified NIP-98 event
- `nonce` — `crypto.randomUUID()` (122 bits entropy)
- `exp` — Unix timestamp, 5 minutes from issuance
- `purpose` — `"zendesk-pre-auth"` (prevents cross-purpose use)

Signing secret: `ZENDESK_PREAUTH_SECRET`, stored in Cloudflare Secrets Store. Separate from `ZENDESK_JWT_SECRET` — different purpose, different key. Staging and production must use different values.

Estimated token size: ~220 characters (150-170 for payload + ~44 for HMAC + separator). Zendesk docs state `user_token` is a string with no format restrictions; no documented length limit.

## Server-Side Changes (divine-relay-manager)

### New endpoint: `POST /api/zendesk/pre-auth`

- Requires NIP-98 auth header (kind 27235)
- Verifies NIP-98 event (signature, timestamp within 60s, URL and method tags match)
- Generates nonce, builds token payload, HMAC-signs it
- Stores nonce in D1 with pubkey and expiry
- Returns `{ "success": true, "token": "<payload>.<signature>" }`

### Modified: `handleMobileJwt` form-urlencoded path

Verification pseudocode:
```
1. Receive user_token from form data
2. Split on "." — if no ".", treat as legacy npub (migration period only)
3. payload_b64 = parts[0], signature_b64 = parts[1]
4. Recompute HMAC-SHA256 over payload_b64 using ZENDESK_PREAUTH_SECRET
5. Constant-time compare computed HMAC with base64url-decoded signature_b64
6. If mismatch → 401
7. Base64url-decode payload_b64 → JSON parse → extract claims
8. Check purpose === "zendesk-pre-auth" → else 401
9. Check exp > now → else 401
10. Atomic: DELETE FROM zendesk_preauth_nonces WHERE nonce = ? AND pubkey = ? RETURNING *
11. If DELETE returned 0 rows → 401 (nonce already consumed or never existed)
12. Extract pubkey from claims, mint Zendesk JWT as before
```

The atomic `DELETE...RETURNING` prevents race conditions — two concurrent callbacks with the same nonce cannot both succeed.

### Migration: backward compatibility

During the transition period (old app versions still pass raw npubs):
- If `user_token` contains no `.` separator, treat as legacy npub (log a warning)
- Remove npub fallback in a later release once app adoption is sufficient

### D1 schema

```sql
CREATE TABLE zendesk_preauth_nonces (
  nonce TEXT PRIMARY KEY,
  pubkey TEXT NOT NULL,
  created_at INTEGER NOT NULL DEFAULT (unixepoch()),
  expires_at INTEGER NOT NULL
);
```

### Nonce cleanup

Add to existing cron trigger (`*/5 * * * *`):
```sql
DELETE FROM zendesk_preauth_nonces WHERE expires_at < unixepoch()
```

### Dead code removal

- Remove the NIP-98 JSON path from `handleMobileJwt`. This path was designed for direct app→JWT calls, which the pre-auth flow replaces. No code in divine-mobile calls this path today (confirmed: the app only uses the Zendesk SDK's callback flow, never calls `/mobile-jwt` directly).
- Remove `ZENDESK_JWT_CALLBACK_SECRET` from Env interface (already unused since callback secret check was removed).

## App-Side Changes (divine-mobile)

### Dependency injection approach

`ZendeskSupportService` uses static methods. `fetchPreAuthToken()` needs `Nip98AuthService` for signing. Rather than refactoring the entire service, `setJwtIdentity()` accepts `Nip98AuthService` as a parameter. Call sites in `vine_drawer.dart` already have `ref` access to read the provider.

### New: `fetchPreAuthToken()` in ZendeskSupportService

- Static method accepting `Nip98AuthService` as parameter
- Uses `Nip98AuthService` to create signed kind 27235 event for `POST <relay-manager-url>/api/zendesk/pre-auth`
- Makes HTTP call with `Authorization: Nostr <token>` header
- Returns the pre-auth token string
- Throws on failure

### Modified: `setJwtIdentity()`

- Signature changes from `setJwtIdentity(String userToken)` to `setJwtIdentity(Nip98AuthService nip98Service)`
- Internally calls `fetchPreAuthToken(nip98Service)`, passes result to native `Identity.createJwt(token:)`

### Modified: call sites in `vine_drawer.dart`

- Lines 346, 404, 442: `setJwtIdentity(npub)` becomes `setJwtIdentity(ref.read(nip98AuthServiceProvider))`

### Config: `RELAY_MANAGER_URL`

Already exists in `.env.example` and build config. Reused, not new.
- Production: `https://api-relay-prod.divine.video`
- Staging: `https://api-relay-staging.divine.video`

### Support requires login

- When JWT is enabled in Zendesk admin, `Identity.createAnonymous()` fails (mismatched identity types cause SDK network errors per Zendesk docs)
- Support menu item disabled or shows "log in to contact support" when user is not authenticated

### Dead code removal

- Remove REST API fallback path in `ZendeskSupportService` (`createTicketViaApi`)
- Remove `ZENDESK_API_TOKEN` and `ZENDESK_API_EMAIL` from build config (no longer needed for ticket creation)

## Security Properties

| Property | Mechanism |
|----------|-----------|
| Identity proof | NIP-98 event signed with user's private key |
| Token integrity | HMAC-SHA256 with server-only secret |
| Replay prevention | Single-use nonce, atomically consumed via DELETE...RETURNING |
| Time-bounding | 5-minute expiry, enforced on verification |
| Cross-purpose prevention | `purpose` claim in token payload |
| Key separation | `ZENDESK_PREAUTH_SECRET` separate from `ZENDESK_JWT_SECRET` |
| Cross-environment isolation | Different `ZENDESK_PREAUTH_SECRET` per environment |

## Error Handling

| Scenario | Behavior |
|----------|----------|
| User not logged in | Support flow blocked, show "log in" message |
| Pre-auth call fails (network) | Show error, user retries |
| Zendesk callback with consumed nonce | 401, user sees auth error, retaps Support for fresh token |
| D1 unavailable | Pre-auth returns 500, support degraded, core app unaffected |
| HMAC verification fails | 401, token rejected |
| Old app version (raw npub) | Accepted during migration period with warning log |

## Known Limitations

- **Zendesk SDK retry:** If Zendesk retries the callback (undocumented but theoretically possible), the consumed nonce causes a 401. User must re-trigger support flow.
- **Keycast signing latency:** Remote NIP-46 signing adds ~200-500ms to the pre-auth round-trip. Acceptable for a "tap Support" action.
- **Requires relay-manager availability:** Support flow depends on relay-manager being up. Today it only depends on Zendesk.
- **5-minute TTL:** The Zendesk SDK calls the JWT endpoint immediately when `Identity.createJwt()` is invoked (before the ticket form opens), so 5 minutes is generous. The token is consumed before the user starts typing.

## Future Consideration

This JWT endpoint may migrate to Keycast (auth service) in the future. The pre-auth token design is portable — the same HMAC verification logic works regardless of which service hosts it.
