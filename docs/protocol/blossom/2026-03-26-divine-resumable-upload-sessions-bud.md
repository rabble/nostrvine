Status: Draft Divine Extension

Mobile client status: Implemented behind capability discovery and legacy fallback in `mobile/packages/blossom_upload_service/lib/src/blossom_upload_service.dart` and `mobile/lib/services/upload_manager.dart`. A fresh publish attempts the OS-backed whole-file `PUT` first (`uploadVideoInBackground`); on failure, or when a persisted resumable session already exists, `uploadVideoWithResume` falls through to the chunked resumable protocol so retries resume from the server's last committed `Upload-Offset` instead of byte 0.

# Divine Resumable Upload Sessions for Blossom

## Summary

This document defines a Divine-specific Blossom extension for resumable uploads. It preserves standard Blossom `PUT /upload` for old clients and adds an optional control-plane flow that issues an opaque upload URL on `upload.divine.video`.

The extension is intentionally storage-agnostic. The client never speaks GCS, S3, or any other storage provider protocol directly by name. It only follows Divine-owned HTTP endpoints and temporary session URLs.

## Goals

- Preserve existing Blossom `PUT /upload`.
- Allow resumable uploads for slow or interrupted mobile networks.
- Keep only the completed object servable as a normal Blossom blob.
- Keep public canonical blob URLs on `media.divine.video`.

## Non-Goals

- Standardize upload chunk blobs as public Blossom objects.
- Require third-party Blossom servers to implement the extension.
- Expose raw storage provider credentials or public bucket endpoints to clients.

## Compatibility

- Clients that do not support this extension continue using signed `PUT /upload`.
- Servers that do not advertise this extension continue receiving signed `PUT /upload`.
- This extension is Divine-only for the initial rollout.

## Capability Discovery

Divine-controlled servers that support resumable sessions advertise a Divine-specific capability on `HEAD /upload`.

Example response headers:

```http
X-Divine-Upload-Extensions: resumable-sessions
X-Divine-Upload-Control-Host: https://media.divine.video
X-Divine-Upload-Data-Host: https://upload.divine.video
```

Clients must treat absence of these headers as "legacy single-shot upload only".
The current mobile implementation probes `HEAD /upload` before each video upload attempt and only enters the resumable flow when `resumable-sessions` is present.

## Control Plane

### `POST /upload/init`

Creates an upload session for a final blob.

Request JSON:

```json
{
  "sha256": "<final blob sha256>",
  "size": 12345678,
  "contentType": "video/mp4",
  "fileName": "clip.mp4"
}
```

Request requirements:

- Blossom-style upload authentication
- Final SHA-256 and final size are required

Successful response:

```json
{
  "uploadId": "up_123",
  "uploadUrl": "https://upload.divine.video/sessions/up_123",
  "expiresAt": "2026-03-26T15:00:00Z",
  "chunkSize": 8388608,
  "nextOffset": 0,
  "requiredHeaders": {
    "Authorization": "Bearer <session token>"
  },
  "capabilities": {
    "resume": true,
    "queryOffset": true
  }
}
```

Rules:

- `uploadUrl` is opaque.
- Clients must not derive semantics from its host or path.
- `requiredHeaders` are scoped to this session only.
- The current mobile client persists `uploadId`, `uploadUrl`, `chunkSize`, `nextOffset`, `expiresAt`, and `requiredHeaders` in `PendingUpload` so interrupted uploads can resume after restart.

### `POST /upload/{uploadId}/complete`

Finalizes the upload session.

Behavior:

- verifies the uploaded bytes exist
- verifies final size matches the declared size
- verifies final SHA-256 matches the declared hash
- promotes the final object into canonical Blossom storage
- returns the normal completed blob descriptor and any Divine streaming fields

Optional request headers:

- `X-ProofMode-Manifest`
- `X-ProofMode-Signature`
- `X-ProofMode-PublicKey`
- `X-ProofMode-Attestation`
- `X-ProofMode-C2PA`

`X-ProofMode-PublicKey` carries the PGP public key matching
`X-ProofMode-Signature`. The two travel together because a signature cannot be
verified from headers alone without it; a server that sees one without the
other must treat the signature as unverified rather than invalid.

