---
name: certmanager-dns01-gke-private-cluster
description: |
  Fix cert-manager DNS01 ACME challenges stuck in "pending" state with "DNS record not yet
  propagated" inside GKE private clusters, even when TXT records exist in Cloudflare DNS.
  Use when: (1) cert-manager challenges show "pending" for hours with propagation check failures,
  (2) dig from outside cluster shows correct TXT records but cert-manager can't verify them,
  (3) Using Cloudflare DNS01 solver in a GKE private cluster with Cloud NAT,
  (4) Google Cloud intercepts 8.8.8.8 DNS queries returning NXDOMAIN for Cloudflare-managed records,
  (5) Even --dns01-recursive-nameservers with 1.1.1.1 doesn't fix the propagation check despite
  TXT records being verifiable from busybox pods in the same namespace. Covers the full debugging
  flow and certbot manual workaround.
author: Claude Code
version: 1.0.0
date: 2026-03-28
---

# Cert-Manager DNS01 Challenge Failure in GKE Private Clusters

## Problem
Cert-manager DNS01 ACME challenges get stuck in "pending" state indefinitely inside GKE private
clusters. The propagation check fails with "DNS record for X not yet propagated" even though
the TXT records are correctly created in Cloudflare and verifiable from everywhere — including
from inside the cluster using busybox pods.

## Context / Trigger Conditions
- cert-manager with Cloudflare DNS01 solver
- GKE private cluster (private nodes, public endpoint) with Cloud NAT
- Challenges show `presented: true` but `state: pending` for hours
- cert-manager logs show: `"propagation check failed" err="DNS record for \"example.com\" not yet propagated"`
- `dig TXT _acme-challenge.example.com` from outside returns correct value
- busybox `nslookup` from inside cluster also returns correct value
- Certificate resource shows `Ready: False` with `reason: RequestChanged`

## Root Causes Discovered

### 1. Google Cloud intercepts DNS to 8.8.8.8
Inside GKE VPCs, DNS queries to `8.8.8.8` are intercepted by Google Cloud infrastructure.
For Cloudflare-managed domains, this can return **NXDOMAIN** even when the record exists.
This is because Google routes 8.8.8.8 through their internal DNS infrastructure which may
have different resolution behavior than the public Google DNS service.

**Verification:**
```bash
# From inside cluster - returns NXDOMAIN
kubectl run dns-test --image=busybox:1.36 --rm -i --restart=Never -- \
  nslookup -type=TXT _acme-challenge.example.com 8.8.8.8

# From inside cluster - returns correct result
kubectl run dns-test --image=busybox:1.36 --rm -i --restart=Never -- \
  nslookup -type=TXT _acme-challenge.example.com 1.1.1.1
```

### 2. Cert-manager propagation check still fails with correct resolvers
Even after configuring `--dns01-recursive-nameservers=1.1.1.1:53,1.0.0.1:53` and
`--dns01-recursive-nameservers-only=true`, cert-manager's propagation check may still fail.
The Go DNS library used by cert-manager (miekg/dns) behaves differently from busybox's
nslookup. The exact cause is unclear but may relate to:
- DNS response parsing differences between miekg/dns and system resolvers
- TCP vs UDP DNS query differences
- Internal cert-manager caching or timing issues
- Cloud NAT interaction with DNS traffic patterns

## Solution

### Attempt 1: Configure recursive DNS resolvers (may not be sufficient)
Add to cert-manager Helm values:
```yaml
dns01RecursiveNameservers: "1.1.1.1:53,1.0.0.1:53"
dns01RecursiveNameserversOnly: true
```

**IMPORTANT:** Do NOT use `8.8.8.8` — Google Cloud intercepts this inside GKE VPCs.

For ArgoCD-managed cert-manager (Helm chart), add to the Application `valuesObject`:
```yaml
valuesObject:
  dns01RecursiveNameservers: "1.1.1.1:53,1.0.0.1:53"
  dns01RecursiveNameserversOnly: true
```

### Attempt 2: Manual cert generation with certbot (reliable workaround)
If the resolver fix doesn't work, generate the cert locally and inject it:

```bash
# Install certbot with Cloudflare plugin
pipx install certbot
pipx inject certbot certbot-dns-cloudflare

# Get Cloudflare API token from cluster
CF_TOKEN=$(kubectl get secret cloudflare-api-token-secret -n cert-manager \
  -o jsonpath='{.data.api-token}' | base64 -d)

# Create credentials file
mkdir -p /tmp/certbot-cf
echo "dns_cloudflare_api_token = $CF_TOKEN" > /tmp/certbot-cf/cloudflare.ini
chmod 600 /tmp/certbot-cf/cloudflare.ini

# Generate certificate
certbot certonly \
  --dns-cloudflare \
  --dns-cloudflare-credentials /tmp/certbot-cf/cloudflare.ini \
  --dns-cloudflare-propagation-seconds 30 \
  -d '*.example.com' -d 'example.com' \
  --non-interactive --agree-tos --email admin@example.com \
  --config-dir /tmp/certbot-cf/config \
  --work-dir /tmp/certbot-cf/work \
  --logs-dir /tmp/certbot-cf/logs \
  --key-type ecdsa --elliptic-curve secp256r1

# Inject into cluster
kubectl create secret tls wildcard-tls-secret \
  --cert=/tmp/certbot-cf/config/live/example.com/fullchain.pem \
  --key=/tmp/certbot-cf/config/live/example.com/privkey.pem \
  -n nginx-gateway --dry-run=client -o yaml | kubectl apply -f -

# Clean up
rm -rf /tmp/certbot-cf
```

## Verification
```bash
# Check the certificate served by the gateway
echo | openssl s_client -connect upload.example.com:443 \
  -servername upload.example.com 2>/dev/null | \
  openssl x509 -noout -subject -ext subjectAltName

# Test endpoint
curl -s https://upload.example.com/
```

## Debugging Commands
```bash
# Check challenge status
kubectl get challenges -n nginx-gateway

# Check challenge details (key = expected TXT value)
kubectl get challenge <name> -n nginx-gateway \
  -o jsonpath='domain: {.spec.dnsName}, key: {.spec.key}, presented: {.status.presented}'

# Check cert-manager args
kubectl get deployment cert-manager -n cert-manager \
  -o jsonpath='{.spec.template.spec.containers[0].args}'

# Check certificate status
kubectl get certificate wildcard-tls -n nginx-gateway -o yaml

# Check what cert is currently in the secret
kubectl get secret wildcard-tls-secret -n nginx-gateway \
  -o jsonpath='{.data.tls\.crt}' | base64 -d | \
  openssl x509 -noout -subject -ext subjectAltName

# Test DNS from inside cluster
kubectl run dns-test --image=busybox:1.36 --rm -i --restart=Never -- \
  nslookup -type=TXT _acme-challenge.example.com 1.1.1.1

# Delete stale order to force refresh
kubectl delete order <order-name> -n nginx-gateway
```

## Notes
- The manually generated cert expires after 90 days and won't auto-renew
- cert-manager will eventually overwrite the manually injected secret when/if it
  successfully issues its own cert — this is fine and desired
- When requesting both wildcard (`*.example.com`) and base (`example.com`), ACME requires
  separate authorizations that both use `_acme-challenge.example.com` TXT records with
  different values
- ArgoCD root apps with `automated.enabled: false` won't auto-sync — you need to trigger
  manually via `kubectl patch app root -n argocd --type merge -p '{"operation":{"sync":...}}'`
- The cert-manager container is distroless (no shell) — you can't exec into it to debug DNS
