---
name: hono-subapp-undefined-response-1101
description: |
  Fix Cloudflare Workers Error 1101 "Worker threw exception" caused by Hono sub-app route
  handlers returning undefined instead of a Response. Use when: (1) Error 1101 on a specific
  hostname but not others sharing the same worker, (2) "the Promise did not resolve to
  'Response'" in wrangler dev logs, (3) Hono sub-app route handler uses bare `return` to
  skip handling for non-matching hostnames or conditions. The fix is to add `next` parameter
  and call `return next()` instead of bare `return` in route handlers that conditionally skip.
author: Claude Code
version: 1.0.0
date: 2026-02-27
---

# Hono Sub-App Route Handler Returns Undefined → CF Error 1101

## Problem
A Cloudflare Worker using Hono with sub-apps crashes with Error 1101 ("Worker threw
exception") when a route handler in a sub-app returns `undefined` instead of a `Response`.
This commonly happens when route handlers have hostname guards that use bare `return` to
skip processing, intending to let other routes handle the request.

## Context / Trigger Conditions
- Cloudflare Workers dashboard or browser shows **Error 1101: Worker threw exception**
- `wrangler dev` logs show: **"Incorrect type for Promise: the Promise did not resolve to 'Response'"**
- Multiple hostnames route to the same worker (e.g., `names.divine.video` and `names.admin.divine.video`)
- Hono sub-app has route handlers with conditional hostname checks that use bare `return`
- The sub-app has middleware that calls `next()` for non-matching hostnames, but the route handlers duplicate the check and return `undefined`

## Root Cause
In Hono, **route handlers** (`.get()`, `.post()`, etc.) MUST return a `Response`. Only
**middleware** (registered via `.use()`) can call `next()` to pass control downstream.

However, if a route handler includes `next` in its parameter list (`async (c, next) => {}`),
Hono treats it as middleware-like, allowing `return next()` to pass control to the next
matching handler.

A bare `return` (which returns `undefined`) from a route handler causes the Cloudflare
Workers runtime to throw because it expects a `Response` object.

## Solution

**Bad** — returns `undefined`, crashes the worker:
```typescript
app.get('/', async (c) => {
  if (!ALLOWED_HOSTNAMES.includes(hostname)) {
    return // undefined! → Error 1101
  }
  return c.html(page())
})
```

**Good** — accepts `next` parameter and calls it to pass control:
```typescript
app.get('/', async (c, next) => {
  if (!ALLOWED_HOSTNAMES.includes(hostname)) {
    return next() // passes to next handler in chain
  }
  return c.html(page())
})
```

Key insight: Adding `next` to the handler signature changes Hono's treatment of the
handler, allowing it to delegate to downstream routes.

## Verification
1. Run `wrangler dev` and curl with the non-matching hostname:
   ```bash
   curl -s -o /dev/null -w "%{http_code}" http://localhost:8787/ -H "Host: other.example.com"
   ```
2. Should return a valid HTTP status (200, 404, etc.) instead of 500
3. No "did not resolve to Response" errors in the terminal

## Example
A worker serves both `names.divine.video` (public UI) and `names.admin.divine.video`
(admin SPA). The public routes sub-app has a landing page handler that only responds for
`names.divine.video`. When `names.admin.divine.video` hits this handler, it should pass
through to the catch-all admin SPA handler. Using bare `return` crashes the worker;
using `return next()` (with `next` in params) properly delegates.

## Notes
- This only applies to Hono route handlers, not middleware (`.use()` handlers always have `next`)
- The error is invisible in Cloudflare's dashboard — you only see generic "Error 1101"
- `wrangler dev` gives the real error: "the Promise did not resolve to 'Response'"
- If your sub-app middleware already guards routes, you may not need hostname checks in individual handlers at all — but if you do, use the `next` pattern
- This pattern is common in multi-tenant workers where one worker handles multiple hostnames
