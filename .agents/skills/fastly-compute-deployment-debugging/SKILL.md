---
name: fastly-compute-deployment-debugging
description: |
  Debug Fastly Compute deployments that appear successful but return stale/wrong responses.
  Use when: (1) fastly compute publish succeeds but version check shows old version,
  (2) new endpoints return 404 after deployment, (3) cache-busted requests work but regular
  requests fail, (4) fastly domain list doesn't show your custom domain. Covers edge
  propagation timing, cached error responses, and domain management API differences.
author: Claude Code
version: 1.0.0
date: 2026-01-21
---

# Fastly Compute Deployment Debugging

## Problem

After deploying to Fastly Compute, requests return stale content or 404s even though:
- `fastly compute publish` reported success
- The new version shows as "active" in `fastly service-version list`
- The code is correct and works locally

## Context / Trigger Conditions

- Version endpoint returns old version string after deployment
- New routes/features return 404
- `fastly purge --all` doesn't fix the issue
- Requests with cache buster (`?v=random`) work but regular requests don't
- `fastly domain list` doesn't show your custom domain
- Different POPs return different results

## Solution

### 1. Verify Code is Actually Deployed

```bash
# Check the direct edgecompute.app URL (bypasses custom domain config)
curl https://your-service.edgecompute.app/version

# Compare to custom domain
curl https://your-custom-domain.com/version
```

If edgecompute.app works but custom domain doesn't, it's a domain configuration issue.

### 2. Diagnose Cached Error Responses

The most common issue: 404s get cached at edge POPs before new code propagates.

```bash
# Test with cache buster
curl "https://your-domain.com/endpoint?bust=$RANDOM"

# Test without
curl "https://your-domain.com/endpoint"
```

If cache-busted works but regular doesn't = **cached error response**.

**Fix**: Wait 2-5 minutes for full propagation, then purge:
```bash
fastly purge --all --service-id YOUR_SERVICE_ID
```

### 3. Check Domain Configuration (Two APIs!)

Fastly has TWO domain management systems:

| System | CLI Command | API Endpoint |
|--------|-------------|--------------|
| Classic Domains | `fastly domain list` | `/service/{id}/version/{ver}/domain` |
| Versionless Domains | *(not shown in CLI)* | `/domain-management/v1/domains` |

**If `fastly domain list` doesn't show your domain**, check the versionless API:

```bash
# Get your API token
TOKEN=$(fastly profile token)

# Query domain-management API
curl -s -H "Fastly-Key: $TOKEN" \
  "https://api.fastly.com/domain-management/v1/domains?filter%5Bfqdn%5D=your-domain.com"
```

Look for `"activated": true` and `"verified": true`.

### 4. Force Clean Rebuild

If build caching is suspected:

```bash
rm -rf pkg target
fastly compute publish --comment "clean build"
```

### 5. Wait for Propagation

Fastly Compute deployments can take **2-5 minutes** to propagate to all POPs worldwide.
Even after `fastly service-version list` shows the version as active, some POPs may
still serve old code.

**Timeline**:
- Version marked "active": ~30 seconds
- Most POPs updated: ~1-2 minutes
- All POPs updated: ~3-5 minutes (sometimes longer)

### 6. Check Real-time Logs

```bash
fastly log-tail --service-id YOUR_SERVICE_ID
```

Then make a request and see if it appears. If no logs appear, the request isn't
reaching your Compute code (likely a domain/routing issue).

## Verification

After waiting and purging:

```bash
# Multiple requests to hit different POPs
for i in 1 2 3 4 5; do
  curl -s "https://your-domain.com/version"
  sleep 1
done
```

All should return the new version.

## Example

**Scenario**: Deployed thumbnail serving code, but `/hash.jpg` returns 404.

**Debug steps**:
1. `curl https://service.edgecompute.app/hash.jpg?v=123` → 200 (code works!)
2. `curl https://custom-domain.com/hash.jpg` → 404 (cached)
3. Wait 3 minutes
4. `fastly purge --all --service-id XXX`
5. `curl https://custom-domain.com/hash.jpg` → 200 (working!)

**Root cause**: 404 was cached at edge before new code propagated.

## Notes

- **Accounts created before Sept 2025**: May have classic domains, newer accounts use versionless
- **Don't panic**: If version check works on edgecompute.app, the code is deployed - just wait
- **Purge timing**: Purge AFTER propagation completes, not immediately after deploy
- **POP variance**: Different geographic POPs may propagate at different speeds
- **Error caching**: Fastly may cache 404/500 responses - this amplifies propagation issues

## References

- [Fastly Compute Documentation](https://www.fastly.com/documentation/guides/compute/)
- [Working with versionless domains](https://www.fastly.com/documentation/guides/getting-started/domains/working-with-domains/working-with-domains/)
- [Working with classic domains](https://www.fastly.com/documentation/guides/getting-started/domains/working-with-domains/working-with-classic-domains/)
- [Domain Management API](https://www.fastly.com/documentation/reference/api/domain-management/domains/)
- [Classic Domain API](https://www.fastly.com/documentation/reference/api/services/domain/)
