---
name: gorse-worker-health-probe-fix
description: |
  Fix Gorse worker pods stuck in not-ready state due to failing health probes. Use when:
  (1) gorse-worker pods show 0/1 Ready but Running status, (2) Readiness probe using
  pgrep fails silently, (3) Worker logs show normal operation but pod never becomes ready,
  (4) Using zhenghaoz/gorse-worker image. The gorse-worker container is a minimal image
  without pgrep or ps commands, so exec-based probes using these fail.
author: Claude Code
version: 1.0.0
date: 2026-01-30
---

# Gorse Worker Health Probe Fix

## Problem
Gorse worker pods remain in not-ready state (0/1 Ready) even though the worker process
is running correctly and processing jobs. This breaks HPA scaling and service health.

## Context / Trigger Conditions
- gorse-worker pods show `0/1 Ready` but `Running` status
- Worker logs show normal operation: `"msg":"complete ranking recommendation"`
- Pod never transitions to Ready state
- Deployment uses exec-based readiness probe with `pgrep -f gorse-worker`
- Using the official `zhenghaoz/gorse-worker` Docker image

## Root Cause
The `zhenghaoz/gorse-worker` image is a minimal/distroless image that doesn't include
common utilities like `pgrep`, `ps`, or `procps`. The exec probe silently fails because
the command doesn't exist.

```yaml
# This probe FAILS silently - pgrep doesn't exist in the container
readinessProbe:
  exec:
    command: ["pgrep", "-f", "gorse-worker"]
```

## Solution
Replace the pgrep-based probe with a process check using shell built-ins that exist
in the minimal image:

```yaml
# Use kill -0 to check if PID 1 (main process) is alive
livenessProbe:
  exec:
    command: ["sh", "-c", "kill -0 1"]
  initialDelaySeconds: 30
  periodSeconds: 10
readinessProbe:
  exec:
    command: ["sh", "-c", "kill -0 1"]
  initialDelaySeconds: 10
  periodSeconds: 5
```

The `kill -0 <pid>` command checks if a process exists without sending any signal.
PID 1 is the main container process (gorse-worker).

## Verification
After applying the fix:

```bash
kubectl get pods -n gorse | grep worker
# Should show 1/1 Ready

kubectl describe pod <worker-pod> -n gorse | grep -A5 "Readiness:"
# Should show passing readiness checks
```

## Example
Kustomize patch to fix worker probes:

```yaml
patches:
  - target:
      kind: Deployment
      name: gorse-worker
    patch: |-
      - op: replace
        path: /spec/template/spec/containers/0/livenessProbe
        value:
          exec:
            command: ["sh", "-c", "kill -0 1"]
          initialDelaySeconds: 30
          periodSeconds: 10
      - op: replace
        path: /spec/template/spec/containers/0/readinessProbe
        value:
          exec:
            command: ["sh", "-c", "kill -0 1"]
          initialDelaySeconds: 10
          periodSeconds: 5
```

## Notes
- This issue affects only gorse-worker; gorse-master and gorse-server have HTTP endpoints for probes
- The worker doesn't expose any HTTP endpoints, so exec probes are required
- Alternative: use TCP probe on the gRPC port if the worker exposes one
- This pattern applies to any minimal/distroless container without procps utilities
