# PRD: Private Backend Sync for Drafts & Clips

Status: Proposed (design draft — not yet approved for implementation)
Related: #4828 (feature), part of #4623 (account/session-recovery epic)
Validated against: current mobile architecture on 2026-07-06.

## Status

- **Owner:** mobile team
- **State:** Design proposal, open for review
- **Scope:** Persist and recover creator drafts + clips across sessions and devices, tied to the user's Nostr identity, kept private end-to-end.

This document is a design proposal, not a decided plan. It exists to get the privacy model and the deletion contract reviewed **before** any code lands, because the feature spans several packages (`db_client`, `blossom_upload_service`, `nostr_client`, app services) and the privacy decision is hard to reverse once users have data in the backend.

## Problem

Drafts and clips are local-only today. They are lost on app crash, reinstall, device switch, or accidental data clear. #4828 asks that they be persisted to the backend so unfinished content is automatically recoverable across sessions and devices, linked to the user's Nostr identity, and synced securely.

The hard requirement layered on top: **drafts and clips are unfinished, often personal content and must stay private.** On Nostr everything published to a relay is public by default, so "sync it to Nostr" naively would expose exactly the content we are trying to protect.

## Current state (grounded)

- Metadata lives in Drift tables [`drafts`](../mobile/packages/db_client/lib/src/database/tables.dart) / [`clips`](../mobile/packages/db_client/lib/src/database/tables.dart), already scoped by `owner_pubkey`. The local DB is already encrypted at rest ([`database_encryption_bootstrap.dart`](../mobile/lib/services/database_encryption_bootstrap.dart)).
- Media are local file paths. Media only leaves the device on **publish**, via Blossom ([`blossom_upload_service`](../mobile/packages/blossom_upload_service/), [`upload_manager.dart`](../mobile/lib/services/upload_manager.dart)).
- Local deletion already uses a **reference-counted** model: [`FileCleanupService.deleteFileIfUnreferenced`](../mobile/lib/services/file_cleanup_service.dart) deletes a media file only once no clip/draft row references it. Clips soft-delete to trash (`clips.deleted_at`) and are purged after a retention window ([`ClipLibraryService.purgeExpiredTrash`](../mobile/lib/services/clip_library_service.dart)).

The primitives this feature needs already exist in the codebase:

- **NIP-44 encrypt/decrypt** on the signer ([`local_key_signer.dart`](../mobile/lib/services/local_key_signer.dart)).
- **Encrypt-to-self** is already a shipped pattern: NIP-17 sends a self-addressed gift-wrap so the user's other devices receive the message, and the DM read-cursor is "published encrypted-to-self over Nostr and restored on reinstall" (#4977, see the `Conversations.lastReadTimestamp` comment in `tables.dart`).
- **Encrypted media upload** exists for NIP-17 kind-15 file messages: the file is AES-GCM encrypted, the ciphertext is uploaded, and key/nonce/hash are stored separately (`DirectMessages` kind-15 columns; [`dm_repository.dart`](../mobile/packages/dm_repository/lib/src/dm_repository.dart)).

## Privacy model (the core decision)

Three possible postures:

| Posture | Who can read | Verdict |
|---|---|---|
| Public Nostr event (plaintext) | Anyone with relay access | Rejected — this is the leak |
| **Encrypt-to-self (E2E)** | Only the user, with their key | **Chosen** |
| Private-by-ACL (server enforces owner-only) | The Divine backend, technically | Weaker — server becomes trust anchor |

**Decision: end-to-end, encrypt-to-self.** The user's own key is the only thing that can decrypt draft metadata and clip media. Not the relay, not Divine's backend.

Why not rely on obscurity for media: **Blossom retrieval is public-by-hash.** Auth is enforced on upload (a signed Blossom auth event), but `GET /<sha256>` on a standard Blossom server is unauthenticated. So an *unencrypted* draft clip is retrievable by anyone who learns its hash. Keeping the hash only inside an encrypted draft is security-by-obscurity, not privacy — and the content at stake is raw, unpublished, possibly personal footage the user may never choose to post. Therefore clip media must be **encrypted before upload**, reusing the kind-15 file scheme.

## Proposed architecture

Upload clips as they are created; sync the draft as tiny encrypted JSON.

