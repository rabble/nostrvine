---
name: cloud-scheduler-permission-denied
description: |
  Fix Google Cloud Scheduler silently failing to trigger Cloud Run jobs with status code 7
  (PERMISSION_DENIED). Use when: (1) Cloud Run jobs stop running but schedulers show ENABLED,
  (2) gcloud scheduler jobs describe shows lastAttemptTime but status.code: 7,
  (3) Jobs worked before but stopped after IAM changes or project updates.
  The scheduler service account needs roles/run.invoker on the project.
author: Claude Code
version: 1.0.0
date: 2026-02-08
---

# Cloud Scheduler Permission Denied (Code 7)

## Problem
Cloud Scheduler jobs silently fail to trigger Cloud Run jobs. The scheduler shows as
ENABLED, attempts are made (lastAttemptTime updates), but Cloud Run jobs never start.
The only indicator is `status.code: 7` which means PERMISSION_DENIED.

## Context / Trigger Conditions
- Cloud Run jobs previously ran on schedule but stopped
- Dashboard shows jobs as "FAILED" or "DONE" with old timestamps
- `gcloud scheduler jobs describe <name>` shows:
  ```
  lastAttemptTime: '2026-02-08T14:00:03.316530Z'
  state: ENABLED
  status:
    code: 7
  ```
- No obvious errors in Cloud Logging for the scheduler

## Solution

1. **Identify the scheduler's service account**:
   ```bash
   gcloud scheduler jobs describe <scheduler-name> \
     --location=<region> \
     --project=<project> \
     --format="yaml(httpTarget.oauthToken.serviceAccountEmail)"
   ```

2. **Grant run.invoker role to that service account**:
   ```bash
   gcloud projects add-iam-policy-binding <project-id> \
     --member="serviceAccount:<service-account-email>" \
     --role="roles/run.invoker"
   ```

3. **Test by manually triggering the scheduler**:
   ```bash
   gcloud scheduler jobs run <scheduler-name> \
     --location=<region> \
     --project=<project>
   ```

4. **Verify the Cloud Run job started**:
   ```bash
   gcloud run jobs executions list \
     --region=<region> \
     --project=<project> \
     --limit=5
   ```

## Verification
After granting permissions and triggering:
- `status.code` should no longer be 7 on next attempt
- New Cloud Run job execution should appear in executions list
- Execution should show RUNNING status

## Example

```bash
# Check scheduler status - note code: 7
gcloud scheduler jobs describe profile-crawler-schedule \
  --location=us-central1 \
  --project=my-project

# Grant permission
gcloud projects add-iam-policy-binding my-project \
  --member="serviceAccount:my-scheduler@my-project.iam.gserviceaccount.com" \
  --role="roles/run.invoker"

# Test
gcloud scheduler jobs run profile-crawler-schedule \
  --location=us-central1 \
  --project=my-project
```

## Notes
- Status code 7 is gRPC's PERMISSION_DENIED - not documented prominently for Cloud Scheduler
- This commonly happens after:
  - Creating new service accounts
  - Migrating projects
  - IAM policy updates that remove inherited permissions
  - Using a custom service account instead of the default
- The scheduler will keep attempting (and failing) silently - no alerts by default
- Consider adding Cloud Monitoring alerts for scheduler failures

## References
- [Cloud Scheduler HTTP targets](https://cloud.google.com/scheduler/docs/http-target-auth)
- [Cloud Run IAM roles](https://cloud.google.com/run/docs/reference/iam/roles)
- [gRPC status codes](https://grpc.io/docs/guides/status-codes/)
