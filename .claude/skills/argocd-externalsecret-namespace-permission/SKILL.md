---
name: argocd-externalsecret-namespace-permission
description: |
  Fix ArgoCD ExternalSecret deployment failing with "namespace X is not permitted in project Y".
  Use when: (1) ExternalSecret shows OutOfSync in ArgoCD but won't sync, (2) ArgoCD application
  status shows "namespace X is not permitted in project 'infrastructure'", (3) ExternalSecret
  targets a namespace managed by a different ArgoCD project, (4) Using apps-of-apps pattern
  with separate infrastructure and application projects.
author: Claude Code
version: 1.0.0
date: 2026-01-29
---

# ArgoCD ExternalSecret Namespace Permission Error

## Problem
ExternalSecrets defined in a shared "external-secrets-resources" ApplicationSet fail to
deploy to namespaces that aren't in the ArgoCD project's allowed destinations. The sync
shows OutOfSync but refuses to apply.

## Context / Trigger Conditions
- ArgoCD application shows `OutOfSync` status but doesn't sync
- Checking application resources shows:
  ```
  message: namespace gorse is not permitted in project 'infrastructure'
  ```
- ExternalSecret is in a shared ApplicationSet (e.g., `external-secrets-resources`)
- Target namespace belongs to a different application (e.g., `gorse` app in `default` project)
- Using apps-of-apps pattern with project-based isolation

## Root Cause
ArgoCD projects define allowed destination namespaces. When ExternalSecrets are deployed
via a centralized "infrastructure" project but target namespaces managed by application-specific
projects, the infrastructure project doesn't have permission to deploy to those namespaces.

## Solution
Move the ExternalSecret from the shared external-secrets-resources to the application itself.

### Step 1: Create ExternalSecret in the application
```yaml
# k8s/applications/gorse/base/external-secret.yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: gorse-secrets
  namespace: gorse
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: gcp-secret-manager
    kind: ClusterSecretStore
  target:
    name: gorse-secrets
    creationPolicy: Owner
  data:
    - secretKey: api_key
      remoteRef:
        key: gorse-api-key-ENVIRONMENT
```

### Step 2: Add to application kustomization
```yaml
# k8s/applications/gorse/base/kustomization.yaml
resources:
  - namespace.yaml
  - external-secret.yaml  # Add here
  - deployment.yaml
```

### Step 3: Add environment-specific patches in overlays
```yaml
# k8s/applications/gorse/overlays/staging/kustomization.yaml
patches:
  - target:
      kind: ExternalSecret
      name: gorse-secrets
    patch: |-
      - op: replace
        path: /spec/data/0/remoteRef/key
        value: gorse-api-key-staging
```

### Step 4: Remove from external-secrets-resources
Remove the ExternalSecret from `k8s/external-secrets/base/` and all overlay patches.

## Verification
1. Sync the application: `argocd app sync gorse`
2. Check ExternalSecret status: `kubectl get externalsecrets -n gorse`
3. Verify secret created: `kubectl get secrets -n gorse`

## Alternative Solutions

### Option 1: Expand project destinations
Add the namespace to the infrastructure project's allowed destinations in ArgoCD.
Not recommended as it breaks project isolation.

### Option 2: Use ClusterSecretStore
If using ClusterSecretStore, the secret can be referenced from any namespace.
The ExternalSecret itself still needs to be in an allowed namespace.

## Notes
- This pattern is common when migrating from monolithic to modular ArgoCD setups
- Each application should own its secret definitions for better isolation
- ClusterSecretStore remains shared; only ExternalSecret moves
- The "infrastructure" project typically manages cluster-wide resources, not app-specific secrets
