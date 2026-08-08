---
name: fastly-wildcard-subdomain-compute-edge
description: |
  Fix wildcard subdomain routing for Fastly Compute@Edge services when subdomains resolve
  but return 500 "Domain Not Found" or empty responses. Use when: (1) TLS subscription
  "issued" but edge serves default certificate (CN=j.sni-644-default), (2) Fastly domain-v1
  create succeeds but subdomain returns 500, (3) Static publisher/PublisherServer returns
  empty content for subdomain requests, (4) DNS wildcard CNAME resolves to wrong target.
  Covers TLS configuration SNI endpoint selection (x.sni vs j.sni vs w.sni), DNS trailing
  dot issues, Fastly domain-v1 activation, and reading from KV store directly when
  PublisherServer fails for subdomains.
author: Claude Code
version: 1.1.0
date: 2026-02-02
---

# Fastly Wildcard Subdomain Routing for Compute@Edge

## Problem
Wildcard subdomains (*.example.com) don't work on Fastly Compute@Edge services even after:
- Creating the domain with `fastly domain-v1 create`
- Setting up DNS records
- The static publisher working fine for the apex domain

Symptoms include:
- 500 errors with "Fastly error: unknown domain: subdomain.example.com"
- PublisherServer returning empty responses (content-length: 0) for subdomain requests
- TLS subscriptions stuck in "pending" state
- DNS resolving to wrong targets

## Context / Trigger Conditions

1. **Wrong SNI endpoint**: TLS certificate is "issued" but edge serves default certificate
   (`CN=j.sni-644-default.ssl.fastly.net` instead of your domain).

   **CRITICAL**: The TLS configuration name tells you which SNI endpoint to use:
   - "HTTP/3 & TLS v1.3 + 0RTT **(x.sni)**" → DNS to `x.sni.global.fastly.net.`
   - "HTTP/3 & TLS v1.3 **(w.sni)**" → DNS to `w.sni.global.fastly.net.`
   - Default/legacy → DNS to `j.sni.global.fastly.net.`

   Check your TLS configuration:
   ```bash
   FASTLY_KEY=$(fastly profile token) && curl -s -H "Fastly-Key: $FASTLY_KEY" \
     "https://api.fastly.com/tls/configurations" | jq '.data[] | {id: .id, name: .attributes.name}'
   ```

   Verify by connecting directly to the correct endpoint:
   ```bash
   echo | openssl s_client -servername subdomain.yourdomain.com \
     -connect x.sni.global.fastly.net:443 2>/dev/null | openssl x509 -noout -subject
   ```

2. **DNS trailing dot issue**: CNAME records resolve to `target.com.yourdomain.com` instead
   of `target.com` because the DNS provider appends the zone name without a trailing dot.

   Check with: `dig @ns-server *.yourdomain.com CNAME +short`

   Bad: `x.sni.global.fastly.net.yourdomain.com.`
   Good: `x.sni.global.fastly.net.`

3. **Domain not activated**: Fastly domain-v1 shows `"activated": false, "verified": false`
   even after DNS is set up.

   Check with:
   ```bash
   curl -s -H "Fastly-Key: $(fastly profile token)" \
     "https://api.fastly.com/domain-management/v1/domains/DOMAIN_ID" | jq
   ```

3. **PublisherServer returns empty for subdomains**: The `@fastly/compute-js-static-publish`
   PublisherServer returns null/empty responses when the request hostname is a subdomain,
   even though it works for the apex domain and edgecompute.app URL.

## Solution

### Part 1: Fix DNS Configuration

1. **Wildcard CNAME with trailing dot** (check your TLS config for correct SNI endpoint):
   ```
   Name: *
   Type: CNAME
   Value: x.sni.global.fastly.net.   <- Use endpoint from your TLS config name (x.sni, w.sni, or j.sni)
   ```

2. **ACME challenge CNAME with trailing dot** (for TLS validation):
   ```
   Name: _acme-challenge
   Type: CNAME
   Value: CHALLENGE_VALUE.fastly-validations.com.   <- MUST include trailing dot
   ```

3. Alternative: Use A records instead of CNAME (avoids trailing dot issues):
   ```
   Name: *
   Type: A
   Values: 151.101.1.242, 151.101.65.242, 151.101.129.242, 151.101.193.242
   ```

### Part 2: Recreate Fastly Domain (if stuck)

If domain shows `activated: false` even after DNS is correct:

