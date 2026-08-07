---
name: cloud-run-job-cloudsql-setup
description: |
  Set up Cloud Run Jobs with CloudSQL connection. Use when: (1) Deploying long-running
  batch jobs that need database access, (2) Errors like "Cloud SQL Proxy not found" in
  container, (3) "password authentication failed" despite correct credentials, (4) Job
  creation fails with permission errors. Covers socket path configuration, IAM permissions,
  and common gotchas.
author: Claude Code
version: 1.0.0
date: 2026-01-31
---

# Cloud Run Job with CloudSQL Setup

## Problem
Setting up Cloud Run Jobs to connect to CloudSQL involves multiple non-obvious steps
and gotchas that cause confusing errors. The main issues are:
1. Wrong gcloud flags for CloudSQL connection
2. Incorrect socket path configuration
3. Missing IAM permissions
4. App code trying to start proxy when Cloud Run already provides it

## Context / Trigger Conditions
- Error: "unrecognized arguments: --add-cloudsql-instances" (wrong flag name)
- Error: "Cloud SQL Proxy not found" (app trying to start proxy in container)
- Error: "password authentication failed" (socket path misconfigured or newline in secret)
- Error: "Permission denied on secret" (missing secretAccessor role)
- Error: "does not have permission to access namespaces" (missing cloudsql.client role)

## Solution

### 1. Create the Job with Correct Flags

```bash
gcloud run jobs create my-job \
  --region=us-central1 \
  --image=gcr.io/PROJECT/IMAGE:latest \
  --set-cloudsql-instances=PROJECT:REGION:INSTANCE \  # NOT --add-cloudsql-instances
  --set-env-vars="POSTGRES_SOCKET_PATH=/cloudsql/PROJECT:REGION:INSTANCE,POSTGRES_DATABASE=mydb,POSTGRES_USER=myuser" \
  --set-secrets="POSTGRES_PASSWORD=my-secret:latest"
```

**Key:** Use `--set-cloudsql-instances` NOT `--add-cloudsql-instances`

### 2. Configure Socket Path in App

For Node.js with `pg` library:
```typescript
// Use socketPath for unix socket, not host
if (config.socketPath) {
  pool = new Pool({
    host: config.socketPath,  // e.g., "/cloudsql/project:region:instance"
    database: config.database,
    user: config.user,
    password: config.password,
  });
}
```

Environment variable: `POSTGRES_SOCKET_PATH=/cloudsql/PROJECT:REGION:INSTANCE`

### 3. Grant Required IAM Permissions

```bash
# Secret access
gcloud secrets add-iam-policy-binding my-secret \
  --member="serviceAccount:PROJECT_NUMBER-compute@developer.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"

# CloudSQL connection
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:PROJECT_NUMBER-compute@developer.gserviceaccount.com" \
  --role="roles/cloudsql.client"
```

### 4. Don't Auto-Start Proxy in Container

Cloud Run automatically provides the CloudSQL proxy socket. If your app has logic to
start the proxy, skip it when a socket path is configured:

```typescript
// Skip proxy start if socketPath provided (Cloud Run handles it)
if (!config.socketPath && config.host === "localhost") {
  await ensureCloudSqlProxy();  // Only for local development
}
```

### 5. Create Secrets Without Newlines

```bash
# WRONG - adds trailing newline
gcloud secrets create my-secret --data-file=- <<< "password"

# CORRECT - no trailing newline
echo -n "password" | gcloud secrets create my-secret --data-file=-
```

## Verification

```bash
# Check job config
gcloud run jobs describe my-job --region=us-central1

# Execute and check logs
gcloud run jobs execute my-job --region=us-central1
gcloud run jobs logs read my-job --region=us-central1 --limit=50
```

## Example: Complete Setup

```bash
# 1. Create secrets (no newlines!)
echo -n "dbpassword123" | gcloud secrets create db-password --data-file=-

# 2. Grant permissions
gcloud secrets add-iam-policy-binding db-password \
  --member="serviceAccount:123456789-compute@developer.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"

# 3. Create job
gcloud run jobs create my-processor \
  --region=us-central1 \
  --image=gcr.io/my-project/processor:latest \
  --memory=4Gi \
  --cpu=2 \
  --task-timeout=86400s \
  --max-retries=3 \
  --set-cloudsql-instances=my-project:us-central1:my-instance \
  --set-env-vars="POSTGRES_SOCKET_PATH=/cloudsql/my-project:us-central1:my-instance,POSTGRES_DATABASE=mydb,POSTGRES_USER=myuser" \
  --set-secrets="POSTGRES_PASSWORD=db-password:latest"

# 4. Execute
gcloud run jobs execute my-processor --region=us-central1
```

## Notes
- Cloud Run Job timeout max is 86400s (24 hours)
- The socket path format is `/cloudsql/PROJECT:REGION:INSTANCE`
- Socket appears as a Unix socket at that path when container starts
- No need for Cloud SQL Proxy binary in your container
- Cloud Build service account needs different permissions than the compute service account
- **PostgreSQL password reset gotcha**: When resetting Cloud SQL PostgreSQL passwords, do NOT use `--host='%'`. That flag is MySQL-specific and creates a separate user entry in PostgreSQL, causing intermittent password auth failures (some jobs connect, others don't, despite identical DATABASE_URL). Use: `gcloud sql users set-password USERNAME --instance=INSTANCE --password=PASSWORD` (no `--host` flag)
- Password changes may take a minute to propagate through Cloud SQL Auth Proxy sidecars. If auth fails immediately after a reset, redeploy the job to force a fresh proxy connection

## References
- https://cloud.google.com/run/docs/configuring/connect-cloudsql
- https://cloud.google.com/sql/docs/postgres/connect-run
