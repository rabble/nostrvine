---
name: gcs-s3-compat-acl-rejection
description: |
  Fix S3 "InvalidArgument" errors when using Google Cloud Storage S3-compatible API
  with ObjectCannedAcl::PublicRead or x-amz-acl headers. Use when: (1) put_object or
  upload_blob fails with InvalidArgument on GCS, (2) Using aws-sdk-s3 Rust crate with
  GCS endpoint (storage.googleapis.com), (3) Bucket has uniform bucket-level access enabled
  (GCS default since 2023), (4) S3 operations work on MinIO/AWS but fail on GCS.
  GCS rejects per-object ACLs when uniform bucket-level access is enabled.
author: Claude Code
version: 1.0.0
date: 2026-03-21
---

# GCS S3-Compatible API ACL Rejection

## Problem
S3 `put_object` calls fail with `InvalidArgument` when targeting Google Cloud Storage
via its S3-compatible API, despite working correctly with MinIO or AWS S3.

## Context / Trigger Conditions
- Using `aws-sdk-s3` (Rust) or any S3 SDK with GCS endpoint
- `AWS_ENDPOINT=https://storage.googleapis.com`
- Error: `Error { code: "InvalidArgument", message: "Invalid argument." }`
- Stack trace shows `S3BlobStore::put_temp` or similar S3 put operation
- The GCS bucket has **uniform bucket-level access** enabled (GCS default)

## Solution
Remove `ObjectCannedAcl::PublicRead` from put_object calls when using GCS:

```rust
// BEFORE (fails on GCS with uniform bucket-level access)
self.client
    .put_object()
    .body(body)
    .bucket(&self.s3_bucket)
    .key(key)
    .acl(ObjectCannedAcl::PublicRead)  // This causes InvalidArgument
    .send()
    .await?;

// AFTER (works with GCS)
self.client
    .put_object()
    .body(body)
    .bucket(&self.s3_bucket)
    .key(key)
    // Remove .acl() — use bucket-level IAM instead
    .send()
    .await?;
```

For public read access, configure the bucket IAM policy instead:
```bash
gsutil iam ch allUsers:objectViewer gs://YOUR_BUCKET
```

Or disable uniform bucket-level access (not recommended):
```bash
gsutil ubla set off gs://YOUR_BUCKET
```

## Verification
After removing the `.acl()` call, upload should succeed:
```bash
curl -X POST "$PDS_URL/xrpc/com.atproto.repo.uploadBlob" \
  -H "Authorization: Bearer $JWT" \
  -H "Content-Type: video/mp4" \
  --data-binary @test.mp4
```

## Notes
- GCS uniform bucket-level access has been the default since 2023
- The `copy_object` call in `move_object()` also uses `.acl(PublicRead)` and will fail
- This affects rsky-pds blob storage: `rsky-pds/src/actor_store/aws/s3.rs` lines 69, 97, 212
- MinIO doesn't enforce this restriction, so local dev works but production GCS fails
- The same issue applies to `put_permanent()` and `move_object()` methods
