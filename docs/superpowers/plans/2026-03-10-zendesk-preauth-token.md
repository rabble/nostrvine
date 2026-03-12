# Zendesk Pre-Auth Token Hardening Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace raw npub with nonce-bound HMAC-signed pre-auth token in the Zendesk JWT identity flow, preventing impersonation via public keys.

**Architecture:** App proves identity via NIP-98 to a new `/api/zendesk/pre-auth` endpoint on divine-relay-manager, receives an HMAC-signed short-lived token, and passes that to the Zendesk SDK instead of the raw npub. The existing `/api/zendesk/mobile-jwt` callback verifies the token's HMAC signature and single-use nonce before minting the Zendesk JWT.

**Tech Stack:** TypeScript (Cloudflare Workers, D1), Dart/Flutter (divine-mobile), HMAC-SHA256, NIP-98

**Spec:** `docs/superpowers/specs/2026-03-10-zendesk-preauth-token-design.md`

**Cross-repo:** This plan spans two repositories:
- `~/code/divine-relay-manager` — server-side (Tasks 1-5)
- `~/code/divine-mobile` — app-side (Tasks 6-9)

---

## Chunk 1: Server-Side (divine-relay-manager)

### Task 1: D1 Schema — Nonce Table

**Files:**
- Create: `worker/migrations/NNNN_zendesk_preauth_nonces.sql` (determine next number from existing migrations)

- [ ] **Step 1: Check existing migrations and create migration file**

```bash
ls ~/code/divine-relay-manager/worker/migrations/
```

Use the next available migration number (e.g., if `0002_*` exists, use `0003`). Create the file:

```sql
-- Migration: Add zendesk_preauth_nonces table for single-use pre-auth tokens
CREATE TABLE IF NOT EXISTS zendesk_preauth_nonces (
  nonce TEXT PRIMARY KEY,
  pubkey TEXT NOT NULL,
  created_at INTEGER NOT NULL DEFAULT (unixepoch()),
  expires_at INTEGER NOT NULL
);

CREATE INDEX idx_nonces_expires ON zendesk_preauth_nonces(expires_at);
```

- [ ] **Step 2: Apply migration to staging D1**

```bash
cd ~/code/divine-relay-manager/worker
npx wrangler d1 execute divine-moderation-decisions-staging --file=migrations/NNNN_zendesk_preauth_nonces.sql --config=wrangler.staging.toml
```

Expected: table created successfully.

- [ ] **Step 3: Verify table exists**

```bash
npx wrangler d1 execute divine-moderation-decisions-staging --command="SELECT name FROM sqlite_master WHERE type='table' AND name='zendesk_preauth_nonces'" --config=wrangler.staging.toml
```

Expected: one row returned.

- [ ] **Step 4: Commit**

```bash
git add worker/migrations/
git commit -m "chore(d1): add zendesk_preauth_nonces table for pre-auth tokens"
```

---

### Task 2: Pre-Auth Token Generation and Verification Helpers

**Files:**
- Create: `worker/src/zendesk-preauth.ts`
- Create: `worker/src/zendesk-preauth.test.ts`

Pure functions with no external dependencies (except `crypto.subtle`), easy to test.

`generatePreAuthToken` returns `{ token, nonce, expiresAt }` so callers can store the nonce in D1 without re-parsing the token.

- [ ] **Step 1: Write failing tests for token generation**

File: `worker/src/zendesk-preauth.test.ts`

