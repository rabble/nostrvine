---
name: microservice-api-endpoint-routing-404
description: |
  Debug 404 errors for API endpoints in microservice architectures where code exists but
  routing sends requests to wrong service. Use when: (1) API endpoint returns 404 despite
  code being deployed, (2) Multiple services share same hostname via HTTPRoute/Ingress,
  (3) Service logs show "Health server" but you expected API endpoints, (4) Monorepo
  deploys multiple images and endpoint might be in different service than expected.
  Covers: verifying which service handles which paths, HTTPRoute path precedence,
  testing endpoints directly from inside cluster, matching image tags across services.
author: Claude Code
version: 1.0.0
date: 2026-01-29
---

# Microservice API Endpoint Routing 404 Debugging

## Problem
API endpoint returns 404 even though the code implementing it has been deployed. This
commonly happens in microservice architectures where multiple services share the same
hostname and HTTPRoutes/Ingress rules determine which service handles which paths.

## Context / Trigger Conditions
- New endpoint returns 404 but code is definitely deployed
- Multiple services (e.g., relay + api) share the same external hostname
- Service logs show "Health server listening" or similar health-only messages
- HTTPRoute or Ingress rules split traffic by path prefix
- Monorepo builds multiple Docker images from same commit

## Solution

### Step 1: Identify which service actually handles the path
Check HTTPRoute/Ingress rules to see routing:
```bash
kubectl get httproute <name> -n <namespace> -o yaml | grep -A 50 "rules:"
```

Look for path matching rules and which backend service they point to:
- `/api/*` might go to `api-service:8080`
- `/` might go to `websocket-service:7777`

### Step 2: Test the endpoint directly on each service from inside cluster
```bash
kubectl run curl-test -n <namespace> --image=curlimages/curl --restart=Never \
  -- curl -v "http://<service-name>:<port>/<endpoint>" \
  && sleep 5 \
  && kubectl logs -n <namespace> curl-test \
  && kubectl delete pod -n <namespace> curl-test
```

This bypasses external routing and tests directly against each service.

### Step 3: Check service logs for endpoint registration
```bash
kubectl logs -l app=<service-name> -n <namespace> --tail=50 | grep -i -E "(endpoint|route|api|listening)"
```

Look for messages like:
- "Health server listening on 0.0.0.0:8080" = health only, no API
- "API server listening" or "Registered /api/..." = serves API endpoints

### Step 4: For monorepos, check if matching image exists for correct service
If feature was added to service A but endpoint is served by service B, check if
service B has the same commit tag:
```bash
gcloud artifacts docker images list <registry>/<service-b> --include-tags --limit=10
```

### Step 5: Deploy the correct service with feature + required env vars
Update the service that actually handles the endpoint path:
- New image tag with the feature
- Any environment variables (API keys, URLs) the feature needs
- Any secrets referenced by the feature

## Verification
1. Service logs show endpoint registered: "Recommendations API enabled at /api/users/:pubkey/recommendations"
2. Direct curl from inside cluster returns 200
3. External request through HTTPRoute returns expected data

## Example

Architecture:
```
Hostname: relay.example.com
  /api/* → funnelcake-api:8080 (REST API)
  /      → funnelcake-relay:7777 (WebSocket)
```

Problem: `/api/users/x/recommendations` returns 404

Investigation:
1. HTTPRoute shows `/api/*` → funnelcake-api (not relay)
2. Direct test to relay:8080 returns 404 (health server only)
3. Direct test to api:8080 also returns 404 (old image)
4. Registry shows both api and relay have image tag `3c0696a`
5. API was running old tag `487178e`

Fix: Deploy funnelcake-api with tag `3c0696a` + GORSE_URL + GORSE_API_KEY env vars

## Notes
- Services in same namespace can share Kubernetes Secrets
- Health endpoints (/livez, /readyz) are often on separate port from API
- HTTPRoute path matching: more specific paths take precedence
- Always check which service handles which paths before assuming endpoint location
