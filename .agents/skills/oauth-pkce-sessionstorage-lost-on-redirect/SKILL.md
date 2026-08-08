---
name: oauth-pkce-sessionstorage-lost-on-redirect
description: |
  Fix OAuth PKCE "Session not found" or "No code verifier" errors in SPAs after redirect
  from external auth server. Use when: (1) OAuth callback fails with session/verifier not found
  despite flow starting correctly, (2) PKCE code_verifier stored in sessionStorage is missing
  after redirect back from auth server, (3) Error only happens in production or cross-origin
  redirects, not in local dev. Root cause: sessionStorage is lost when the browser opens a new
  tab, changes browsing context, or certain browsers clear it during cross-origin navigation.
  Fix: use localStorage instead (clean up after exchange).
author: Claude Code
version: 1.0.0
date: 2026-03-23
---

# OAuth PKCE sessionStorage Lost on Redirect

## Problem
OAuth PKCE flow fails at the code exchange step because the PKCE code verifier stored in
`sessionStorage` is missing after the redirect from the external authorization server.
The error message typically says "Session not found" or "No code verifier found" with no
indication that the storage backend is the issue.

## Context / Trigger Conditions
- SPA initiates OAuth PKCE flow, storing code_verifier in `sessionStorage`
- User is redirected to external auth server (e.g., `login.example.com`)
- Auth server redirects back to SPA callback URL with `?code=...&state=...`
- SPA tries to exchange code but can't find the PKCE verifier
- Error message is about "session not found" or "missing verifier", NOT about storage
- Works fine in local development (same-origin), fails in production (cross-origin)

## Root Cause
`sessionStorage` is scoped per-tab AND per-origin, and has additional fragility:
1. If the auth server opens a new tab or popup, the new tab has empty sessionStorage
2. Some browsers (especially Safari with ITP) may clear sessionStorage during cross-origin
   navigation chains
3. If the auth server does multiple redirects (302 chains), some browsers treat the
   return as a new browsing context
4. Mobile browsers are particularly aggressive about clearing sessionStorage

## Solution
Switch from `sessionStorage` to `localStorage` for the PKCE code verifier storage:

```typescript
// BEFORE (fragile)
const client = createOAuthClient({
  storage: sessionStorage,
});

// AFTER (reliable)
const client = createOAuthClient({
  storage: localStorage,
});
```

The security concern with localStorage (verifier persists longer) is mitigated because:
- The PKCE verifier is single-use; the auth server rejects it after first exchange
- Most OAuth SDKs clean up the verifier after successful `exchangeCode()`
- `getAuthorizationUrl()` overwrites any stale verifier on new flow start

## Verification
1. Start OAuth flow on the SPA
2. Complete auth on the external server
3. Callback should successfully exchange the code without "session not found" errors
4. Check `localStorage` — the `divine_pkce` (or equivalent) key should be cleaned up
   after successful exchange

## Example
From `@divinevideo/login` SDK integration:

```typescript
function createClient() {
  return createDivineClient({
    serverUrl: 'https://login.divine.video',
    clientId: 'divine-web',
    redirectUri: buildCallbackUrl(),
    // localStorage survives cross-origin redirects more reliably than sessionStorage
    storage: localStorage,
  });
}
```

## Notes
- If the OAuth SDK doesn't accept a `storage` parameter, you may need to manually
  store/retrieve the verifier in localStorage and pass it to `exchangeCode(verifier)`
- Also move any return-path or state data from sessionStorage to localStorage if it
  needs to survive the redirect
- In test environments (jsdom/vitest), `localStorage` may not be fully implemented;
  provide an in-memory Storage stub in test setup
- The SDK's README often recommends localStorage — check docs before defaulting to
  sessionStorage for "security"