```
Record clip
  └─> AES-GCM encrypt (per-clip key)
        └─> upload ciphertext to Blossom  ──> content-addressed URL (sha256)

Draft (metadata only, KB-scale)
  └─> NIP-44 encrypt-to-self
        └─> publish as addressable event (NIP-78 kind 30078, or an app-specific
            addressable kind), content = { draft JSON + clip URLs + per-clip keys }
```

Rationale:

- **The draft event stays tiny and nearly free to sync.** It carries references (Blossom URLs/hashes) and decryption keys, not media bytes. Editor state history is the only field that grows, and it is KB, not MB.
- **Content-addressing makes re-sync idempotent.** Editing a draft re-encrypts and republishes the small event; already-uploaded clips are not re-uploaded.
- **Cross-device is automatic.** Any device holding the user's key can fetch the event, decrypt it, pull the referenced ciphertext blobs, and decrypt them.
- **A draft clip is a different artifact from a published video.** The draft clip is an encrypted, non-transcodable blob. When the user actually publishes, the pipeline uploads a fresh **plaintext, transcodable** video (HLS, server thumbnails). There is intentionally no dedup between the two.

## Deletion propagation (explicit requirement)

**When a draft or clip is deleted locally, its backend copy must be deleted too.** This is a first-class requirement, not a follow-up.

- **Draft event:** publish a NIP-09 kind 5 deletion referencing the addressable event, and overwrite the addressable coordinate with an empty tombstone so a relay that ignores kind 5 still serves nothing useful.
- **Clip blob:** delete the ciphertext from Blossom. **Gap:** `blossom_upload_service` currently implements upload only — there is **no BUD-02 `DELETE /<sha256>`** capability. This feature must add authenticated blob deletion, or the backend must run server-side GC that reaps unreferenced hashes. This is called out as an open dependency below.
- **Reference counting must be mirrored server-side.** Locally, `FileCleanupService.deleteFileIfUnreferenced` refuses to delete a file another row still references. The same content-addressed clip can be referenced by more than one draft, so backend deletion must not delete a blob still referenced by another (encrypted) draft the user owns. Naively deleting on every draft delete would corrupt other drafts.
- **Cascade paths:** account deletion / data cleanup ([`user_data_cleanup_service.dart`](../mobile/lib/services/user_data_cleanup_service.dart)) and trash purge (`purgeExpiredTrash`) must both propagate to the backend, not just the local DB.

## Open questions and risks

1. **Where does the "backend" live?** Two shapes: (a) pure Nostr — relay for the encrypted event + Blossom for encrypted blobs, no Divine-owned service; or (b) a Divine-owned service (funnelcake) fronted by NIP-98 auth, which buys quota/retention/resumable-upload control at the cost of centralization. E2E encryption makes (b) acceptable trust-wise, but it is more backend work. **Needs a decision.**
2. **Remote signer (Keycast / NIP-46).** NIP-44 encrypt/decrypt requires RPC round-trips to the bunker. Encrypting keys for many clips could be slow or flaky; the DM path already carries recovery machinery (`pending_gift_wraps`) for exactly this. The sync scheduler must tolerate partial/slow signer availability.
3. **Upload timing vs. wasted uploads.** Uploading every recorded clip immediately also uploads clips the user later discards. Options: upload on first *"save as draft"* rather than on every raw take; or upload-on-record plus aggressive GC when the clip is trashed. Cost knob to decide.
4. **Key loss = data loss.** True E2E means Divine cannot recover a user's drafts if they lose their key. This is the correct trade-off for privacy but must be communicated in the UX.
5. **Relay acceptance.** The chosen event kind must be accepted by the relays we target (the divine relay has stricter policies for some kinds).
6. **Quota / retention / storage cost** for encrypted blobs on Blossom.

## Phasing (proposal)

- **Phase 0** — this design + review (design review gate).
- **Phase 1** — metadata-only encrypted draft sync, no media. Validates the encrypt-to-self publish/restore loop **and** the deletion contract (kind 5 + tombstone) end to end, at low risk.
- **Phase 2** — encrypted clip blobs on Blossom + authenticated Blossom DELETE + server/refcount GC.
- **Phase 3** — background sync service, multi-device conflict resolution, upload-timing policy.

## Non-goals (v1)

- Shared / collaborative drafts.
- Server-side transcoding or preview of draft media (impossible while encrypted, by design).
- Web-client parity.