```typescript
import { describe, it, expect } from 'vitest';
import { generatePreAuthToken, verifyPreAuthToken } from './zendesk-preauth';

const TEST_SECRET = 'test-secret-key-for-hmac-signing-1234567890abcdef';

describe('generatePreAuthToken', () => {
  it('returns token, nonce, and expiresAt', async () => {
    const result = await generatePreAuthToken('aabbccdd'.repeat(8), TEST_SECRET);
    expect(result.token).toBeDefined();
    expect(result.nonce).toBeDefined();
    expect(result.nonce.length).toBe(36); // UUID format
    expect(result.expiresAt).toBeGreaterThan(Math.floor(Date.now() / 1000));
  });

  it('token has two dot-separated base64url segments', async () => {
    const { token } = await generatePreAuthToken('aabbccdd'.repeat(8), TEST_SECRET);
    const parts = token.split('.');
    expect(parts).toHaveLength(2);
    expect(parts[0].length).toBeGreaterThan(0);
    expect(parts[1].length).toBeGreaterThan(0);
  });

  it('embeds pubkey, nonce, exp, and purpose in the payload', async () => {
    const pubkey = 'aabbccdd'.repeat(8);
    const { token } = await generatePreAuthToken(pubkey, TEST_SECRET);
    const payloadB64 = token.split('.')[0];
    const padding = '='.repeat((4 - (payloadB64.length % 4)) % 4);
    const payload = JSON.parse(atob(payloadB64.replace(/-/g, '+').replace(/_/g, '/') + padding));
    expect(payload.pubkey).toBe(pubkey);
    expect(payload.purpose).toBe('zendesk-pre-auth');
    expect(typeof payload.nonce).toBe('string');
    expect(payload.exp).toBeGreaterThan(Math.floor(Date.now() / 1000));
  });

  it('generates unique nonces on each call', async () => {
    const pubkey = 'aabbccdd'.repeat(8);
    const r1 = await generatePreAuthToken(pubkey, TEST_SECRET);
    const r2 = await generatePreAuthToken(pubkey, TEST_SECRET);
    expect(r1.nonce).not.toBe(r2.nonce);
  });
});

describe('verifyPreAuthToken', () => {
  it('returns valid result for a freshly generated token', async () => {
    const pubkey = 'aabbccdd'.repeat(8);
    const { token } = await generatePreAuthToken(pubkey, TEST_SECRET);
    const result = await verifyPreAuthToken(token, TEST_SECRET);
    expect(result.valid).toBe(true);
    expect(result.pubkey).toBe(pubkey);
    expect(result.nonce).toBeDefined();
  });

  it('rejects a token with a tampered payload', async () => {
    const pubkey = 'aabbccdd'.repeat(8);
    const { token } = await generatePreAuthToken(pubkey, TEST_SECRET);
    const [, sig] = token.split('.');
    const tamperedPayload = btoa(JSON.stringify({ pubkey: '1111111111111111'.repeat(4), nonce: 'fake', exp: 9999999999, purpose: 'zendesk-pre-auth' }))
      .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
    const tamperedToken = `${tamperedPayload}.${sig}`;
    const result = await verifyPreAuthToken(tamperedToken, TEST_SECRET);
    expect(result.valid).toBe(false);
    expect(result.error).toContain('signature');
  });

  it('rejects a token with wrong secret', async () => {
    const pubkey = 'aabbccdd'.repeat(8);
    const { token } = await generatePreAuthToken(pubkey, TEST_SECRET);
    const result = await verifyPreAuthToken(token, 'wrong-secret');
    expect(result.valid).toBe(false);
  });

  it('rejects a token with wrong purpose', async () => {
    const pubkey = 'aabbccdd'.repeat(8);
    const payload = { pubkey, nonce: crypto.randomUUID(), exp: Math.floor(Date.now() / 1000) + 300, purpose: 'wrong-purpose' };
    const payloadB64 = btoa(JSON.stringify(payload)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
    const key = await crypto.subtle.importKey('raw', new TextEncoder().encode(TEST_SECRET), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
    const sigBytes = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(payloadB64));
    const sigB64 = btoa(String.fromCharCode(...new Uint8Array(sigBytes))).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
    const token = `${payloadB64}.${sigB64}`;
    const result = await verifyPreAuthToken(token, TEST_SECRET);
    expect(result.valid).toBe(false);
    expect(result.error).toContain('purpose');
  });

  it('rejects an expired token', async () => {
    const pubkey = 'aabbccdd'.repeat(8);
    const payload = { pubkey, nonce: crypto.randomUUID(), exp: Math.floor(Date.now() / 1000) - 60, purpose: 'zendesk-pre-auth' };
    const payloadB64 = btoa(JSON.stringify(payload)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
    const key = await crypto.subtle.importKey('raw', new TextEncoder().encode(TEST_SECRET), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
    const sigBytes = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(payloadB64));
    const sigB64 = btoa(String.fromCharCode(...new Uint8Array(sigBytes))).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
    const token = `${payloadB64}.${sigB64}`;
    const result = await verifyPreAuthToken(token, TEST_SECRET);
    expect(result.valid).toBe(false);
    expect(result.error).toContain('expired');
  });

  it('rejects a malformed token without dot separator', async () => {
    const result = await verifyPreAuthToken('nodot', TEST_SECRET);
    expect(result.valid).toBe(false);
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd ~/code/divine-relay-manager/worker
npx vitest run src/zendesk-preauth.test.ts
```

Expected: FAIL — module not found.

- [ ] **Step 3: Implement token generation and verification**

File: `worker/src/zendesk-preauth.ts`

