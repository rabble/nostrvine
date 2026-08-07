---
name: fastly-multi-service-routing-debug
description: |
  Debug Fastly Compute services where code changes don't affect behavior due to
  multi-service routing architecture. Use when: (1) deployed changes have no effect,
  (2) unexpected redirects persist after code updates, (3) DNS resolves to Fastly
  but responses don't match deployed code, (4) `fastly service list` shows multiple
  related services. The root cause is often a routing/gateway service intercepting
  requests before they reach your content service.
author: Claude Code
version: 1.0.0
date: 2026-02-02
---

# Fastly Multi-Service Routing Debug

## Problem
You deploy changes to a Fastly Compute service but the behavior doesn't change.
Requests still return old responses, redirects, or errors even after:
- Deploying new code with `fastly compute publish`
- Purging the cache with `fastly purge --all`
- Verifying the correct service version is active

## Context / Trigger Conditions
- DNS resolves to Fastly IPs (151.101.x.x)
- Response headers show `x-served-by: cache-xxx` (Fastly cache)
- Deployed code should return different status/headers but doesn't
- Multiple Fastly services exist for the same project (e.g., `divine-web`, `divine-router`)
- Wildcard subdomain routing is involved (*.example.com)

## Solution

### Step 1: Identify Which Service Handles the Domain

```bash
# List all services
fastly service list

# Check which service handles your domain using domain-v1
fastly domain-v1 list | grep your-domain.com
```

The output shows the service ID for each domain:
```
*.divine.video      glh3AfBEmZKzmAmByvGyAg  76fTayX6mBKa8faLeZ1fet  2025-12-28...
divine.video        1JttvGPc6AlOVg4koUGhPg  76fTayX6mBKa8faLeZ1fet  2025-11-23...
```

The third column is the **service ID** that handles that domain.

### Step 2: Verify Service Architecture

Common patterns:
- **Router + Content**: A routing service (often Rust) sits in front, handling
  subdomain logic, then passes through to a content service
- **Gateway Pattern**: Edge gateway handles auth/rate-limiting, then proxies to origin
- **Wildcard Routing**: `*.domain.com` may be handled by a different service than `domain.com`

### Step 3: Debug the Correct Service

Once you identify the routing service:

```bash
# Check its active version
fastly service-version list --service-id <router-service-id>

# Check its domains
fastly domain list --service-id <router-service-id> --version active

# Find and read its source code (usually in a different repo)
```

### Step 4: Trace Request Flow

Add debug logging to understand the flow:
1. In the routing service: log the Host header and routing decision
2. In the content service: log if requests are even reaching it
3. Check Fastly logs: `fastly log-tail --service-id <id>`

### Step 5: Fix the Correct Service

If the routing service is doing unwanted redirects:
- Update its routing logic to pass through instead of redirect
- Or update it to return the desired response directly
- Deploy to the routing service, not just the content service

## Verification

```bash
# Test with cache bypass
curl -sI -H "Cache-Control: no-cache" "https://subdomain.your-domain.com/?t=$(date +%s)"

# Verify new behavior appears
# Check response headers match what your code should return
```

## Example

**Symptom**: `rabble.divine.video` returns 301 redirect despite divine-web having
code to serve HTML directly.

**Discovery**:
```bash
$ fastly domain-v1 list | grep divine.video
*.divine.video      ...  76fTayX6mBKa8faLeZ1fet  ...  # This is divine-router!
divine.video        ...  76fTayX6mBKa8faLeZ1fet  ...  # Same - router handles both
```

**Root Cause**: `divine-router` (Rust service) was returning 301 redirects in its
`serve_profile()` function, never letting requests reach `divine-web`.

**Fix**: Updated `divine-router` to return the desired response directly instead
of redirecting.

## Notes

- The `fastly domain list` command shows domains on a specific service/version
- The `fastly domain-v1 list` command shows ALL domains across ALL services
- Wildcard domains (`*.domain.com`) often route to a different service than apex
- When using Fastly Compute backends, the request may go: Router → Content → Origin
- Cache purging only affects the service that's caching; if a router caches, purge there
- Response headers like `x-publisher-server-collection` indicate which service responded

## Architecture Patterns

### Pattern 1: Router → Content
```
User → DNS → Fastly Router Service → Fastly Content Service → Origin/KV Store
```
The router handles subdomain logic, auth, or routing rules.

### Pattern 2: Direct
```
User → DNS → Fastly Content Service → Origin/KV Store
```
Single service handles everything.

### Debugging Tip
If you're unsure which pattern applies, check the `[setup.backends]` section in each
service's `fastly.toml` to see if one service proxies to another's edgecompute.app URL.
