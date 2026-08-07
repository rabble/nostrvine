---
name: gorse-runasnonroot-failure
description: |
  Fix Gorse recommendation engine pods crashing with "user: unknown userid 65532" error.
  Use when: (1) Gorse master/server/worker pods show CrashLoopBackOff or Error status,
  (2) Logs show "failed to get user directory" with unknown userid, (3) Running gorse
  containers with runAsNonRoot security context and custom UID. The gorse images call
  os.UserHomeDir() at startup which requires the UID to exist in /etc/passwd.
author: Claude Code
version: 1.0.0
date: 2026-01-29
---

# Gorse runAsNonRoot Container Failure

## Problem
Gorse recommendation engine containers (master, server, worker) crash immediately on
startup when running with Kubernetes `runAsNonRoot: true` and a custom UID like 65532.

## Context / Trigger Conditions
- Gorse pods show `CrashLoopBackOff` or `Error` status
- Pod logs show:
  ```
  {"level":"fatal","ts":...,"caller":"model/built_in.go:95","msg":"failed to get user directory","error":"user: unknown userid 65532"}
  ```
- Deployment has `securityContext.runAsNonRoot: true` and `runAsUser: 65532`
- Using official gorse images (`zhenghaoz/gorse-master`, `zhenghaoz/gorse-server`, `zhenghaoz/gorse-worker`)

## Root Cause
The gorse codebase calls Go's `os.UserHomeDir()` during initialization in `model/built_in.go`.
This function requires the running UID to have an entry in `/etc/passwd`. When running as
a non-root user that doesn't exist in the container's passwd file, the lookup fails.

## Solution
Remove the `runAsNonRoot` and `runAsUser` constraints from the pod security context:

```yaml
# Before (broken)
spec:
  template:
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 65532
        fsGroup: 65532

# After (working)
spec:
  template:
    spec:
      securityContext:
        fsGroup: 1000
```

Apply to all gorse deployments:
- `deployment-master.yaml`
- `deployment-server.yaml`
- `deployment-worker.yaml`
- `init-db-job.yaml` (if using init job)

## Verification
After updating the security context:
1. Delete existing crashing pods: `kubectl delete pods -l app.kubernetes.io/name=gorse -n gorse`
2. Wait for new pods to start
3. Check logs: `kubectl logs -l app=gorse-master -n gorse`
4. Verify master shows connection to data store and cache store

## Notes
- This is a limitation of the official gorse images, not a Kubernetes issue
- The gorse project may fix this in future versions by not requiring home directory
- If security policy requires non-root, you would need to build custom gorse images
  with proper `/etc/passwd` entries for the desired UID
- Redis Stack images used for gorse cache have the same issue with UID 65532

## Related Issues
- Gorse GitHub: The images don't document this requirement
- Similar issues affect other Go applications that use `os.UserHomeDir()`
