---
name: funnelcake-deployment-workflow
description: |
  Deploy funnelcake (api + relay) to ANY environment (production, staging, poc) on GKE via ArgoCD.
  Use when: (1) Deploying new funnelcake commits, (2) Building Docker images for GKE (amd64),
  (3) Running ClickHouse migrations, (4) Troubleshooting ImagePullBackOff errors,
  (5) Syncing staging/poc after production deployment. Covers complete workflow with
  PRE-FLIGHT CHECKLIST to prevent common deployment failures.
author: Claude Code
version: 2.0.0
date: 2026-01-31
---

# Funnelcake Deployment Workflow

## Problem
Deploying funnelcake requires multiple coordinated steps across DIFFERENT environments,
each with its own container registry and ArgoCD instance. Common failures:
- Updating kustomization with image tags that don't exist in target registry
- Assuming push to main auto-deploys to staging/poc (it doesn't)
- Not verifying pods actually started (vs stuck in ImagePullBackOff)

## Context / Trigger Conditions
- User asks to deploy funnelcake to any environment
- New commits need to be deployed
- Migrations need to be run
- Pods stuck in ImagePullBackOff or ErrImagePull
- Staging/poc is behind production

## CRITICAL: Multi-Environment Architecture

**Each environment is ISOLATED - nothing is shared!**

| Environment | Container Registry | ArgoCD | kubectl Context |
|-------------|-------------------|--------|-----------------|
| Production | `us-central1-docker.pkg.dev/dv-platform-prod/containers-production/` | In production cluster | `connectgateway_dv-platform-prod_us-central1_gke-production-membership` |
| Staging | `us-central1-docker.pkg.dev/dv-platform-staging/containers-staging/` | In staging cluster | `connectgateway_dv-platform-staging_us-central1_gke-staging-membership` |
| POC | `us-central1-docker.pkg.dev/rich-compiler-479518-d2/containers-poc/` | In POC cluster | `connectgateway_rich-compiler-479518-d2_us-central1_gke-poc-membership` |

**Key Facts:**
- Images in production registry are NOT available to staging/poc
- Pushing to `main` branch does NOT auto-sync staging/poc ArgoCD
- Each environment's ArgoCD must be synced separately

## PRE-FLIGHT CHECKLIST (DO THIS FIRST!)

Before deploying to ANY environment, verify:

### 1. Does the image exist in the TARGET registry?
```bash
# Check what images exist
gcloud artifacts docker images list \
  us-central1-docker.pkg.dev/<PROJECT>/<REPO>/funnelcake-relay \
  --include-tags --limit=5

# Projects/repos by environment:
# - Production: dv-platform-prod/containers-production
# - Staging: dv-platform-staging/containers-staging
# - POC: rich-compiler-479518-d2/containers-poc
```

**If image doesn't exist → BUILD AND PUSH IT FIRST!**

### 2. Am I updating the correct overlay?
```bash
# Staging overlay:
k8s/applications/funnelcake-relay/overlays/staging/kustomization.yaml

# POC overlay:
k8s/applications/funnelcake-relay/overlays/poc/kustomization.yaml

# Production overlay:
k8s/applications/funnelcake-relay/overlays/production/kustomization.yaml
```

### 3. What's currently deployed vs what's in git?
```bash
# Check deployed image
kubectl --context <CONTEXT> get deployment funnelcake-relay -n funnelcake \
  -o jsonpath='{.spec.template.spec.containers[0].image}'

# Check git kustomization
cat k8s/applications/funnelcake-relay/overlays/<ENV>/kustomization.yaml | grep newTag
```

## Complete Deployment Workflow

### Step 1: Get Latest Code
```bash
cd /Users/rabble/code/divine/divine-funnelcake
git pull
git log --oneline -3  # Note the commit hash (e.g., e02d3b1)
```

### Step 2: Build Images for AMD64 (CRITICAL)

**IMPORTANT**: Mac builds arm64 by default. GKE runs amd64. You MUST specify `--platform linux/amd64`.

```bash
# Build API image
docker buildx build --platform linux/amd64 --target api \
  -t us-central1-docker.pkg.dev/dv-platform-prod/containers-production/funnelcake-api:COMMIT_HASH \
  --push .

# Build Relay image
docker buildx build --platform linux/amd64 --target relay \
  -t us-central1-docker.pkg.dev/dv-platform-prod/containers-production/funnelcake-relay:COMMIT_HASH \
  --push .
```

If you get auth errors, run:
```bash
gcloud auth configure-docker us-central1-docker.pkg.dev --quiet
```

### Step 3: Update Kustomize and Push
```bash
cd /Users/rabble/code/divine/divine-iac-coreconfig

# Update image tags
sed -i '' 's/newTag: "OLD_HASH"/newTag: "NEW_HASH"/' \
  k8s/applications/funnelcake-api/overlays/production/kustomization.yaml
sed -i '' 's/newTag: "OLD_HASH"/newTag: "NEW_HASH"/' \
  k8s/applications/funnelcake-relay/overlays/production/kustomization.yaml

# Commit and push (handle potential conflicts)
git add k8s/applications/funnelcake-*/overlays/production/kustomization.yaml
git commit -m "deploy(production): funnelcake NEW_HASH - description"
git pull --rebase origin main && git push origin main
```

### Step 4: Trigger ArgoCD Sync
```bash
# Refresh to pick up git changes
kubectl patch application funnelcake-api -n argocd --type=merge \
  -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
kubectl patch application funnelcake-relay -n argocd --type=merge \
  -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'

# Wait, then trigger sync
sleep 3
kubectl patch application funnelcake-api -n argocd --type=merge \
  -p '{"operation":{"sync":{"revision":"HEAD"}}}'
kubectl patch application funnelcake-relay -n argocd --type=merge \
  -p '{"operation":{"sync":{"revision":"HEAD"}}}'
```

### Step 5: Wait for Rollout
```bash
kubectl rollout status deploy/funnelcake-api deploy/funnelcake-relay \
  -n funnelcake --timeout=120s
```

### Step 6: Verify
```bash
kubectl get deploy funnelcake-api -n funnelcake \
  -o jsonpath='{.spec.template.spec.containers[0].image}'
```

## Running Migrations

### CRITICAL: Migration Entrypoint Has Two Modes

The `database/entrypoint.sh` detects ClickHouse connection mode from env vars:

- **Mode 1 (CLICKHOUSE_URL)**: Assumes ClickHouse Cloud — forces port 9440 with TLS.
  Use for **production** (ClickHouse Cloud at `*.clickhouse.cloud`).
- **Mode 2 (CLICKHOUSE_HOST + CLICKHOUSE_PORT)**: Direct host/port, no TLS assumption.
  Use for **staging/poc** (self-hosted ClickHouse on port 9000).

**If you pass CLICKHOUSE_URL for self-hosted ClickHouse, migrations will fail with
`i/o timeout` on port 9440 because the self-hosted instance listens on port 9000.**

### Build and Push Migration Image
```bash
cd /Users/rabble/code/divine/divine-funnelcake/database
docker buildx build --platform linux/amd64 \
  -t us-central1-docker.pkg.dev/dv-platform-prod/containers-production/funnelcake-migrate:COMMIT_HASH \
  --push .
```

### Run Migration Job — PRODUCTION (ClickHouse Cloud)
```bash
kubectl delete job funnelcake-db-migrate -n funnelcake --ignore-not-found
cat <<'EOF' | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: funnelcake-db-migrate
  namespace: funnelcake
spec:
  ttlSecondsAfterFinished: 600
  backoffLimit: 3
  template:
    spec:
      restartPolicy: OnFailure
      containers:
        - name: migrate
          image: us-central1-docker.pkg.dev/dv-platform-prod/containers-production/funnelcake-migrate:COMMIT_HASH
          args: ["up"]
          env:
            - name: CLICKHOUSE_URL
              valueFrom:
                secretKeyRef:
                  name: funnelcake-clickhouse-credentials
                  key: CLICKHOUSE_URL
            - name: CLICKHOUSE_USER
              valueFrom:
                secretKeyRef:
                  name: funnelcake-clickhouse-credentials
                  key: CLICKHOUSE_USER
            - name: CLICKHOUSE_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: funnelcake-clickhouse-credentials
                  key: CLICKHOUSE_PASSWORD
            - name: CLICKHOUSE_DATABASE
              valueFrom:
                secretKeyRef:
                  name: funnelcake-clickhouse-credentials
                  key: CLICKHOUSE_DATABASE
EOF
```

### Run Migration Job — STAGING/POC (Self-hosted ClickHouse)
```bash
# Use CLICKHOUSE_HOST + CLICKHOUSE_PORT instead of CLICKHOUSE_URL!
kubectl --context <STAGING_CONTEXT> delete job funnelcake-db-migrate -n funnelcake --ignore-not-found
cat <<'EOF' | kubectl --context <STAGING_CONTEXT> apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: funnelcake-db-migrate
  namespace: funnelcake
spec:
  ttlSecondsAfterFinished: 600
  backoffLimit: 3
  template:
    spec:
      restartPolicy: OnFailure
      containers:
        - name: migrate
          image: us-central1-docker.pkg.dev/dv-platform-staging/containers-staging/funnelcake-migrate:COMMIT_HASH
          args: ["up"]
          env:
            - name: CLICKHOUSE_HOST
              value: "funnelcake-funnelcake-clickhouse.funnelcake.svc.cluster.local"
            - name: CLICKHOUSE_PORT
              value: "9000"
            - name: CLICKHOUSE_USER
              valueFrom:
                secretKeyRef:
                  name: funnelcake-clickhouse-credentials
                  key: CLICKHOUSE_USER
            - name: CLICKHOUSE_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: funnelcake-clickhouse-credentials
                  key: CLICKHOUSE_PASSWORD
            - name: CLICKHOUSE_DATABASE
              valueFrom:
                secretKeyRef:
                  name: funnelcake-clickhouse-credentials
                  key: CLICKHOUSE_DATABASE
EOF
```

### Check Migration Logs
```bash
sleep 10 && kubectl logs job/funnelcake-db-migrate -n funnelcake
```

### Handle "Dirty Database" Error
If you see `error: Dirty database version X`, a previous migration failed partway:

```bash
# Force the version to clear dirty state
kubectl delete job funnelcake-db-migrate -n funnelcake --ignore-not-found
# Create job with args: ["force", "X"] instead of ["up"]
# Then run "up" again
```

## Common Errors and Fixes

### Error: "no match for platform in manifest: not found"
**Cause**: Image built for wrong architecture (arm64 on Mac, but GKE needs amd64)
**Fix**: Rebuild with `--platform linux/amd64`

### Error: "Unauthenticated request" when pushing
**Cause**: Docker not authenticated to Artifact Registry
**Fix**: `gcloud auth configure-docker us-central1-docker.pkg.dev --quiet`

### Error: "failed to push... fetch first"
**Cause**: Remote has new commits
**Fix**: `git pull --rebase origin main && git push origin main`

### Error: "Dirty database version X"
**Cause**: Previous migration failed midway
**Fix**: Run `force X` to clear dirty state, then `up` again

### Pods stuck in ImagePullBackOff
**Causes**:
1. Wrong architecture (check with `kubectl describe pod`)
2. Image doesn't exist (typo in tag)
3. Auth issues (check imagePullSecrets)

## Key Paths
- Funnelcake repo: `/Users/rabble/code/divine/divine-funnelcake`
- IaC repo: `/Users/rabble/code/divine/divine-iac-coreconfig`
- API kustomization: `k8s/applications/funnelcake-api/overlays/production/kustomization.yaml`
- Relay kustomization: `k8s/applications/funnelcake-relay/overlays/production/kustomization.yaml`
- Migrations: `/Users/rabble/code/divine/divine-funnelcake/database/migrations/`

## Deploying to Staging or POC

### Full Workflow for Non-Production Environments

```bash
# 1. Check what's in production that we want to deploy
cat k8s/applications/funnelcake-relay/overlays/production/kustomization.yaml | grep newTag
# e.g., newTag: "e7e79eb"

# 2. CHECK if that image exists in staging registry
gcloud artifacts docker images list \
  us-central1-docker.pkg.dev/dv-platform-staging/containers-staging/funnelcake-relay \
  --include-tags --limit=10 | grep e7e79eb

# 3. If NOT found → BUILD AND PUSH
cd /Users/rabble/code/divine/divine-funnelcake
git checkout e7e79eb

docker build --platform linux/amd64 --target relay \
  -t us-central1-docker.pkg.dev/dv-platform-staging/containers-staging/funnelcake-relay:e7e79eb .
docker push us-central1-docker.pkg.dev/dv-platform-staging/containers-staging/funnelcake-relay:e7e79eb

docker build --platform linux/amd64 --target api \
  -t us-central1-docker.pkg.dev/dv-platform-staging/containers-staging/funnelcake-api:e7e79eb .
docker push us-central1-docker.pkg.dev/dv-platform-staging/containers-staging/funnelcake-api:e7e79eb

# For POC, tag and push to POC registry too
docker tag ...staging...:e7e79eb ...poc...:e7e79eb
docker push ...poc...:e7e79eb

git checkout main  # Return to main

# 4. Update kustomization (only AFTER images exist!)
cd /Users/rabble/code/divine/divine-iac-coreconfig
# Edit staging/poc overlays with new tags

# 5. Commit and push
git add -A && git commit -m "deploy(staging, poc): funnelcake @ e7e79eb" && git push

# 6. Sync ArgoCD (each environment has its own!)
kubectl --context connectgateway_dv-platform-staging_us-central1_gke-staging-membership \
  patch application funnelcake-relay -n argocd --type merge \
  -p '{"operation":{"initiatedBy":{"username":"claude"},"sync":{"syncStrategy":{"apply":{"force":false}}}}}'

# 7. VERIFY pods are actually running (not ImagePullBackOff!)
kubectl --context connectgateway_dv-platform-staging_us-central1_gke-staging-membership \
  get pods -n funnelcake
```

### POST-DEPLOYMENT VERIFICATION CHECKLIST

Always run these after any deployment:

```bash
# 1. Check pod status (should be Running, not ImagePullBackOff)
kubectl --context <CONTEXT> get pods -n funnelcake

# 2. Check actual deployed image matches expected
kubectl --context <CONTEXT> get deployment funnelcake-relay -n funnelcake \
  -o jsonpath='{.spec.template.spec.containers[0].image}'

# 3. Check the website actually works
curl -s https://relay.staging.dvines.org/ | grep -o "version.*" | head -1
```

## Image Registry
- Production: `us-central1-docker.pkg.dev/dv-platform-prod/containers-production/`
- Staging: `us-central1-docker.pkg.dev/dv-platform-staging/containers-staging/`
- POC: `us-central1-docker.pkg.dev/rich-compiler-479518-d2/containers-poc/`

## Notes
- Always use short commit hash (7 chars) for image tags
- Dockerfile has multi-stage build: `--target api` or `--target relay`
- Migration image is in `database/Dockerfile`
- ClickHouse credentials are in `funnelcake-clickhouse-credentials` secret
- ArgoCD needs BOTH refresh AND sync operations