```typescript
// ABOUTME: Pre-auth token generation and verification for Zendesk JWT hardening
// ABOUTME: Produces nonce-bound, HMAC-signed tokens that replace raw npub as user_token

const TOKEN_TTL_SECONDS = 300; // 5 minutes
const TOKEN_PURPOSE = 'zendesk-pre-auth';

interface PreAuthPayload {
  pubkey: string;
  nonce: string;
  exp: number;
  purpose: string;
}

interface GenerateResult {
  token: string;
  nonce: string;
  expiresAt: number;
}

interface VerifyResult {
  valid: boolean;
  pubkey?: string;
  nonce?: string;
  error?: string;
}

function base64UrlEncode(data: string): string {
  return btoa(data)
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');
}

function base64UrlDecode(str: string): string {
  let base64 = str.replace(/-/g, '+').replace(/_/g, '/');
  while (base64.length % 4) {
    base64 += '=';
  }
  return atob(base64);
}

async function hmacSign(data: string, secret: string): Promise<Uint8Array> {
  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign']
  );
  const sigBytes = await crypto.subtle.sign(
    'HMAC',
    key,
    new TextEncoder().encode(data)
  );
  return new Uint8Array(sigBytes);
}

async function hmacVerify(data: string, signature: Uint8Array, secret: string): Promise<boolean> {
  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['verify']
  );
  return crypto.subtle.verify(
    'HMAC',
    key,
    signature,
    new TextEncoder().encode(data)
  );
}

export async function generatePreAuthToken(pubkey: string, secret: string): Promise<GenerateResult> {
  const nonce = crypto.randomUUID();
  const expiresAt = Math.floor(Date.now() / 1000) + TOKEN_TTL_SECONDS;

  const payload: PreAuthPayload = {
    pubkey,
    nonce,
    exp: expiresAt,
    purpose: TOKEN_PURPOSE,
  };

  const payloadB64 = base64UrlEncode(JSON.stringify(payload));
  const sigBytes = await hmacSign(payloadB64, secret);
  const sigB64 = base64UrlEncode(String.fromCharCode(...sigBytes));

  return {
    token: `${payloadB64}.${sigB64}`,
    nonce,
    expiresAt,
  };
}

export async function verifyPreAuthToken(token: string, secret: string): Promise<VerifyResult> {
  const dotIndex = token.indexOf('.');
  if (dotIndex === -1) {
    return { valid: false, error: 'Malformed token: no dot separator' };
  }

  const payloadB64 = token.substring(0, dotIndex);
  const sigB64 = token.substring(dotIndex + 1);

  // Verify HMAC signature (constant-time via crypto.subtle.verify)
  let sigBytes: Uint8Array;
  try {
    const sigStr = base64UrlDecode(sigB64);
    sigBytes = new Uint8Array(sigStr.length);
    for (let i = 0; i < sigStr.length; i++) {
      sigBytes[i] = sigStr.charCodeAt(i);
    }
  } catch {
    return { valid: false, error: 'Malformed token: invalid signature encoding' };
  }

  const signatureValid = await hmacVerify(payloadB64, sigBytes, secret);
  if (!signatureValid) {
    return { valid: false, error: 'Invalid HMAC signature' };
  }

  // Decode and validate payload
  let payload: PreAuthPayload;
  try {
    payload = JSON.parse(base64UrlDecode(payloadB64));
  } catch {
    return { valid: false, error: 'Malformed token: invalid payload' };
  }

  if (payload.purpose !== TOKEN_PURPOSE) {
    return { valid: false, error: `Invalid purpose: expected ${TOKEN_PURPOSE}` };
  }

  const now = Math.floor(Date.now() / 1000);
  if (payload.exp <= now) {
    return { valid: false, error: 'Token expired' };
  }

  return {
    valid: true,
    pubkey: payload.pubkey,
    nonce: payload.nonce,
  };
}

export { TOKEN_PURPOSE, TOKEN_TTL_SECONDS };
export type { PreAuthPayload, GenerateResult, VerifyResult };
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd ~/code/divine-relay-manager/worker
npx vitest run src/zendesk-preauth.test.ts
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add worker/src/zendesk-preauth.ts worker/src/zendesk-preauth.test.ts
git commit -m "feat: add pre-auth token generation and verification helpers

HMAC-SHA256 signed tokens with nonce, expiry, and purpose claims.
Constant-time signature verification via crypto.subtle.verify."
```

---

### Task 3: New `/api/zendesk/pre-auth` Endpoint

**Files:**
- Modify: `worker/src/index.ts` — add import at top of file (~line 11), add to Env interface (~line 38), add route in `handleZendeskRoutes` (~line 1765), add handler function before `handleMobileJwt` (~line 2115)

**Reference:** `verifyNip98Auth` at line 1354, `handleMobileJwt` at line 2120.

- [ ] **Step 1: Add import at top of file**

At the top of `worker/src/index.ts` (with other imports, around line 11):

```typescript
import { generatePreAuthToken, verifyPreAuthToken } from './zendesk-preauth';
```

- [ ] **Step 2: Add `ZENDESK_PREAUTH_SECRET` to the Env interface**

In the `Env` interface (~line 38), add:

```typescript
  ZENDESK_PREAUTH_SECRET?: string;  // HMAC secret for pre-auth token signing/verification
```

- [ ] **Step 3: Add the pre-auth handler function**

