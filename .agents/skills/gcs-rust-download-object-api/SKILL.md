---
name: gcs-rust-download-object-api
description: |
  Fix "DownloadObjectRequest not found" error in google-cloud-storage Rust crate. Use when:
  (1) Trying to download objects from GCS using the Rust SDK, (2) Looking for a download
  request type in http::objects::download module, (3) Compile error about missing type.
  The download_object method uses GetObjectRequest from the get module, not a separate
  DownloadObjectRequest type.
author: Claude Code
version: 1.0.0
date: 2026-01-27
---

# GCS Rust SDK Download Object API

## Problem
When using the `google-cloud-storage` Rust crate to download objects, developers often
look for a `DownloadObjectRequest` type in the `download` module, expecting it to mirror
the upload pattern. This type doesn't exist, causing confusing compile errors.

## Context / Trigger Conditions
- Using `google-cloud-storage` crate in Rust
- Trying to call `client.download_object()`
- Error: `unresolved import google_cloud_storage::http::objects::download::DownloadObjectRequest`
- Looking in `http::objects::download` module for request types

## Solution

The `download_object` method uses `GetObjectRequest` from the `get` module, combined with
`Range` from the `download` module:

```rust
use google_cloud_storage::http::objects::{
    download::Range as DownloadRange,
    get::GetObjectRequest,
};

// Download full object
let data = client.download_object(
    &GetObjectRequest {
        bucket: "my-bucket".to_string(),
        object: "path/to/object".to_string(),
        ..Default::default()
    },
    &DownloadRange::default(),
).await?;

// Download partial object (bytes 0-1023)
let partial = client.download_object(
    &GetObjectRequest {
        bucket: "my-bucket".to_string(),
        object: "path/to/object".to_string(),
        ..Default::default()
    },
    &DownloadRange::Bounded(0, 1023),
).await?;
```

## Verification
Code compiles and `download_object` returns `Vec<u8>` with the object contents.

## Example

```rust
use google_cloud_storage::{
    client::{Client as GcsClient, ClientConfig},
    http::objects::{
        download::Range as DownloadRange,
        get::GetObjectRequest,
        upload::{Media, UploadObjectRequest, UploadType},
    },
};

async fn download_from_gcs(client: &GcsClient, bucket: &str, key: &str) -> Result<Vec<u8>> {
    let data = client.download_object(
        &GetObjectRequest {
            bucket: bucket.to_string(),
            object: key.to_string(),
            ..Default::default()
        },
        &DownloadRange::default(),
    ).await?;

    Ok(data)
}
```

## Notes
- The `Range` type is aliased as `DownloadRange` to avoid conflicts with std::ops::Range
- `DownloadRange::default()` downloads the entire object
- For checking if an object exists without downloading, use `get_object` with `GetObjectRequest`
- The `Media.content_type` field is `Cow<'static, str>`, use `.into()` for string conversion

## References
- [google-cloud-storage crate docs](https://docs.rs/google-cloud-storage)
