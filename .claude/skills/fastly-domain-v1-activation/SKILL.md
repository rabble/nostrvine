---
name: fastly-domain-v1-activation
description: |
  Fix "Fastly error: unknown domain" 500 errors when custom domains return "Domain Not Found"
  despite being created with domain-v1 CLI. Use when: (1) fastly domain-v1 create succeeds
  but domain returns 500, (2) Domain shows activated:false in API response, (3) Classic
  domain API returns "deprecated" error, (4) Custom domain works on edgecompute.app but
  not on your domain. Covers Fastly Compute domain setup post-September 2025.
author: Claude Code
version: 1.0.0
date: 2026-02-01
---

# Fastly Domain-v1 Activation for Compute Services

## Problem
After creating a custom domain with `fastly domain-v1 create --fqdn example.com --service-id XXX`,
the domain returns a 500 error: "Fastly error: unknown domain: example.com. Please check that
this domain has been added to a service." The edgecompute.app URL works fine.

## Context / Trigger Conditions
- Classic domain API returns: "The classic domains APIs are deprecated. Please use the domain management API"
- `fastly domain-v1 create` succeeds with domain-id and service-id
- HTTP request to custom domain returns 500 "Domain Not Found"
- Checking domain via API shows `"activated": false, "verified": false`
- The auto-generated edgecompute.app domain works correctly

## Solution

### Step 1: Create the domain (if not already done)
```bash
fastly domain-v1 create --fqdn example.com --service-id YOUR_SERVICE_ID
```

### Step 2: Create TLS subscription for HTTPS
```bash
fastly tls-subscription create --domain example.com
```

### Step 3: Get DNS configuration requirements
```bash
curl -s -H "Fastly-Key: $(fastly profile token)" \
  "https://api.fastly.com/tls/subscriptions/SUBSCRIPTION_ID?include=tls_authorizations" | jq
```

Look for the `challenges` array in the response. You'll see options like:
- `managed-http-a`: A records pointing to Fastly IPs (use for apex domains)
- `managed-http-cname`: CNAME to `x.sni.global.fastly.net` (use for subdomains)
- `managed-dns`: ACME challenge CNAME for `_acme-challenge.example.com`

### Step 4: Configure DNS
For apex domains, add A records:
```
example.com → 151.101.1.242
example.com → 151.101.65.242
example.com → 151.101.129.242
example.com → 151.101.193.242
```

For subdomains, use CNAME:
```
www.example.com → x.sni.global.fastly.net
```

### Step 5: Wait for automatic activation
Once DNS propagates, Fastly automatically:
1. Verifies domain ownership via HTTP challenge
2. Sets `verified: true`
3. Sets `activated: true`
4. Issues TLS certificate (state changes from "pending" to "issued")

This typically happens within 1-5 minutes after DNS propagation.

### Step 6: Verify activation status
```bash
# Check domain status
curl -s -H "Fastly-Key: $(fastly profile token)" \
  "https://api.fastly.com/domain-management/v1/domains/DOMAIN_ID" | jq

# Should show:
# "activated": true,
# "verified": true

# Check TLS status
fastly tls-subscription describe --id SUBSCRIPTION_ID
# State should be "issued"
```

## Verification
```bash
# Test HTTP (should redirect to HTTPS)
curl -I http://example.com
# Expected: 308 Permanent Redirect to https://

# Test HTTPS
curl -s https://example.com | head -20
# Expected: Your site content
```

## Example

```bash
# 1. Create KV store and link to service
fastly kv-store create --name my-content
fastly resource-link create --resource-id KV_STORE_ID --service-id SERVICE_ID --version latest --autoclone

# 2. Build and deploy
fastly compute publish

# 3. Add custom domain
fastly domain-v1 create --fqdn mysite.com --service-id SERVICE_ID
# Output: Created domain 'mysite.com' (domain-id: ABC123, service-id: XYZ789)

# 4. Set up TLS
fastly tls-subscription create --domain mysite.com
# Output: Created TLS Subscription 'SUB123' (Authority: certainly, Common Name: mysite.com)

# 5. Configure DNS with A records (apex) or CNAME (subdomain)
# 6. Wait ~2-5 minutes for verification
# 7. Site is live at https://mysite.com
```

## Notes

- **Post-September 2025**: The `fastly domain create` command (classic API) is deprecated. Use `fastly domain-v1` instead.
- **No manual activation**: Unlike classic domains, domain-v1 domains activate automatically after DNS verification. There's no explicit "activate" API call.
- **Service version independence**: Domain-v1 creates "versionless domains" that aren't tied to a specific service version. You don't need to clone/activate versions to add domains.
- **TLS is separate**: Domain creation and TLS certificate management are separate operations. You can have a domain without TLS (HTTP only) but most setups want both.
- **Fastly IPs are global**: The A record IPs (151.101.x.242) are Fastly's anycast addresses and route to the nearest edge node.

## References
- [Fastly Domain Management API](https://www.fastly.com/documentation/reference/api/domain-management/domains/)
- [Working with versionless domains](https://www.fastly.com/documentation/guides/getting-started/domains/working-with-domains/working-with-domains/)
- [domain-v1 CLI reference](https://www.fastly.com/documentation/reference/cli/domain-v1/)