Add before `handleMobileJwt` (around line 2115). Uses `console.warn`/`console.log` matching codebase logging convention:

```typescript
async function handleZendeskPreAuth(
  request: Request,
  env: Env,
  corsHeaders: Record<string, string>
): Promise<Response> {
  // Require NIP-98 authentication
  const authResult = await verifyNip98Auth(request, request.url);
  if (!authResult.valid) {
    console.warn('[handleZendeskPreAuth] NIP-98 verification failed:', authResult.error);
    return jsonResponse(
      { success: false, error: `Authentication failed: ${authResult.error}` },
      401,
      corsHeaders
    );
  }

  const pubkey = authResult.pubkey!;

  if (!env.ZENDESK_PREAUTH_SECRET) {
    console.error('[handleZendeskPreAuth] ZENDESK_PREAUTH_SECRET not configured');
    return jsonResponse(
      { success: false, error: 'Pre-auth not configured' },
      500,
      corsHeaders
    );
  }

  if (!env.DB) {
    console.error('[handleZendeskPreAuth] D1 database not available');
    return jsonResponse(
      { success: false, error: 'Database not available' },
      500,
      corsHeaders
    );
  }

  // Generate the pre-auth token (returns token + nonce + expiresAt)
  const { token, nonce, expiresAt } = await generatePreAuthToken(pubkey, env.ZENDESK_PREAUTH_SECRET);

  // Store nonce in D1 for single-use verification
  try {
    await env.DB.prepare(
      'INSERT INTO zendesk_preauth_nonces (nonce, pubkey, expires_at) VALUES (?, ?, ?)'
    ).bind(nonce, pubkey, expiresAt).run();
  } catch (err) {
    console.error('[handleZendeskPreAuth] Failed to store nonce in D1:', err);
    return jsonResponse({ success: false, error: 'Failed to create pre-auth token' }, 500, corsHeaders);
  }

  console.log(`[handleZendeskPreAuth] Token generated for pubkey ${pubkey.substring(0, 8)}...`);

  return jsonResponse({ success: true, token }, 200, corsHeaders);
}
```

- [ ] **Step 4: Add route in `handleZendeskRoutes`**

In `handleZendeskRoutes` (~line 1765), add the new route before the `/mobile-jwt` route:

```typescript
  // Pre-auth token endpoint — requires NIP-98, returns HMAC-signed token
  if (subPath === '/pre-auth' && request.method === 'POST') {
    return handleZendeskPreAuth(request, env, corsHeaders);
  }
```

- [ ] **Step 5: Commit**

```bash
git add worker/src/index.ts
git commit -m "feat: add /api/zendesk/pre-auth endpoint

NIP-98 authenticated endpoint that issues HMAC-signed pre-auth tokens.
Stores nonce in D1 for single-use verification."
```

---

### Task 4: Modify `handleMobileJwt` to Verify Pre-Auth Tokens

**Files:**
- Modify: `worker/src/index.ts` — `handleMobileJwt` function (~line 2120)

**This task modifies the form-urlencoded path to verify pre-auth tokens, with backward-compatible npub fallback during migration.**

- [ ] **Step 1: Modify the form-urlencoded branch**

In `handleMobileJwt`, replace the form-urlencoded handling block (after `if (contentType.includes('application/x-www-form-urlencoded'))`) with:

```typescript
    if (contentType.includes('application/x-www-form-urlencoded')) {
      // Zendesk server-to-server callback — forwards the user_token we provided
      const formData = await request.formData();
      const userToken = formData.get('user_token') as string | null;
      name = formData.get('name') as string | null || undefined;
      email = formData.get('email') as string | null || undefined;

      if (!userToken) {
        return jsonResponse({ success: false, error: 'Missing user_token' }, 400, corsHeaders);
      }

      // Check if this is a pre-auth token (contains dot separator) or legacy npub
      if (userToken.includes('.') && env.ZENDESK_PREAUTH_SECRET) {
        // Pre-auth token path: verify HMAC + consume nonce
        const tokenResult = await verifyPreAuthToken(userToken, env.ZENDESK_PREAUTH_SECRET);
        if (!tokenResult.valid) {
          console.warn(`[handleMobileJwt] Pre-auth token verification failed: ${tokenResult.error}`);
          return jsonResponse({ success: false, error: 'Invalid pre-auth token' }, 401, corsHeaders);
        }

        if (!env.DB) {
          console.error('[handleMobileJwt] D1 database not available for nonce check');
          return jsonResponse({ success: false, error: 'Database not available' }, 500, corsHeaders);
        }

        // Atomic nonce consumption — DELETE returns the row if it existed
        const nonceResult = await env.DB.prepare(
          'DELETE FROM zendesk_preauth_nonces WHERE nonce = ? AND pubkey = ? RETURNING *'
        ).bind(tokenResult.nonce, tokenResult.pubkey).first();

        if (!nonceResult) {
          console.warn(`[handleMobileJwt] Nonce already consumed or not found: ${tokenResult.nonce}`);
          return jsonResponse({ success: false, error: 'Token already used or invalid' }, 401, corsHeaders);
        }

        pubkey = tokenResult.pubkey!;
        console.log(`[handleMobileJwt] Pre-auth token verified for pubkey ${pubkey.substring(0, 8)}...`);

      } else {
        // Legacy npub path — backward compatibility for old app versions
        // TODO: Remove this fallback once app adoption of pre-auth tokens is sufficient
        console.warn('[handleMobileJwt] Legacy npub token received (no pre-auth verification)');

        if (userToken.startsWith('npub1')) {
          try {
            const decoded = nip19.decode(userToken);
            if (decoded.type === 'npub') {
              pubkey = decoded.data as string;
            }
          } catch (e) {
            return jsonResponse({ success: false, error: 'Invalid npub format' }, 400, corsHeaders);
          }
        } else if (/^[0-9a-f]{64}$/i.test(userToken)) {
          pubkey = userToken.toLowerCase();
        } else {
          return jsonResponse({ success: false, error: 'Invalid user_token format' }, 400, corsHeaders);
        }
      }
    }
```

