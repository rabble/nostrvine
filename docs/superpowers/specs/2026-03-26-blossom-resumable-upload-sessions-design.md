Status: Implemented In Mobile Client

# Blossom Resumable Upload Sessions Design

**Problem**

Divine's current mobile upload path is a single Blossom `PUT /upload` request. That keeps the client simple, but it is brittle on slow mobile networks and does not survive app restarts or backgrounding well. We need a Divine-owned resumable upload flow that preserves Blossom compatibility, keeps old clients working, and does not expose incomplete chunks as public blobs.

**Goals**

- Keep existing `PUT /upload` behavior working for old clients.
- Add a Divine-only resumable upload session flow for `media.divine.video`.
- Keep the control plane on a Blossom-owned host and move the heavy data plane to `upload.divine.video`.
- Support resume after app restart and backgrounding.
- Make only the completed object servable; chunks must remain temporary session state.
- Keep storage backend details out of the mobile client.

**Non-Goals**

- Standardize resumable uploads across all Blossom servers in this worktree.
- Expose GCS, S3, or other storage provider semantics directly to the app.
- Make upload chunks independently addressable blobs.
- Remove or deprecate the existing `PUT /upload` path.

**Current Code References**

- `mobile/lib/services/blossom_upload_service.dart`
- `mobile/lib/services/upload_manager.dart`
- `mobile/lib/models/pending_upload.dart`
- `mobile/lib/providers/app_providers.dart`
- `mobile/test/services/blossom_upload_service_test.dart`
- `mobile/test/services/blossom_upload_proofmode_test.dart`
- `mobile/test/services/upload_manager_from_draft_test.dart`
- `mobile/test/services/upload_manager_thumbnail_test.dart`
- `mobile/test/integration/blossom_upload_spec_test.dart`
- `local_stack/blossom-proxy/default.conf.template`

**Research Notes**

- Blossom BUDs currently define single-request upload semantics around `PUT /upload` and `HEAD /upload` preflight.
- `hzrd149/blossom-server` already models the right server boundary: Blossom on the front door, local or S3-compatible storage behind the server.
- No upstream Blossom-native resumable upload standard or commonly adopted implementation was found during research.

**Proposed Design**

1. Keep the current Blossom upload path untouched.
   - Old clients continue using signed `PUT /upload`.
   - Third-party Blossom servers continue using plain `PUT /upload` unless they explicitly advertise resumable support.

2. Add a Divine-only resumable upload extension.
   - Control plane remains on `media.divine.video`.
   - New `POST /upload/init` creates a resumable upload session and returns an opaque `uploadUrl` on `upload.divine.video`.
   - The client treats `uploadUrl` as an opaque tokenized endpoint and never derives meaning from its host or path.

3. Make upload sessions non-servable.
   - Session chunks are never public blobs.
   - `upload.divine.video` accepts `PUT` and `HEAD` for session data only.
   - Only `complete` promotes the assembled object into canonical Blossom storage and returns the final blob descriptor.

4. Keep the final object content-addressed.
   - `init` declares the final SHA-256, size, and content type.
   - `complete` verifies the assembled object matches the declared final SHA-256 and size before promotion.
   - The canonical public URL remains the normal Blossom URL on `media.divine.video/{sha256}`.

5. Persist resumable session state locally.
   - `PendingUpload` stores resumable session metadata such as `uploadId`, `uploadUrl`, `nextOffset`, `chunkSize`, `sessionExpiresAt`, and any scoped upload token or required headers.
   - `UploadManager` resumes from the last committed offset after app restart or app lifecycle interruptions.

**Protocol Summary**

Control plane on `media.divine.video`:

- `HEAD /upload`
  - Existing preflight remains.
  - Divine servers may advertise resumable session support with Divine-specific capability headers.

- `POST /upload/init`
  - Request includes final `sha256`, `size`, `contentType`, optional file metadata, and Blossom-style auth.
  - Response includes:
    - `uploadId`
    - `uploadUrl`
    - `expiresAt`
    - `chunkSize`
    - `requiredHeaders`
    - `nextOffset`
    - capability flags such as `resume` and `queryOffset`

