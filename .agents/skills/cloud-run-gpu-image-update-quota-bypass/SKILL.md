---
name: cloud-run-gpu-image-update-quota-bypass
description: |
  Fix Cloud Run GPU deployment failures caused by quota errors. Use when:
  (1) `gcloud run deploy` fails with "You do not have quota for using GPUs with zonal redundancy"
  AND "You do not have quota for using GPUs without zonal redundancy",
  (2) The service already exists and is running with a GPU,
  (3) You only need to update the container image, not change GPU config.
  Uses `gcloud run services update --image` instead of `gcloud run deploy` to bypass
  quota re-validation on existing GPU services.
author: Claude Code
version: 1.0.0
date: 2026-02-07
---

# Cloud Run GPU Image Update - Quota Bypass

## Problem
When deploying updated container images to an existing Cloud Run service with GPU (e.g., NVIDIA L4),
`gcloud run deploy` fails with quota errors even though the service is already running with a GPU.
The quota check blocks both zonal and non-zonal redundancy configurations, making it impossible
to deploy updated code.

## Context / Trigger Conditions
- `gcloud run deploy` returns:
  ```
  metadata.annotations[run.googleapis.com/maxScale]: You do not have quota for
  using GPUs with zonal redundancy.
  ```
  Followed by:
  ```
  metadata.annotations[run.googleapis.com/maxScale]: You do not have quota for
  using GPUs without zonal redundancy.
  ```
- The GPU service already exists and has a running revision
- You're trying to deploy an updated container image, not change GPU configuration
- The deploy script uses `gcloud run deploy` with `--gpu` flags

## Solution

Instead of `gcloud run deploy` (which re-validates all resource quotas), use
`gcloud run services update` which only updates the specified fields on the existing service:

```bash
# Instead of this (fails with quota error):
gcloud run deploy divine-transcoder \
  --image gcr.io/PROJECT/divine-transcoder \
  --region us-central1 \
  --gpu 1 --gpu-type nvidia-l4 \
  --cpu 4 --memory 16Gi \
  ...

# Use this (updates image on existing service):
gcloud run services update divine-transcoder \
  --region us-central1 \
  --image gcr.io/PROJECT/divine-transcoder:latest
```

Key differences:
- `gcloud run deploy` creates a new service or replaces the full configuration, triggering quota checks
- `gcloud run services update --image` only updates the container image on the existing service,
  preserving all existing GPU/CPU/memory configuration without re-validating quotas

## Verification
```bash
# Verify new revision is active
gcloud run revisions list --service SERVICE_NAME --region REGION --limit=3

# Check the service is serving traffic
gcloud run services describe SERVICE_NAME --region REGION --format='value(status.url)'
```

## Example

```bash
# Build and push updated image
docker build --platform linux/amd64 -t gcr.io/my-project/divine-transcoder .
docker push gcr.io/my-project/divine-transcoder

# Update only the image (bypasses GPU quota re-validation)
gcloud run services update divine-transcoder \
  --region us-central1 \
  --image gcr.io/my-project/divine-transcoder:latest

# Output:
# Deploying...
# Creating Revision...done
# Routing traffic...done
# Service [divine-transcoder] revision [divine-transcoder-00010-vf4] has been deployed
```

## Notes
- This only works for existing services that already have GPU configured
- If you need to change GPU type, CPU, memory, or other settings, you'll need to
  request additional quota via https://g.co/cloudrun/gpu-quota
- First-time GPU deployments in a region get automatic quota of 3 GPUs (non-zonal)
- Quota increases for non-zonal redundancy are granted more quickly than zonal
- If deploy scripts use `gcloud run deploy`, consider adding a fallback to
  `gcloud run services update --image` when quota errors are detected

## References
- [Cloud Run GPU support for services](https://docs.google.com/run/docs/configuring/services/gpu)
- [Cloud Run Quotas and Limits](https://docs.google.com/run/quotas)
- [Cloud Run GPUs GA announcement](https://cloud.google.com/blog/products/serverless/cloud-run-gpus-are-now-generally-available)