- [ ] **Step 2: Remove the NIP-98 JSON path from `handleMobileJwt`**

Find the `else if` block that handles JSON + NIP-98 auth (around line 2177-2197). This path was for direct app-to-JWT calls — nothing in divine-mobile calls this path today (the app only uses the Zendesk SDK's callback flow). The pre-auth flow replaces its purpose. Remove the entire `else if` block. Keep the final `else` error case for unsupported content types.

Ensure the remaining code after this block (pubkey validation, JWT generation at lines 2199+) is preserved and properly connected.

- [ ] **Step 3: Remove `ZENDESK_JWT_CALLBACK_SECRET` from Env interface**

Remove from the Env interface (~line 38):
```typescript
  ZENDESK_JWT_CALLBACK_SECRET?: string;  // For /api/zendesk/mobile-jwt form-urlencoded callback
```

Verify nothing else references it first: `grep -rn 'ZENDESK_JWT_CALLBACK_SECRET' worker/src/`

- [ ] **Step 4: Add nonce cleanup to the cron handler**

In the `scheduled` handler (~line 283), add expired nonce cleanup **after** the existing ReportWatcher try/catch block, before the function returns. Guard against `env.DB` being undefined:

```typescript
  // Clean up expired pre-auth nonces
  if (env.DB) {
    try {
      const deleted = await env.DB.prepare(
        'DELETE FROM zendesk_preauth_nonces WHERE expires_at < unixepoch()'
      ).run();
      if (deleted.meta.changes > 0) {
        console.log(`[scheduled] Cleaned up ${deleted.meta.changes} expired pre-auth nonces`);
      }
    } catch (err) {
      console.error('[scheduled] Failed to clean up pre-auth nonces:', err);
    }
  }
```

- [ ] **Step 5: Commit**

```bash
git add worker/src/index.ts
git commit -m "feat: verify pre-auth tokens in JWT callback, add legacy npub fallback

Zendesk callback now verifies HMAC signature and consumes single-use
nonce. Legacy npub format accepted during migration with warning log.
Removes unused NIP-98 JSON path and ZENDESK_JWT_CALLBACK_SECRET."
```

---

### Task 5: Deploy and Configure Secrets

**Files:**
- No code changes — deployment and secret configuration

- [ ] **Step 1: Generate two separate pre-auth secrets**

```bash
echo "Staging:"; openssl rand -hex 32
echo "Production:"; openssl rand -hex 32
```

Save both outputs. Staging and production **must** use different values for cross-environment isolation.

- [ ] **Step 2: Set the secret in staging**

```bash
cd ~/code/divine-relay-manager/worker
npx wrangler secret put ZENDESK_PREAUTH_SECRET --config=wrangler.staging.toml
```

Paste the staging secret when prompted.

- [ ] **Step 3: Set the secret in production**

```bash
npx wrangler secret put ZENDESK_PREAUTH_SECRET --config=wrangler.prod.toml
```

Paste the production secret when prompted.

- [ ] **Step 4: Apply D1 migration to production**

```bash
npx wrangler d1 execute divine-moderation-decisions-prod --file=migrations/NNNN_zendesk_preauth_nonces.sql --config=wrangler.prod.toml
```

(Use the same migration filename from Task 1.)

- [ ] **Step 5: Deploy to staging**

```bash
npx wrangler deploy --config=wrangler.staging.toml
```

- [ ] **Step 6: Deploy to production**

```bash
npx wrangler deploy --config=wrangler.prod.toml
```

- [ ] **Step 7: Verify endpoints respond**

```bash
# Should return 401 (no NIP-98 auth)
curl -s -X POST https://api-relay-staging.divine.video/api/zendesk/pre-auth | jq .

# Legacy npub path should still work on /mobile-jwt (Zendesk callback format)
curl -s -X POST https://api-relay-staging.divine.video/api/zendesk/mobile-jwt \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d 'user_token=npub1test' | jq .
```

---

## Chunk 2: App-Side (divine-mobile)

### Important Notes for Chunk 2

These issues were identified during review and must be handled:

1. **`RELAY_MANAGER_URL` must use `EnvironmentConfig`, not `String.fromEnvironment`.** The codebase uses `EnvironmentConfig` for environment-aware URLs. Add a `relayManagerApiUrl` getter to `EnvironmentConfig`.
2. **NIP-98 token caching will break repeated pre-auth requests.** `Nip98AuthService` caches tokens by URL+method for 10 minutes, but the server-side NIP-98 check requires timestamps within 60 seconds. Clear the cache before creating the auth token.
3. **Capture `nip98Service` before drawer closes.** The `vine_drawer.dart` comment at line 288-289 warns: "All services and values must be captured BEFORE the drawer is closed, because ref becomes invalid after widget unmounts." Capture `nip98Service` at the same point as `userPubkey`.
4. **`createTicketViaApi` has a caller in `profile_setup_screen.dart:1670`.** The reserved username flow uses `createTicketViaApi` directly. This caller must be updated or the method kept for that use case.
5. **`_createTicketWithFormViaApi` (lines 729-795) also uses `apiToken`/`apiEmail`.** This REST API path is used by `createStructuredBugReport` and `createFeatureRequest` as a desktop fallback. Must be addressed before removing config values.
6. **Preserve the `_initialized` guard** in `setJwtIdentity` — don't make the pre-auth HTTP call if the SDK isn't initialized.

### Task 6: Add `relayManagerApiUrl` to EnvironmentConfig and `fetchPreAuthToken`

**Files:**
- Modify: `mobile/lib/models/environment_config.dart` — add `relayManagerApiUrl` getter
- Modify: `mobile/lib/services/zendesk_support_service.dart` — add `fetchPreAuthToken` static method
- Modify: `mobile/test/services/zendesk_support_service_test.dart` — add test
- Reference: `mobile/lib/services/relay_notification_api_service.dart:220-252` — NIP-98 HTTP call pattern

- [ ] **Step 1: Add `relayManagerApiUrl` to `EnvironmentConfig`**

Read `mobile/lib/models/environment_config.dart` first to understand the existing pattern. Add a getter:

```dart
String get relayManagerApiUrl {
  switch (environment) {
    case AppEnvironment.local:
      return 'http://$localHost:8787'; // Wrangler dev default port
    case AppEnvironment.poc:
    case AppEnvironment.test:
    case AppEnvironment.staging:
      return 'https://api-relay-staging.divine.video';
    case AppEnvironment.production:
      return 'https://api-relay-prod.divine.video';
  }
}
```

Verify the `AppEnvironment` enum values by reading the file first. Adjust the switch cases to match.

- [ ] **Step 2: Add `fetchPreAuthToken` method**

Add to `mobile/lib/services/zendesk_support_service.dart`. Accept `relayManagerUrl` and `Nip98AuthService` as parameters. Clear the NIP-98 cache before creating the token to avoid stale timestamps:

```dart
/// Fetches a pre-auth token from relay-manager by proving identity via NIP-98.
///
/// The token is HMAC-signed and nonce-bound — it replaces the raw npub
/// as the Zendesk SDK user_token to prevent impersonation.
///
/// Throws [Exception] if the pre-auth request fails.
static Future<String> fetchPreAuthToken({
  required Nip98AuthService nip98Service,
  required String relayManagerUrl,
}) async {
  final url = '$relayManagerUrl/api/zendesk/pre-auth';

  // Clear NIP-98 cache to avoid reusing a token with a stale timestamp.
  // The server requires created_at within 60s, but tokens are cached 10min.
  nip98Service.clearTokenCache();

  // Create NIP-98 auth token for this endpoint
  final authToken = await nip98Service.createAuthToken(
    url: url,
    method: HttpMethod.post,
  );

  if (authToken == null) {
    throw Exception('Failed to create NIP-98 auth token');
  }

  final response = await http.post(
    Uri.parse(url),
    headers: {
      'Authorization': authToken.authorizationHeader,
      'Content-Type': 'application/json',
    },
  );

  if (response.statusCode != 200) {
    Log.error(
      'Pre-auth token request failed: ${response.statusCode} ${response.body}',
      category: LogCategory.network,
    );
    throw Exception('Pre-auth request failed: ${response.statusCode}');
  }

  final data = jsonDecode(response.body) as Map<String, dynamic>;
  if (data['success'] != true || data['token'] == null) {
    throw Exception('Pre-auth response missing token');
  }

  Log.debug(
    'Pre-auth token obtained successfully',
    category: LogCategory.network,
  );

  return data['token'] as String;
}
```

Add necessary imports (check which already exist first):
```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:openvine/services/nip98_auth_service.dart';
```

- [ ] **Step 3: Write test**

Check existing test patterns in `mobile/test/services/zendesk_support_service_test.dart` first (`head -80`). Follow the same mock/setup style. Test that `fetchPreAuthToken` calls `createAuthToken` with the correct URL and method, and parses the response correctly.

- [ ] **Step 4: Run tests**

```bash
cd ~/code/divine-mobile/mobile
flutter test test/services/zendesk_support_service_test.dart
```

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/models/environment_config.dart mobile/lib/services/zendesk_support_service.dart mobile/test/services/zendesk_support_service_test.dart
git commit -m "feat: add fetchPreAuthToken for NIP-98 authenticated pre-auth flow

Adds relayManagerApiUrl to EnvironmentConfig. Clears NIP-98 token
cache before each pre-auth request to avoid stale timestamps."
```

---

### Task 7: Modify `setJwtIdentity` to Use Pre-Auth Token

**Files:**
- Modify: `mobile/lib/services/zendesk_support_service.dart:223` — change `setJwtIdentity` signature
- Modify: `mobile/lib/widgets/vine_drawer.dart` — update call sites, capture `nip98Service` before drawer closes

- [ ] **Step 1: Update `setJwtIdentity`**

At line 223 of `zendesk_support_service.dart`. Preserve the `_initialized` guard:

```dart
/// Sets Zendesk JWT identity using a pre-auth token obtained via NIP-98.
///
/// Fetches a pre-auth token from relay-manager (proving identity with
/// the user's private key), then passes it to the Zendesk SDK.
///
/// Throws [Exception] if pre-auth fails. Returns false if SDK not initialized.
static Future<bool> setJwtIdentity({
  required Nip98AuthService nip98Service,
  required String relayManagerUrl,
}) async {
  if (!_initialized) {
    Log.warning(
      'Zendesk not initialized, cannot set JWT identity',
      category: LogCategory.ui,
    );
    return false;
  }

  try {
    final preAuthToken = await fetchPreAuthToken(
      nip98Service: nip98Service,
      relayManagerUrl: relayManagerUrl,
    );
    final result = await _channel.invokeMethod<bool>(
      'setJwtIdentity',
      {'userToken': preAuthToken},
    );
    return result ?? false;
  } catch (e) {
    Log.error(
      'Failed to set JWT identity: $e',
      category: LogCategory.network,
    );
    return false;
  }
}
```

- [ ] **Step 2: Update call sites in `vine_drawer.dart`**

**Critical:** Capture `nip98Service` BEFORE the drawer closes (around line 146-149, where `userPubkey` is captured). Then pass it through to the handler methods.

In the Support `onTap` handler (around line 132), add to the captures before `Navigator.of(context).pop()`:

```dart
final nip98Service = ref.read(nip98AuthServiceProvider);
```

Then update `_showSupportOptionsDialog` to accept and pass `nip98Service`.

At line 346 (View Past Messages):
```dart
// Before:
final npub = NostrKeyUtils.encodePubKey(userPubkey);
await ZendeskSupportService.setJwtIdentity(npub);

// After:
await ZendeskSupportService.setJwtIdentity(
  nip98Service: nip98Service,
  relayManagerUrl: relayManagerUrl,
);
```

Similarly at lines 404 and 442. The `relayManagerUrl` comes from `EnvironmentConfig` — read the current environment config provider to get it. Capture this before the drawer closes too.

The `nip98AuthServiceProvider` is declared in `app_providers.dart` (re-exported via barrel), which is already imported in `vine_drawer.dart` at line 12.

- [ ] **Step 3: Run analyzer and tests**

```bash
cd ~/code/divine-mobile/mobile
flutter analyze lib/services/zendesk_support_service.dart lib/widgets/vine_drawer.dart
flutter test test/services/zendesk_support_service_test.dart
```

- [ ] **Step 4: Commit**

```bash
git add mobile/lib/services/zendesk_support_service.dart mobile/lib/widgets/vine_drawer.dart
git commit -m "feat: use pre-auth token instead of raw npub for Zendesk JWT identity

setJwtIdentity now fetches a pre-auth token via NIP-98 from
relay-manager. Captures nip98Service before drawer closes to
avoid accessing ref after widget disposal."
```

---

### Task 8: Require Login for Support, Clean Up REST API Code

**Files:**
- Modify: `mobile/lib/widgets/vine_drawer.dart` — gate Support on login
- Modify: `mobile/lib/services/zendesk_support_service.dart` — remove `createTicketViaApi` and REST API fallback in `createTicket`
- Modify: `mobile/lib/screens/profile_setup_screen.dart:1670` — update caller of `createTicketViaApi`

- [ ] **Step 1: Check all callers of `createTicketViaApi` and `_createTicketWithFormViaApi`**

```bash
cd ~/code/divine-mobile/mobile
grep -rn 'createTicketViaApi\|_createTicketWithFormViaApi' lib/
```

Identify all callers. Known callers:
- `zendesk_support_service.dart` internal PlatformException fallback (~line 408-424)
- `profile_setup_screen.dart:1670` — reserved username request

For `profile_setup_screen.dart`: Replace the `createTicketViaApi` call with `createTicket` (native SDK path), since JWT auth will be active. If the reserved username flow needs to work without native SDK (macOS), consider keeping `createTicketViaApi` for that one use case or filing a follow-up issue.

- [ ] **Step 2: Gate the Support drawer item on login**

In `vine_drawer.dart`, add an early return at the top of the Support `onTap` handler:

```dart
_DrawerItem(
  title: 'Support',
  onTap: () async {
    final userPubkey = authService.currentPublicKeyHex;
    if (userPubkey == null) {
      Navigator.of(context).pop();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Log in to contact support'),
            backgroundColor: VineTheme.error,
          ),
        );
      }
      return;
    }
    // ... rest of existing handler
  },
),
```

- [ ] **Step 3: Remove REST API fallback from `createTicket`**

In `zendesk_support_service.dart`, find the `PlatformException` catch block in `createTicket` (~line 408-424) that falls back to `createTicketViaApi`. Remove that fallback — let the error propagate to the caller.

- [ ] **Step 4: Remove `createTicketViaApi` method**

Remove `createTicketViaApi` (~lines 503-577) from `zendesk_support_service.dart`. If `profile_setup_screen.dart` still needs it, keep it but mark with a TODO to migrate.

- [ ] **Step 5: Check `_createTicketWithFormViaApi` and `_buildRequester`**

```bash
grep -rn '_createTicketWithFormViaApi\|_buildRequester' lib/
```

These methods also use `apiToken`/`apiEmail`. If they are only used by `createStructuredBugReport` and `createFeatureRequest` as desktop fallbacks, and desktop is not a current target, remove them. If they have active callers, keep them with a TODO.

- [ ] **Step 6: Run analyzer and tests**

```bash
cd ~/code/divine-mobile/mobile
flutter analyze
flutter test
```

Fix any unused import warnings. Update or remove tests referencing removed methods.

- [ ] **Step 7: Commit**

```bash
git add mobile/lib/services/zendesk_support_service.dart mobile/lib/widgets/vine_drawer.dart mobile/lib/screens/profile_setup_screen.dart
git commit -m "fix: require login for support, remove REST API ticket fallback