When present, these headers carry the same ProofMode metadata that legacy
`PUT /upload` accepts. Clients should send them on `complete` so resumable
uploads preserve the same server-side ProofMode handling without forcing the
video bytes back onto the legacy single-request upload path.

These headers are **supplementary and size-capped**. Servers must not treat
them as the delivery mechanism for the proof: the canonical manifest is the
`proofmode` tag on the kind 34236 event, and the C2PA manifest is embedded in
the uploaded bytes. No Divine Blossom server reads them today.

Clients must keep the combined `X-ProofMode-*` header size within a
conservative budget — the mobile client uses 8 KiB
(`BlossomUploadService.maxProofModeHeaderBytes`) — and drop headers that do
not fit, cheapest-and-most-identifying first.

Measured against `media.divine.video`, combined request headers must stay
under **128 KiB over HTTP/1.1** (past it the edge answers 502) and under
**64 KiB over HTTP/2** (past it the connection is closed mid-request).

An uncapped client sends the device attestation twice — base64 inside
`X-ProofMode-Manifest` and again in `X-ProofMode-Attestation` — so it crosses
128 KiB once the raw attestation passes roughly 47.5 KB, and every upload from
that device then fails with an opaque 502, or with a connection reset while
the body is still streaming on the legacy `PUT /upload` path. Android
attestation size is device-dependent (it is the `X509Certificate.toString()`
dump of the whole chain), so an uncapped client fails on some devices and not
others.

Any future proof payload that can exceed the budget must travel in the
`complete` request body, not in a header.

Example successful response:

```json
{
  "url": "https://media.divine.video/<sha256>",
  "fallbackUrl": "https://media.divine.video/<sha256>",
  "streaming": {
    "hlsUrl": "https://stream.divine.video/<id>/master.m3u8",
    "mp4Url": "https://stream.divine.video/<id>/play_720p.mp4",
    "status": "processing"
  }
}
```

### `DELETE /upload/{uploadId}`

Aborts a pending session and deletes temporary session state.

## Data Plane

### `PUT /sessions/{uploadId}`

Uploads a byte range for a resumable session.

Required headers:

- `Content-Range`
- any server-provided `requiredHeaders`

Body:

- raw bytes for the declared range only

Rules:

- chunks are never public blobs
- server may reject overlapping or invalid ranges
- server may return the next committed offset

### `HEAD /sessions/{uploadId}`

Returns session progress information for resume.

Suggested response headers:

```http
Upload-Offset: 16777216
Upload-Expires-At: 2026-03-26T15:00:00Z
```

Alternative:

- server may return uploaded ranges instead of a single offset if sparse uploads are supported

## Authentication

- `init` requires Blossom-style signed upload auth
- `complete` requires Blossom-style signed upload auth
- session chunk requests use only the short-lived upload-session token returned by `init`

This keeps the heavy chunk path cheap while preserving Blossom ownership of upload authorization.

## Serving Rules

- incomplete uploads are never servable
- incomplete uploads never produce a public blob descriptor
- only a completed, hash-verified object becomes a normal Blossom blob

## Error Handling

- `400`: invalid request body or missing final hash/size
- `401`: invalid Blossom auth or invalid session token
- `404`: unknown session
- `409`: conflicting or overlapping chunk state
- `410`: expired session
- `416`: invalid content range
- `422`: final size or SHA-256 mismatch during completion

Servers should include an explanatory reason in the response body or `X-Reason` header.
The current mobile client treats `404` and `410` session errors as terminal "session expired" failures and clears the persisted resumable session state.

## Storage Backend

This extension is backend-agnostic.

Servers may implement session storage using:

- local temporary files
- object-storage multipart uploads
- resumable provider uploads
- other internal mechanisms

Clients must not depend on backend-specific behavior.

## Notes

- This extension is designed to be easy to upstream later, but it starts as a Divine-only optional feature.
- If the design proves stable, it can be proposed as a draft BUD for broader Blossom adoption.
- Repo-local coverage uses a fake Dio-backed integration test because the resumable upload server endpoints are not implemented in this repository's local stack yet.