- `POST /upload/{uploadId}/complete`
  - Verifies upload integrity, promotes the final object into canonical storage, and returns the normal Blossom blob descriptor plus Divine streaming fields.

- `DELETE /upload/{uploadId}`
  - Aborts a resumable session.

Data plane on `upload.divine.video`:

- `PUT /sessions/{id}`
  - Accepts chunk bytes with `Content-Range`.
  - Uses a short-lived upload-session token or server-supplied required headers.

- `HEAD /sessions/{id}`
  - Reports committed offset or received ranges for resume.

- No `GET`
  - Session uploads are never public and never return a blob descriptor.

**Capability Discovery**

- Divine resumable support should be explicitly advertised.
- For the first version, capability discovery can ride on `HEAD /upload` headers on Divine-controlled hosts.
- Custom servers remain on `PUT /upload` unless they advertise the extension.

**Authentication And Security**

- `init` and `complete` require Blossom-style signed upload auth.
- `uploadUrl` is opaque and short-lived.
- Session uploads are tightly scoped to one upload session and one declared final object.
- No storage provider credentials are ever exposed to the client.
- Incomplete sessions expire and are garbage-collected.

**Mobile Architecture**

- `BlossomUploadService` grows a second path:
  - legacy single-shot upload
  - Divine resumable session upload
- `UploadManager` decides whether to use resumable upload based on server support and host ownership.
- `PendingUpload` persists resumable session fields so interrupted uploads can resume.
- The app continues publishing the normal canonical blob URL and streaming URLs after completion.

**Implementation Notes**

- The mobile client now probes `HEAD /upload` before each video upload attempt and stays on legacy `PUT /upload` unless `X-Divine-Upload-Extensions: resumable-sessions` is present.
- `PendingUpload` persists a `BlossomResumableUploadSession` value with `uploadId`, `uploadUrl`, `chunkSize`, `nextOffset`, `expiresAt`, and `requiredHeaders`.
- `UploadManager.initialize()` now auto-resumes persisted `uploading` and `retrying` records that still have resumable session state.
- `404` and `410` session failures are treated as terminal expired-session errors. The upload record moves to `failed` and clears the persisted session so the next user retry starts clean.
- ProofMode metadata rides on the resumable `complete` request so ProofMode-backed videos can still use resumable chunk uploads without falling back to legacy `PUT /upload`.

**File Boundaries**

- Protocol and handoff docs:
  - `docs/protocol/blossom/2026-03-26-divine-resumable-upload-sessions-bud.md`
- Existing mobile upload flow:
  - `mobile/lib/services/blossom_upload_service.dart`
  - `mobile/lib/services/upload_manager.dart`
  - `mobile/lib/models/pending_upload.dart`
  - `mobile/lib/providers/app_providers.dart`
- New mobile model/helper files:
  - `mobile/lib/models/blossom_resumable_upload_session.dart`
  - `mobile/lib/services/blossom_resumable_upload_client.dart`

**Verification**

- Model tests for persisted resumable session state.
- Service tests for:
  - capability discovery
  - `init` request/response handling
  - chunk upload retry and resume offset handling
  - `complete` fallback to legacy failure behavior
- UploadManager tests for:
  - resume after restart
  - resume after app backgrounding
  - fallback to legacy `PUT /upload` for unsupported servers
- Integration coverage for the Divine resumable happy path using a Dio-backed fake protocol server in `mobile/test/integration/blossom_resumable_upload_integration_test.dart`.
- Local harness now routes both `media.divine.video` and `upload.divine.video` through `local_stack/blossom-proxy/default.conf.template` so host separation can be exercised once the server endpoints exist.

**Risks**

- Server and client can drift if the Divine extension is not documented as a concrete contract.
- Persisted resumable state adds Hive schema churn and generated file updates.
- If the mobile client accidentally normalizes `uploadUrl` into canonical media URLs, the public blob URLs will break.
- Session expiry and local resume state can create confusing retry loops if error handling is vague.

**Recommendation**

Ship the Divine-only extension first, keep the client protocol under our own domain, and document it as a draft Divine BUD that is clean enough to upstream later if the design proves stable.