Support flow now requires authentication. REST API fallback removed
from createTicket. Updated profile_setup_screen reserved username flow."
```

---

### Task 9: Clean Up Dead Config

**Files:**
- Modify: `mobile/lib/config/zendesk_config.dart` — remove `apiToken` and `apiEmail` (only if no remaining callers)
- Modify: `mobile/.env` and `mobile/.env.example` — remove `ZENDESK_API_TOKEN` and `ZENDESK_API_EMAIL`

- [ ] **Step 1: Check what still references these config values**

```bash
cd ~/code/divine-mobile/mobile
grep -rn 'ZENDESK_API_TOKEN\|ZENDESK_API_EMAIL\|ZendeskConfig\.apiToken\|ZendeskConfig\.apiEmail' lib/ test/
```

**Only proceed with removal if no remaining references exist.** If `_createTicketWithFormViaApi` was kept in Task 8, these config values must stay too. In that case, skip this task and file a follow-up to clean up when the REST API paths are fully removed.

- [ ] **Step 2: Remove from `zendesk_config.dart`**

Remove `apiToken` and `apiEmail` constants (~lines 26-32). Keep `appId`, `clientId`, and `url`.

- [ ] **Step 3: Remove from `.env` and `.env.example`**

Remove the `ZENDESK_API_TOKEN` and `ZENDESK_API_EMAIL` lines.

- [ ] **Step 4: Remove from build scripts**

```bash
grep -rn 'ZENDESK_API_TOKEN\|ZENDESK_API_EMAIL' ~/code/divine-mobile/
```

Remove from any `--dart-define` flags in build configurations. Do not use `git add -A` — add specific files:

- [ ] **Step 5: Run analyzer and tests**

```bash
cd ~/code/divine-mobile/mobile
flutter analyze
flutter test
```

- [ ] **Step 6: Commit**

```bash
git add mobile/lib/config/zendesk_config.dart mobile/.env mobile/.env.example
git commit -m "chore: remove unused Zendesk REST API config (apiToken, apiEmail)

No longer needed — ticket creation uses native SDK with JWT auth."
```