```bash
# 1. Delete TLS subscription first (if exists)
fastly tls-subscription delete --id SUBSCRIPTION_ID --force

# 2. Delete the domain
fastly domain-v1 delete --domain-id DOMAIN_ID

# 3. Recreate domain
fastly domain-v1 create --fqdn "*.yourdomain.com" --service-id SERVICE_ID

# 4. Create new TLS subscription
fastly tls-subscription create --domain "*.yourdomain.com"

# 5. Wait 1-5 minutes for verification and TLS issuance
```

### Part 3: Fix PublisherServer for Subdomains

The PublisherServer from `@fastly/compute-js-static-publish` doesn't serve content for
subdomain hostnames. You must read from the KV store directly:

```javascript
if (subdomain) {
  // Open the content KV store
  const contentStore = new KVStore('your-content-store-name');

  // Read the index file - NOTE: collection name might be 'undefined' not 'default'
  const indexEntry = await contentStore.get('default_index_undefined');
  const indexData = await indexEntry.json();

  // Get the index.html entry - structure is { '/path': { key: 'sha256:HASH', ... } }
  const indexHtmlInfo = indexData['/index.html'];

  // Read the actual content
  const contentHash = indexHtmlInfo.key.replace('sha256:', '');
  const contentKey = `default_files_sha256_${contentHash}`;
  const htmlEntry = await contentStore.get(contentKey);
  const html = await htmlEntry.text();

  // Inject subdomain-specific data and return
  const modifiedHtml = html.replace('<head>', `<head><script>window.SUBDOMAIN_DATA = {...}</script>`);
  return new Response(modifiedHtml, {
    headers: { 'Content-Type': 'text/html; charset=utf-8' }
  });
}
```

### Part 4: Key Format Discovery

The static publisher uses these KV key formats:
- Index: `${publishId}_index_${collectionName}` (e.g., `default_index_undefined`)
- Settings: `${publishId}_settings_${collectionName}`
- Files: `${publishId}_files_sha256_${hash}`

To discover your actual key names:
```bash
curl -s -H "Fastly-Key: $(fastly profile token)" \
  "https://api.fastly.com/resources/stores/kv/STORE_ID/keys?limit=50" | jq '.data[]' | grep index
```

## Verification

```bash
# 1. Verify DNS is correct
dig @8.8.8.8 subdomain.yourdomain.com A +short
# Should return Fastly IPs

# 2. Verify domain is activated
curl -s -H "Fastly-Key: $(fastly profile token)" \
  "https://api.fastly.com/domain-management/v1/domains/DOMAIN_ID" | jq '{activated, verified}'
# Both should be true

# 3. Verify TLS is issued
fastly tls-subscription list | grep yourdomain
# State should be "issued"

# 4. Test the subdomain
curl -sI "https://subdomain.yourdomain.com"
# Should return 200 with content
```

## Example

Complete fix for `*.divine.space` subdomain routing:

```javascript
// In Compute@Edge handler
if (subdomain && namesStore) {
  const entry = await namesStore.get(`name:${subdomain}`);

  const contentStore = new KVStore('divine-space-content');
  const indexEntry = await contentStore.get('default_index_undefined');
  const indexData = await indexEntry.json();
  const indexHtmlInfo = indexData['/index.html'];
  const contentHash = indexHtmlInfo.key.replace('sha256:', '');
  const htmlEntry = await contentStore.get(`default_files_sha256_${contentHash}`);
  const html = await htmlEntry.text();

  if (entry) {
    const data = await entry.json();
    const injectedHtml = html.replace('<head>', `<head>
      <script>window.__DIVINE_SPACE_USER__ = {
        subdomain: "${subdomain}",
        pubkey: "${data.pubkey}"
      };</script>`);
    return new Response(injectedHtml, {
      headers: { 'Content-Type': 'text/html; charset=utf-8' }
    });
  }
}
```

## Notes

- The `collectionName` in KV keys is often `undefined` (literal string) rather than
  `default` due to how the static publisher is configured. Always check actual keys.
- DNS changes can take up to 3 hours to propagate due to TTL settings.
- Fastly edge cache may serve stale responses—use `fastly purge --all` after changes.
- Static assets (/assets/*, .js, .css files) should be served BEFORE subdomain handling
  using the normal PublisherServer.
- The wildcard TLS cert (*.domain.com) requires the ACME challenge DNS record to be
  correct before it will issue.

## References

- [Fastly Domain Management API](https://www.fastly.com/documentation/reference/api/domain-management/domains/)
- [Working with versionless domains](https://www.fastly.com/documentation/guides/getting-started/domains/working-with-domains/)
- [domain-v1 CLI reference](https://www.fastly.com/documentation/reference/cli/domain-v1/)
- [TLS Subscriptions API](https://www.fastly.com/documentation/reference/api/tls/subscriptions/)
