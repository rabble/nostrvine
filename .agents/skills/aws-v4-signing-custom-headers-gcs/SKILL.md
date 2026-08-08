---
name: aws-v4-signing-custom-headers-gcs
description: |
  Add custom metadata headers (x-amz-meta-*) to AWS v4 signed requests for GCS S3-compatible
  API. Use when: (1) Adding custom metadata to GCS uploads via S3 API, (2) Getting signature
  mismatch errors after adding new headers, (3) x-amz-meta-* headers being ignored or causing
  403 errors. Custom headers MUST be included in canonical headers and signed headers list.
author: Claude Code
version: 1.0.0
date: 2026-01-20
---

# AWS v4 Signing with Custom Metadata Headers for GCS

## Problem

When adding custom metadata headers (`x-amz-meta-*`) to GCS S3-compatible API requests,
the requests fail with signature mismatch errors. The headers must be properly included
in the AWS v4 signature calculation.

## Context / Trigger Conditions

- Using GCS S3-compatible XML API (not the native JSON API)
- Adding `x-amz-meta-*` headers for object metadata
- Error: "SignatureDoesNotMatch" or 403 Forbidden after adding headers
- Headers work with unsigned requests but fail with AWS v4 signing
- HMAC credentials configured for GCS interoperability

## Solution

Custom headers must be included in **both** the canonical headers and the signed headers list,
sorted **alphabetically**:

### 1. Canonical Headers (alphabetically sorted)

```rust
let canonical_headers = format!(
    "host:{}\nx-amz-content-sha256:{}\nx-amz-date:{}\nx-amz-meta-owner:{}\n",
    host, payload_hash, amz_date, owner  // Note: alphabetical order!
);
```

### 2. Signed Headers List

```rust
let signed_headers = "host;x-amz-content-sha256;x-amz-date;x-amz-meta-owner";
```

### 3. Complete Example (Rust)

```rust
fn sign_request_with_owner(
    req: &mut Request,
    config: &GCSConfig,
    payload_hash: Option<String>,
    owner: &str
) -> Result<()> {
    // Set headers first
    req.set_header("x-amz-date", &amz_date);
    req.set_header("x-amz-content-sha256", &payload_hash);
    req.set_header("x-amz-meta-owner", owner);  // Custom metadata

    // Canonical headers - MUST be alphabetically sorted
    let signed_headers = "host;x-amz-content-sha256;x-amz-date;x-amz-meta-owner";
    let canonical_headers = format!(
        "host:{}\nx-amz-content-sha256:{}\nx-amz-date:{}\nx-amz-meta-owner:{}\n",
        host, payload_hash, amz_date, owner
    );

    // Rest of AWS v4 signing...
    let canonical_request = format!(
        "{}\n{}\n{}\n{}\n{}\n{}",
        method, uri, query, canonical_headers, signed_headers, payload_hash
    );

    // Sign and add Authorization header...
}
```

## Verification

After uploading, verify metadata is present:
```bash
gsutil stat gs://bucket/object-name
# Should show:
#     Metadata:
#         owner: <value>
```

Or via S3 API:
```bash
aws s3api head-object --bucket bucket --key object-name --endpoint-url https://storage.googleapis.com
```

## Example

**Before (broken)** - header not in signature:
```rust
let signed_headers = "host;x-amz-content-sha256;x-amz-date";  // Missing x-amz-meta-owner
req.set_header("x-amz-meta-owner", owner);  // Header added but not signed
// Result: 403 SignatureDoesNotMatch
```

**After (working)** - header properly signed:
```rust
let signed_headers = "host;x-amz-content-sha256;x-amz-date;x-amz-meta-owner";  // Included!
req.set_header("x-amz-meta-owner", owner);
// Include in canonical_headers too
// Result: 200 OK, metadata visible in GCS
```

## Notes

- Header names are case-insensitive but conventionally lowercase in canonical form
- The semicolon-separated signed headers list must match the newline-separated canonical headers
- For GCS, the metadata appears as `Metadata: key: value` in gsutil stat output
- When using the native GCS JSON API, use the `metadata` object field instead
- Multiple custom headers can be added - just ensure all are in canonical/signed lists

## References

- AWS Signature Version 4: https://docs.aws.amazon.com/AmazonS3/latest/API/sig-v4-header-based-auth.html
- GCS S3 Interoperability: https://cloud.google.com/storage/docs/interoperability
- GCS Object Metadata: https://cloud.google.com/storage/docs/metadata
